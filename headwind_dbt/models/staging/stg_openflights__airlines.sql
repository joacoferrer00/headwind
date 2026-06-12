with source as (
    select * from {{ source('headwind_raw', 'openflights_airlines') }}
),

renamed as (
    select
        cast(airline_id as int64) as airline_id,
        nullif(trim(name), '') as airline_name,
        nullif(trim(alias), '\\N') as airline_alias,
        nullif(trim(iata), '\\N') as airline_iata,
        nullif(trim(icao), '\\N') as airline_icao,
        nullif(trim(callsign), '\\N') as radio_callsign,
        nullif(trim(country), '\\N') as country,
        trim(active) = 'Y' as is_active,
    from source
    where nullif(trim(icao), '\\N') is not null
)

select * from renamed
