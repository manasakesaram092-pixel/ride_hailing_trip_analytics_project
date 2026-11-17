
CREATE OR REPLACE STREAMING TABLE bronze_trips
(
    CONSTRAINT data_loaded EXPECT (trip_id IS NOT NULL)
)
COMMENT 'Bronze layer: Ride trips raw data ingested from CSV via Auto Loader'
AS
SELECT 
    *,
    _metadata.file_path AS source_file,
    current_timestamp() AS ingested_at
FROM STREAM read_files(
    '/Volumes/ride_hailing_trip_analytics_project/default/volume/',
    format => 'csv',
    header => true,
    pathGlobFilter => 'ride_trips_raw.csv'
);
