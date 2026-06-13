-- The weather join is keyed on the hour of first_seen_at (origin) and last_seen_at
-- (destination). A matched weather observation must therefore sit on the flight's own
-- day, allowing a one-day tolerance for movements that cross midnight (firstseen can
-- precede the OpenSky `day` by up to one calendar day). A larger gap means weather was
-- mis-joined from the wrong day. Returns offending rows; passes when there are none.
select
    flight_id,
    flight_date,
    first_seen_at,
    last_seen_at,
    origin_weather_event,
    destination_weather_event
from {{ ref('int_flights_with_weather') }}
where
    (
        origin_weather_event is not null
        and abs(date_diff(date(first_seen_at), flight_date, day)) > 1
    )
    or (
        destination_weather_event is not null
        and abs(date_diff(date(last_seen_at), flight_date, day)) > 1
    )
