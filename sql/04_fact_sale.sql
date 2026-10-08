-- =====================================================
-- 04_fact_sale.sql : load dw.fact_sale
-- Grain: one row per customer invoice line
-- Reads OLTP + dw dims only. Placeholder: {{run_id}}
-- =====================================================

BEGIN TRANSACTION;

DELETE FROM dw.fact_sale;

INSERT INTO dw.fact_sale (
    invoice_line_id, invoice_id, order_id,
    invoice_date_key, delivery_date_key,
    customer_key, stock_item_key, salesperson_key, city_key,
    invoiced_qty, unit_price, tax_rate, tax_amount,
    extended_amount_excl_tax, extended_amount_incl_tax, profit,
    days_order_to_invoice, days_invoice_to_delivery,
    _run_id, _loaded_at
)
WITH invoice_line_base AS (
    SELECT
        il.invoice_line_id,
        il.invoice_id,
        i.order_id,
        i.customer_id,
        i.salesperson_person_id,
        i.invoice_date,
        CAST(i.confirmed_delivery_time AS DATE) AS delivery_date,
        o.order_date,
        il.stock_item_id,
        il.quantity,
        il.unit_price,
        il.tax_rate,
        il.tax_amount,
        il.extended_price,
        il.line_profit
    FROM oltp.invoice_lines AS il
    INNER JOIN oltp.invoices AS i
            ON i.invoice_id = il.invoice_id
    INNER JOIN oltp.orders AS o
            ON o.order_id = i.order_id
)
SELECT
    b.invoice_line_id,
    b.invoice_id,
    b.order_id,
    COALESCE(di.date_key, -1)         AS invoice_date_key,
    COALESCE(dd.date_key, -1)         AS delivery_date_key,
    COALESCE(c.customer_key, -1)      AS customer_key,
    COALESCE(si.stock_item_key, -1)   AS stock_item_key,
    COALESCE(e.employee_key, -1)      AS salesperson_key,
    COALESCE(ci.city_key, -1)         AS city_key,
    b.quantity                        AS invoiced_qty,
    b.unit_price,
    b.tax_rate,
    b.tax_amount,
    b.extended_price - b.tax_amount   AS extended_amount_excl_tax,
    b.extended_price                  AS extended_amount_incl_tax,
    b.line_profit                     AS profit,
    DATE_DIFF('day', b.order_date, b.invoice_date)    AS days_order_to_invoice,
    DATE_DIFF('day', b.invoice_date, b.delivery_date) AS days_invoice_to_delivery,
    '{{run_id}}'                      AS _run_id,
    CURRENT_TIMESTAMP                 AS _loaded_at
FROM invoice_line_base AS b
LEFT JOIN dw.dim_date AS di
       ON di.full_date = b.invoice_date
LEFT JOIN dw.dim_date AS dd
       ON dd.full_date = b.delivery_date
LEFT JOIN dw.dim_customer AS c
       ON c.customer_id = b.customer_id
      AND b.invoice_date BETWEEN c.effective_from AND c.effective_to
LEFT JOIN dw.dim_city AS ci
       ON ci.city_id = c.delivery_city_id
LEFT JOIN dw.dim_stock_item AS si
       ON si.stock_item_id = b.stock_item_id
LEFT JOIN dw.dim_employee AS e
       ON e.person_id = b.salesperson_person_id;

COMMIT;
