{{
    config(
        cluster_by=['origin_icao', 'destination_icao'],
    )
}}

-- Per OD-pair weather and shock sensitivity.
-- weather_sensitivity_index: relative drop in flights on bad-weather days vs clear days in 2019.
-- shock_sensitivity_index: relative drop in flights during collapse phase vs 2019 baseline.
-- Only OD pairs where at least one endpoint is a hub and pair has >= 12 flights in 2019.
with hubs as (
    select airport_icao from {{ ref('seed_top_hubs') }}
),

flights as (
    select
        origin_icao,
        destination_icao,
        flight_date,
        coalesce(origin_weather_event, 'clear') as hub_weather_event,
    from {{ ref('int_flights_with_weather') }}
    where
        origin_icao in (select hubs.airport_icao from hubs)
        or destination_icao in (select hubs.airport_icao from hubs)
),

-- weather sensitivity: compare avg daily flights on clear vs non-clear days in 2019
weather_daily as (
    select
        origin_icao,
        destination_icao,
        flight_date,
        hub_weather_event,
        count(*) as daily_flights,
    from flights
    where extract(year from flight_date) = 2019
    group by origin_icao, destination_icao, flight_date, hub_weather_event
),

weather_agg as (
    select
        origin_icao,
        destination_icao,
        avg(case when hub_weather_event = 'clear' then daily_flights end) as avg_flights_clear,
        avg(case when hub_weather_event != 'clear' then daily_flights end)
            as avg_flights_bad_weather,
        count(distinct case when hub_weather_event = 'clear' then flight_date end)
            as clear_days_2019,
        count(distinct case when hub_weather_event != 'clear' then flight_date end)
            as bad_weather_days_2019,
        sum(daily_flights) as total_flights_2019,
    from weather_daily
    group by origin_icao, destination_icao
),

-- shock sensitivity: compare collapse phase to 2019 baseline
shock_agg as (
    select
        origin_icao,
        destination_icao,
        avg(case when extract(year from flight_month) = 2019 then monthly_flights end)
            as avg_monthly_2019,
        avg(
            case
                when flight_month between cast('2020-01-01' as date) and cast('2020-06-30' as date)
                    then monthly_flights
            end
        ) as avg_monthly_collapse,
    from (
        select
            origin_icao,
            destination_icao,
            date_trunc(flight_date, month) as flight_month,
            count(*) as monthly_flights
        from flights
        group by origin_icao, destination_icao, date_trunc(flight_date, month)
    ) as monthly_by_od
    group by origin_icao, destination_icao
),

final as (
    select
        w.origin_icao,
        w.destination_icao,
        w.total_flights_2019,
        w.avg_flights_clear,
        w.avg_flights_bad_weather,
        round(
            safe_divide(w.avg_flights_clear - w.avg_flights_bad_weather, w.avg_flights_clear),
            4
        ) as weather_sensitivity_index,
        s.avg_monthly_2019,
        s.avg_monthly_collapse,
        round(
            safe_divide(s.avg_monthly_2019 - s.avg_monthly_collapse, s.avg_monthly_2019),
            4
        ) as shock_sensitivity_index,
    from weather_agg as w
    inner join shock_agg as s
        on
            w.origin_icao = s.origin_icao
            and w.destination_icao = s.destination_icao
    where w.total_flights_2019 >= 12
)

select * from final
