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