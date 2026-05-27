---
name: new-model
description: "Scaffold a new dbt model plus its YAML in the headwind project, following CONVENTIONS.md. TRIGGERS: 'new model', '/new-model', 'scaffold a dbt model', 'create a staging/intermediate/mart model'. Ask for layer and entity if not given."
---

# new-model

Scaffold a dbt model + its `.yml` in `headwind_dbt/models/`, consistent with
[CONVENTIONS.md](../../CONVENTIONS.md).

## Steps

1. Determine layer and name from the request (ask if unclear):
   - staging → `models/staging/stg_<source>__<entity>.sql`
   - intermediate → `models/intermediate/int_<entity>_<verb>.sql`
   - marts → `models/marts/dim_<entity>.sql` / `fct_<entity>.sql` / `mart_<concept>.sql`
2. Write the `.sql` with the house structure:
   - import CTEs reading from `{{ source() }}` (staging) or `{{ ref() }}` (downstream)
   - logic CTEs, then a `final` CTE, then `select * from final`
   - lowercase keywords, 4-space indent, trailing commas, no `select *` outside staging
   - for marts: add `{{ config(materialized='table', partition_by=..., cluster_by=[...]) }}`
3. Write/extend the layer's `.yml` (e.g. `models/staging/_staging__models.yml`):
   - model description
   - column descriptions
   - tests on the primary key (`not_null`, `unique`), plus `relationships` /
     `accepted_values` / dbt-expectations where they add rigor
4. Run `dbt parse` to confirm it is valid. Do not build unless asked.

Keep it minimal. No invented columns: base the model on the actual upstream schema.
