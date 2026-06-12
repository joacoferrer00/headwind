with source as (
    select * from {{ source('headwind_raw', 'weather') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key(['airport_icao', 'cast(obs_time as string)']) }}
            as weather_observation_id,
        airport_icao,
        -- obs_time loaded as INT64 nanoseconds from pyarrow datetime64[ns]
        timestamp_micros(cast(obs_time / 1000 as int64)) as observed_at,
        obs_date as observation_date,
        timestamp_trunc(timestamp_micros(cast(obs_time / 1000 as int64)), hour) as observation_hour,
        temperature_2m,
        relative_humidity_2m,
        wind_speed_10m,
        wind_gusts_10m,
        wind_direction_10m,
        precipitation,
        rain,
        snowfall,
        snow_depth,
        cloud_cover,
        surface_pressure,
    from source
)

select * from renamed
