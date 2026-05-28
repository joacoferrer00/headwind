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

## Milestones (numbered, not time-boxed)

1. **Foundation.** Repo, GCP project, BigQuery datasets, dbt scaffold, conventions,
   skills. `dbt debug` passes.
2. **Ingestion.** Zenodo flights to GCS to BQ. Open-Meteo Python pull to GCS to BQ.
   OurAirports + OpenFlights one-shot CSVs loaded.
3. **Modeling.** Staging + intermediate + dimensional model. Build the
   flight × weather join.
4. **Quality.** Tests (dbt generic + singular + dbt-expectations), freshness rules,
   docs site.
5. **Delivery.** Evidence.dev dashboard + GitHub Actions CI/CD.
6. **Polish.** Killer README leading with the cross-stress question, screenshots,
   headline insights.

---

## Immediate next steps

Foundation (milestone 1) is done:
- ✅ gcloud project `headwind-497302`, ADC credentials in place.
- ✅ GCS landing bucket `gs://headwind-497302-raw` (EU, uniform access).
- ✅ BigQuery dataset `headwind_raw` (EU).
- ✅ dbt project at `headwind_dbt/` with medallion layer config and folders.
  `~/.dbt/profiles.yml` set (oauth, EU, `maximum_bytes_billed` cap).
  `dbt debug` and `dbt parse` pass.
- ✅ Billing budget ($1, project Headwind, 50/90/100% alerts).
- ✅ Writing conventions ([CONVENTIONS.md](CONVENTIONS.md)) and project skills in place.

Open:
1. **Pick the top-20 EU hubs.** Use a quick read of the 2019 Zenodo data to rank by
   total observed flights at airports in EU countries. Lock the list before modeling.
2. **Download Zenodo flight CSVs.** Months 2019-01 to 2022-12. Upload to
   `gs://headwind-497302-raw/zenodo_flights/dt=YYYY-MM-DD/`.
3. **Pull Open-Meteo weather** for those 20 airports across the 4-year window. Python
   script, paginated, backoff, checkpoint, Parquet to GCS.
4. **Load one-shot reference CSVs** (OurAirports, OpenFlights) to GCS, then `bq load`
   into `headwind_raw`.
5. **Tooling alongside:** `.sqlfluff`, `ruff`/`pyproject.toml`, `.pre-commit-config.yaml`.

---

## Training references

Joaquin learns while building. Reference links live in [CLAUDE.md](CLAUDE.md):
BigQuery (sandbox, partitioning, clustering), dbt (Fundamentals, bigquery setup,
`ref()`/`source()`, tests).
