-- =====================================================
-- 03_dim_stock_item.sql : load dw.dim_stock_item (SCD1, full reload)
-- Source: oltp.stock_items + colors + package_types (x2) + suppliers
-- =====================================================

BEGIN TRANSACTION;

DELETE FROM dw.dim_stock_item;

INSERT INTO dw.dim_stock_item (
    stock_item_key, stock_item_id, stock_item_name,
    brand, size, color_name,
    unit_package_name, outer_package_name, supplier_name,
    quantity_per_outer, lead_time_days, is_chiller_stock, barcode,
    tax_rate, unit_price, recommended_retail_price, typical_weight_per_unit
)
SELECT
    ROW_NUMBER() OVER (ORDER BY si.stock_item_id) AS stock_item_key,
    si.stock_item_id,
    si.stock_item_name,
    COALESCE(si.brand, 'N/A')       AS brand,
    COALESCE(si.size, 'N/A')        AS size,
    COALESCE(co.color_name, 'N/A')  AS color_name,
    up.package_type_name            AS unit_package_name,
    op.package_type_name            AS outer_package_name,
    su.supplier_name,
    si.quantity_per_outer,
    si.lead_time_days,
    si.is_chiller_stock,
    si.barcode,
    si.tax_rate,
    si.unit_price,
    si.recommended_retail_price,
    si.typical_weight_per_unit
FROM oltp.stock_items AS si
JOIN oltp.package_types AS up
  ON up.package_type_id = si.unit_package_id
JOIN oltp.package_types AS op
  ON op.package_type_id = si.outer_package_id
JOIN oltp.suppliers AS su
  ON su.supplier_id = si.supplier_id
LEFT JOIN oltp.colors AS co
  ON co.color_id = si.color_id;

-- Unknown member
INSERT INTO dw.dim_stock_item (
    stock_item_key, stock_item_id, stock_item_name,
    brand, size, color_name,
    unit_package_name, outer_package_name, supplier_name
)
VALUES (-1, -1, 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown');

COMMIT;
