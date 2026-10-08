-- =====================================================
-- 03_dim_customer_scd2.sql : SCD2 change logic for dw.dim_customer
-- {{batch_date}} (yyyy-mm-dd) is replaced by Python before running.
-- Needs staging.stg_customer to be built first.
-- Re-running with the same input changes nothing.
-- Note: brand new customers also start at {{batch_date}}.
-- =====================================================

BEGIN TRANSACTION;

-- 1. CLOSE: current rows whose tracked attributes changed
UPDATE dw.dim_customer AS d
SET effective_to = DATE '{{batch_date}}' - 1,
    is_current   = FALSE
FROM staging.stg_customer AS s
WHERE d.customer_id = s.customer_id
  AND d.is_current
  AND d.row_hash <> s.row_hash;

-- 2. INSERT: new current row for every customer without a current row
--    (changed customers + brand new customers)
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
    customer_category_id, customer_category_name,
    buying_group_id, buying_group_name,
    customer_name, delivery_city_id, delivery_address_line,
    phone_number, website_url, credit_limit, payment_days,
    standard_discount_percentage, account_opened_date, is_on_credit_hold,
    row_hash,
    DATE '{{batch_date}}' AS effective_from,
    DATE '9999-12-31'     AS effective_to,
    TRUE                  AS is_current
FROM (
    SELECT
        s.customer_id,
        s.customer_category_id, s.customer_category_name,
        s.buying_group_id, s.buying_group_name,
        s.customer_name, s.delivery_city_id, s.delivery_address_line,
        s.phone_number, s.website_url, s.credit_limit, s.payment_days,
        s.standard_discount_percentage, s.account_opened_date, s.is_on_credit_hold,
        s.row_hash
    FROM staging.stg_customer AS s
    LEFT JOIN dw.dim_customer AS d
           ON d.customer_id = s.customer_id
          AND d.is_current
    WHERE d.customer_id IS NULL
    ORDER BY s.customer_id
) AS new_versions;

-- 3. OVERWRITE: Type 1 attributes on ALL versions of the customer
UPDATE dw.dim_customer AS d
SET customer_name                = s.customer_name,
    delivery_city_id             = s.delivery_city_id,
    delivery_address_line        = s.delivery_address_line,
    phone_number                 = s.phone_number,
    website_url                  = s.website_url,
    credit_limit                 = s.credit_limit,
    payment_days                 = s.payment_days,
    standard_discount_percentage = s.standard_discount_percentage,
    account_opened_date          = s.account_opened_date,
    is_on_credit_hold            = s.is_on_credit_hold
FROM staging.stg_customer AS s
WHERE d.customer_id = s.customer_id
  AND (
         d.customer_name                IS DISTINCT FROM s.customer_name
      OR d.delivery_city_id             IS DISTINCT FROM s.delivery_city_id
      OR d.delivery_address_line        IS DISTINCT FROM s.delivery_address_line
      OR d.phone_number                 IS DISTINCT FROM s.phone_number
      OR d.website_url                  IS DISTINCT FROM s.website_url
      OR d.credit_limit                 IS DISTINCT FROM s.credit_limit
      OR d.payment_days                 IS DISTINCT FROM s.payment_days
      OR d.standard_discount_percentage IS DISTINCT FROM s.standard_discount_percentage
      OR d.account_opened_date          IS DISTINCT FROM s.account_opened_date
      OR d.is_on_credit_hold            IS DISTINCT FROM s.is_on_credit_hold
  );

COMMIT;
