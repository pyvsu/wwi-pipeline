-- =====================================================
-- 04_fact_order.sql : load dw.fact_order
-- Grain: one row per customer order line
-- Reads OLTP + dw dims only. Placeholder: {{run_id}}
-- =====================================================

BEGIN TRANSACTION;

DELETE FROM dw.fact_order;

INSERT INTO dw.fact_order (
    order_line_id, order_id, backorder_order_id,
    order_date_key, customer_key, stock_item_key, salesperson_key, city_key,
    ordered_qty, picked_qty, unit_price, tax_rate,
    extended_amount_excl_tax, tax_amount, extended_amount_incl_tax,
    _run_id, _loaded_at
)
WITH order_line_base AS (
    SELECT
        ol.order_line_id,
        ol.order_id,
        o.backorder_order_id,
        o.customer_id,
        o.salesperson_person_id,
        o.order_date,
        ol.stock_item_id,
        ol.quantity,
        ol.picked_quantity,
        ol.unit_price,
        ol.tax_rate,
        ROUND(ol.quantity * ol.unit_price, 2)                    AS amount_excl_tax,
        ROUND(ol.quantity * ol.unit_price * ol.tax_rate / 100, 2) AS tax_amount
    FROM oltp.order_lines AS ol
    INNER JOIN oltp.orders AS o
            ON o.order_id = ol.order_id
)
SELECT
    b.order_line_id,
    b.order_id,
    b.backorder_order_id,
    COALESCE(d.date_key, -1)          AS order_date_key,
    COALESCE(c.customer_key, -1)      AS customer_key,
    COALESCE(si.stock_item_key, -1)   AS stock_item_key,
    COALESCE(e.employee_key, -1)      AS salesperson_key,
    COALESCE(ci.city_key, -1)         AS city_key,
    b.quantity                        AS ordered_qty,
    b.picked_quantity                 AS picked_qty,
    b.unit_price,
    b.tax_rate,
    b.amount_excl_tax                 AS extended_amount_excl_tax,
    b.tax_amount,
    b.amount_excl_tax + b.tax_amount  AS extended_amount_incl_tax,
    '{{run_id}}'                      AS _run_id,
    CURRENT_TIMESTAMP                 AS _loaded_at
FROM order_line_base AS b
LEFT JOIN dw.dim_date AS d
       ON d.full_date = b.order_date
LEFT JOIN dw.dim_customer AS c
       ON c.customer_id = b.customer_id
      AND b.order_date BETWEEN c.effective_from AND c.effective_to
LEFT JOIN dw.dim_city AS ci
       ON ci.city_id = c.delivery_city_id
LEFT JOIN dw.dim_stock_item AS si
       ON si.stock_item_id = b.stock_item_id
LEFT JOIN dw.dim_employee AS e
       ON e.person_id = b.salesperson_person_id;

COMMIT;
