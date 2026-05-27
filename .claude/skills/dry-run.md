---
name: dry-run
description: "Estimate how many bytes a dbt model (or ad-hoc SQL) would scan in BigQuery WITHOUT running it. Cost paranoia gate. TRIGGERS: 'dry run', '/dry-run', 'how much will this scan', 'estimate cost', 'check bytes billed'. Use before building anything that touches a large table."
---

# dry-run

Report the BigQuery scan cost of a model before executing it, so we never blow the free
tier (1 TB/month). See [PIPELINE.md](../../PIPELINE.md) cost section.

## Steps

1. Compile, do not run:
   `cd headwind_dbt && dbt compile --select <model>` (activate `.venv` first).
   The compiled SQL is in `target/compiled/.../<model>.sql`.
2. Dry-run that SQL against BigQuery to get bytes-to-scan. Use the bundled-python `bq`:
   `bq query --use_legacy_sql=false --dry_run --flagfile=/dev/null < compiled.sql`
   or the Python client with `job_config=QueryJobConfig(dry_run=True, use_query_cache=False)`.
3. Report:
   - bytes that would be scanned (convert to MB/GB)
   - whether it is under the `maximum_bytes_billed` cap in `~/.dbt/profiles.yml` (~1 GB)
   - if it is large, point at the likely cause (missing partition filter, `select *`,
     unpartitioned join) and suggest the fix
4. Do not build. This is read-only estimation.
