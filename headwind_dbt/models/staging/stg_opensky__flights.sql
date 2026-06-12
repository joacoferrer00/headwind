{{
    config(
        materialized='table',
        partition_by={
            'field': 'flight_date',
            'data_type': 'date',
            'granularity': 'month',
        },
        cluster_by=['origin_icao', 'destination_icao'],
    )
}}

with source as (
    select * from {{ source('headwind_raw', 'flights') }}
),

cleaned as (
    select
        {{ dbt_utils.generate_surrogate_key(['callsign', 'day', 'firstseen']) }} as flight_id,
        callsign,
        substr(callsign, 1, 3) as airline_icao,
        number as flight_number,
        icao24 as aircraft_icao24,
        registration as aircraft_registration,
        typecode as aircraft_typecode,
        origin as origin_icao,
        destination as destination_icao,
        -- day is stored as 'YYYY-MM-DD HH:MM:SS+00:00' in some Parquet partitions
        parse_date('%Y-%m-%d', substr(day, 1, 10)) as flight_date,
        safe.timestamp_millis(firstseen) as first_seen_at,
        safe.timestamp_millis(lastseen) as last_seen_at,
        round((lastseen - firstseen) / 60000.0, 2) as flight_duration_minutes,
        latitude_1,
        longitude_1,
        altitude_1,
        latitude_2,
        longitude_2,
        altitude_2,
    from source
    where
        day is not null
        and (origin is not null or destination is not null)
        and firstseen is not null
        and lastseen is not null
        and lastseen >= firstseen
        and safe.timestamp_millis(firstseen) is not null
        and safe.timestamp_millis(lastseen) is not null
)

-- The raw Parquet files contain exact-duplicate rows; keep one row per
-- callsign + flight_date + first_seen_at.
select * from cleaned
qualify
    row_number() over (partition by callsign, flight_date, first_seen_at order by last_seen_at desc)
    = 1
