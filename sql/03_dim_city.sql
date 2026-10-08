-- =====================================================
-- 03_dim_city.sql : load dw.dim_city (SCD1, full reload)
-- Source: oltp.cities + state_provinces + countries
-- =====================================================

BEGIN TRANSACTION;

DELETE FROM dw.dim_city;

INSERT INTO dw.dim_city (
    city_key, city_id, city_name,
    state_province_code, state_province_name, sales_territory,
    country_name, continent, region, subregion,
    latitude, longitude, latest_recorded_population
)
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.city_id) AS city_key,
    ci.city_id,
    ci.city_name,
    sp.state_province_code,
    sp.state_province_name,
    sp.sales_territory,
    co.country_name,
    co.continent,
    co.region,
    co.subregion,
    ci.latitude,
    ci.longitude,
    ci.latest_recorded_population
FROM oltp.cities AS ci
JOIN oltp.state_provinces AS sp
  ON sp.state_province_id = ci.state_province_id
JOIN oltp.countries AS co
  ON co.country_id = sp.country_id;

-- Unknown member
INSERT INTO dw.dim_city (
    city_key, city_id, city_name,
    state_province_code, state_province_name, sales_territory,
    country_name, continent, region, subregion,
    latitude, longitude, latest_recorded_population
)
VALUES (-1, -1, 'Unknown', NULL, 'Unknown', 'Unknown', 'Unknown', NULL, NULL, NULL, NULL, NULL, NULL);

COMMIT;
