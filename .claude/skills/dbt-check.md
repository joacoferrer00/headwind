---
name: dbt-check
description: "Build and test a dbt model and its downstream in the headwind project, then report pass/fail. TRIGGERS: 'dbt check', '/dbt-check', 'build and test this model', 'run dbt on X'. Fast feedback loop while modeling."
---

# dbt-check

Build + test a model and what depends on it, report results clearly.

## Steps

1. From `headwind_dbt/` with `.venv` active.
2. Run: `dbt build --select <model>+` (the `+` includes downstream models and tests).
   For just the model and its own tests, use `dbt build --select <model>`.
3. If a build or test fails, read the error, show the offending model/test, and propose
   a fix. Do not silently retry.
4. Report a short summary: models built, tests passed/failed, and any warnings.

Cost note: if the model is large or new, run [dry-run](dry-run.md) first. Respect the
`maximum_bytes_billed` cap.
