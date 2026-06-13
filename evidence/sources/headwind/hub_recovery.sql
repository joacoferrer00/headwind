-- Monthly traffic per hub across 2019-2022 with recovery ratio vs the 2019 baseline
-- and pandemic phase, enriched with the airport name. Answers BQ4 (collapse + recovery).
select
    r.hub_icao,
    a.airport_name,
    r.flight_month,
    r.year,
    r.total_movements,
    r.baseline_movements_2019,
    r.recovery_ratio,
    r.pandemic_phase
from `headwind-497302.dbt_dev.mart_hub_recovery` as r
inner join `headwind-497302.dbt_dev.dim_airport` as a on a.airport_icao = r.hub_icao
order by r.hub_icao, r.flight_month
