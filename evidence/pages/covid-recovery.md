---
title: COVID collapse and recovery
description: How fast each hub and carrier fell in 2020 and how far they recovered by 2022.
---

# COVID collapse and recovery (acute shock)

The pandemic is a natural experiment: a sudden, system-wide demand collapse in Q2 2020,
followed by an uneven recovery through 2022. Recovery ratio is monthly traffic divided by
the same calendar month in 2019 (1.0 = back to the pre-shock baseline).

## Hub recovery trajectories

```sql hub_recovery
select * from headwind.hub_recovery
```

<LineChart
    data={hub_recovery}
    x=flight_month
    y=recovery_ratio
    series=airport_name
    title="Monthly traffic vs 2019 baseline, by hub"
    yAxisTitle="Recovery ratio (1.0 = 2019 level)"
    yMax=1.5
/>

The trough in spring 2020 is the collapse; how quickly a line climbs back toward 1.0 is
the recovery speed.

## Where each hub stood by end of 2022

```sql hub_recovery_2022
select
    airport_name,
    round(avg(recovery_ratio), 3) as recovery_2022
from headwind.hub_recovery
where year = 2022
group by airport_name
order by recovery_2022 desc
```

<BarChart
    data={hub_recovery_2022}
    x=airport_name
    y=recovery_2022
    swapXY=true
    title="Average 2022 recovery ratio by hub"
    yAxisTitle="2022 traffic vs 2019"
/>

## How carriers reshaped through the shock

```sql airline_recovery
select * from headwind.airline_recovery
```

<LineChart
    data={airline_recovery}
    x=flight_month
    y=total_flights
    series=airline_name
    title="Monthly flights by carrier (largest 12)"
    yAxisTitle="Flights"
/>
