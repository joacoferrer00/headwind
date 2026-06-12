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

-- Joins each hub-touching flight to hourly weather at origin and destination.
-- Only flights where origin or destination is one of the top-20 EU hubs are included.
-- Weather is available only for hub airports; non-hub endpoints get null weather.
-- Join key: timestamp_trunc(first_seen_at, HOUR) = origin observation_hour,
--           timestamp_trunc(last_seen_at, HOUR) = destination observation_hour.
with hubs as (
    select airport_icao from {{ ref('seed_top_hubs') }}
),

flights as (
    select
        flight_id,
        callsign,
        airline_icao,
        flight_number,
        aircraft_icao24,
        aircraft_typecode,
        origin_icao,
        destination_icao,
        flight_date,
        first_seen_at,
        last_seen_at,
        flight_duration_minutes,
    from {{ ref('stg_opensky__flights') }}
    where
        origin_icao in (select hubs.airport_icao from hubs)
        or destination_icao in (select hubs.airport_icao from hubs)
),

-- Deduplicate by (airport_icao, observation_hour) in case obs_time precision
-- introduced sub-hour duplicates after the parquet round-trip.
weather as (
    select
        airport_icao,
        observation_hour,
        avg(temperature_2m) as temperature_2m,
        avg(relative_humidity_2m) as relative_humidity_2m,
        avg(wind_speed_10m) as wind_speed_10m,
        avg(wind_gusts_10m) as wind_gusts_10m,
        avg(precipitation) as precipitation,
        avg(snowfall) as snowfall,
        avg(cloud_cover) as cloud_cover,
        avg(surface_pressure) as surface_pressure,
    from {{ ref('stg_openmeteo__weather') }}
    group by airport_icao, observation_hour
),

with_origin_weather as (
    select
        f.flight_id,
        f.callsign,
        f.airline_icao,
        f.flight_number,
        f.aircraft_icao24,
        f.aircraft_typecode,
        f.origin_icao,
        f.destination_icao,
        f.flight_date,
        f.first_seen_at,
        f.last_seen_at,
        f.flight_duration_minutes,
        wo.temperature_2m as origin_temperature_2m,
        wo.relative_humidity_2m as origin_relative_humidity_2m,
        wo.wind_speed_10m as origin_wind_speed_10m,
        wo.wind_gusts_10m as origin_wind_gusts_10m,
        wo.precipitation as origin_precipitation,
        wo.snowfall as origin_snowfall,
        wo.cloud_cover as origin_cloud_cover,
        wo.surface_pressure as origin_surface_pressure,
        case
            when wo.snowfall > 0 then 'snow'
            when wo.wind_gusts_10m > 20 and wo.surface_pressure < 990 then 'storm'
            when wo.wind_speed_10m > 10 or wo.wind_gusts_10m > 15 then 'windy'
            when wo.relative_humidity_2m > 90 and wo.cloud_cover > 80 then 'fog'
            when wo.airport_icao is not null then 'clear'
        end as origin_weather_event,
    from flights as f
    left join weather as wo
        on
            f.origin_icao = wo.airport_icao
            and timestamp_trunc(f.first_seen_at, hour) = wo.observation_hour
),

final as (
    select
        f.flight_id,
        f.callsign,
        f.airline_icao,
        f.flight_number,
        f.aircraft_icao24,
        f.aircraft_typecode,
        f.origin_icao,
        f.destination_icao,
        f.flight_date,
        f.first_seen_at,
        f.last_seen_at,
        f.flight_duration_minutes,
        f.origin_temperature_2m,
        f.origin_relative_humidity_2m,
        f.origin_wind_speed_10m,
        f.origin_wind_gusts_10m,
        f.origin_precipitation,
        f.origin_snowfall,
        f.origin_cloud_cover,
        f.origin_surface_pressure,
        f.origin_weather_event,
        wd.temperature_2m as destination_temperature_2m,
        wd.relative_humidity_2m as destination_relative_humidity_2m,
        wd.wind_speed_10m as destination_wind_speed_10m,
        wd.wind_gusts_10m as destination_wind_gusts_10m,
        wd.precipitation as destination_precipitation,
        wd.snowfall as destination_snowfall,
        wd.cloud_cover as destination_cloud_cover,
        wd.surface_pressure as destination_surface_pressure,
        case
            when wd.snowfall > 0 then 'snow'
            when wd.wind_gusts_10m > 20 and wd.surface_pressure < 990 then 'storm'
            when wd.wind_speed_10m > 10 or wd.wind_gusts_10m > 15 then 'windy'
            when wd.relative_humidity_2m > 90 and wd.cloud_cover > 80 then 'fog'
            when wd.airport_icao is not null then 'clear'
        end as destination_weather_event,
    from with_origin_weather as f
    left join weather as wd
        on
            f.destination_icao = wd.airport_icao
            and timestamp_trunc(f.last_seen_at, hour) = wd.observation_hour
)

select * from final
