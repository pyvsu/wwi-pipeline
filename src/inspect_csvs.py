import glob
import os

import duckdb

con = duckdb.connect()  # in-memory database, nothing is saved

for path in sorted(glob.glob("data/raw/**/*.csv", recursive=True)):
    folder = os.path.basename(os.path.dirname(path))
    name = os.path.basename(path)

    row_count = con.sql(
        f"SELECT COUNT(*) FROM read_csv_auto('{path}')"
    ).fetchone()[0]

    columns = con.sql(
        f"DESCRIBE SELECT * FROM read_csv_auto('{path}')"
    ).fetchall()

    print(f"\n{folder}/{name}: {row_count} rows")
    for col_name, col_type, *_ in columns:
        print(f"   {col_name}  ({col_type})")