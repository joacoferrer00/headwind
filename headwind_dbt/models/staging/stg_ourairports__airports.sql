with source as (
    select * from {{ source('headwind_raw', 'ourairports_airports') }}
),

renamed as (
    select
        ident as airport_icao,
        iata_code as airport_iata,
        name as airport_name,
        type as airport_type,
        cast(latitude_deg as float64) as latitude,
        cast(longitude_deg as float64) as longitude,
        cast(elevation_ft as float64) as elevation_ft,
        iso_country as country_iso2,
        iso_region as region_iso,
        municipality,
        scheduled_service,
        gps_code,
    from source
    where ident is not null
)

select * from renamed
