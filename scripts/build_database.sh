#!/bin/bash

# Build DuckDB database from flight track JSON files
echo "Building DuckDB database from flight track data..."

# Remove old database if it exists
rm -f data/data.duckdb

# Create the database and load all flight tracks
duckdb data/data.duckdb << 'EOF'
-- Create table with all flight track points from JSON files
CREATE TABLE flight_tracks AS
WITH unnested AS (
    SELECT
        regexp_extract(filename, 'flight-track-(\d{4}-\d{2}-\d{2})\.json', 1) as flight_date,
        timestamp as base_timestamp,
        unnest(range(1, array_length(trace)+1)) as idx,
        unnest(trace) as point
    FROM read_json('data/flight-track-*.json', filename=true, format='unstructured', ignore_errors=true)
)
SELECT
    flight_date,
    base_timestamp,
    idx,
    point[1]::DOUBLE as time_offset,
    point[2]::DOUBLE as lat,
    point[3]::DOUBLE as lng,
    COALESCE(TRY_CAST(point[4] AS INTEGER), 0) as altitude_ft,
    to_timestamp(base_timestamp + point[1]::DOUBLE) as timestamp
FROM unnested
ORDER BY flight_date, idx;

-- Create flight summary table with segmentation
CREATE TABLE flight_summary AS
WITH altitudes AS (
    SELECT
        *,
        CASE WHEN altitude_ft < 2000 THEN 1 ELSE 0 END as is_ground
    FROM flight_tracks
),
transitions AS (
    SELECT
        *,
        LAG(is_ground, 1, 1) OVER (PARTITION BY flight_date ORDER BY idx) as prev_ground,
        CASE
            WHEN LAG(is_ground, 1, 1) OVER (PARTITION BY flight_date ORDER BY idx) = 1 AND is_ground = 0
            THEN 1 ELSE 0
        END as is_takeoff
    FROM altitudes
),
flight_segments AS (
    SELECT
        *,
        SUM(is_takeoff) OVER (PARTITION BY flight_date ORDER BY idx) as flight_num
    FROM transitions
    WHERE is_ground = 0  -- Only airborne points
),
flight_endpoints AS (
    SELECT
        flight_date,
        base_timestamp,
        flight_num,
        MIN(time_offset) as takeoff_time,
        MAX(time_offset) as landing_time,
        MIN(idx) as takeoff_idx,
        MAX(idx) as landing_idx,
        COUNT(*) as num_points
    FROM flight_segments
    GROUP BY flight_date, base_timestamp, flight_num
),
flight_details AS (
    SELECT DISTINCT
        e.flight_date,
        e.base_timestamp,
        e.flight_num,
        e.takeoff_time,
        e.landing_time,
        e.num_points,
        -- Get takeoff details
        FIRST_VALUE(s.lat) OVER (PARTITION BY e.flight_date, e.flight_num ORDER BY s.idx) as takeoff_lat,
        FIRST_VALUE(s.lng) OVER (PARTITION BY e.flight_date, e.flight_num ORDER BY s.idx) as takeoff_lng,
        FIRST_VALUE(s.altitude_ft) OVER (PARTITION BY e.flight_date, e.flight_num ORDER BY s.idx) as takeoff_altitude,
        -- Get landing details
        LAST_VALUE(s.lat) OVER (PARTITION BY e.flight_date, e.flight_num ORDER BY s.idx
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as landing_lat,
        LAST_VALUE(s.lng) OVER (PARTITION BY e.flight_date, e.flight_num ORDER BY s.idx
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as landing_lng,
        LAST_VALUE(s.altitude_ft) OVER (PARTITION BY e.flight_date, e.flight_num ORDER BY s.idx
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as landing_altitude
    FROM flight_endpoints e
    JOIN flight_segments s ON e.flight_date = s.flight_date AND e.flight_num = s.flight_num
)
SELECT
    flight_date,
    flight_num,
    strftime(to_timestamp(base_timestamp + takeoff_time), '%Y-%m-%dT%H:%M:%SZ') as takeoff_timestamp,
    ROUND(takeoff_lat, 6) as takeoff_lat,
    ROUND(takeoff_lng, 6) as takeoff_lng,
    COALESCE(takeoff_altitude, 0) as takeoff_altitude_ft,
    CASE
        WHEN ABS(takeoff_lat - (-25.9)) < 0.5 AND ABS(takeoff_lng - 32.57) < 0.5 THEN 'Maputo'
        WHEN ABS(takeoff_lat - (-12.99)) < 0.5 AND ABS(takeoff_lng - 40.52) < 0.5 THEN 'Pemba'
        WHEN ABS(takeoff_lat - (-10.82)) < 1.0 AND ABS(takeoff_lng - 40.53) < 1.0 THEN 'Afungi'
        ELSE 'Unknown'
    END as takeoff_location,
    strftime(to_timestamp(base_timestamp + landing_time), '%Y-%m-%dT%H:%M:%SZ') as landing_timestamp,
    ROUND(landing_lat, 6) as landing_lat,
    ROUND(landing_lng, 6) as landing_lng,
    COALESCE(landing_altitude, 0) as landing_altitude_ft,
    CASE
        WHEN ABS(landing_lat - (-25.9)) < 0.5 AND ABS(landing_lng - 32.57) < 0.5 THEN 'Maputo'
        WHEN ABS(landing_lat - (-12.99)) < 0.5 AND ABS(landing_lng - 40.52) < 0.5 THEN 'Pemba'
        -- Wider box and altitude check for Afungi (signal often lost on approach)
        WHEN ABS(landing_lat - (-10.82)) < 1.0 AND ABS(landing_lng - 40.53) < 1.0
             AND COALESCE(landing_altitude, 10000) > 3000 THEN 'Afungi'
        WHEN landing_lat < -10.0 AND landing_lat > -12.0
             AND landing_lng > 39.5 AND landing_lng < 41.5
             AND COALESCE(landing_altitude, 10000) > 5000 THEN 'Afungi'
        ELSE 'Unknown'
    END as landing_location,
    ROUND((landing_time - takeoff_time) / 60.0, 1) as flight_duration_minutes
FROM flight_details
WHERE (landing_time - takeoff_time) > 900  -- At least 15 minutes
  AND num_points > 50  -- At least 50 airborne points
ORDER BY flight_date, flight_num;

-- Show summary
SELECT COUNT(*) as total_points FROM flight_tracks;
SELECT COUNT(*) as total_flights FROM flight_summary;
EOF

echo "✅ Database created successfully!"
echo "Tables created:"
echo "  - flight_tracks: All raw flight track points"
echo "  - flight_summary: Aggregated flight segments"
