
-- ==========================================
-- GOLD 1: MONTHLY TRIPS SUMMARY
-- ==========================================

CREATE OR REFRESH MATERIALIZED VIEW gold_monthly_trips AS

SELECT
    DATE_TRUNC('MONTH', trip_date) AS trip_month,
    COUNT(*) AS trips,
    SUM(distance_km) AS total_km,

    SUM(fare_amount - COALESCE(discount_amount, 0))
        AS net_revenue,

    SUM(driver_payout) AS driver_payout,

    SUM(fare_amount - COALESCE(discount_amount, 0))
        - SUM(driver_payout) AS platform_earnings

FROM silver_trip

GROUP BY DATE_TRUNC('MONTH', trip_date);


-- ==========================================
-- GOLD 2: CITY SUMMARY
-- ==========================================

CREATE OR REFRESH MATERIALIZED VIEW gold_city_summary AS

SELECT
    region,
    city,
    COUNT(*) AS trips,

    SUM(fare_amount - COALESCE(discount_amount, 0))
        AS net_revenue,

    AVG(fare_amount - COALESCE(discount_amount, 0))
        AS avg_fare_per_trip

FROM silver_trip

GROUP BY region, city;


-- ==========================================
-- GOLD 3: VEHICLE SUMMARY
-- ==========================================

CREATE OR REFRESH MATERIALIZED VIEW gold_vehicle_summary AS

SELECT
    vehicle_type,
    COUNT(*) AS trips,
    SUM(distance_km) AS total_km,

    SUM(fare_amount - COALESCE(discount_amount, 0))
        AS net_revenue,

    AVG(customer_rating) AS avg_rating

FROM silver_trip

GROUP BY vehicle_type;



-- ==========================================
-- GOLD 4: PAYMENT SUMMARY
-- ==========================================

CREATE OR REFRESH MATERIALIZED VIEW gold_payment_summary AS

SELECT
    payment_method,
    COUNT(*) AS trips,

    SUM(fare_amount - COALESCE(discount_amount, 0))
        AS net_revenue,

    SUM(
        CASE
            WHEN payment_status = 'Pending'
            THEN fare_amount - COALESCE(discount_amount, 0)
            ELSE 0
        END
    ) AS pending_amount

FROM silver_trip

GROUP BY payment_method;



-- ==========================================
-- GOLD 5: DATA QUALITY SUMMARY
-- ==========================================

CREATE OR REFRESH MATERIALIZED VIEW gold_data_qualitys AS

WITH bronze_quality AS (
    SELECT
        COUNT(*) AS bronze_rows,

        COUNT(*) - COUNT(DISTINCT trip_id)
            AS duplicate_rows,

        SUM(CASE
            WHEN distance_km <= 0 THEN 1 ELSE 0
        END) AS invalid_distance_rows,

        SUM(CASE
            WHEN rate_per_km < 0 THEN 1 ELSE 0
        END) AS invalid_rate_rows,

        SUM(CASE
            WHEN city IS NULL OR TRIM(city) = ''
            THEN 1 ELSE 0
        END) AS missing_city_rows,

        SUM(CASE
            WHEN payment_method IS NULL
                 OR TRIM(payment_method) = ''
            THEN 1 ELSE 0
        END) AS missing_payment_rows,

        SUM(CASE
            WHEN fare_amount IS NULL
            THEN 1 ELSE 0
        END) AS missing_fare_rows,

        SUM(CASE
            WHEN customer_rating IS NULL
            THEN 1 ELSE 0
        END) AS missing_rating_rows

    FROM bronze_trips
),

silver_quality AS (
    SELECT COUNT(*) AS clean_rows
    FROM silver_trip
),

rejected_quality AS (
    SELECT COUNT(*) AS rejected_rows
    FROM silver_trip_rejected
)

SELECT
    b.bronze_rows,
    b.duplicate_rows,
    b.invalid_distance_rows,
    b.invalid_rate_rows,
    b.missing_city_rows,
    b.missing_payment_rows,
    b.missing_fare_rows,
    b.missing_rating_rows,

    s.clean_rows,
    r.rejected_rows,

    b.bronze_rows -
        (s.clean_rows + r.rejected_rows + b.duplicate_rows)
        AS reconciliation_difference,

    CASE
        WHEN b.bronze_rows =
             s.clean_rows + r.rejected_rows + b.duplicate_rows
        THEN 'Passed'
        ELSE 'Failed'
    END AS reconciliation_status

FROM bronze_quality b
CROSS JOIN silver_quality s
CROSS JOIN rejected_quality r;