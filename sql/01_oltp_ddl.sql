-- =====================================================
-- 01_oltp_ddl.sql : OLTP layer (normalized, typed, keyed)
-- Rebuilt on every run. Audit schema (etl) is kept.
-- =====================================================

DROP SCHEMA IF EXISTS oltp CASCADE;
CREATE SCHEMA oltp;
CREATE SCHEMA IF NOT EXISTS etl;

-- ---------- Geography (load order: 1 -> 2 -> 3) ----------

CREATE TABLE oltp.countries (
    country_id                  INTEGER       PRIMARY KEY,
    country_name                VARCHAR       NOT NULL,
    formal_name                 VARCHAR,
    latest_recorded_population  BIGINT        CHECK (latest_recorded_population >= 0),
    continent                   VARCHAR,
    region                      VARCHAR,
    subregion                   VARCHAR,
    _source_file                VARCHAR       NOT NULL,
    _ingested_at                TIMESTAMP     NOT NULL,
    _run_id                     VARCHAR       NOT NULL
);

CREATE TABLE oltp.state_provinces (
    state_province_id           INTEGER       PRIMARY KEY,
    state_province_code         VARCHAR,
    state_province_name         VARCHAR       NOT NULL,
    country_id                  INTEGER       NOT NULL REFERENCES oltp.countries (country_id),
    sales_territory             VARCHAR,
    latest_recorded_population  BIGINT        CHECK (latest_recorded_population >= 0),
    _source_file                VARCHAR       NOT NULL,
    _ingested_at                TIMESTAMP     NOT NULL,
    _run_id                     VARCHAR       NOT NULL
);

CREATE TABLE oltp.cities (
    city_id                     INTEGER       PRIMARY KEY,
    city_name                   VARCHAR       NOT NULL,
    state_province_id           INTEGER       NOT NULL REFERENCES oltp.state_provinces (state_province_id),
    latitude                     DECIMAL(10,7)  CHECK (latitude  BETWEEN  -90 AND  90),
    longitude                    DECIMAL(10,7)  CHECK (longitude BETWEEN -180 AND 180),
    latest_recorded_population  BIGINT        CHECK (latest_recorded_population >= 0),
    _source_file                VARCHAR       NOT NULL,
    _ingested_at                TIMESTAMP     NOT NULL,
    _run_id                     VARCHAR       NOT NULL
);

-- ---------- People and lookups ----------

CREATE TABLE oltp.people (
    person_id          INTEGER    PRIMARY KEY,
    full_name          VARCHAR    NOT NULL,
    preferred_name     VARCHAR,
    search_name        VARCHAR,
    is_employee        BOOLEAN    NOT NULL,
    is_salesperson     BOOLEAN    NOT NULL,
    _source_file       VARCHAR    NOT NULL,
    _ingested_at       TIMESTAMP  NOT NULL,
    _run_id            VARCHAR    NOT NULL
);

CREATE TABLE oltp.customer_categories (
    customer_category_id    INTEGER    PRIMARY KEY,
    customer_category_name  VARCHAR    NOT NULL,
    _source_file            VARCHAR    NOT NULL,
    _ingested_at            TIMESTAMP  NOT NULL,
    _run_id                 VARCHAR    NOT NULL
);

CREATE TABLE oltp.buying_groups (
    buying_group_id    INTEGER    PRIMARY KEY,
    buying_group_name  VARCHAR    NOT NULL,
    _source_file       VARCHAR    NOT NULL,
    _ingested_at       TIMESTAMP  NOT NULL,
    _run_id            VARCHAR    NOT NULL
);

CREATE TABLE oltp.delivery_methods (
    delivery_method_id    INTEGER    PRIMARY KEY,
    delivery_method_name  VARCHAR    NOT NULL,
    _source_file          VARCHAR    NOT NULL,
    _ingested_at          TIMESTAMP  NOT NULL,
    _run_id               VARCHAR    NOT NULL
);

-- ---------- Customers (needs all of the above + cities) ----------

CREATE TABLE oltp.customers (
    customer_id                   INTEGER        PRIMARY KEY,
    customer_name                 VARCHAR        NOT NULL,
    bill_to_customer_id           INTEGER        NOT NULL REFERENCES oltp.customers (customer_id),
    customer_category_id          INTEGER        NOT NULL REFERENCES oltp.customer_categories (customer_category_id),
    buying_group_id               INTEGER        REFERENCES oltp.buying_groups (buying_group_id),
    primary_contact_person_id     INTEGER        NOT NULL REFERENCES oltp.people (person_id),
    alternate_contact_person_id   INTEGER        REFERENCES oltp.people (person_id),
    delivery_method_id            INTEGER        NOT NULL REFERENCES oltp.delivery_methods (delivery_method_id),
    delivery_city_id              INTEGER        NOT NULL REFERENCES oltp.cities (city_id),
    credit_limit                  DECIMAL(18,2)  CHECK (credit_limit >= 0),
    account_opened_date           DATE           NOT NULL,
    standard_discount_percentage  DECIMAL(18,3)  CHECK (standard_discount_percentage BETWEEN 0 AND 100),
    is_statement_sent             BOOLEAN,
    is_on_credit_hold             BOOLEAN,
    payment_days                  INTEGER        CHECK (payment_days >= 0),
    phone_number                  VARCHAR,
    website_url                   VARCHAR,
    delivery_address_line         VARCHAR,
    delivery_location_lat          DECIMAL(10,7)   CHECK (delivery_location_lat  BETWEEN  -90 AND  90),
    delivery_location_long         DECIMAL(10,7)   CHECK (delivery_location_long BETWEEN -180 AND 180),
    _source_file                  VARCHAR        NOT NULL,
    _ingested_at                  TIMESTAMP      NOT NULL,
    _run_id                       VARCHAR        NOT NULL
);

-- ---------- Product side ----------

CREATE TABLE oltp.colors (
    color_id       INTEGER    PRIMARY KEY,
    color_name     VARCHAR    NOT NULL,
    _source_file   VARCHAR    NOT NULL,
    _ingested_at   TIMESTAMP  NOT NULL,
    _run_id        VARCHAR    NOT NULL
);

CREATE TABLE oltp.package_types (
    package_type_id    INTEGER    PRIMARY KEY,
    package_type_name  VARCHAR    NOT NULL,
    _source_file       VARCHAR    NOT NULL,
    _ingested_at       TIMESTAMP  NOT NULL,
    _run_id            VARCHAR    NOT NULL
);

CREATE TABLE oltp.stock_groups (
    stock_group_id    INTEGER    PRIMARY KEY,
    stock_group_name  VARCHAR    NOT NULL,
    _source_file      VARCHAR    NOT NULL,
    _ingested_at      TIMESTAMP  NOT NULL,
    _run_id           VARCHAR    NOT NULL
);

CREATE TABLE oltp.suppliers (
    supplier_id                  INTEGER        PRIMARY KEY,
    supplier_name                VARCHAR        NOT NULL,
    supplier_category_id         INTEGER,       -- no FK: parent table not loaded
    primary_contact_person_id    INTEGER        NOT NULL REFERENCES oltp.people (person_id),
    alternate_contact_person_id  INTEGER        REFERENCES oltp.people (person_id),
    delivery_method_id           INTEGER        REFERENCES oltp.delivery_methods (delivery_method_id),
    delivery_city_id             INTEGER        NOT NULL REFERENCES oltp.cities (city_id),
    postal_city_id               INTEGER        NOT NULL REFERENCES oltp.cities (city_id),
    supplier_reference           VARCHAR,
    payment_days                 INTEGER        CHECK (payment_days >= 0),
    phone_number                 VARCHAR,
    website_url                  VARCHAR,
    delivery_address_line        VARCHAR,
    delivery_location_lat         DECIMAL(10,7)   CHECK (delivery_location_lat  BETWEEN  -90 AND  90),
    delivery_location_long        DECIMAL(10,7)   CHECK (delivery_location_long BETWEEN -180 AND 180),
    _source_file                 VARCHAR        NOT NULL,
    _ingested_at                 TIMESTAMP      NOT NULL,
    _run_id                      VARCHAR        NOT NULL
);

CREATE TABLE oltp.stock_items (
    stock_item_id             INTEGER        PRIMARY KEY,
    stock_item_name           VARCHAR        NOT NULL,
    supplier_id               INTEGER        NOT NULL REFERENCES oltp.suppliers (supplier_id),
    color_id                  INTEGER        REFERENCES oltp.colors (color_id),
    unit_package_id           INTEGER        NOT NULL REFERENCES oltp.package_types (package_type_id),
    outer_package_id          INTEGER        NOT NULL REFERENCES oltp.package_types (package_type_id),
    brand                     VARCHAR,
    size                      VARCHAR,
    lead_time_days            INTEGER        CHECK (lead_time_days >= 0),
    quantity_per_outer        INTEGER        CHECK (quantity_per_outer > 0),
    is_chiller_stock          BOOLEAN,
    barcode                   VARCHAR,
    tax_rate                  DECIMAL(18,3)  CHECK (tax_rate >= 0),
    unit_price                DECIMAL(18,2)  CHECK (unit_price >= 0),
    recommended_retail_price  DECIMAL(18,2)  CHECK (recommended_retail_price >= 0),
    typical_weight_per_unit   DECIMAL(18,3)  CHECK (typical_weight_per_unit >= 0),
    _source_file              VARCHAR        NOT NULL,
    _ingested_at              TIMESTAMP      NOT NULL,
    _run_id                   VARCHAR        NOT NULL
);

CREATE TABLE oltp.stock_item_stock_groups (
    stock_item_stock_group_id  INTEGER    PRIMARY KEY,
    stock_item_id              INTEGER    NOT NULL REFERENCES oltp.stock_items (stock_item_id),
    stock_group_id             INTEGER    NOT NULL REFERENCES oltp.stock_groups (stock_group_id),
    _source_file               VARCHAR    NOT NULL,
    _ingested_at               TIMESTAMP  NOT NULL,
    _run_id                    VARCHAR    NOT NULL,
    UNIQUE (stock_item_id, stock_group_id)
);

-- ---------- Orders ----------

CREATE TABLE oltp.orders (
    order_id                       INTEGER    PRIMARY KEY,
    customer_id                    INTEGER    NOT NULL REFERENCES oltp.customers (customer_id),
    salesperson_person_id          INTEGER    NOT NULL REFERENCES oltp.people (person_id),
    picked_by_person_id            INTEGER    REFERENCES oltp.people (person_id),
    contact_person_id              INTEGER    REFERENCES oltp.people (person_id),
    backorder_order_id             INTEGER    REFERENCES oltp.orders (order_id),
    order_date                     DATE       NOT NULL,
    expected_delivery_date         DATE,
    customer_purchase_order_number VARCHAR,
    is_undersupply_backordered     BOOLEAN,
    picking_completed_when         TIMESTAMP,
    _source_file                   VARCHAR    NOT NULL,
    _ingested_at                   TIMESTAMP  NOT NULL,
    _run_id                        VARCHAR    NOT NULL
);

CREATE TABLE oltp.order_lines (
    order_line_id          INTEGER        PRIMARY KEY,
    order_id               INTEGER        NOT NULL REFERENCES oltp.orders (order_id),
    stock_item_id          INTEGER        NOT NULL REFERENCES oltp.stock_items (stock_item_id),
    description            VARCHAR,
    package_type_id        INTEGER        REFERENCES oltp.package_types (package_type_id),
    quantity               INTEGER        NOT NULL CHECK (quantity > 0),
    unit_price             DECIMAL(18,2)  CHECK (unit_price >= 0),
    tax_rate               DECIMAL(18,3)  NOT NULL CHECK (tax_rate >= 0),
    picked_quantity        INTEGER        CHECK (picked_quantity >= 0),
    picking_completed_when TIMESTAMP,
    _source_file           VARCHAR        NOT NULL,
    _ingested_at           TIMESTAMP      NOT NULL,
    _run_id                VARCHAR        NOT NULL
);

-- ---------- Invoices ----------

CREATE TABLE oltp.invoices (
    invoice_id                     INTEGER    PRIMARY KEY,
    customer_id                    INTEGER    NOT NULL REFERENCES oltp.customers (customer_id),
    bill_to_customer_id            INTEGER    NOT NULL REFERENCES oltp.customers (customer_id),
    order_id                       INTEGER    NOT NULL REFERENCES oltp.orders (order_id),
    delivery_method_id             INTEGER    REFERENCES oltp.delivery_methods (delivery_method_id),
    contact_person_id              INTEGER    REFERENCES oltp.people (person_id),
    accounts_person_id             INTEGER    REFERENCES oltp.people (person_id),
    salesperson_person_id          INTEGER    NOT NULL REFERENCES oltp.people (person_id),
    packed_by_person_id            INTEGER    REFERENCES oltp.people (person_id),
    invoice_date                   DATE       NOT NULL,
    customer_purchase_order_number VARCHAR,
    delivery_instructions          VARCHAR,
    total_dry_items                INTEGER    CHECK (total_dry_items >= 0),
    total_chiller_items            INTEGER    CHECK (total_chiller_items >= 0),
    confirmed_delivery_time        TIMESTAMP,
    confirmed_received_by          VARCHAR,
    _source_file                   VARCHAR    NOT NULL,
    _ingested_at                   TIMESTAMP  NOT NULL,
    _run_id                        VARCHAR    NOT NULL
);

CREATE TABLE oltp.invoice_lines (
    invoice_line_id   INTEGER        PRIMARY KEY,
    invoice_id        INTEGER        NOT NULL REFERENCES oltp.invoices (invoice_id),
    stock_item_id     INTEGER        NOT NULL REFERENCES oltp.stock_items (stock_item_id),
    description       VARCHAR,
    package_type_id   INTEGER        REFERENCES oltp.package_types (package_type_id),
    quantity          INTEGER        NOT NULL CHECK (quantity > 0),
    unit_price        DECIMAL(18,2)  CHECK (unit_price >= 0),
    tax_rate          DECIMAL(18,3)  NOT NULL CHECK (tax_rate >= 0),
    tax_amount        DECIMAL(18,2)  CHECK (tax_amount >= 0),
    line_profit       DECIMAL(18,2),
    extended_price    DECIMAL(18,2)  CHECK (extended_price >= 0),
    _source_file      VARCHAR        NOT NULL,
    _ingested_at      TIMESTAMP      NOT NULL,
    _run_id           VARCHAR        NOT NULL
);