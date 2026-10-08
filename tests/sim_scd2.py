"""sim_scd2.py : simulate a source change in STAGING and run the SCD2 SQL twice.
Run from the repo root: python tests/sim_scd2.py
"""
import duckdb

con = duckdb.connect("wwi.duckdb")


def run_scd2(batch_date: str) -> None:
    sql = open("sql/03_dim_customer_scd2.sql").read()
    con.execute(sql.replace("{{batch_date}}", batch_date))


def report(title: str) -> None:
    print(f"\n--- {title}")
    print("rows / current / closed:", con.execute(
        """
        SELECT COUNT(*),
               COUNT(*) FILTER (WHERE is_current),
               COUNT(*) FILTER (WHERE NOT is_current)
        FROM dw.dim_customer
        """
    ).fetchone())
    print("max key:", con.execute(
        "SELECT MAX(customer_key) FROM dw.dim_customer"
    ).fetchone()[0])
    print("overlapping date ranges:", con.execute(
        """
        SELECT COUNT(*)
        FROM dw.dim_customer AS a
        JOIN dw.dim_customer AS b
          ON a.customer_id = b.customer_id
         AND a.customer_key < b.customer_key
         AND a.effective_from <= b.effective_to
         AND b.effective_from <= a.effective_to
        """
    ).fetchone()[0])
    print("customers without exactly 1 current row:", con.execute(
        """
        SELECT COUNT(*)
        FROM (
            SELECT customer_id
            FROM dw.dim_customer
            GROUP BY customer_id
            HAVING COUNT(*) FILTER (WHERE is_current) <> 1
        )
        """
    ).fetchone()[0])
    for row in con.execute(
        """
        SELECT customer_key, customer_id, customer_category_name,
               effective_from, effective_to, is_current
        FROM dw.dim_customer
        WHERE customer_id IN (1, 2, 3)
        ORDER BY customer_id, customer_key
        """
    ).fetchall():
        print(row)
    print("customer 5 phone (all versions):", con.execute(
        "SELECT phone_number FROM dw.dim_customer WHERE customer_id = 5"
    ).fetchall())


# 1. reset to the batch 1 state
con.execute("DROP TABLE IF EXISTS dw.dim_customer")
con.execute("DROP SEQUENCE IF EXISTS dw.seq_customer_key")
con.execute(open("sql/02_olap_ddl.sql").read())
con.execute(open("sql/03_dim_customer_stage.sql").read())
con.execute(open("sql/03_dim_customer_initial.sql").read())
report("after batch 1")

# 2. simulate a changed source (STAGING only, never the dimension)
#    customers 1-3 take the category of the first customer who is not 'Novelty Shop'
con.execute(
    """
    UPDATE staging.stg_customer AS s
    SET customer_category_id   = t.customer_category_id,
        customer_category_name = t.customer_category_name,
        row_hash = md5(concat_ws(
            '|',
            CAST(t.customer_category_id AS VARCHAR),
            COALESCE(CAST(s.buying_group_id AS VARCHAR), '')
        ))
    FROM (
        SELECT customer_category_id, customer_category_name
        FROM staging.stg_customer
        WHERE customer_category_name <> 'Novelty Shop'
        ORDER BY customer_id
        LIMIT 1
    ) AS t
    WHERE s.customer_id IN (1, 2, 3)
    """
)
con.execute(
    "UPDATE staging.stg_customer SET phone_number = '(000) 555-0100' WHERE customer_id = 5"
)

changed = con.execute(
    """
    SELECT COUNT(*)
    FROM staging.stg_customer
    WHERE customer_id IN (1, 2, 3) AND customer_category_name <> 'Novelty Shop'
    """
).fetchone()[0]
assert changed == 3, f"simulated change did not apply ({changed}/3 customers)"

# 3. apply batch 2, then apply it again
run_scd2("2015-01-01")
report("after batch 2 (2015-01-01)")
run_scd2("2015-01-01")
report("after batch 2 AGAIN (must be identical)")
