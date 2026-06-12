{{
    config(
        partition_by={
            'field': 'flight_month',
            'data_type': 'date',
            'granularity': 'month',
        },
        cluster_by=['hub_icao', 'weather_event'],
    )
}}

-- Hub traffic and flight-duration stats per hub × month × weather condition.
-- Each flight contributes one departure row (if origin is a hub) and one arrival row
-- (if destination is a hub), each carrying that hub's weather event for that movement.
with hubs as (
    select airport_icao from {{ ref('seed_top_hubs') }}
),

departures as (
    select
        origin_icao as hub_icao,
        date_trunc(flight_date, month) as flight_month,
        coalesce(origin_weather_event, 'clear') as weather_event,
        flight_duration_minutes,
    from {{ ref('int_flights_with_weather') }}
    where origin_icao in (select hubs.airport_icao from hubs)
),

arrivals as (
    select
        destination_icao as hub_icao,
        date_trunc(flight_date, month) as flight_month,
        coalesce(destination_weather_event, 'clear') as weather_event,
        flight_duration_minutes,
    from {{ ref('int_flights_with_weather') }}
    where destination_icao in (select hubs.airport_icao from hubs)
),

movements as (
    select * from departures
    union all
    select * from arrivals
),

final as (
    select
        hub_icao,
        flight_month,
        weather_event,
        count(*) as total_movements,
        round(avg(flight_duration_minutes), 2) as avg_flight_duration_minutes,
        round(stddev(flight_duration_minutes), 2) as stddev_flight_duration_minutes,
        round(approx_quantiles(flight_duration_minutes, 100)[offset(50)], 2)
            as p50_flight_duration_minutes,
        round(approx_quantiles(flight_duration_minutes, 100)[offset(95)], 2)
            as p95_flight_duration_minutes,
    from movements
    group by hub_icao, flight_month, weather_event
)

select * from final
