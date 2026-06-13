-- Every top-20 hub must have a 2019 traffic baseline, since the baseline is the
-- denominator for all collapse-and-recovery ratios. Returns any hub missing from
-- int_traffic_baselines; the test passes when there are none.
with hubs as (
    select airport_icao from {{ ref('seed_top_hubs') }}
)

select h.airport_icao
from hubs as h
where not exists (
    select 1
    from {{ ref('int_traffic_baselines') }} as b
    where b.hub_icao = h.airport_icao
)
