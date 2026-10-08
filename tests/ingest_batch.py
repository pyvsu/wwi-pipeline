"""ingest_batch.py : rebuild OLTP for one batch and show customers 1-5.
Run from the repo root: python -m tests.ingest_batch 2
"""
import sys

import duckdb

from src.ingest import end_run, ingest_all, start_run

batch_id = int(sys.argv[1])

con = duckdb.connect("wwi.duckdb")
con.execute(open("sql/00_etl_ddl.sql").read())
con.execute(open("sql/01_oltp_ddl.sql").read())

run_id = start_run(con, batch_id)
try:
    ingest_all(con, run_id, batch_id)
    end_run(con, run_id, "SUCCESS")
except Exception as error:
    end_run(con, run_id, "FAILED", str(error))
    raise

print(f"\nbatch {batch_id}: customers 1-5 in oltp.customers")
for row in con.execute(
    """
    SELECT customer_id, customer_category_id, buying_group_id, _source_file
    FROM oltp.customers
    WHERE customer_id BETWEEN 1 AND 5
    ORDER BY customer_id
    """
).fetchall():
    print(row)
