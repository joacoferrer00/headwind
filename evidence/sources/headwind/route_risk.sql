-- Origin-destination pairs with their weather-sensitivity and shock-sensitivity indices.
-- Answers BQ3 (route weather risk) and feeds the cross-stress view at route grain.
-- Limited to the busiest 2019 routes so the page stays legible.
select
    origin_icao,
    destination_icao,
    origin_icao || ' -> ' || destination_icao as route,
    total_flights_2019,
    weather_sensitivity_index,
    shock_sensitivity_index
from `headwind-497302.dbt_dev.mart_route_risk`
where weather_sensitivity_index is not null and shock_sensitivity_index is not null
order by total_flights_2019 desc
limit 200
