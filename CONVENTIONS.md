# CONVENTIONS.md — headwind

Writing conventions for SQL (dbt) and Python so the codebase reads like one author, not
a patchwork of AI outputs. These are enforced by sqlfluff + ruff + pre-commit, and they
are binding for any code Claude generates here.

Companion docs: [CLAUDE.md](CLAUDE.md), [PIPELINE.md](PIPELINE.md), [PLANNING.md](PLANNING.md).

---

## SQL / dbt

Based on the dbt Labs style guide, adapted for BigQuery.

### Formatting
- Lowercase everything: keywords, function names, types. (`select`, not `SELECT`.)
- 4-space indentation. No tabs.
- Trailing commas, not leading.
- One column per line in `select` lists once there is more than one column.
- Lines under ~100 chars.
- sqlfluff (bigquery dialect, dbt templater) is the source of truth on style. If sqlfluff
  and this doc ever disagree, fix the doc.

### Model structure
- CTEs over subqueries, always. Read top to bottom.
- Start with import CTEs (`with source as (select ... from {{ ref(...) }})`), then logic
  CTEs, then one `final` CTE, then `select * from final`.
- One model = one file = one `select`.
- `ref()` and `source()` only. Never hardcode a project/dataset/table name in a model.
- No `select *` except in a staging import CTE reading directly from a source. Everywhere
  else, list columns explicitly.

### Naming
- Models:
  - staging: `stg_<source>__<entity>` (e.g. `stg_opensky__flights`)
  - intermediate: `int_<entity>_<verb>` (e.g. `int_flights_joined_to_weather`)
  - marts: `dim_<entity>`, `fct_<entity>`, or `mart_<concept>`
- Columns: `snake_case`.
- Primary key is the first column, named `<entity>_id` (surrogate keys via
  `dbt_utils.generate_surrogate_key`).
- Timestamps end in `_at` and are UTC. Dates end in `_date`. Booleans start with `is_` or
  `has_`. Counts/measures get a clear unit when ambiguous (`delay_minutes`).

### BigQuery cost discipline (non-negotiable, see PIPELINE.md)
- Every materialized table sets `partition_by` (usually a date column).
- Large tables set `cluster_by` on common filter/join keys (max 4).
- Prefer incremental materialization for large fact models.

### Tests & docs
- Every model has a `.yml` next to it: a description, and tests on at least the primary
  key (`not_null`, `unique`).
- Use `relationships` tests for foreign keys, `accepted_values` for enums, and
  dbt-expectations for ranges/distributions where it adds rigor.

---

## Python

Target: Python 3.11. Style enforced by ruff (lint + format), line length 88.

### Formatting & style
- ruff format (black-compatible). Do not hand-format against it.
- Type hints on every function signature (args and return).
- `snake_case` for functions and variables, `UPPER_CASE` for module constants,
  `PascalCase` for classes.
- f-strings for interpolation. No `%` or `.format()`.
- `pathlib.Path` over `os.path`.
- Standard-library `logging` over `print` for anything beyond a throwaway script.

### Structure
- Small, single-purpose functions. A function does one thing and its name says what.
- A `if __name__ == "__main__":` entry point in runnable scripts; logic lives in functions
  so it is importable and testable.
- Config and secrets come from environment variables, never hardcoded. No credentials in
  the repo (see PIPELINE.md auth note).

### Ingestion specifics (the API scripts)
- Use a `requests.Session`.
- Retry with exponential backoff on 429/5xx; respect `Retry-After`.
- Persist a checkpoint (last timestamp/page fetched) so a crashed run resumes.
- Writes to GCS are idempotent: re-running a date overwrites that date's partition, never
  appends duplicates.
- Write Parquet, partitioned by date (`dt=YYYY-MM-DD`).

### Comments & docstrings
- Default to no comments. Add one only when the *why* is non-obvious.
- One-line docstrings for simple functions. Short docstrings for complex ones. Never
  multi-paragraph docstrings.

---

## General
- All `.md` files in English. No em-dashes anywhere (code, comments, commits, docs).
- pre-commit runs sqlfluff + ruff before every commit. A failing hook blocks the commit;
  fix the cause, do not bypass with `--no-verify`.
