-- Per-hub flight-duration profile by weather event, weighted by movements. Shows how
-- much each weather condition degrades operations at each hub. Answers BQ1-2 (weather
-- resilience and which conditions hurt).
select
    h.hub_icao,
    a.airport_name,
    h.weather_event,
    sum(h.total_movements) as total_movements,
    round(
        safe_divide(
            sum(h.avg_flight_duration_minutes * h.total_movements),
            sum(h.total_movements)
        ),
        1
    ) as avg_flight_duration_minutes
from `headwind-497302.dbt_dev.mart_hub_resilience` as h
inner join `headwind-497302.dbt_dev.dim_airport` as a on a.airport_icao = h.hub_icao
group by h.hub_icao, a.airport_name, h.weather_event
order by h.hub_icao, h.weather_event
