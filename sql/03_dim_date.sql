-- =====================================================
-- 03_dim_date.sql : load dw.dim_date (full reload)
-- Range: 2013-01-01 to 2016-12-31. Fiscal year starts Nov 1.
-- =====================================================

BEGIN TRANSACTION;

DELETE FROM dw.dim_date;

INSERT INTO dw.dim_date (
    date_key, full_date, day_of_month, day_name, weekday_number,
    month_number, month_name, quarter, calendar_year,
    fiscal_month, fiscal_quarter, fiscal_year
)
WITH calendar AS (
    SELECT CAST(d AS DATE) AS full_date
    FROM generate_series(DATE '2013-01-01', DATE '2016-12-31', INTERVAL 1 DAY) AS t(d)
),
parts AS (
    SELECT
        full_date,
        month(full_date)  AS month_number,
        year(full_date)   AS calendar_year,
        ((month(full_date) + 1) % 12) + 1 AS fiscal_month
    FROM calendar
)
SELECT
    CAST(strftime(full_date, '%Y%m%d') AS INTEGER) AS date_key,
    full_date,
    day(full_date)                                 AS day_of_month,
    dayname(full_date)                             AS day_name,
    isodow(full_date)                              AS weekday_number,
    month_number,
    monthname(full_date)                           AS month_name,
    quarter(full_date)                             AS quarter,
    calendar_year,
    fiscal_month,
    (fiscal_month + 2) // 3                        AS fiscal_quarter,
    CASE WHEN month_number >= 11
         THEN calendar_year + 1
         ELSE calendar_year
    END                                            AS fiscal_year
FROM parts;

-- Unknown member
INSERT INTO dw.dim_date (
    date_key, full_date, day_of_month, day_name, weekday_number,
    month_number, month_name, quarter, calendar_year,
    fiscal_month, fiscal_quarter, fiscal_year
)
VALUES (-1, NULL, NULL, 'Unknown', NULL, NULL, 'Unknown', NULL, NULL, NULL, NULL, NULL);

COMMIT;
