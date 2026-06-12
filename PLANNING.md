# PLANNING.md — headwind

What the project answers, scope decisions, the dimensional model, milestones, and
immediate next steps.

Companion docs:
- [CLAUDE.md](CLAUDE.md) — how we work and the project brief.
- [PIPELINE.md](PIPELINE.md) — full end-to-end architecture, layer by layer.

---

## Pitch

An EU hub is stressed in two ways: **chronic** (weather, every day) and **acute** (a
shock like a pandemic). headwind builds an end-to-end pipeline that crosses 2019–2022
European flight data with historical weather to identify which hubs are most resilient
to each kind of stress, and whether resilience to one predicts resilience to the other.

Repo subtitle: *"European aviation operational resilience analytics — dbt + BigQuery +
weather + COVID shock as a natural experiment."*

---

## Business questions the project answers

**Chronic stress (weather):**
1. **Hub resilience to weather:** which top-20 EU airports show the most stable traffic
   and shortest flight-duration variance once adjusted for weather severity?
2. **Seasonality:** which hubs degrade in which season, and under which weather
   condition (snow, wind, fog, storm)?
3. **Route risk:** which origin-destination pairs see the largest traffic drops on
   bad-weather days at either end?

**Acute shock (COVID):**
4. **Collapse and recovery:** how fast did each hub drop in March-April 2020, and how
   close to 2019 baseline did it return by end of 2022?
5. **Airline strategy:** how did major EU carriers reshape their network through the
   shock? Which kept their hub concentration, which diversified?

**Cross-stress (the headline question):**
6. **Are hubs that handled the shock well also the ones that handle weather well?**
   Or are these orthogonal forms of resilience?
7. **Are the airlines that recovered fastest also the ones with the best
   weather-adjusted performance?**

---

## Scope decisions (locked)

| # | Topic | Decision |
|---|-------|----------|
| 1 | Airport scope | Top 20 EU hubs by 2019 traffic |
| 2 | Time window | 1 Jan 2019 – 31 Dec 2022 (4 years, pre-shock + collapse + recovery) |
| 3 | Flight source | OpenSky COVID-19 Flight Dataset (Zenodo, CC-BY) |
| 4 | Refresh cadence | One-shot historical load (dataset is frozen at Dec 2022) |
| 5 | Metric layer | dbt semantic layer only if time allows; else metrics in marts SQL |
| 6 | Dashboard | Evidence.dev |
| 7 | CI/CD scope | Full: `dbt build` on PR + docs deploy + scheduled CI |
| 8 | COVID policy stringency (OWID) | Optional stretch source, only if core marts are solid |

---

## Data sources

- **OpenSky COVID-19 Flight Dataset** ([Zenodo, CC-BY](https://doi.org/10.5281/zenodo.3931948))
  — one row per observed flight (callsign, origin/destination ICAO, takeoff/landing
  timestamps, aircraft type, registration) for every flight OpenSky saw between
  1 Jan 2019 and 31 Dec 2022. Monthly CSVs.
- **Open-Meteo Historical Weather API** — free, no auth. Weather by lat/long + timestamp.
  Pulled per airport per day for the 4-year window.
- **OurAirports.com** — one-shot CSV of every airport (lat, long, IATA, ICAO, country)
  → `dim_airport`.
- **OpenFlights.org** — airlines and routes datasets → `dim_airline`.
- *(Stretch)* **Our World in Data — COVID-19 Government Response Tracker** — daily
  stringency index per country, plus case/death counts. Lets us weight the shock by how
  hard each country actually locked down, instead of treating "2020" as one block.

---

## Data realities (verified from source, locked)

Checked against the actual Zenodo record and Open-Meteo docs. These drive modeling
decisions and must be respected by any model built here:

- **Zenodo flights = 48 monthly `flightlist_YYYYMMDD_YYYYMMDD.csv.gz` files** (record
  [7923702](https://zenodo.org/records/7923702)), 8.1 GB total, covering 2019-01 to
  2022-12. Columns: `callsign, number, icao24, registration, typecode, origin,
  destination, firstseen, lastseen, day, latitude_1/longitude_1/altitude_1,
  latitude_2/longitude_2/altitude_2`.
- **`origin` / `destination` (ICAO) are frequently null.** OpenSky cannot always resolve
  endpoints. A hub's traffic counts flights where it is the non-null origin OR
  destination; flights null on the relevant side are dropped, and the coverage caveat is
  documented in the README. This is the single biggest data-quality fact.
- **No airline column.** Airline is derived from `callsign[:3]` (the airline ICAO code),
  joined to OpenFlights airlines. Some callsigns will not resolve; leave as unknown.
- **No takeoff/landing fields per se.** `firstseen`/`lastseen` are the proxies; flight
  duration = `lastseen - firstseen`.
- **Open-Meteo: one request covers the full multi-year hourly range per lat/long.** Pull
  is ~20 requests (one per hub, chunk by year only if a response is unwieldy), not a
  per-airport-day paginated crawl. No auth, no meaningful rate limit at this volume.
- **No `visibility` variable in Open-Meteo hourly.** The `fog` weather event is proxied
  from high relative humidity + low cloud base, or dropped if the proxy is weak. Wind,
  snow, precipitation, storm (gusts + pressure) are all directly available.

---

## Dimensional model (sketch)

**Facts:**
- `fact_flights` — grain: one observed flight. Partitioned by `departure_date`,
  clustered by `origin_airport_icao`.
- `fact_weather_observations` — grain: one hourly observation per airport.
- *(Stretch)* `fact_policy_stringency` — grain: one country-day. Sourced from OWID.

**Dimensions:**
- `dim_airport` (lat, long, country, ICAO, IATA)
- `dim_airline`
- `dim_aircraft` (by tail number / registration)
- `dim_date`
- `dim_weather_event` (clear / windy / snow / fog / storm)
- `dim_pandemic_phase` (pre-shock 2019, collapse Q2 2020, restricted 2020-2021,
  recovery 2022)

**Notable intermediate models:**
- `int_flights_with_weather` — the temporal-spatial join (flight × hourly weather at
  origin and destination, ±30 min window). The technical centerpiece.
- `int_traffic_baselines` — per-hub baseline traffic from 2019, used as the denominator
  for collapse-and-recovery metrics.

**Marts:**
- `mart_hub_resilience` — per hub × month × weather condition: traffic, flight-duration
  variance, share of long-tail durations.
- `mart_hub_recovery` — per hub × pandemic phase: traffic vs 2019 baseline, recovery
  half-life, network reach (unique destinations).
- `mart_route_risk` — origin-destination pair with a weather-sensitivity index and a
  shock-sensitivity index.
- `mart_airline_performance` — airline-level: hub concentration, weather-adjusted
  flight-duration performance, recovery trajectory.

---

## Plan (executable, dependency-ordered)

The manual for `/implement`. Each step is self-contained with a "Done when". Phase 1 is
done; phases 2 to 6 are the runway. Phase 7 is optional. Hard constraints: BigQuery cost
rules (partition + cluster every table, `maximum_bytes_billed` cap), conventions in
[CONVENTIONS.md](CONVENTIONS.md), no service-account JSON committed to the repo.

### Phase 1 — Foundation (DONE)
GCP project `headwind-497302` + ADC, GCS bucket `gs://headwind-497302-raw` (EU), BigQuery
dataset `headwind_raw` (EU), dbt project at `headwind_dbt/` (medallion config,
`~/.dbt/profiles.yml` target `dev`, EU, `maximum_bytes_billed` cap, `dbt debug`/`dbt parse`
pass), $1 billing budget, conventions and project skills. Remote: `github.com/joacoferrer00/headwind`.

### Phase 2 — Tooling + ingestion to raw
2.1 **Repo tooling.**
   - What: add `.sqlfluff` (bigquery dialect, dbt templater), `pyproject.toml` (ruff,
     line 88), `.pre-commit-config.yaml` (sqlfluff + ruff), and `headwind_dbt/packages.yml`
     (`dbt_utils`, `dbt_expectations`, `codegen`).
   - Where: repo root + `headwind_dbt/`.
   - Done when: `pre-commit install` works, `dbt deps` resolves, `dbt parse` passes.
   - Depends on: none.
2.2 **Download flights (Zenodo).**
   - What: Python script pulls the 48 `flightlist_*.csv.gz` files from record 7923702
     (Zenodo API file listing), converts each to Parquet, uploads to
     `gs://headwind-497302-raw/zenodo_flights/dt=YYYY-MM-01/`. Idempotent per partition.
   - How: `requests.Session`, stream the `.gz`, parse `day` to date, write Parquet. No
     elaborate pagination needed (static files).
   - Done when: 48 Parquet partitions in GCS.
   - Depends on: 2.1.
2.3 **Load reference data (one-shot).**
   - What: download OurAirports `airports.csv`, OpenFlights `airlines.dat` + `routes.dat`;
     upload to GCS; `bq load` into `headwind_raw` (`ourairports_airports`,
     `openflights_airlines`, `openflights_routes`).
   - Done when: three raw tables exist with sane row counts.
   - Depends on: 2.1.
2.4 **Load flights to raw.**
   - What: `bq load` the Parquet into `headwind_raw.flights`, partitioned by `day`.
   - Done when: table partitioned by date, row count matches source order of magnitude.
   - Depends on: 2.2.
2.5 **Pick and freeze the top-20 EU hubs.**
   - What: query 2019 flights, rank airports by total observed movements (non-null origin
     + destination), join `ourairports_airports` for country, filter to EU scope, take
     top 20. Write the result to `headwind_dbt/seeds/seed_top_hubs.csv`
     (`airport_icao, iata, name, country, latitude, longitude`).
   - How: EU scope default = EU-27 + UK + CH + NO (keeps LHR, ZRH, OSL in play). Freezing
     the list as a seed makes every downstream step deterministic and reproducible.
   - Done when: `seed_top_hubs.csv` committed with 20 rows, `dbt seed` loads it.
   - Depends on: 2.3, 2.4.
2.6 **Pull weather (Open-Meteo).**
   - What: Python script, one request per hub for the full 2019-2022 hourly window (chunk
     by year only if a response is too large), variables: temperature_2m,
     relative_humidity_2m, wind_speed_10m, wind_gusts_10m, wind_direction_10m,
     precipitation, rain, snowfall, snow_depth, cloud_cover, surface_pressure. Parquet to
     `gs://headwind-497302-raw/openmeteo/dt=YYYY-MM-01/`, then `bq load` to
     `headwind_raw.weather` partitioned by date.
   - Done when: raw weather table covers 20 airports x ~35k hourly rows each.
   - Depends on: 2.5 (needs the locked hub lat/long).

### Phase 3 — Modeling (staging to marts)
3.1 **Sources.** `sources.yml` declaring the raw tables; freshness off (frozen dataset).
3.2 **Staging** (`stg_`, views): `stg_opensky__flights` (cast types, derive
   `airline_icao` from `callsign[:3]`, `flight_duration_minutes` from
   `lastseen - firstseen`, keep only flights touching a hub), `stg_openmeteo__weather`,
   `stg_ourairports__airports`, `stg_openflights__airlines`, `stg_openflights__routes`.
   Each with a `.yml`: description + PK `not_null`/`unique`.
   - Done when: `dbt build --select staging` passes with tests green.
3.3 **Dimensions:** `dim_airport` (hubs flagged), `dim_airline`, `dim_aircraft` (by
   `icao24`/registration), `dim_date` (dbt_utils date spine 2019-2022),
   `dim_weather_event` (clear/windy/snow/fog/storm, derived; fog proxied per data
   realities), `dim_pandemic_phase` (pre-shock 2019 / collapse Q2 2020 / restricted
   2020-2021 / recovery 2022, as a seed or case logic).
3.4 **Intermediate** (`int_`, the centerpiece): `int_traffic_baselines` (2019 per-hub
   baseline = denominator for recovery), `int_flights_with_weather` (join each flight to
   the hourly weather at its origin and destination hub on the matching `date_hour`;
   handle null endpoints). Join is hourly (weather grain), not a ±30 min window.
   - Done when: `dbt build --select intermediate` passes; spot-check row counts.
3.5 **Marts** (`mart_`, tables, partitioned + clustered): `mart_hub_resilience`,
   `mart_hub_recovery`, `mart_route_risk`, `mart_airline_performance`.
   - Done when: `dbt build --select marts` passes; each mart answers its business question.
   - Depends on: 3.1-3.4.

### Phase 4 — Quality
4.1 Generic tests: PK `not_null`/`unique` on every model, `relationships` on FKs
   (flight to airport/airline/date), `accepted_values` on weather event + pandemic phase.
4.2 Singular tests (`tests/`): no landing before takeoff, every hub has a 2019 baseline,
   no flight maps to a weather hour outside its `day`.
4.3 dbt-expectations: row-count ranges, `expect_column_values_to_be_between` on durations
   and traffic, distribution checks on key measures.
   - Done when: `dbt build` (models + all tests) is fully green.

### Phase 5 — Delivery (CI/CD + dashboard)
5.1 **BigQuery CI auth (the one human-in-the-loop point).**
   - What: create a service account, grant `roles/bigquery.dataEditor` +
     `roles/bigquery.jobUser`, set up Workload Identity Federation bound to the GitHub
     repo (preferred, no long-lived key), and register the secret/provider with
     `gh secret set`. Add a `ci` target to `profiles.yml` (service-account method, dataset
     `dbt_ci`).
   - How: the agent does this end to end via `gcloud` + `gh` IF `gh auth status` is logged
     in with repo admin. If not, it stops and hands Joaquin the exact `gh secret set`
     command to run. The SA key never lands in the repo (CLAUDE.md rule).
   - Done when: a manual Actions run authenticates and runs `dbt build` against `dbt_ci`.
5.2 **GitHub Actions CI:** PR workflow runs sqlfluff, `dbt deps`, `dbt build` + `dbt test`
   against `dbt_ci`. Done when: green check on a test PR.
5.3 **dbt docs:** `dbt docs generate`, published to GitHub Pages (lineage DAG browsable).
5.4 **Evidence.dev dashboard:** pages built around the business questions, connected to
   the BQ marts, built and deployed to GitHub Pages / Netlify via Actions (reuses the 5.1
   secret). Done when: the site is live and renders the cross-stress headline.

### Phase 6 — Polish (ship it)
6.1 Replace the dbt starter `README.md` with the portfolio README: lead with the
   cross-stress question, architecture diagram, the live dashboard + dbt docs links,
   screenshots, headline insights, the null-endpoint coverage caveat, and a "future work"
   list (the Phase 7 items + OpenSky Trino live extension).
   - Done when: README ships and the repo reads as a finished portfolio piece.

### Phase 7 — Stretch (only if the core is solid)
7.1 dbt semantic layer for the core metrics. 7.2 OWID stringency as a weighting source.
7.3 SCD Type 2 on `dim_airport`. Each is independent and optional; skip cleanly if time
runs short and leave it in the README "future work" list.

---

## Open questions / human-in-the-loop

- **CI secret (Phase 5.1):** fully autonomous only if `gh` is authenticated with repo
  admin. The agent verifies `gh auth status` early; if it fails, Joaquin runs one
  `gh secret set` command. Everything else is hands-off.
- **EU hub scope (2.5):** defaulted to EU-27 + UK + CH + NO. Revisit only if a clearly
  major hub is excluded by the filter.
- **`fog` event (3.3):** no Open-Meteo visibility; proxy from humidity + cloud base, or
  drop the category if the proxy is noisy. Agent decides at modeling time and documents it.
