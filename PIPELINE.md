# PIPELINE.md — headwind architecture

End-to-end architecture of the project, layer by layer, with the reasoning behind
each tool, the assumptions we locked in, and the extras we may add if time allows.

Companion docs:
- [CLAUDE.md](CLAUDE.md) — how we work and the project brief.
- [PLANNING.md](PLANNING.md) — scope decisions, data model, milestones.

---

## 1. The big picture

```
YOUR LAPTOP (repo)                    GCP project headwind-497302
─────────────────                     ──────────────────────────
Python ingest scripts  ──HTTPS──▶     GCS bucket (raw Parquet, partitioned by date)
                                              │
                                              ▼  bq load / external table
                                      BigQuery dataset: raw
                                              │
dbt models (.sql + .yml) ─HTTPS──▶    BigQuery: staging → intermediate → marts
                                              │
                                              ▼
                                      Evidence.dev dashboard  ◀── reads marts
```

Two things to internalize:

1. **Code lives only on your laptop and GitHub.** The GCP project does not "contain"
   the repo. It only holds data (in GCS and BigQuery) and the saved queries dbt runs.
2. **dbt does not process data.** It compiles your SQL templates into plain SQL and
   ships that SQL to BigQuery over HTTPS. BigQuery does the heavy lifting. Data never
   lands on your disk (except a `SELECT ... LIMIT 100` for debugging).

The shape of the pipeline is the **medallion architecture**: raw (bronze) → cleaned
and typed (silver) → business-ready aggregates (gold). In dbt terms that maps to
`raw` → `staging` + `intermediate` → `marts`.

---

## 2. Layer by layer

### 2.1 Ingestion — Python scripts

**What it is:** standalone Python scripts that call the source APIs, page through the
responses, respect rate limits, and write the results to GCS as Parquet files.

**Why Python and not a managed connector (Fivetran, Airbyte):** the sources here are
niche public APIs (OpenSky, Open-Meteo). Writing the ingest by hand shows you can deal
with pagination, backoff, retries, and checkpointing. That is a real Analytics
Engineering skill, and managed connectors would hide it.

**Key concerns the scripts handle:**
- **Pagination:** APIs return data in chunks. The script loops until there is no more.
- **Rate limits:** OpenSky is aggressive on the free tier. We add exponential backoff
  (wait longer after each failure) and persist a checkpoint (last timestamp fetched)
  so a crashed run resumes instead of restarting.
- **Idempotency:** re-running a day should overwrite that day's file, not duplicate it.
  Partitioning the output by date (see Landing) makes this clean.

**Output format — Parquet:** columnar, compressed, typed. Much cheaper to store and
faster to scan than CSV/JSON, and BigQuery reads it natively.

### 2.2 Landing — GCS (bronze layer)

**What it is:** a Google Cloud Storage bucket (`headwind-497302-raw`) holding the raw
Parquet files exactly as pulled from the APIs, organized by date:

```
gs://headwind-497302-raw/opensky/dt=2026-05-24/flights.parquet
gs://headwind-497302-raw/openmeteo/dt=2026-05-24/weather.parquet
```

**Why a landing zone at all (and not load straight to BigQuery):**
- **Cheap, durable storage.** GCS costs cents at this volume. Raw data sits here forever.
- **Replayable.** If a dbt model has a bug, we re-run dbt against the same raw files.
  We do not have to re-hit the APIs (which are slow and rate-limited).
- **Separation of concerns.** Ingestion's only job is "get bytes safely to storage."
  Transformation is a separate stage that can fail and retry independently.

**The `dt=YYYY-MM-DD` folder convention** is called Hive partitioning. BigQuery can read
these folders as a partitioned external table, so a query filtered to one date only
scans that day's file.

### 2.3 Warehouse — BigQuery

**What it is:** Google's serverless data warehouse. You send SQL, it scans the data and
returns results. No servers to manage; you pay per byte scanned.

**Datasets** (BigQuery's word for a schema/namespace), all in location `EU`:
- `raw` — landing tables loaded from GCS, untouched.
- `staging` — dbt output, one cleaned model per source table.
- `intermediate` — dbt output, joins and reusable logic.
- `marts` — dbt output, the final business tables the dashboard reads.

**Free tier (permanent):** 1 TB of query scan per month and 10 GB of storage. The cost
unit is **bytes scanned**, not rows. A `SELECT *` with no filter on the partition column
scans the whole table and burns the budget. See section 4 for the rules we enforce.

### 2.4 Transformation — dbt-bigquery

**What it is:** dbt (data build tool) turns SQL `SELECT` statements into managed tables
and views. You write a file `stg_flights.sql` containing a `SELECT`, and dbt wraps it in
`CREATE TABLE AS ...`, figures out the dependency order, and runs everything against
BigQuery.

**Where things live (this answers your "I don't know where the data is stored" question):**
- **Your SQL and YAML files** live in the repo on your laptop and GitHub. Nothing else.
- **The actual tables** live in BigQuery. dbt creates them there when you run `dbt build`.
- **dbt's run artifacts** (logs, compiled SQL, the `manifest.json`) live in `target/`
  locally and are gitignored. They are regenerated on every run.

**`ref()` and `source()` — the two functions that make dbt work:**
- `source('raw', 'flights')` points at a raw table we declared in YAML. It marks the
  edge of the DAG (data that came from outside dbt).
- `ref('stg_flights')` points at another dbt model. dbt reads these references to build
  the dependency graph and decide run order. You never hardcode table names, so you can
  rename or re-point environments without touching SQL.

**The medallion layers in dbt:**
- **staging** (`stg_`): one model per source table. Rename columns, cast types, no joins.
  Thin and boring on purpose. Materialized as views (cheap, always fresh).
- **intermediate** (`int_`): the interesting joins and reusable building blocks. Not
  exposed to the dashboard. Materialized as views or ephemeral.
- **marts** (`mart_`/`fct_`/`dim_`): the business-ready tables. Materialized as tables
  (or incremental), partitioned and clustered. This is what Evidence reads.

**YAML's job:** the `.sql` file is the logic; the `.yml` next to it is the metadata.
Sources, column descriptions, tests, and freshness rules all live in YAML. dbt reads it
to run tests and to generate the docs site.

### 2.5 Tests — dbt generic + singular + dbt-expectations

dbt tests are assertions that run against the built tables. If one fails, the build fails.

- **Generic tests** (in YAML): the built-ins `not_null`, `unique`, `accepted_values`,
  `relationships` (foreign-key integrity). Declared per column, reused everywhere.
- **Singular tests** (a `.sql` file in `tests/`): a custom query that should return zero
  rows. Example: "no flight has a landing timestamp before its takeoff."
- **dbt-expectations** (a package): a richer library inspired by Great Expectations.
  Things like `expect_column_values_to_be_between`, row-count ranges, distribution checks.

The point is rigor beyond `not_null`/`unique`. For a portfolio piece, visible, serious
testing is a strong signal.

### 2.6 Docs — dbt docs site → GitHub Pages

`dbt docs generate` produces a static website from your models, YAML descriptions, and
the dependency graph, including an interactive **lineage DAG**. We publish it to GitHub
Pages so a recruiter can click through the model graph in a browser. Free and navigable.

### 2.7 Orchestration — GitHub Actions (daily cron)

**What it is:** GitHub's built-in CI/CD. We define workflows (YAML in `.github/workflows/`)
that run on two triggers:
- **On pull request:** run `dbt build` (models + tests) against a CI dataset so broken SQL
  never reaches main.
- **On a daily schedule (cron):** run the ingest scripts, then `dbt build` against prod,
  then publish the docs.

**Why not Airflow/Dagster:** those are heavy orchestrators meant for large teams and
complex DAGs. For a daily batch of two sources, GitHub Actions is enough and keeps the
whole project in one place. Reaching for Airflow here would be over-engineering.

### 2.8 Linting — sqlfluff + pre-commit hooks

- **sqlfluff:** a SQL linter and formatter. Enforces consistent style (keyword case,
  indentation, comma placement) and catches some errors. It understands dbt templating.
- **pre-commit:** a framework that runs hooks (like sqlfluff) automatically before each
  `git commit`. A commit with badly formatted SQL gets blocked until it is fixed.

Together they make discipline visible in the repo: every commit is already clean.

### 2.9 Serving — Evidence.dev

**What it is:** a framework where you write Markdown files with SQL queries embedded in
them, and it renders a polished data app (charts, tables, narrative) from the query
results. It connects directly to BigQuery and reads the marts.

**Why Evidence over Looker Studio:** Looker Studio is drag-and-drop and easier, but
Evidence is code-first (SQL + Markdown, version-controlled), which is much more in line
with the Analytics Engineering identity. It is the more differentiating choice for the
portfolio.

### 2.10 Metric layer — dbt semantic layer (stretch goal)

**What it is:** instead of hardcoding a metric like "on-time rate" inside each mart, you
define it once in YAML (a semantic model + metric), and any consumer queries it
consistently. It prevents the classic "every dashboard computes the KPI slightly
differently" problem.

**Status:** bonus. Strong technical signal if time allows, otherwise metrics live as
plain SQL in the marts. Not on the critical path.

---

## 3. Data flow end to end

1. **Ingest.** Python scripts hit OpenSky (flights) and Open-Meteo (weather), page
   through, back off on rate limits, checkpoint progress.
2. **Land.** Scripts write Parquet to `gs://headwind-497302-raw/<source>/dt=YYYY-MM-DD/`.
   One-shot reference data (OurAirports, OpenFlights CSVs) loads once.
3. **Load to raw.** `bq load` (or external tables) brings the Parquet into the BigQuery
   `raw` dataset, partitioned by date.
4. **Stage.** dbt `stg_` models clean and type each raw table (views).
5. **Build intermediate.** dbt joins flights to weather and builds delay-cascade logic.
   `int_flights_with_weather` is the technical centerpiece (temporal + spatial join).
6. **Build marts.** dbt produces `mart_hub_resilience`, `mart_route_risk`,
   `mart_airline_performance`, partitioned and clustered.
7. **Test.** Generic + singular + dbt-expectations tests run as part of `dbt build`.
8. **Document.** `dbt docs generate` builds the lineage site, published to GitHub Pages.
9. **Serve.** Evidence.dev reads the marts and renders the dashboard.
10. **Orchestrate.** GitHub Actions runs steps 1 to 9 on PRs (CI) and on a daily cron.

---

## 4. Cost design — paranoia mode

BigQuery free tier is **1 TB scanned per month** and **10 GB storage**. Cost is bytes
scanned, not rows. Rules we enforce from day one:

- Every table has a `PARTITION BY` column (usually a `DATE`). Queries filter on it so
  they scan one partition, not the whole table.
- Large tables add `CLUSTER BY` (up to 4 columns) on common filter/join keys.
- Before running a new query, read the "This will process X" estimate in the BigQuery UI.
- A billing alert is set at $1 USD in GCP as a tripwire.
- Never `SELECT *` without a partition filter on a big table. That is the main way to
  blow the budget.

Auth note: `gcloud auth application-default login` writes credentials to
`%APPDATA%\gcloud\` that the Google libraries and dbt pick up automatically. Never commit
a service-account JSON to the repo.

---

## 5. Locked assumptions

These were open questions in the original plan. Now decided:

| # | Decision | Choice |
|---|----------|--------|
| 1 | Airport scope | Top 20 EU hubs to start, expand if time allows |
| 2 | Time window | 2 years (enables year-over-year seasonal comparison) |
| 3 | Refresh cadence | Daily incremental (most demonstrable for the role) |
| 4 | Metric layer | dbt semantic layer only if time allows; else metrics in marts SQL |
| 5 | Dashboard | Evidence.dev (code-first, more differentiating than Looker Studio) |
| 6 | CI/CD scope | Full: `dbt build` on PR + docs deploy + scheduled prod runs |
| 7 | Flight pricing | Out of scope (phase 2, avoid scope creep) |

---

## 6. Extras (only if the core is solid)

- dbt semantic layer (assumption #4).
- Eurocontrol public dashboards as a cross-validation source for the marts.
- SCD Type 2 on `dim_airport` (capacity/runways change over time).
- Flight pricing scraping as a phase-2 route-analysis extension.
