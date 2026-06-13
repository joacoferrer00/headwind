---
title: Cross-stress detail
description: Whether resilience to chronic weather stress predicts resilience to the acute shock.
---

# Cross-stress: do the two resiliences travel together?

This is the headline question. For each hub we have a **weather-resilience** score (how
little flight duration degrades under non-clear weather) and a **shock-resilience** score
(how close 2022 traffic returned to the 2019 baseline). If a hub being good at one
predicted being good at the other, the scatter below would trend along a diagonal.

```sql cross_stress
select * from headwind.cross_stress
```

```sql correlation
select round(corr(weather_resilience, shock_resilience), 2) as r
from headwind.cross_stress
```

Across the 20 hubs, the correlation between the two scores is
**<Value data={correlation} column=r />**. That is weak: knowing a hub handles weather
well tells you little about how it weathered the shock. Operational robustness to daily
weather and structural recovery from a demand collapse are largely **separate** kinds of
resilience.

<ScatterPlot
    data={cross_stress}
    x=weather_resilience
    y=shock_resilience
    series=hub_icao
    xAxisTitle="Weather resilience"
    yAxisTitle="Shock resilience (2022 vs 2019)"
    tooltipTitle=airport_name
/>

## Hub-by-hub scores

```sql cross_stress_table
select
    airport_name,
    country_iso2,
    weather_resilience,
    shock_resilience
from headwind.cross_stress
order by shock_resilience desc
```

<DataTable data={cross_stress_table} rows=20>
    <Column id=airport_name title="Hub" />
    <Column id=country_iso2 title="Country" />
    <Column id=weather_resilience title="Weather resilience" fmt='0.000' />
    <Column id=shock_resilience title="Shock resilience" fmt='0.000' />
</DataTable>

<small>Interpretation note: both scores are coarse, single-number summaries of richer
behaviour (see the [weather](/weather-resilience) and [recovery](/covid-recovery) pages
for the underlying detail). They are meant to surface whether a relationship exists, not
to rank hubs precisely.</small>
