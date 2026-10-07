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
    latitude                    DECIMAL(9,6)  CHECK (latitude  BETWEEN  -90 AND  90),
    longitude                   DECIMAL(9,6)  CHECK (longitude BETWEEN -180 AND 180),
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
    delivery_location_lat         DECIMAL(9,6)   CHECK (delivery_location_lat  BETWEEN  -90 AND  90),
    delivery_location_long        DECIMAL(9,6)   CHECK (delivery_location_long BETWEEN -180 AND 180),
    _source_file                  VARCHAR        NOT NULL,
    _ingested_at                  TIMESTAMP      NOT NULL,
    _run_id                       VARCHAR        NOT NULL
);