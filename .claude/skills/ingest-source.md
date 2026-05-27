---
name: ingest-source
description: "Scaffold a new Python ingestion script for an API source in the headwind project, following CONVENTIONS.md (Session, backoff, checkpoint, idempotent Parquet to GCS). TRIGGERS: 'new ingest', '/ingest-source', 'scaffold an ingestion script', 'pull data from <API>'. Ask for the source if not given."
---

# ingest-source

Scaffold an ingestion script that lands raw data in GCS as Parquet, following the Python
conventions in [CONVENTIONS.md](../../CONVENTIONS.md) and the landing design in
[PIPELINE.md](../../PIPELINE.md).

## Steps

1. Identify the source (OpenSky, Open-Meteo, etc.) and its auth + pagination model. Ask
   if unclear. Check the API links in [CLAUDE.md](../../CLAUDE.md).
2. Create the script under `ingestion/<source>.py` with:
   - a `requests.Session`
   - exponential backoff + retry on 429/5xx, respecting `Retry-After`
   - a checkpoint (last timestamp/page) persisted so a crashed run resumes
   - pagination loop until exhausted
   - output written as Parquet to `gs://headwind-497302-raw/<source>/dt=YYYY-MM-DD/`,
     idempotent (re-running a date overwrites that partition, never duplicates)
   - config + secrets from env vars, never hardcoded
   - type hints, `logging` (not print), `pathlib`, f-strings
   - a `if __name__ == "__main__":` entry point; logic in importable functions
3. Keep it minimal and runnable for one source, one day, before generalizing.
4. Do not commit credentials. Remind the user which env vars the script expects.
