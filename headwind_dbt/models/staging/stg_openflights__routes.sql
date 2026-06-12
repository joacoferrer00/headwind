with source as (
    select * from {{ source('headwind_raw', 'openflights_routes') }}
),

renamed as (
    select
        nullif(trim(airline), '\\N') as airline_iata_or_icao,
        nullif(trim(airline_id), '\\N') as airline_id,
        nullif(trim(source_airport), '\\N') as origin_iata_or_icao,
        nullif(trim(source_airport_id), '\\N') as origin_airport_id,
        nullif(trim(destination_airport), '\\N') as destination_iata_or_icao,
        nullif(trim(destination_airport_id), '\\N') as destination_airport_id,
        coalesce(trim(codeshare) = 'Y', false) as is_codeshare,
        cast(stops as int64) as stops,
        nullif(trim(equipment), '\\N') as equipment,
    from source
    where
        nullif(trim(source_airport), '\\N') is not null
        and nullif(trim(destination_airport), '\\N') is not null
)

select * from renamed
