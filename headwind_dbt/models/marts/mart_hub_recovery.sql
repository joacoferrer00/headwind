{{
    config(
        partition_by={
            'field': 'flight_month',
            'data_type': 'date',
            'granularity': 'month',
        },
        cluster_by=['hub_icao'],
    )
}}

-- Per-hub monthly traffic across all years, compared to the 2019 same-month baseline.
-- Answers BQ4: collapse and recovery trajectory per hub.
with hubs as (
    select airport_icao from {{ ref('seed_top_hubs') }}
),

departures as (
    select
        origin_icao as hub_icao,
        date_trunc(flight_date, month) as flight_month,
    from {{ ref('int_flights_with_weather') }}
    where origin_icao in (select h.airport_icao from hubs as h)
),

arrivals as (
    select
        destination_icao as hub_icao,
        date_trunc(flight_date, month) as flight_month,
    from {{ ref('int_flights_with_weather') }}
    where destination_icao in (select h.airport_icao from hubs as h)
),

all_movements as (
    select * from departures
    union all
    select * from arrivals
),

monthly_movements as (
    select
        hub_icao,
        flight_month,
        count(*) as total_movements,
    from all_movements
    group by hub_icao, flight_month
),

baselines as (
    select
        hub_icao,
        extract(month from flight_month) as calendar_month,
        total_movements_2019,
    from {{ ref('int_traffic_baselines') }}
),

pandemic_phases as (
    select * from {{ ref('dim_pandemic_phase') }}
),

final as (
    select
        m.hub_icao,
        m.flight_month,
        extract(year from m.flight_month) as year,
        extract(month from m.flight_month) as calendar_month,
        m.total_movements,
        b.total_movements_2019 as baseline_movements_2019,
        round(safe_divide(m.total_movements, b.total_movements_2019), 4) as recovery_ratio,
        m.total_movements - coalesce(b.total_movements_2019, 0) as movement_delta_vs_2019,
        pp.pandemic_phase,
    from monthly_movements as m
    left join baselines as b
        on
            m.hub_icao = b.hub_icao
            and extract(month from m.flight_month) = b.calendar_month
    left join pandemic_phases as pp
        on m.flight_month between pp.phase_start_date and pp.phase_end_date
)

select * from final
