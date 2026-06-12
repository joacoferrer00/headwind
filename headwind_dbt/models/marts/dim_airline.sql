with airlines as (
    select * from {{ ref('stg_openflights__airlines') }}
),

-- OpenFlights has ~36 duplicate ICAO codes; keep the lowest airline_id (primary listing)
deduped as (
    select
        airline_icao,
        airline_id,
        airline_iata,
        airline_name,
        radio_callsign,
        country as airline_country,
        is_active,
        row_number() over (partition by airline_icao order by airline_id) as rn,
    from airlines
),

final as (
    select
        airline_icao,
        airline_id,
        airline_iata,
        airline_name,
        radio_callsign,
        airline_country,
        is_active,
    from deduped
    where rn = 1
)

select * from final
