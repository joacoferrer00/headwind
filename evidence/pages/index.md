---
title: headwind
description: EU aviation operational resilience, chronic weather stress vs the acute COVID shock.
---

# Are weather-resilient hubs also shock-resilient?

European hubs face two kinds of stress: **chronic** (bad weather, every week) and
**acute** (the COVID-19 demand collapse of 2020). _headwind_ crosses 2019-2022 flight
observations with hourly weather at the top 20 EU hubs to ask one question: are the hubs
that shrug off weather the same ones that absorbed the pandemic shock, or are these two
different kinds of resilience?

```sql cross_stress
select * from headwind.cross_stress
```

<ScatterPlot
    data={cross_stress}
    x=weather_resilience
    y=shock_resilience
    series=hub_icao
    xAxisTitle="Weather resilience (1 = bad weather adds no delay)"
    yAxisTitle="Shock resilience (2022 traffic vs 2019)"
    tooltipTitle=airport_name
/>

Each point is a hub. Right means operations barely degrade under bad weather; up means
2022 traffic returned close to (or above) the 2019 baseline. If the two resiliences were
the same thing, the points would line up diagonally; if they are independent, the cloud
is shapeless.

## The three lenses

- **[Weather resilience](/weather-resilience)** - which hubs and routes degrade under
  snow, wind, fog, and storms (BQ1-3).
- **[COVID collapse and recovery](/covid-recovery)** - how fast each hub and carrier fell
  in 2020 and how far they came back by 2022 (BQ4-5).
- **[Cross-stress detail](/cross-stress)** - the headline relationship, hub by hub (BQ6-7).

<small>Data: OpenSky COVID-19 flight dataset (Zenodo), Open-Meteo historical weather,
OurAirports, OpenFlights. Coverage caveat: OpenSky cannot always resolve a flight's
endpoints, so a hub's traffic counts only flights where it is the non-null origin or
destination. Built with dbt + BigQuery; see the
<a href="https://joacoferrer00.github.io/headwind/dbt-docs/">dbt documentation and lineage</a>.</small>
