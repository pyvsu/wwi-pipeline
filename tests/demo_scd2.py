"""demo_scd2.py : prove SCD2 on dim_customer using the real ingest + SQL files.
Run from the repo root: python -m tests.demo_scd2
Writes evidence to docs/evidence/scd2_demo_stage1.md
"""
import contextlib
import io
from pathlib import Path

import duckdb

from src.ingest import end_run, ingest_all, start_run

BATCH_DATE = "2015-01-01"
DIM_FILES = [
    "sql/03_dim_date.sql",
    "sql/03_dim_city.sql",
    "sql/03_dim_employee.sql",
    "sql/03_dim_stock_item.sql",
    "sql/03_bridge_stock_item_group.sql",
]
EVIDENCE = Path("docs/evidence/scd2_demo_stage1.md")


def run_sql(con, path, batch_date=None):
    text = Path(path).read_text()
    if batch_date:
        text = text.replace("{{batch_date}}", batch_date)
    con.execute(text)


def ingest(con, batch_id):
    run_sql(con, "sql/00_etl_ddl.sql")
    run_sql(con, "sql/01_oltp_ddl.sql")
    run_id = start_run(con, batch_id)
    try:
        with contextlib.redirect_stdout(io.StringIO()):  # hide the 18 table lines
            ingest_all(con, run_id, batch_id)
        end_run(con, run_id, "SUCCESS")
    except Exception as error:
        end_run(con, run_id, "FAILED", str(error))
        raise


def run_batch_1(con):
    con.execute("DROP SCHEMA IF EXISTS dw CASCADE")
    con.execute("DROP SCHEMA IF EXISTS staging CASCADE")
    run_sql(con, "sql/02_olap_ddl.sql")
    ingest(con, 1)
    for f in DIM_FILES:
        run_sql(con, f)
    run_sql(con, "sql/03_dim_customer_stage.sql")
    run_sql(con, "sql/03_dim_customer_initial.sql")


def run_batch_2(con):
    ingest(con, 2)
    for f in DIM_FILES:
        run_sql(con, f)
    run_sql(con, "sql/03_dim_customer_stage.sql")
    run_sql(con, "sql/03_dim_customer_scd2.sql", BATCH_DATE)


def totals(con):
    return con.execute(
        """
        SELECT COUNT(*), COUNT(*) FILTER (WHERE is_current), MAX(customer_key)
        FROM dw.dim_customer
        """
    ).fetchone()


def snapshot(con, title):
    rows = con.execute(
        """
        SELECT customer_key, customer_id, customer_category_name,
               buying_group_name, effective_from, effective_to, is_current
        FROM dw.dim_customer
        WHERE customer_id BETWEEN 1 AND 8
        ORDER BY customer_id, effective_from
        """
    ).fetchall()
    total, current, max_key = totals(con)
    lines = [
        f"### {title}",
        "",
        f"rows={total}  current={current}  max_key={max_key}",
        "",
        "| key | id | category | buying group | from | to | current |",
        "|---|---|---|---|---|---|---|",
    ]
    lines += ["| " + " | ".join(str(v) for v in r) + " |" for r in rows]
    text = "\n".join(lines) + "\n"
    print(text)
    return text


con = duckdb.connect("wwi.duckdb")
report = ["# SCD2 demo, Stage 1 (dim_customer)", ""]

run_batch_1(con)
report.append(snapshot(con, "BEFORE: after batch 1"))
assert totals(con)[:2] == (664, 664), totals(con)

run_batch_2(con)
report.append(snapshot(con, f"AFTER: batch 2 (effective {BATCH_DATE})"))
assert totals(con)[:2] == (668, 664), totals(con)  # 4 customers got a new version

run_batch_2(con)
report.append(snapshot(con, "AFTER: batch 2 run a second time (must be identical)"))
assert totals(con)[:2] == (668, 664), totals(con)  # re-run adds nothing

overlaps = con.execute(
    """
    SELECT COUNT(*)
    FROM dw.dim_customer a
    JOIN dw.dim_customer b
      ON a.customer_id = b.customer_id
     AND a.customer_key < b.customer_key
     AND a.effective_from <= b.effective_to
     AND b.effective_from <= a.effective_to
    """
).fetchone()[0]
assert overlaps == 0, overlaps
print("ALL CHECKS PASSED: 664 -> 668 rows, 4 closed, 0 overlaps, re-run adds nothing")

EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
EVIDENCE.write_text("\n".join(report))
print(f"evidence written to {EVIDENCE}")
