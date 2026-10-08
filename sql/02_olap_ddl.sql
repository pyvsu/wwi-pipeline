-- =====================================================
-- 02_olap_ddl.sql : dw layer (dimensions + bridge)
-- Safe to run many times (IF NOT EXISTS).
-- No foreign keys: integrity is checked by DQ checks.
-- =====================================================

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dw;

-- ---------- dim_date (generated calendar, fiscal year starts Nov 1) ----------

CREATE TABLE IF NOT EXISTS dw.dim_date (
    date_key         INTEGER      PRIMARY KEY,   -- yyyymmdd, -1 = unknown
    full_date        DATE,
    day_of_month     INTEGER,
    day_name         VARCHAR,
    weekday_number   INTEGER,                    -- 1 = Monday ... 7 = Sunday
    month_number     INTEGER,
    month_name       VARCHAR,
    quarter          INTEGER,
    calendar_year    INTEGER,
    fiscal_month     INTEGER,
    fiscal_quarter   INTEGER,
    fiscal_year      INTEGER
);

-- ---------- dim_city (SCD1) ----------

CREATE TABLE IF NOT EXISTS dw.dim_city (
    city_key                    INTEGER   PRIMARY KEY,   -- -1 = unknown
    city_id                     INTEGER,
    city_name                   VARCHAR,
    state_province_code         VARCHAR,
    state_province_name         VARCHAR,
    sales_territory             VARCHAR,
    country_name                VARCHAR,
    continent                   VARCHAR,
    region                      VARCHAR,
    subregion                   VARCHAR,
    latitude                    DECIMAL(10,7),
    longitude                   DECIMAL(10,7),
    latest_recorded_population  BIGINT
);

-- ---------- dim_employee (SCD1) ----------

CREATE TABLE IF NOT EXISTS dw.dim_employee (
    employee_key    INTEGER   PRIMARY KEY,   -- -1 = unknown
    person_id       INTEGER,
    full_name       VARCHAR,
    preferred_name  VARCHAR,
    is_salesperson  BOOLEAN
);

-- ---------- dim_stock_item (SCD1) ----------

CREATE TABLE IF NOT EXISTS dw.dim_stock_item (
    stock_item_key            INTEGER        PRIMARY KEY,   -- -1 = unknown
    stock_item_id             INTEGER,
    stock_item_name           VARCHAR,
    brand                     VARCHAR,
    size                      VARCHAR,
    color_name                VARCHAR,
    unit_package_name         VARCHAR,
    outer_package_name        VARCHAR,
    supplier_name             VARCHAR,
    quantity_per_outer        INTEGER,
    lead_time_days            INTEGER,
    is_chiller_stock          BOOLEAN,
    barcode                   VARCHAR,
    tax_rate                  DECIMAL(18,3),
    unit_price                DECIMAL(18,2),
    recommended_retail_price  DECIMAL(18,2),
    typical_weight_per_unit   DECIMAL(18,3)
);

-- ---------- bridge: one row per item-category link ----------

CREATE TABLE IF NOT EXISTS dw.bridge_stock_item_group (
    stock_item_key    INTEGER   NOT NULL,
    stock_group_id    INTEGER   NOT NULL,
    stock_group_name  VARCHAR   NOT NULL,
    PRIMARY KEY (stock_item_key, stock_group_id)
);

-- ---------- dim_customer (SCD2 on category + buying group) ----------

CREATE SEQUENCE IF NOT EXISTS dw.seq_customer_key START 1;

CREATE TABLE IF NOT EXISTS dw.dim_customer (
    customer_key                  INTEGER        PRIMARY KEY DEFAULT nextval('dw.seq_customer_key'),
    customer_id                   INTEGER        NOT NULL,   -- business key, -1 = unknown
    -- Type 2 (tracked) attributes
    customer_category_id          INTEGER,
    customer_category_name        VARCHAR,
    buying_group_id               INTEGER,
    buying_group_name             VARCHAR,
    -- Type 1 attributes (overwritten on all versions)
    customer_name                 VARCHAR,
    delivery_city_id              INTEGER,
    delivery_address_line         VARCHAR,
    phone_number                  VARCHAR,
    website_url                   VARCHAR,
    credit_limit                  DECIMAL(18,2),
    payment_days                  INTEGER,
    standard_discount_percentage  DECIMAL(18,3),
    account_opened_date           DATE,
    is_on_credit_hold             BOOLEAN,
    -- SCD2 control columns
    row_hash                      VARCHAR        NOT NULL,   -- md5 of tracked attributes only
    effective_from                DATE           NOT NULL,
    effective_to                  DATE           NOT NULL,
    is_current                    BOOLEAN        NOT NULL
);
