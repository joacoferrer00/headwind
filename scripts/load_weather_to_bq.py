"""Load already-uploaded weather Parquet files from GCS into BigQuery headwind_raw.weather."""

import csv
import logging
import sys
from pathlib import Path

from google.cloud import bigquery

SEED_CSV = Path(__file__).parent.parent / "headwind_dbt" / "seeds" / "seed_top_hubs.csv"
GCS_BUCKET = "headwind-497302-raw"
GCS_PREFIX = "openmeteo"
BQ_PROJECT = "headwind-497302"
BQ_DATASET = "headwind_raw"
BQ_TABLE = "weather"
YEARS = [2019, 2020, 2021, 2022]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)


def main() -> None:
    with open(SEED_CSV, newline="", encoding="utf-8") as f:
        hubs = [row["airport_icao"] for row in csv.DictReader(f)]

    uris = [
        f"gs://{GCS_BUCKET}/{GCS_PREFIX}/dt={year}-01-01/{icao}.parquet"
        for icao in hubs
        for year in YEARS
    ]
    log.info("Loading %d URIs into BigQuery...", len(uris))

    bq_client = bigquery.Client(project=BQ_PROJECT)
    full_table = f"{BQ_PROJECT}.{BQ_DATASET}.{BQ_TABLE}"
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        time_partitioning=bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.MONTH,
            field="obs_date",
        ),
        clustering_fields=["airport_icao"],
    )
    job = bq_client.load_table_from_uri(uris, full_table, job_config=job_config)
    job.result()
    table = bq_client.get_table(full_table)
    log.info(
        "Done: %s rows, %.2f GB", f"{table.num_rows:,}", (table.num_bytes or 0) / 1e9
    )


if __name__ == "__main__":
    main()
