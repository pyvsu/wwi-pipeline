-- =====================================================
-- 04_fact_ddl.sql : Fact tables
-- fact_order: one row per customer order line
-- fact_sale : one row per customer invoice line
-- Safe to run many times (IF NOT EXISTS).
-- =====================================================

CREATE TABLE IF NOT EXISTS dw.fact_order (
    order_line_id             INTEGER        PRIMARY KEY,
    order_id                  INTEGER        NOT NULL,
    backorder_order_id        INTEGER,
    order_date_key            INTEGER        NOT NULL,
    customer_key              INTEGER        NOT NULL,
    stock_item_key            INTEGER        NOT NULL,
    salesperson_key           INTEGER        NOT NULL,
    city_key                  INTEGER        NOT NULL,
    ordered_qty               INTEGER        NOT NULL,
    picked_qty                INTEGER,
    unit_price                DECIMAL(18,2),
    tax_rate                  DECIMAL(18,3)  NOT NULL,
    extended_amount_excl_tax  DECIMAL(18,2),
    tax_amount                DECIMAL(18,2),
    extended_amount_incl_tax  DECIMAL(18,2),
    _run_id                   VARCHAR        NOT NULL,
    _loaded_at                TIMESTAMP      NOT NULL
);

CREATE TABLE IF NOT EXISTS dw.fact_sale (
    invoice_line_id           INTEGER        PRIMARY KEY,
    invoice_id                INTEGER        NOT NULL,
    order_id                  INTEGER        NOT NULL,
    invoice_date_key          INTEGER        NOT NULL,
    delivery_date_key         INTEGER        NOT NULL,
    customer_key              INTEGER        NOT NULL,
    stock_item_key            INTEGER        NOT NULL,
    salesperson_key           INTEGER        NOT NULL,
    city_key                  INTEGER        NOT NULL,
    invoiced_qty              INTEGER        NOT NULL,
    unit_price                DECIMAL(18,2),
    tax_rate                  DECIMAL(18,3)  NOT NULL,
    tax_amount                DECIMAL(18,2),
    extended_amount_excl_tax  DECIMAL(18,2),
    extended_amount_incl_tax  DECIMAL(18,2),
    profit                    DECIMAL(18,2),
    days_order_to_invoice     INTEGER,
    days_invoice_to_delivery  INTEGER,
    _run_id                   VARCHAR        NOT NULL,
    _loaded_at                TIMESTAMP      NOT NULL
);
