-- =====================================================
-- 03_dim_customer_stage.sql : staging.stg_customer
-- Current customer picture from OLTP + row_hash of the
-- Type 2 (tracked) attributes: category and buying group.
-- =====================================================

CREATE SCHEMA IF NOT EXISTS staging;

CREATE OR REPLACE TABLE staging.stg_customer AS
SELECT
    c.customer_id,
    -- Type 2 (tracked)
    c.customer_category_id,
    cc.customer_category_name,
    c.buying_group_id,
    COALESCE(bg.buying_group_name, 'N/A') AS buying_group_name,
    -- Type 1
    c.customer_name,
    c.delivery_city_id,
    c.delivery_address_line,
    c.phone_number,
    c.website_url,
    c.credit_limit,
    c.payment_days,
    c.standard_discount_percentage,
    c.account_opened_date,
    c.is_on_credit_hold,
    -- fingerprint of tracked attributes only
    md5(concat_ws(
        '|',
        COALESCE(CAST(c.customer_category_id AS VARCHAR), ''),
        COALESCE(CAST(c.buying_group_id AS VARCHAR), '')
    )) AS row_hash
FROM oltp.customers AS c
JOIN oltp.customer_categories AS cc
  ON cc.customer_category_id = c.customer_category_id
LEFT JOIN oltp.buying_groups AS bg
  ON bg.buying_group_id = c.buying_group_id;
