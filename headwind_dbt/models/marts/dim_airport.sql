with airports as (
    select * from {{ ref('stg_ourairports__airports') }}
),

hubs as (
    select airport_icao
    from {{ ref('seed_top_hubs') }}
),

final as (
    select
        a.airport_icao,
        a.airport_iata,
        a.airport_name,
        a.airport_type,
        a.latitude,
        a.longitude,
        a.elevation_ft,
        a.country_iso2,
        a.region_iso,
        a.municipality,
        a.scheduled_service,
        h.airport_icao is not null as is_hub,
    from airports as a
    left join hubs as h on a.airport_icao = h.airport_icao
)

select * from final
