"""run_pipeline.py : ONE entry point for the whole WWI pipeline.

    python run_pipeline.py --batch 1
    python run_pipeline.py --batch 2 --effective-date 2015-01-01

Batch 1 = fresh build (drops dw + staging). Batch 2 = apply changes on top.
"""
import argparse
import contextlib
import io
import sys
import time
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace

import duckdb

from src.dq import raise_on_critical, run_checks, save_evidence
from src.ingest import LOAD_ORDER, csv_path, end_run, ingest_all, start_run
from src.logger import get_logger

DB_FILE = "wwi.duckdb"

SCD1_DIM_FILES = [
    "sql/03_dim_date.sql",
    "sql/03_dim_city.sql",
    "sql/03_dim_employee.sql",
    "sql/03_dim_stock_item.sql",
    "sql/03_bridge_stock_item_group.sql",
]

COUNT_TABLES = [
    "oltp.customers", "oltp.orders", "oltp.order_lines",
    "oltp.invoices", "oltp.invoice_lines",
    "dw.dim_date", "dw.dim_city", "dw.dim_customer", "dw.dim_employee",
    "dw.dim_stock_item", "dw.bridge_stock_item_group",
    "dw.fact_order", "dw.fact_sale",
]


# ---------- helpers ----------

def run_sql(con, path: str, **params) -> None:
    """Run a .sql file. {{name}} placeholders are replaced from params."""
    text = Path(path).read_text()
    for key, value in params.items():
        text = text.replace("{{" + key + "}}", str(value))
    con.execute(text)


def count_rows(con, table: str) -> int:
    return con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]


def log_output(ctx, fn, *args):
    """Run fn, send anything it prints to the logger, return its result."""
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        result = fn(*args)
    for line in buffer.getvalue().splitlines():
        if line.strip():
            ctx.log.info("  " + line)
    return result


# ---------- the 9 steps ----------

def step_validate_sources(ctx) -> None:
    paths = [csv_path(source, ctx.batch) for source, _ in LOAD_ORDER]
    missing = [p for p in paths if not Path(p).exists()]
    if missing:
        raise FileNotFoundError("Missing source files: " + ", ".join(missing))
    ctx.log.info(f"  all {len(paths)} source files found")


def step_prepare_oltp(ctx) -> None:
    run_sql(ctx.con, "sql/01_oltp_ddl.sql")


def step_ingest(ctx) -> None:
    log_output(ctx, ingest_all, ctx.con, ctx.run_id, ctx.batch)


def step_validate_oltp(ctx) -> None:
    rows = ctx.con.execute(
        """
        SELECT target_table, rows_read, rows_loaded, rows_duplicate, rows_rejected
        FROM etl.ingestion_log
        WHERE run_id = ?
        ORDER BY loaded_at
        """,
        [ctx.run_id],
    ).fetchall()
    if len(rows) != len(LOAD_ORDER):
        raise ValueError(f"Expected {len(LOAD_ORDER)} ingested tables, found {len(rows)}")

    problems = []
    for table, read, loaded, dup, rejected in rows:
        in_table = count_rows(ctx.con, f"oltp.{table}")
        if read != loaded + dup + rejected or loaded != in_table:
            problems.append(table)
        if rejected:
            ctx.log.warning(f"  {table}: {rejected:,} values rejected (see etl.rejected_rows)")
    if problems:
        raise ValueError("OLTP load does not reconcile: " + ", ".join(problems))
    ctx.log.info(f"  {len(rows)} tables reconcile: read = loaded + duplicate + rejected")


def step_prepare_olap(ctx) -> None:
    if ctx.batch == 1:
        ctx.con.execute("DROP SCHEMA IF EXISTS dw CASCADE")
        ctx.con.execute("DROP SCHEMA IF EXISTS staging CASCADE")
        ctx.log.info("  batch 1: dropped dw and staging for a fresh build")
    run_sql(ctx.con, "sql/02_olap_ddl.sql")
    run_sql(ctx.con, "sql/04_fact_ddl.sql")
    if ctx.batch == 2 and count_rows(ctx.con, "dw.dim_customer") == 0:
        raise RuntimeError(
            "Batch 2 needs an existing warehouse. Run: python run_pipeline.py --batch 1"
        )


def step_load_dimensions(ctx) -> None:
    for path in SCD1_DIM_FILES:
        run_sql(ctx.con, path)
        ctx.log.info(f"  loaded {Path(path).stem}")
    run_sql(ctx.con, "sql/03_dim_customer_stage.sql")
    if ctx.batch == 1:
        run_sql(ctx.con, "sql/03_dim_customer_initial.sql")
    else:
        run_sql(ctx.con, "sql/03_dim_customer_scd2.sql", batch_date=ctx.effective_date)
    total, current = ctx.con.execute(
        "SELECT COUNT(*), COUNT(*) FILTER (WHERE is_current) FROM dw.dim_customer"
    ).fetchone()
    ctx.log.info(f"  dim_customer (SCD2): {total:,} rows, {current:,} current")


def step_load_facts(ctx) -> None:
    for name in ("order", "sale"):
        run_sql(ctx.con, f"sql/04_fact_{name}.sql", run_id=ctx.run_id)
        ctx.log.info(f"  fact_{name}: {count_rows(ctx.con, f'dw.fact_{name}'):,} rows loaded")


def step_final_dq(ctx) -> None:
    results = log_output(ctx, run_checks, ctx.con, ctx.run_id)
    save_evidence(ctx.con, ctx.run_id)
    warnings = [name for name, severity, _, status in results
                if severity == "WARNING" and status == "FAIL"]
    if warnings:
        ctx.log.warning("  WARNING checks failed (run continues): " + ", ".join(warnings))
    raise_on_critical(results)


def step_write_result(ctx) -> None:
    for table in COUNT_TABLES:
        ctx.log.info(f"  rows {table:<30}{count_rows(ctx.con, table):>10,}")
    end_run(ctx.con, ctx.run_id, "SUCCESS")


STEPS = [
    ("Validate source files", step_validate_sources),
    ("Prepare OLTP schema", step_prepare_oltp),
    ("Ingest CSVs into OLTP", step_ingest),
    ("Validate OLTP load", step_validate_oltp),
    ("Prepare OLAP schemas and staging", step_prepare_olap),
    ("Load dimensions (incl. SCD2)", step_load_dimensions),
    ("Load facts", step_load_facts),
    ("Final data quality checks", step_final_dq),
    ("Write pipeline result", step_write_result),
]


# ---------- runner ----------

def run_step(ctx, number: int, name: str, fn) -> None:
    ctx.log.info(f"STEP {number}/{len(STEPS)} START  {name}")
    started = time.perf_counter()
    try:
        fn(ctx)
    except Exception as error:
        with contextlib.suppress(Exception):
            ctx.con.execute("ROLLBACK")  # never leave a transaction open
        ctx.log.error(f"STEP {number}/{len(STEPS)} FAILED {name}: {error}")
        raise
    ctx.log.info(f"STEP {number}/{len(STEPS)} DONE   {name} ({time.perf_counter() - started:.1f}s)")


def parse_args():
    parser = argparse.ArgumentParser(description="Run the WWI data pipeline.")
    parser.add_argument("--batch", type=int, choices=[1, 2], required=True,
                        help="1 = fresh build, 2 = apply customer changes (SCD2)")
    parser.add_argument("--effective-date", help="YYYY-MM-DD. Required for --batch 2")
    args = parser.parse_args()
    if args.batch == 2:
        if not args.effective_date:
            parser.error("--effective-date is required for --batch 2")
        try:
            datetime.strptime(args.effective_date, "%Y-%m-%d")
        except ValueError:
            parser.error("--effective-date must look like 2015-01-01")
    return args


def main() -> None:
    args = parse_args()
    log = get_logger()
    con = duckdb.connect(DB_FILE)

    run_sql(con, "sql/00_etl_ddl.sql")          # step 0: audit tables
    run_id = start_run(con, args.batch)
    ctx = SimpleNamespace(con=con, log=log, run_id=run_id,
                          batch=args.batch, effective_date=args.effective_date)

    log.info("=" * 70)
    log.info(f"PIPELINE START run_id={run_id} batch={args.batch} "
             f"effective_date={args.effective_date}")
    try:
        for number, (name, fn) in enumerate(STEPS, start=1):
            run_step(ctx, number, name, fn)
    except Exception as error:
        end_run(con, run_id, "FAILED", str(error))
        log.error(f"PIPELINE FAILED run_id={run_id}: {error}")
        con.close()
        sys.exit(1)

    log.info(f"PIPELINE SUCCESS run_id={run_id}")
    con.close()


if __name__ == "__main__":
    main()
