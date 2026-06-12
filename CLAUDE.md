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

Phase 1 (foundation) and Phase 2.1 (tooling) are done. Phase 2.2 (Zenodo download) is
running in background (`scripts/ingest_zenodo_flights.py`, idempotent, resumable). Phase 2.3
(reference data) is done: OurAirports + OpenFlights loaded to `headwind_raw`. Phase 3.1
(sources.yml) and the three reference staging models are green. Next concrete steps: wait for
2.2 to finish (48 Parquet partitions in GCS), then run 2.4 (`scripts/load_flights_to_bq.py`),
then 2.5 (top-20 hub seed), 2.6 (weather pull), and complete Phase 3 staging.

Full phase breakdown in [PLANNING.md](PLANNING.md) (the north for `/implement`).

**Project commands** (`.claude/commands/`): none yet. Useful global skills: `/plan`,
`/implement`, `/polish`, `/update-docs`, `/sql-evidence`.

**Known gotcha (fixed):** the `bq` CLI looked for a missing `python3.14`. A persistent
user env var `CLOUDSDK_PYTHON` now points at the SDK's bundled python, so new shells
work. `gcloud` and `dbt` were never affected.

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
