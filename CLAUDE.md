# CLAUDE.md — headwind

Portfolio project: end-to-end EU aviation + weather pipeline → hub resilience analysis.
Stack: **dbt-bigquery + BigQuery + GCS + Python + Evidence.dev**.

Companion docs (read these for detail):
- [PLANNING.md](PLANNING.md) — scope decisions, business questions, dimensional model,
  milestones, immediate next steps.
- [PIPELINE.md](PIPELINE.md) — full end-to-end architecture, every layer explained,
  cost design, locked assumptions, extras.
- [CONVENTIONS.md](CONVENTIONS.md) — SQL (dbt) and Python writing conventions. Binding
  for all code generated here.

---

## How we work on this project

This is a **portfolio deliverable**, not a study exercise. The goal is to ship a complete,
credible end-to-end dbt pipeline that proves Joaquin can stand up a dbt + BigQuery project,
then close it and move on. The differentiator on display is **orchestration**: Joaquin
drives Claude Code to build, test, and document the whole thing, ideally running
`/implement` with as much autonomy as the planning allows. He does not read every line of
SQL; he steers the agent that writes it.

- **All `.md` files in English, always.** No exceptions.
- **No em-dashes (—)** anywhere: responses, code, commits, file content. Use commas,
  periods, colons, parentheses.
- **Optimize for autonomous execution.** Make decisions and keep moving; surface blockers
  only when a choice genuinely changes the outcome. Do not stop to teach dbt/BigQuery
  basics unless asked.
- Pragmatism over elegance. If it works, we ship and move on.
- Short answers by default. He will ask for more detail if he wants it.

---

## Current state (2026-06-12)

Phases 1-3 fully built and committed. All models materialize in BigQuery (`dbt_dev`
dataset). 79/79 dbt tests pass. SQLFluff violations resolved (AL03/RF02/RF04/LT05 fixed
in the model files) and the pre-commit hook now lints via the dbt templater from the
project venv, so the whole pipeline commits cleanly.

Next step: Phase 4 (Quality tests). See the plan in [PLANNING.md](PLANNING.md).

Full phase breakdown in [PLANNING.md](PLANNING.md) (the north for `/implement`).

**Project commands** (`.claude/commands/`): none yet. Useful global skills: `/plan`,
`/implement`, `/polish`, `/update-docs`, `/sql-evidence`.

**Known gotchas (all resolved):**

- `bq` CLI missing `python3.14`: fixed via `CLOUDSDK_PYTHON` env var pointing at the
  SDK's bundled python.
- `day` column in raw flights is STRING, format `'YYYY-MM-DD HH:MM:SS+00:00'`. Parse
  with `parse_date('%Y-%m-%d', substr(day, 1, 10))`. Cannot partition the raw table on
  it; partitioning is done in `stg_opensky__flights` on `flight_date` (DATE).
- `firstseen` / `lastseen` in flights are Unix **milliseconds** (not seconds). Use
  `safe.timestamp_millis()`. Duration = `(lastseen - firstseen) / 60000.0` minutes.
- Weather `obs_time` from pyarrow is INT64 **nanoseconds**. Use
  `timestamp_micros(cast(obs_time / 1000 as int64))`.
- GCS folders with `=` in the path break BigQuery wildcard loads. Pass explicit URI list
  instead of a wildcard for `headwind_raw.weather`.
- OpenFlights has 36 duplicate airline ICAO codes. `dim_airline` deduplicates via
  `row_number()` keeping lowest `airline_id`.
- Raw Parquet flights contain exact-duplicate rows. `stg_opensky__flights` deduplicates
  with `QUALIFY row_number() over (partition by callsign, flight_date, first_seen_at ...) = 1`.
- `maximum_bytes_billed` in `~/.dbt/profiles.yml` is **5 GB** (not 1 GB). Uniqueness
  tests on the 117M-row flights table scan ~4 GB; 1 GB cap breaks them. Rebuilding
  `int_flights_with_weather` needs ~12 GB -- raise to 20 GB temporarily for that step.
- The pre-commit SQLFluff hook is `repo: local` (`language: system`) and uses the **dbt
  templater**, so it needs the project venv on PATH: commit from the activated venv. The
  upstream sqlfluff hook's isolated env cannot resolve dbt's namespace packages
  (`cannot import name 'flags' from 'dbt'`), so the jinja templater false-positived on
  `dbt_utils` (TMP/PRS). The dbt templater also needs ADC creds at lint time.

---

## Cost rules — paranoia mode

BigQuery free tier (permanent): **1 TB scanned/month** + **10 GB storage**. Cost is bytes
scanned, not rows. Self-imposed rules:
- Every BigQuery table has `PARTITION BY` (usually a DATE).
- Every large table adds `CLUSTER BY` (up to 4 columns).
- Read the "This will process X" estimate before running a new query.
- Billing alert set at $1 USD in GCP.
- Never commit a service-account JSON. Auth comes from
  `gcloud auth application-default login` (creds in `%APPDATA%\gcloud\`).

Full reasoning in [PIPELINE.md](PIPELINE.md#4-cost-design--paranoia-mode).

---

## Project links

- GCP console (home): https://console.cloud.google.com/home/dashboard?project=headwind-497302
- BigQuery Studio: https://console.cloud.google.com/bigquery?project=headwind-497302
- Cloud Storage: https://console.cloud.google.com/storage/browser?project=headwind-497302
- Billing: https://console.cloud.google.com/billing
- IAM: https://console.cloud.google.com/iam-admin/iam?project=headwind-497302

## Data sources

- OpenSky COVID-19 Flight Dataset (flights, Zenodo, CC-BY): https://doi.org/10.5281/zenodo.3931948
- Open-Meteo Historical (weather, free, no auth): https://open-meteo.com/en/docs/historical-weather-api
- OurAirports (one-shot CSV): https://ourairports.com/data/
- OpenFlights (one-shot datasets): https://openflights.org/data.html
- *(Stretch)* Our World in Data COVID-19 dataset (policy stringency): https://github.com/owid/covid-19-data

## Training references

- BigQuery: [sandbox](https://cloud.google.com/bigquery/docs/sandbox),
  [partitioning](https://cloud.google.com/bigquery/docs/partitioned-tables),
  [clustering](https://cloud.google.com/bigquery/docs/clustered-tables).
- dbt: [Fundamentals](https://learn.getdbt.com/courses/dbt-fundamentals),
  [bigquery setup](https://docs.getdbt.com/docs/core/connect-data-platform/bigquery-setup),
  [ref/source](https://docs.getdbt.com/docs/build/sql-models),
  [tests](https://docs.getdbt.com/docs/build/data-tests).
