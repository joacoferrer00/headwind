-- Static lookup: five weather event categories and their classification thresholds.
-- The actual event classification per observation lives in int_flights_with_weather.
with categories as (
    select
        'clear' as weather_event,
        'Minimal precipitation and low wind' as description,
        1 as sort_order
    union all
    select
        'windy' as weather_event,
        'Wind speed > 10 m/s or gusts > 15 m/s' as description,
        2 as sort_order
    union all
    select
        'snow' as weather_event,
        'Snowfall > 0 cm' as description,
        3 as sort_order
    union all
    select
        'fog' as weather_event,
        'Relative humidity > 90% and cloud cover > 80% (visibility proxy)' as description,
        4 as sort_order
    union all
    select
        'storm' as weather_event,
        'Wind gusts > 20 m/s and surface pressure < 990 hPa' as description,
        5 as sort_order
)

select * from categories
