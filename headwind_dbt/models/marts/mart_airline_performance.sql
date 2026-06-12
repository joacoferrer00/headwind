{{
    config(
        partition_by={
            'field': 'flight_month',
            'data_type': 'date',
            'granularity': 'month',
        },
        cluster_by=['airline_icao'],
    )
}}

-- Monthly airline performance: flight counts, duration stats, hub concentration,
-- weather-adjusted relative performance vs the airline's own 2019 baseline.
with hubs as (
    select airport_icao from {{ ref('seed_top_hubs') }}
),

flights as (
    select
        airline_icao,
        origin_icao,
        destination_icao,
        flight_date,
        date_trunc(flight_date, month) as flight_month,
        flight_duration_minutes,
        coalesce(origin_weather_event, 'clear') as origin_weather_event,
    from {{ ref('int_flights_with_weather') }}
    where airline_icao is not null
),

monthly as (
    select
        airline_icao,
        flight_month,
        count(*) as total_flights,
        round(avg(flight_duration_minutes), 2) as avg_flight_duration_minutes,
        round(stddev(flight_duration_minutes), 2) as stddev_flight_duration_minutes,
        -- hub concentration: share of flights departing from or arriving at a hub
        round(
            countif(
                origin_icao in (select hubs.airport_icao from hubs)
                or destination_icao in (select hubs.airport_icao from hubs)
            ) / count(*),
            4
        ) as hub_concentration_ratio,
        -- clear-weather-only flights (for weather-adjusted comparison)
        countif(origin_weather_event = 'clear') as clear_weather_flights,
        round(
            avg(case when origin_weather_event = 'clear' then flight_duration_minutes end),
            2
        ) as avg_duration_clear_weather,
        round(
            avg(case when origin_weather_event != 'clear' then flight_duration_minutes end),
            2
        ) as avg_duration_bad_weather,
    from flights
    group by airline_icao, flight_month
),

-- 2019 baseline per airline per calendar month
baseline_2019 as (
    select
        airline_icao,
        extract(month from flight_month) as calendar_month,
        avg(total_flights) as avg_flights_2019,
    from monthly
    where extract(year from flight_month) = 2019
    group by airline_icao, calendar_month
),

final as (
    select
        m.airline_icao,
        m.flight_month,
        extract(year from m.flight_month) as year,
        m.total_flights,
        m.avg_flight_duration_minutes,
        m.stddev_flight_duration_minutes,
        m.hub_concentration_ratio,
        m.clear_weather_flights,
        m.avg_duration_clear_weather,
        m.avg_duration_bad_weather,
        b.avg_flights_2019 as baseline_avg_flights_2019,
        round(safe_divide(m.total_flights, b.avg_flights_2019), 4) as traffic_recovery_ratio,
    from monthly as m
    left join baseline_2019 as b
        on
            m.airline_icao = b.airline_icao
            and extract(month from m.flight_month) = b.calendar_month
)

select * from final
