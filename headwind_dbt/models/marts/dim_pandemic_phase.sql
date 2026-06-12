-- Static lookup: four pandemic phases covering the 2019-2022 analysis window.
with phases as (
    select
        'pre_shock' as pandemic_phase,
        cast('2019-01-01' as date) as phase_start_date,
        cast('2019-12-31' as date) as phase_end_date,
        'Full 2019 baseline year before pandemic' as description,
        1 as sort_order
    union all
    select
        'collapse' as pandemic_phase,
        cast('2020-01-01' as date) as phase_start_date,
        cast('2020-06-30' as date) as phase_end_date,
        'Initial pandemic collapse and lockdown period, Q1-Q2 2020' as description,
        2 as sort_order
    union all
    select
        'restricted' as pandemic_phase,
        cast('2020-07-01' as date) as phase_start_date,
        cast('2021-12-31' as date) as phase_end_date,
        'Partial recovery under ongoing restrictions, H2 2020 through 2021' as description,
        3 as sort_order
    union all
    select
        'recovery' as pandemic_phase,
        cast('2022-01-01' as date) as phase_start_date,
        cast('2022-12-31' as date) as phase_end_date,
        'Post-restriction recovery, full year 2022' as description,
        4 as sort_order
)

select * from phases
