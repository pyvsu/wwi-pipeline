"""make_batch2.py : build data/batch2/customers_batch2.csv from the raw customers file.

Changes the category / buying group of a few customers (same CustomerID).
Run from the repo root: python -m src.make_batch2
"""
from pathlib import Path

import duckdb

from src.ingest import csv_path, csv_source

# customer_id -> new value (ids come from oltp.customer_categories / buying_groups)
CATEGORY_CHANGES = {1: 4, 2: 5, 3: 6}   # Supermarket, Computer Store, Gift Store
GROUP_CHANGES = {4: 2}                  # Wingtip Toys

SOURCE = csv_path("Sales.Customers")
OUT_FILE = Path("data/batch2/customers_batch2.csv")


def case_expr(column: str, changes: dict) -> str:
    whens = " ".join(f"WHEN {cid} THEN '{new}'" for cid, new in changes.items())
    return (
        f'CASE CAST("CustomerID" AS INTEGER) {whens} ELSE "{column}" END '
        f'AS "{column}"'
    )


def main() -> None:
    con = duckdb.connect()  # in-memory, nothing is saved
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    con.execute(
        f"""
        COPY (
            SELECT * REPLACE (
                {case_expr("CustomerCategoryID", CATEGORY_CHANGES)},
                {case_expr("BuyingGroupID", GROUP_CHANGES)}
            )
            FROM {csv_source(SOURCE)}
        ) TO '{OUT_FILE}' (HEADER, DELIMITER ',')
        """
    )

    original = csv_source(SOURCE)
    batch2 = csv_source(str(OUT_FILE))

    rows_original = con.execute(f"SELECT COUNT(*) FROM {original}").fetchone()[0]
    rows_batch2 = con.execute(f"SELECT COUNT(*) FROM {batch2}").fetchone()[0]
    rows_changed = con.execute(
        f"SELECT COUNT(*) FROM (SELECT * FROM {original} EXCEPT SELECT * FROM {batch2})"
    ).fetchone()[0]

    print(f"written: {OUT_FILE}")
    print(f"rows original / batch2: {rows_original} / {rows_batch2}")
    print(f"rows that differ from original: {rows_changed} (expected {len(set(CATEGORY_CHANGES) | set(GROUP_CHANGES))})")

    print("customers 1-8 in batch2 (id, category id, buying group id):")
    for row in con.execute(
        f"""
        SELECT "CustomerID", "CustomerCategoryID", "BuyingGroupID"
        FROM {batch2}
        WHERE CAST("CustomerID" AS INTEGER) BETWEEN 1 AND 8
        ORDER BY CAST("CustomerID" AS INTEGER)
        """
    ).fetchall():
        print(row)


if __name__ == "__main__":
    main()
