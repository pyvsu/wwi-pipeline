# Source-to-Target Mapping (Draft v1)

Sources: dataset from Kaggle (pauloviniciusornelas/wwimporters); schema reference from Microsoft's WideWorldImporters OLTP and DW catalogs.

Flow: `CSV file` → `oltp.<table>` → `dw.<dim or fact>`

---

## 1. CSV → OLTP

### Required (14 files)

| CSV file | OLTP table | Rows | Primary key | Foreign keys |
|---|---|---:|---|---|
| Application.Countries | `countries` | 190 | country_id | none |
| Application.StateProvinces | `state_provinces` | 53 | state_province_id | country_id → countries |
| Application.Cities | `cities` | 37,940 | city_id | state_province_id → state_provinces |
| Application.People | `people` | 1,111 | person_id | none |
| Sales.CustomerCategories | `customer_categories` | 8 | customer_category_id | none |
| Sales.BuyingGroups | `buying_groups` | 2 | buying_group_id | none |
| Sales.Customers | `customers` | 663 | customer_id | customer_category_id, buying_group_id (nullable), delivery_city_id, primary_contact_person_id, bill_to_customer_id (self) |
| Warehouse.Colors | `colors` | 36 | color_id | none |
| Warehouse.PackageTypes | `package_types` | 14 | package_type_id | none |
| Warehouse.StockItems | `stock_items` | 227 | stock_item_id | color_id (nullable), unit_package_id, outer_package_id, supplier_id |
| Sales.Orders | `orders` | 73,595 | order_id | customer_id, salesperson_person_id, picked_by_person_id (nullable), backorder_order_id (nullable, self) |
| Sales.OrderLines | `order_lines` | 231,412 | order_line_id | order_id, stock_item_id, package_type_id |
| Sales.Invoices | `invoices` | 70,510 | invoice_id | customer_id, order_id, salesperson_person_id, delivery_method_id |
| Sales.InvoiceLines | `invoice_lines` | 228,265 | invoice_line_id | invoice_id, stock_item_id, package_type_id |

### Recommended extras (small, cheap, make the model better)

| CSV file | OLTP table | Rows | Why |
|---|---|---:|---|
| Purchasing.Suppliers | `suppliers` | 13 | Supplier name for `dim_stock_item` |
| Application.DeliveryMethods | `delivery_methods` | 10 | Keeps the delivery method FK valid |
| Warehouse.StockGroups | `stock_groups` | 10 | Product category (see decision 2) |
| Warehouse.StockItemStockGroups | `stock_item_stock_groups` | 442 | Links items to categories |

Rule: only add a foreign key when the parent table is loaded. If it isn't, keep the column but skip the FK.

### Load order (parents first)

```text
countries → state_provinces → cities
people, customer_categories, buying_groups, delivery_methods
customers
colors, package_types, suppliers → stock_items
stock_groups → stock_item_stock_groups
orders → order_lines
invoices → invoice_lines
```

---

## 2. OLTP → Data warehouse

### Dimensions

| DW table | Built from | SCD | Notes |
|---|---|---|---|
| `dim_date` | generated calendar | n/a | Fiscal year starts Nov 1. Must cover all order, invoice, and delivery dates. |
| `dim_city` | cities + state_provinces + countries | Type 1 | Includes SalesTerritory, Continent, Region, Subregion |
| `dim_customer` | customers + customer_categories + buying_groups + delivery city | **Type 2** | Type 2 attributes: category, buying group. Type 1: name, phone, address, credit limit. |
| `dim_employee` | people where `is_employee = 1` | Type 1 | Keep `is_salesperson` flag |
| `dim_stock_item` | stock_items + colors + package_types (unit and outer) + suppliers | Type 1 | Brand, size, color, packages, supplier, prices |
| `bridge_stock_item_group` | stock_item_stock_groups + stock_groups | Type 1 | Columns: stock_item_key, stock_group_id, stock_group_name. One row per item-category link (442 rows). |

Every dimension gets an **Unknown member** row with key = -1.

### Facts

| DW table | Grain | Built from | Join to dimensions |
|---|---|---|---|
| `fact_order` | One row per **order line** | order_lines + orders | customer (SCD2, by order date), stock item, salesperson, city, order date |
| `fact_sale` | One row per **invoice line** | invoice_lines + invoices (+ orders for order date) | customer (SCD2, by invoice date), stock item, salesperson, city, invoice date, delivery date |

### Measure mapping

| Measure | fact_order | fact_sale |
|---|---|---|
| Quantity | `order_lines.quantity` → ordered_qty | `invoice_lines.quantity` → invoiced_qty |
| Picked quantity | `order_lines.picked_quantity` | n/a |
| Unit price | `order_lines.unit_price` | `invoice_lines.unit_price` |
| Tax rate | `order_lines.tax_rate` | `invoice_lines.tax_rate` |
| Tax amount | calculated: qty × price × rate / 100 | `invoice_lines.tax_amount` |
| Amount excl. tax | calculated: qty × price | `extended_price − tax_amount` |
| Amount incl. tax | excl. tax + tax amount | `invoice_lines.extended_price` |
| Profit | n/a | `invoice_lines.line_profit` |
| Days order → invoice | n/a | `invoice_date − order_date` |
| Days invoice → delivery | n/a | `CAST(confirmed_delivery_time AS DATE) − invoice_date` |
| Degenerate keys | order_id, order_line_id, backorder_order_id | invoice_id, invoice_line_id, order_id |

---

## 3. What I noticed in the inventory

1. **Text in numeric columns.** DuckDB read these as VARCHAR, which means they hold text like `NULL` or empty strings: `Customers.BuyingGroupID`, `Customers.AlternateContactPersonID`, `Customers.CreditLimit`, `StockItems.ColorID`, `Orders.PickedByPersonID`, `Orders.BackorderOrderID`, `Cities.Latitude/Longitude/LatestRecordedPopulation`. Phase 1 must clean these with `nullstr` / `TRY_CAST`.
2. **Product category is many-to-many.** One stock item can belong to several stock groups. Joining straight to facts would **multiply rows and inflate sales**. **DECIDED: Option A, bridge table** (`bridge_stock_item_group`). Use it only in category queries, and never add category totals together because they overlap.
3. **InvoiceLines has no OrderLineID.** To compare ordered vs invoiced (questions 6 and 8), join on `(order_id, stock_item_id)`. We must check this pair is unique in order_lines.
4. **Delivery date** only exists as `Invoices.ConfirmedDeliveryTime` (timestamp, may be empty). Cast to date. Missing → Unknown date member.
5. **No city on orders or invoices.** City comes from the customer's delivery city.
6. **No history columns.** The files have no ValidFrom/ValidTo, so no change history comes with the data. This is why we create a batch 2 file for the SCD2 demo.
7. **People has only 6 columns**, so `dim_employee` stays small.

## 4. Still to verify (before Friday)

- [ ] `(order_id, stock_item_id)` unique in `order_lines`
- [ ] Every `salesperson_person_id` exists in people where `is_employee = 1`
- [x] Date ranges of orders and invoices: **2013-01-01 to 2016-05-31** for both (`dim_date` will cover 2013-01-01 to 2016-12-31; batch 2 effective date = 2015-01-01)
- [ ] Tax rate is a percent (for example 15.000) and `tax_amount = qty × price × rate / 100` matches `invoice_lines.tax_amount`
