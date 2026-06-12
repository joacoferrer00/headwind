{{
    config(
        partition_by={
            'field': 'date_day',
            'data_type': 'date',
            'granularity': 'month',
        },
    )
}}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart='day',
        start_date="cast('2019-01-01' as date)",
        end_date="cast('2023-01-01' as date)"
    ) }}
),

final as (
    select
        cast(date_day as date) as date_day,
        extract(year from date_day) as year,
        extract(quarter from date_day) as quarter_of_year,
        extract(month from date_day) as month,
        extract(week from date_day) as week_of_year,
        extract(dayofyear from date_day) as day_of_year,
        extract(dayofweek from date_day) as day_of_week,
        format_date('%B', date_day) as month_name,
        format_date('%A', date_day) as day_name,
        extract(dayofweek from date_day) in (1, 7) as is_weekend,
        date_trunc(date_day, month) as month_start_date,
        date_trunc(date_day, quarter) as quarter_start_date,
    from date_spine
)

select * from final
