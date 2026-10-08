"""scd2_snapshot.py : append a snapshot to docs/evidence/scd2_demo_stage2.md

Run: python -m tests.scd2_snapshot "Title of this snapshot"
"""
import sys
from pathlib import Path

import duckdb

EVIDENCE = Path("docs/evidence/scd2_demo_stage2.md")


def md_table(headers: list, rows: list) -> str:
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    lines += ["| " + " | ".join(str(v) for v in row) + " |" for row in rows]
    return "\n".join(lines)


def main(title: str) -> None:
    con = duckdb.connect("wwi.duckdb", read_only=True)

    totals = con.execute(
        """
        SELECT
            (SELECT COUNT(*) FROM dw.dim_customer),
            (SELECT COUNT(*) FROM dw.dim_customer WHERE is_current),
            (SELECT COUNT(*) FROM dw.fact_order),
            (SELECT COUNT(*) FROM dw.fact_sale)
        """
    ).fetchone()

    versions = con.execute(
        """
        SELECT customer_key, customer_id, customer_category_name,
               COALESCE(buying_group_name, '-') AS buying_group_name,
               effective_from, effective_to, is_current
        FROM dw.dim_customer
        WHERE customer_id BETWEEN 1 AND 8
        ORDER BY customer_id, effective_from
        """
    ).fetchall()

    sales = con.execute(
        """
        SELECT c.customer_id, c.customer_key, c.customer_category_name,
               c.effective_from, COUNT(*) AS sale_lines,
               SUM(f.extended_amount_incl_tax) AS amount_incl_tax
        FROM dw.fact_sale AS f
        INNER JOIN dw.dim_customer AS c
                ON c.customer_key = f.customer_key
        WHERE c.customer_id BETWEEN 1 AND 4
        GROUP BY ALL
        ORDER BY c.customer_id, c.effective_from
        """
    ).fetchall()

    parts = [
        f"## {title}",
        "",
        md_table(
            ["dim_customer rows", "current rows", "fact_order rows", "fact_sale rows"],
            [totals],
        ),
        "",
        "Customers 1-8, all versions:",
        "",
        md_table(
            ["customer_key", "customer_id", "category", "buying_group",
             "effective_from", "effective_to", "is_current"],
            versions,
        ),
        "",
        "fact_sale lines per customer version (customers 1-4):",
        "",
        md_table(
            ["customer_id", "customer_key", "category", "effective_from",
             "sale_lines", "amount_incl_tax"],
            sales,
        ),
        "",
    ]
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    with EVIDENCE.open("a", encoding="utf-8") as f:
        f.write("\n".join(parts) + "\n")
    print(f"snapshot written: {title}")


if __name__ == "__main__":
    main(sys.argv[1])
