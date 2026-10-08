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
