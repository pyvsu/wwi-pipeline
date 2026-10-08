-- =====================================================
-- 05_dq_checks.sql : data quality checks
-- Each check returns ONE number: the count of bad rows.
-- 0 = PASS. Format per check (read by src/dq.py):
--   -- name: <check_name>
--   -- severity: CRITICAL | WARNING
--   <one SELECT returning the bad row count>
-- =====================================================

-- name: fact_order_rowcount_matches_oltp
-- severity: CRITICAL
SELECT ABS(
    (SELECT COUNT(*) FROM dw.fact_order)
  - (SELECT COUNT(*) FROM oltp.order_lines)
);

-- name: fact_sale_rowcount_matches_oltp
-- severity: CRITICAL
SELECT ABS(
    (SELECT COUNT(*) FROM dw.fact_sale)
  - (SELECT COUNT(*) FROM oltp.invoice_lines)
);

-- name: fact_order_no_unknown_keys
-- severity: CRITICAL
SELECT COUNT(*)
FROM dw.fact_order
WHERE order_date_key  = -1
   OR customer_key    = -1
   OR stock_item_key  = -1
   OR salesperson_key = -1
   OR city_key        = -1;

-- name: fact_sale_no_unknown_keys
-- severity: CRITICAL
SELECT COUNT(*)
FROM dw.fact_sale
WHERE invoice_date_key = -1
   OR customer_key     = -1
   OR stock_item_key   = -1
   OR salesperson_key  = -1
   OR city_key         = -1;

-- name: fact_sale_delivery_date_known
-- severity: WARNING
SELECT COUNT(*)
FROM dw.fact_sale
WHERE delivery_date_key = -1;

-- name: dim_customer_one_current_row_per_customer
-- severity: CRITICAL
SELECT COUNT(*)
FROM (
    SELECT customer_id
    FROM dw.dim_customer
    WHERE customer_key <> -1
    GROUP BY customer_id
    HAVING COUNT(*) FILTER (WHERE is_current) <> 1
);

-- name: dim_customer_no_overlapping_ranges
-- severity: CRITICAL
SELECT COUNT(*)
FROM dw.dim_customer AS a
INNER JOIN dw.dim_customer AS b
        ON a.customer_id  = b.customer_id
       AND a.customer_key < b.customer_key
       AND a.effective_from <= b.effective_to
       AND b.effective_from <= a.effective_to
WHERE a.customer_key <> -1;

-- name: dim_city_business_key_unique
-- severity: CRITICAL
SELECT COUNT(*)
FROM (
    SELECT city_id
    FROM dw.dim_city
    WHERE city_key <> -1
    GROUP BY city_id
    HAVING COUNT(*) > 1
);

-- name: dim_employee_business_key_unique
-- severity: CRITICAL
SELECT COUNT(*)
FROM (
    SELECT person_id
    FROM dw.dim_employee
    WHERE employee_key <> -1
    GROUP BY person_id
    HAVING COUNT(*) > 1
);

-- name: dim_stock_item_business_key_unique
-- severity: CRITICAL
SELECT COUNT(*)
FROM (
    SELECT stock_item_id
    FROM dw.dim_stock_item
    WHERE stock_item_key <> -1
    GROUP BY stock_item_id
    HAVING COUNT(*) > 1
);

-- name: dim_date_full_date_unique
-- severity: CRITICAL
SELECT COUNT(*)
FROM (
    SELECT full_date
    FROM dw.dim_date
    WHERE date_key <> -1
    GROUP BY full_date
    HAVING COUNT(*) > 1
);

-- name: dw_surrogate_keys_not_null
-- severity: CRITICAL
SELECT
    (SELECT COUNT(*) FROM dw.dim_customer   WHERE customer_key   IS NULL)
  + (SELECT COUNT(*) FROM dw.dim_city       WHERE city_key       IS NULL)
  + (SELECT COUNT(*) FROM dw.dim_employee   WHERE employee_key   IS NULL)
  + (SELECT COUNT(*) FROM dw.dim_stock_item WHERE stock_item_key IS NULL)
  + (SELECT COUNT(*) FROM dw.dim_date       WHERE date_key       IS NULL);

-- name: oltp_customers_bill_to_valid
-- severity: CRITICAL
SELECT COUNT(*)
FROM oltp.customers AS c
LEFT JOIN oltp.customers AS parent
       ON parent.customer_id = c.bill_to_customer_id
WHERE parent.customer_id IS NULL;

-- name: oltp_orders_backorder_valid
-- severity: CRITICAL
SELECT COUNT(*)
FROM oltp.orders AS o
LEFT JOIN oltp.orders AS parent
       ON parent.order_id = o.backorder_order_id
WHERE o.backorder_order_id IS NOT NULL
  AND parent.order_id IS NULL;

-- name: fact_order_valid_measures
-- severity: CRITICAL
SELECT COUNT(*)
FROM dw.fact_order
WHERE ordered_qty <= 0
   OR unit_price < 0
   OR tax_rate < 0
   OR extended_amount_excl_tax < 0
   OR extended_amount_incl_tax < 0;

-- name: fact_sale_valid_measures
-- severity: CRITICAL
SELECT COUNT(*)
FROM dw.fact_sale
WHERE invoiced_qty <= 0
   OR unit_price < 0
   OR tax_rate < 0
   OR tax_amount < 0
   OR extended_amount_excl_tax < 0
   OR extended_amount_incl_tax < 0;

-- name: fact_sale_dates_in_sequence
-- severity: CRITICAL
SELECT COUNT(*)
FROM dw.fact_sale
WHERE days_order_to_invoice    < 0
   OR days_invoice_to_delivery < 0;

-- name: fact_sale_order_to_invoice_over_365_days
-- severity: WARNING
SELECT COUNT(*)
FROM dw.fact_sale
WHERE days_order_to_invoice > 365;
