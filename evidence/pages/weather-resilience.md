---
title: Weather resilience
description: How chronic weather stress degrades operations at each EU hub.
---

# Weather resilience (chronic stress)

How much do snow, wind, fog, and storms degrade operations, and where? Flight duration is
the proxy for operational stress: longer and more variable durations mean holding,
re-routing, and congestion.

## Flight duration by weather condition

```sql hub_weather
select * from headwind.hub_weather
```

<BarChart
    data={hub_weather}
    x=airport_name
    y=avg_flight_duration_minutes
    series=weather_event
    type=grouped
    swapXY=true
    title="Average flight duration by hub and weather event (minutes)"
    yAxisTitle="Avg duration (min)"
/>

The gap between a hub's clear-weather bar and its storm or snow bar is its weather
penalty: a small gap is a resilient hub.

## Movements by weather condition

```sql weather_mix
select
    weather_event,
    sum(total_movements) as movements
from headwind.hub_weather
group by weather_event
order by movements desc
```

<BarChart
    data={weather_mix}
    x=weather_event
    y=movements
    title="Total movements by weather event (all hubs)"
/>

## Most weather-sensitive routes

Routes ranked by their weather-sensitivity index: the relative drop in daily flights on
bad-weather days versus clear days in 2019 (1 = the route effectively shuts down on bad
days).

```sql route_weather
select route, total_flights_2019, weather_sensitivity_index
from headwind.route_risk
order by weather_sensitivity_index desc
limit 15
```

<DataTable data={route_weather} rows=15>
    <Column id=route title="Route" />
    <Column id=total_flights_2019 title="Flights (2019)" />
    <Column id=weather_sensitivity_index title="Weather sensitivity" fmt='0.000' />
</DataTable>
