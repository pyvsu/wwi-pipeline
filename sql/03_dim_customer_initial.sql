-- =====================================================
-- 03_dim_customer_initial.sql : first load of dw.dim_customer
-- Assumes dw.dim_customer is EMPTY and staging.stg_customer is built.
-- Every customer gets one open-ended current row.
-- =====================================================

BEGIN TRANSACTION;

INSERT INTO dw.dim_customer (
    customer_key, customer_id,
    customer_category_id, customer_category_name,
    buying_group_id, buying_group_name,
    customer_name, delivery_city_id, delivery_address_line,
    phone_number, website_url, credit_limit, payment_days,
    standard_discount_percentage, account_opened_date, is_on_credit_hold,
    row_hash, effective_from, effective_to, is_current
)
SELECT
    nextval('dw.seq_customer_key') AS customer_key,
    customer_id,
    customer_category_id,
    customer_category_name,
    buying_group_id,
    buying_group_name,
    customer_name,
    delivery_city_id,
    delivery_address_line,
    phone_number,
    website_url,
    credit_limit,
    payment_days,
    standard_discount_percentage,
    account_opened_date,
    is_on_credit_hold,
    row_hash,
    DATE '1900-01-01' AS effective_from,
    DATE '9999-12-31' AS effective_to,
    TRUE              AS is_current
FROM (
    SELECT
        customer_id, customer_category_id, customer_category_name,
        buying_group_id, buying_group_name, customer_name,
        delivery_city_id, delivery_address_line, phone_number, website_url,
        credit_limit, payment_days, standard_discount_percentage,
        account_opened_date, is_on_credit_hold, row_hash
    FROM staging.stg_customer
    ORDER BY customer_id
) AS ordered_customers;

-- Unknown member (does not use the sequence)
INSERT INTO dw.dim_customer (
    customer_key, customer_id,
    customer_category_name, buying_group_name, customer_name,
    row_hash, effective_from, effective_to, is_current
)
VALUES (
    -1, -1,
    'Unknown', 'Unknown', 'Unknown',
    'unknown', DATE '1900-01-01', DATE '9999-12-31', TRUE
);

COMMIT;
