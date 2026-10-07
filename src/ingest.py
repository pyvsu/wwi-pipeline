"""ingest.py : load raw CSVs into the oltp schema."""
import re
from pathlib import Path

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
        + f"\nFROM read_csv('{path}', all_varchar = true, nullstr = ['', 'NULL'])"
    )