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

- **All `.md` files in English, always.** No exceptions.
- **No em-dashes (—)** anywhere: responses, code, commits, file content. Use commas,
  periods, colons, parentheses.
- Joaquin is **not an expert in dbt/BigQuery yet.** Explain the "why" behind technical
  decisions, not just the "what". This is a learning project as much as a delivery one.
- Pragmatism over elegance. If it works, we move on.
- Short answers by default. He will ask for more detail if he wants it.

---

## Current state (2026-05-27)

**Done:**
- `.venv/` with Python 3.11.
- `requirements.txt`: dbt-core 1.10, dbt-bigquery 1.10, google-cloud-storage/bigquery,
  pyarrow, pandas, requests, sqlfluff, pre-commit.
- `.gitignore` and `.vscode/settings.json` configured (interpreter points at `.venv`).
- dbt Power User extension (Innoverio) installed in VS Code.
- Google Cloud SDK installed, authenticated as `joacoferrer00@gmail.com`, ADC in place.
- GCP project: **`headwind-497302`**.
- GCS landing bucket `gs://headwind-497302-raw` (EU) created.
- BigQuery dataset `headwind_raw` (EU) created.
- dbt project at `headwind_dbt/`, `~/.dbt/profiles.yml` configured, `dbt debug` passes.

**Immediate next steps** live in [PLANNING.md](PLANNING.md#immediate-next-steps).

**Project skills** (`.claude/skills/`): `/new-model`, `/dry-run`, `/dbt-check`,
`/ingest-source`, `/readme-killer`.

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

## Data source APIs

- OpenSky Network (flights, free, requires signup): https://opensky-network.org/
- Open-Meteo Historical (weather, free, no auth): https://open-meteo.com/en/docs/historical-weather-api
- OurAirports (one-shot CSV): https://ourairports.com/data/
- OpenFlights (one-shot datasets): https://openflights.org/data.html

## Training references

- BigQuery: [sandbox](https://cloud.google.com/bigquery/docs/sandbox),
  [partitioning](https://cloud.google.com/bigquery/docs/partitioned-tables),
  [clustering](https://cloud.google.com/bigquery/docs/clustered-tables).
- dbt: [Fundamentals](https://learn.getdbt.com/courses/dbt-fundamentals),
  [bigquery setup](https://docs.getdbt.com/docs/core/connect-data-platform/bigquery-setup),
  [ref/source](https://docs.getdbt.com/docs/build/sql-models),
  [tests](https://docs.getdbt.com/docs/build/data-tests).
