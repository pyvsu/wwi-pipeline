"""ingest.py : load raw CSVs into the oltp schema."""
import re
from pathlib import Path
import uuid
from datetime import datetime

RAW_DIR = Path("data/raw")

# (source file, target table) in load order: parents first
LOAD_ORDER = [
    ("Application.Countries", "countries"),
    ("Application.StateProvinces", "state_provinces"),
    ("Application.Cities", "cities"),
    ("Application.People", "people"),
    ("Sales.CustomerCategories", "customer_categories"),
    ("Sales.BuyingGroups", "buying_groups"),
    ("Application.DeliveryMethods", "delivery_methods"),
    ("Sales.Customers", "customers"),
    ("Warehouse.Colors", "colors"),
    ("Warehouse.PackageTypes", "package_types"),
    ("Purchasing.Suppliers", "suppliers"),
    ("Warehouse.StockItems", "stock_items"),
    ("Warehouse.StockGroups", "stock_groups"),
    ("Warehouse.StockItemStockGroups", "stock_item_stock_groups"),
    ("Sales.Orders", "orders"),
    ("Sales.OrderLines", "order_lines"),
    ("Sales.Invoices", "invoices"),
    ("Sales.InvoiceLines", "invoice_lines"),
]


def csv_path(source: str) -> str:
    """'Sales.Orders' -> 'data/raw/Sales/Sales.Orders.csv'"""
    schema = source.split(".")[0]
    return str(RAW_DIR / schema / f"{source}.csv")


def to_snake(name: str) -> str:
    """CountryID -> country_id, WebsiteURL -> website_url"""
    return re.sub(r"(?<=[a-z])(?=[A-Z])", "_", name).lower()


def get_target_columns(con, table: str) -> list:
    """Column name and type from the DDL, skipping our _audit columns."""
    return con.execute(
        """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'oltp'
          AND table_name = ?
          AND NOT starts_with(column_name, '_')
        ORDER BY ordinal_position
        """,
        [table],
    ).fetchall()


def get_csv_columns(con, path: str) -> dict:
    """Map snake_case name -> original CSV header name."""
    rows = con.execute(
        f"DESCRIBE SELECT * FROM read_csv('{path}', all_varchar = true)"
    ).fetchall()
    return {to_snake(row[0]): row[0] for row in rows}


def cast_expr(csv_col: str, data_type: str) -> str:
    """Safe conversion: bad values become NULL instead of crashing."""
    raw = f'"{csv_col}"'
    if data_type == "VARCHAR":
        return raw
    if data_type == "BOOLEAN":
        return f"TRY_CAST(TRY_CAST({raw} AS INTEGER) AS BOOLEAN)"
    if data_type.startswith("DECIMAL"):
        return f"TRY_CAST(REPLACE({raw}, ',', '.') AS {data_type})"
    if data_type == "DATE":
        return (
            f"COALESCE(TRY_CAST(TRY_STRPTIME({raw}, '%d/%m/%Y') AS DATE), "
            f"TRY_CAST({raw} AS DATE))"
        )
    if data_type == "TIMESTAMP":
        return (
            f"COALESCE(TRY_STRPTIME({raw}, ['%d/%m/%Y %H:%M:%S', '%d/%m/%Y %H:%M']), "
            f"TRY_CAST({raw} AS TIMESTAMP))"
        )
    return f"TRY_CAST({raw} AS {data_type})"


def build_typed_select(con, table: str, path: str) -> str:
    """Assemble the cleaning SELECT for one table."""
    csv_cols = get_csv_columns(con, path)
    lines = []
    for name, data_type in get_target_columns(con, table):
        if name not in csv_cols:
            raise ValueError(f"{table}.{name} has no matching column in {path}")
        lines.append(f"    {cast_expr(csv_cols[name], data_type)} AS {name}")
    return (
        "SELECT\n"
        + ",\n".join(lines)
        + f"\nFROM {csv_source(path)}"
    )

def csv_source(path: str) -> str:
    """The one read_csv call used everywhere: all text, blank/'NULL' -> NULL."""
    return f"read_csv('{path}', all_varchar = true, nullstr = ['', 'NULL'])"


def get_primary_key(con, table: str) -> str:
    return con.execute(
        """
        SELECT constraint_column_names[1]
        FROM duckdb_constraints()
        WHERE schema_name = 'oltp'
          AND table_name = ?
          AND constraint_type = 'PRIMARY KEY'
        """,
        [table],
    ).fetchone()[0]


def get_required_columns(con, table: str) -> list:
    """NOT NULL columns (PK included), skipping our _audit columns."""
    rows = con.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'oltp'
          AND table_name = ?
          AND is_nullable = 'NO'
          AND NOT starts_with(column_name, '_')
        ORDER BY ordinal_position
        """,
        [table],
    ).fetchall()
    return [row[0] for row in rows]


def build_rejected_sql(con, table: str, source_file: str, path: str, run_id: str) -> str:
    """One SELECT per checkable column: finds values that failed to convert."""
    csv_cols = get_csv_columns(con, path)
    pk_csv = csv_cols[get_primary_key(con, table)]
    required = set(get_required_columns(con, table))

    parts = []
    for name, data_type in get_target_columns(con, table):
        if data_type == "VARCHAR" and name not in required:
            continue  # optional text can never fail a cast
        raw = f'"{csv_cols[name]}"'
        cast = cast_expr(csv_cols[name], data_type)
        if name in required:
            bad = f"{cast} IS NULL"
            reason = "required value missing or invalid"
        else:
            bad = f"{raw} IS NOT NULL AND {cast} IS NULL"
            reason = "value failed type cast"
        parts.append(
            f"""SELECT '{run_id}' AS run_id, '{source_file}' AS source_file,
                   "{pk_csv}" AS row_key, '{name}' AS column_name,
                   {raw} AS original_value, '{reason}' AS reason
            FROM {csv_source(path)}
            WHERE {bad}"""
        )
    return "\nUNION ALL\n".join(parts)


def start_run(con, batch_id: int) -> str:
    run_id = str(uuid.uuid4())
    con.execute(
        """
        INSERT INTO etl.pipeline_run (run_id, batch_id, start_time, status)
        VALUES (?, ?, ?, 'RUNNING')
        """,
        [run_id, batch_id, datetime.now()],
    )
    return run_id


def end_run(con, run_id: str, status: str, error_message: str = None) -> None:
    con.execute(
        """
        UPDATE etl.pipeline_run
        SET end_time = ?, status = ?, error_message = ?
        WHERE run_id = ?
        """,
        [datetime.now(), status, error_message, run_id],
    )


def load_table(con, run_id: str, source: str, table: str) -> dict:
    """Load one CSV into one oltp table, in one transaction."""
    path = csv_path(source)
    source_file = Path(path).name
    typed_sql = build_typed_select(con, table, path)
    cols = ", ".join(name for name, _ in get_target_columns(con, table))
    pk = get_primary_key(con, table)
    valid_filter = " AND ".join(f"{c} IS NOT NULL" for c in get_required_columns(con, table))
    now = datetime.now()

    con.execute("BEGIN")
    try:
        # 1. Keep original text of every bad value
        con.execute(
            f"""
            INSERT INTO etl.rejected_rows
                (run_id, source_file, row_key, column_name, original_value, reason, rejected_at)
            SELECT *, ?
            FROM ({build_rejected_sql(con, table, source_file, path, run_id)})
            """,
            [now],
        )

        # 2. Count what we read and what is valid
        rows_read, rows_valid = con.execute(
            f"""
            WITH typed AS ({typed_sql})
            SELECT COUNT(*), COUNT(*) FILTER (WHERE {valid_filter})
            FROM typed
            """
        ).fetchone()

        # 3. Load valid rows, one per primary key
        con.execute(
            f"""
            INSERT INTO oltp.{table} ({cols}, _source_file, _ingested_at, _run_id)
            WITH typed AS ({typed_sql})
            SELECT {cols}, ?, ?, ?
            FROM typed
            WHERE {valid_filter}
            QUALIFY ROW_NUMBER() OVER (PARTITION BY {pk} ORDER BY {pk}) = 1
            """,
            [source_file, now, run_id],
        )
        rows_loaded = con.execute(
            f"SELECT COUNT(*) FROM oltp.{table} WHERE _run_id = ?", [run_id]
        ).fetchone()[0]

        # 4. Write the logbook entry
        stats = {
            "rows_read": rows_read,
            "rows_loaded": rows_loaded,
            "rows_duplicate": rows_valid - rows_loaded,
            "rows_rejected": rows_read - rows_valid,
        }
        con.execute(
            """
            INSERT INTO etl.ingestion_log
                (run_id, source_file, target_table, rows_read, rows_loaded,
                 rows_duplicate, rows_rejected, loaded_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [run_id, source_file, table, *stats.values(), now],
        )
        con.execute("COMMIT")
        return stats
    except Exception:
        con.execute("ROLLBACK")
        raise


def ingest_all(con, run_id: str) -> None:
    """Load every table in LOAD_ORDER and print one line per table."""
    for source, table in LOAD_ORDER:
        s = load_table(con, run_id, source, table)
        print(
            f"{table:<26}"
            f"read={s['rows_read']:>8,}  loaded={s['rows_loaded']:>8,}  "
            f"dup={s['rows_duplicate']:>4,}  rejected={s['rows_rejected']:>4,}"
        )