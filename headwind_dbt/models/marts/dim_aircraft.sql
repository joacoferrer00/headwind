with flights as (
    select
        aircraft_icao24,
        aircraft_registration,
        aircraft_typecode,
    from {{ ref('stg_opensky__flights') }}
    where aircraft_icao24 is not null
),

-- Keep the most common (registration, typecode) per icao24 to handle reregistrations
ranked as (
    select
        aircraft_icao24,
        aircraft_registration,
        aircraft_typecode,
        count(*) as obs_count,
        row_number() over (partition by aircraft_icao24 order by count(*) desc) as rn,
    from flights
    group by aircraft_icao24, aircraft_registration, aircraft_typecode
),

final as (
    select
        aircraft_icao24,
        aircraft_registration,
        aircraft_typecode,
    from ranked
    where rn = 1
)

select * from final
