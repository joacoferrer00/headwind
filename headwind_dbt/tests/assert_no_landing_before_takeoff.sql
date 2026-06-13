-- A flight cannot land before it takes off: last_seen_at must be at or after
-- first_seen_at. Returns offending rows; the test passes when there are none.
select
    flight_id,
    first_seen_at,
    last_seen_at
from {{ ref('int_flights_with_weather') }}
where last_seen_at < first_seen_at
