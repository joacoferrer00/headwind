# headwind_dbt

dbt project for the headwind EU aviation resilience pipeline.

See the root [CLAUDE.md](../CLAUDE.md) and [PLANNING.md](../PLANNING.md) for project context,
current state, and next steps. See [CONVENTIONS.md](../CONVENTIONS.md) for SQL and Python
style rules that apply to all models here.

## Quick start

```bash
cd headwind_dbt
dbt deps        # install packages
dbt parse       # verify project compiles
dbt build       # run models + tests (requires headwind_raw tables to exist)
```

Auth: ADC via `gcloud auth application-default login`. Profile: `~/.dbt/profiles.yml`,
target `dev`, dataset `dbt_dev`, project `headwind-497302` (EU).
