{{
    config(
        materialized='table',
        cluster_by=['hub_icao'],
    )
}}

-- Per-hub, per-month 2019 baseline movements (departures + arrivals separately).
-- Used as the denominator for collapse-and-recovery metrics in mart_hub_recovery.
with flights as (
    select
        origin_icao,
        destination_icao,
        flight_date,
    from {{ ref('stg_opensky__flights') }}
    where
        flight_date between cast('2019-01-01' as date) and cast('2019-12-31' as date)
),

hubs as (
    select airport_icao from {{ ref('seed_top_hubs') }}
),

departures as (
    select
        f.origin_icao as hub_icao,
        date_trunc(f.flight_date, month) as flight_month,
        count(*) as departure_count,
    from flights as f
    inner join hubs as h on f.origin_icao = h.airport_icao
    group by hub_icao, flight_month
),

arrivals as (
    select
        f.destination_icao as hub_icao,
        date_trunc(f.flight_date, month) as flight_month,
        count(*) as arrival_count,
    from flights as f
    inner join hubs as h on f.destination_icao = h.airport_icao
    group by hub_icao, flight_month
),

final as (
    select
        coalesce(d.hub_icao, a.hub_icao) as hub_icao,
        coalesce(d.flight_month, a.flight_month) as flight_month,
        coalesce(d.departure_count, 0) as departure_count_2019,
        coalesce(a.arrival_count, 0) as arrival_count_2019,
        coalesce(d.departure_count, 0) + coalesce(a.arrival_count, 0) as total_movements_2019,
    from departures as d
    full outer join arrivals as a
        on
            d.hub_icao = a.hub_icao
            and d.flight_month = a.flight_month
)

select * from final
