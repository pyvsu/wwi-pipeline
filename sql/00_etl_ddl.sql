-- =====================================================
-- 00_etl_ddl.sql : Audit tables (NEVER dropped)
-- Safe to run many times (IF NOT EXISTS).
-- =====================================================

CREATE SCHEMA IF NOT EXISTS etl;

CREATE TABLE IF NOT EXISTS etl.pipeline_run (
    run_id         VARCHAR    PRIMARY KEY,
    batch_id       INTEGER    NOT NULL,
    start_time     TIMESTAMP  NOT NULL,
    end_time       TIMESTAMP,
    status         VARCHAR    NOT NULL CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),
    error_message  VARCHAR
);

CREATE TABLE IF NOT EXISTS etl.ingestion_log (
    run_id          VARCHAR    NOT NULL,
    source_file     VARCHAR    NOT NULL,
    target_table    VARCHAR    NOT NULL,
    rows_read       INTEGER    NOT NULL,
    rows_loaded     INTEGER    NOT NULL,
    rows_duplicate  INTEGER    NOT NULL,
    rows_rejected   INTEGER    NOT NULL,
    loaded_at       TIMESTAMP  NOT NULL,
    PRIMARY KEY (run_id, source_file)
);

CREATE TABLE IF NOT EXISTS etl.rejected_rows (
    run_id          VARCHAR    NOT NULL,
    source_file     VARCHAR    NOT NULL,
    row_key         VARCHAR,
    column_name     VARCHAR,
    original_value  VARCHAR,
    reason          VARCHAR,
    rejected_at     TIMESTAMP  NOT NULL
);