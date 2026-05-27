# PLANNING.md — headwind

General planning for the project: what it answers, scope decisions, the dimensional
model, milestones, and immediate next steps.

Companion docs:
- [CLAUDE.md](CLAUDE.md) — how we work and the project brief.
- [PIPELINE.md](PIPELINE.md) — full end-to-end architecture, layer by layer.

---

## Pitch

End-to-end pipeline that crosses real European flight data with historical weather to
identify which hubs are most resilient to operational disruption, and which routes carry
the highest risk of lost connections when a hub goes down.

Repo subtitle: *"European aviation operational resilience analytics — dbt + BigQuery +
weather correlation."*

---

## Business questions the project answers

1. **Hub resilience:** which top-20 EU airports have the best on-time performance once
   adjusted for weather severity? (Madrid in July is not Frankfurt in January.)
2. **Seasonality:** which hubs collapse in which season, and by what kind of event
   (snow, wind, fog, storm)?
3. **Delay propagation:** when a major hub is delayed, which downstream routes lose the
   most connections?
4. **Backup hubs:** as an airline head of ops, which backup hub should be pre-approved
   for each season?
5. **Airlines:** adjusting for the hubs they operate, which EU airline performs best in
   adverse conditions?

---

## Scope decisions (locked)

| # | Topic | Decision |
|---|-------|----------|
| 1 | Airport scope | Top 20 EU hubs to start, expand if time allows |
| 2 | Time window | 2 years (year-over-year seasonal comparison) |
| 3 | Refresh cadence | Daily incremental |
| 4 | Metric layer | dbt semantic layer only if time allows; else metrics in marts SQL |
| 5 | Dashboard | Evidence.dev |
| 6 | CI/CD scope | Full: `dbt build` on PR + docs deploy + scheduled prod runs |
| 7 | Flight pricing | Out of scope (phase 2) |

---

## Data sources

- **OpenSky Network API** — European flights, historical, free, basic auth. Real
  takeoff/landing timestamps (not schedules).
- **Open-Meteo Historical Weather API** — free, no auth, weather by lat/long + timestamp.
- **OurAirports.com** — one-shot CSV of every airport (lat, long, IATA, ICAO, country)
  → `dim_airport`.
- **OpenFlights.org** — airlines and routes datasets → `dim_airline`.
- **Eurocontrol public dashboards** — official aggregate punctuality metrics, used to
  cross-validate the marts.

---

## Dimensional model (sketch)

**Facts:**
- `fact_flights` — grain: one flight. Partitioned by `departure_date`, clustered by
  `origin_airport_code`.
- `fact_weather_observations` — grain: one hourly observation per airport.

**Dimensions:**
- `dim_airport` (SCD Type 2 — capacity/runways can change)
- `dim_airline`
- `dim_aircraft` (by tail number when available)
- `dim_date`
- `dim_weather_event` (clear / windy / snow / fog / storm)

**Notable intermediate models:**
- `int_flights_with_weather` — the temporal join of flight × weather (±30 min window,
  nearest airport). The most interesting model technically.
- `int_delay_cascades` — groups flights by aircraft tail number to track propagation.

**Marts:**
- `mart_hub_resilience` — metrics by airport × month × weather condition.
- `mart_route_risk` — origin-destination pair with a lost-connection risk index.
- `mart_airline_performance` — airline performance adjusted for hubs operated.

---

## Milestones (numbered, not time-boxed)

1. **Foundation.** Repo, GCP project, BigQuery datasets, `dbt init`, OpenSky API
   exploration, scope confirmed. `dbt debug` passes.
2. **Ingestion.** Python scripts → GCS Parquet → BigQuery `raw` tables, with pagination,
   backoff, and checkpointing.
3. **Modeling.** dbt staging + intermediate + dimensional model, including the
   flight × weather join.
4. **Quality.** Serious tests (dbt-expectations, freshness, singular) + docs site.
5. **Delivery.** Evidence.dev dashboard + GitHub Actions CI/CD.
6. **Polish.** Killer README opening with the business question, screenshots, headline
   insights.

---

## Immediate next steps

1. Finish `gcloud init` → select project `[4] headwind-497302`.
2. Set a **billing alert at $1 USD** in GCP before anything else.
3. `gcloud auth application-default login` (creates the credentials dbt will use; this is
   different from the normal login).
4. Create the GCS landing bucket (e.g. `headwind-497302-raw`).
5. Create the initial BigQuery dataset (e.g. `headwind_raw`, location `EU`).
6. `dbt init headwind_dbt` inside the repo, configure `~/.dbt/profiles.yml` to point at
   the project.
7. `dbt debug` → "All checks passed" means setup is complete.

---

## Training (do before going hands-on with data)

Optional now (Joaquin chose to learn while building), but the references are kept here:

- **BigQuery:** sandbox/free tier, partitioning, clustering, public datasets for practice.
- **dbt:** dbt Fundamentals (first 2 modules), dbt-bigquery setup, `ref()`/`source()`,
  tests.

Links live in [CLAUDE.md](CLAUDE.md).
