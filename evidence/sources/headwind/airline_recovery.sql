-- Monthly traffic for the largest carriers (by total 2019-2022 flights), with their
-- recovery ratio vs their own 2019 baseline and airline name. Answers BQ5 (how carriers
-- reshaped their network through the shock).
with ranked as (
    select airline_icao, sum(total_flights) as lifetime_flights
    from `headwind-497302.dbt_dev.mart_airline_performance`
    group by airline_icao
    order by lifetime_flights desc
    limit 12
)

select
    p.airline_icao,
    coalesce(al.airline_name, p.airline_icao) as airline_name,
    p.flight_month,
    p.year,
    p.total_flights,
    p.traffic_recovery_ratio
from `headwind-497302.dbt_dev.mart_airline_performance` as p
inner join ranked as r on r.airline_icao = p.airline_icao
left join `headwind-497302.dbt_dev.dim_airline` as al on al.airline_icao = p.airline_icao
order by p.airline_icao, p.flight_month
