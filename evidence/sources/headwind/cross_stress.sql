-- The headline: one weather-resilience score and one shock-resilience score per hub,
-- so the dashboard can show whether the two forms of resilience are related.
-- shock_resilience: average 2022 recovery ratio vs the 2019 baseline (1.0 = fully back).
-- weather_resilience: 1 minus the relative flight-duration penalty under non-clear
-- weather (1.0 = bad weather adds nothing; lower = operations degrade more under stress).
with shock as (
    select
        hub_icao,
        avg(case when year = 2022 then recovery_ratio end) as recovery_2022
    from `headwind-497302.dbt_dev.mart_hub_recovery`
    group by hub_icao
),

weather as (
    select
        hub_icao,
        safe_divide(
            sum(case when weather_event != 'clear' then avg_flight_duration_minutes * total_movements end),
            sum(case when weather_event != 'clear' then total_movements end)
        ) as bad_weather_duration,
        safe_divide(
            sum(case when weather_event = 'clear' then avg_flight_duration_minutes * total_movements end),
            sum(case when weather_event = 'clear' then total_movements end)
        ) as clear_weather_duration
    from `headwind-497302.dbt_dev.mart_hub_resilience`
    group by hub_icao
)

select
    a.airport_name,
    a.country_iso2,
    s.hub_icao,
    round(s.recovery_2022, 3) as shock_resilience,
    round(1 - safe_divide(w.bad_weather_duration - w.clear_weather_duration, w.clear_weather_duration), 3)
        as weather_resilience
from shock as s
inner join weather as w using (hub_icao)
inner join `headwind-497302.dbt_dev.dim_airport` as a on a.airport_icao = s.hub_icao
order by shock_resilience desc
