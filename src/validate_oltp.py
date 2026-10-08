"""validate_oltp.py : checks after the CSV -> OLTP load.

Writes docs/evidence/oltp_validation.txt.
Run: python -m src.validate_oltp
"""
import sys
from pathlib import Path

import duckdb

from src.ingest import LOAD_ORDER, csv_path, csv_source

OUT_FILE = Path("docs/evidence/oltp_validation.txt")

# Each check counts BAD rows. 0 = PASS.
CHECKS = [
    (
        "customers.bill_to_customer_id points to a real customer",
        """
        SELECT COUNT(*)
        FROM oltp.customers AS c
        LEFT JOIN oltp.customers AS parent
               ON parent.customer_id = c.bill_to_customer_id
        WHERE parent.customer_id IS NULL
        """,
    ),
    (
        "orders.backorder_order_id points to a real order",
        """
        SELECT COUNT(*)
        FROM oltp.orders AS o
        LEFT JOIN oltp.orders AS parent
               ON parent.order_id = o.backorder_order_id
        WHERE o.backorder_order_id IS NOT NULL
          AND parent.order_id IS NULL
        """,
    ),
    (
        "(order_id, stock_item_id) is unique in order_lines",
        """
        SELECT COUNT(*)
        FROM (
            SELECT order_id, stock_item_id
            FROM oltp.order_lines
            GROUP BY order_id, stock_item_id
            HAVING COUNT(*) > 1
        )
        """,
    ),
    (
        "order salespeople exist in people as employees",
        """
        SELECT COUNT(*)
        FROM oltp.orders AS o
        LEFT JOIN oltp.people AS p
               ON p.person_id = o.salesperson_person_id AND p.is_employee
        WHERE p.person_id IS NULL
        """,
    ),
    (
        "invoice salespeople exist in people as employees",
        """
        SELECT COUNT(*)
        FROM oltp.invoices AS i
        LEFT JOIN oltp.people AS p
               ON p.person_id = i.salesperson_person_id AND p.is_employee
        WHERE p.person_id IS NULL
        """,
    ),
    (
        "invoice_lines.tax_amount = quantity x unit_price x tax_rate / 100",
        """
        SELECT COUNT(*)
        FROM oltp.invoice_lines
        WHERE ABS(tax_amount - ROUND(quantity * unit_price * tax_rate / 100, 2)) > 0.01
        """,
    ),
]


def main() -> None:
    con = duckdb.connect("wwi.duckdb", read_only=True)
    lines = []

    def log(msg: str = "") -> None:
        print(msg)
        lines.append(msg)

    run_id = con.execute(
        """
        SELECT run_id
        FROM etl.pipeline_run
        WHERE status = 'SUCCESS'
        ORDER BY start_time DESC
        LIMIT 1
        """
    ).fetchone()[0]
    failures = 0

    log(f"OLTP validation for run {run_id}")
    log("Primary keys: never NULL (enforced by the PRIMARY KEY constraint)")

    log()
    log("1. Row counts: CSV = loaded + duplicate + rejected, and loaded = OLTP rows")
    log(f"{'table':<26}{'csv':>9}{'loaded':>9}{'dup':>6}{'rej':>6}{'oltp':>9}  status")
    for source, table in LOAD_ORDER:
        csv_rows = con.execute(
            f"SELECT COUNT(*) FROM {csv_source(csv_path(source))}"
        ).fetchone()[0]
        loaded, dup, rej = con.execute(
            """
            SELECT rows_loaded, rows_duplicate, rows_rejected
            FROM etl.ingestion_log
            WHERE run_id = ? AND target_table = ?
            """,
            [run_id, table],
        ).fetchone()
        oltp_rows = con.execute(f"SELECT COUNT(*) FROM oltp.{table}").fetchone()[0]
        ok = csv_rows == loaded + dup + rej and loaded == oltp_rows
        failures += not ok
        log(
            f"{table:<26}{csv_rows:>9,}{loaded:>9,}{dup:>6,}{rej:>6,}"
            f"{oltp_rows:>9,}  {'PASS' if ok else 'FAIL'}"
        )

    log()
    log("2. Relationship and business checks (bad rows should be 0)")
    for name, sql in CHECKS:
        bad = con.execute(sql).fetchone()[0]
        failures += bad > 0
        log(f"{'PASS' if bad == 0 else 'FAIL'}  {name}  (bad rows: {bad:,})")

    log()
    log("3. Values rejected during type conversion (originals kept in etl.rejected_rows)")
    rejected = con.execute(
        """
        SELECT source_file, column_name, COUNT(*) AS bad_values,
               ANY_VALUE(original_value) AS sample_value
        FROM etl.rejected_rows
        WHERE run_id = ?
        GROUP BY source_file, column_name
        ORDER BY source_file, column_name
        """,
        [run_id],
    ).fetchall()
    if not rejected:
        log("none")
    for source_file, column_name, bad_values, sample in rejected:
        log(f"{source_file:<34}{column_name:<28}{bad_values:>8,}  e.g. {sample}")

    log()
    log("RESULT: " + ("PASS" if failures == 0 else f"FAIL ({failures} checks failed)"))

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text("\n".join(lines) + "\n")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
