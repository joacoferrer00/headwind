"""Load GCS Parquet flight partitions into BigQuery headwind_raw.flights.

day arrives as BYTE_ARRAY (string) in the Parquet files, so it cannot be
used as a partition column at load time. The raw table is an unpartitioned
landing zone; partitioning and clustering happen in the dbt staging model
once day is cast to DATE.
"""

import logging
import sys

from google.cloud import bigquery

BQ_PROJECT = "headwind-497302"
BQ_DATASET = "headwind_raw"
BQ_TABLE = "flights"
GCS_URI = "gs://headwind-497302-raw/zenodo_flights/*/data.parquet"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)

# day is STRING (BYTE_ARRAY in Parquet); firstseen/lastseen are Unix INT64.
FLIGHTS_SCHEMA = [
    bigquery.SchemaField("callsign", "STRING"),
    bigquery.SchemaField("number", "STRING"),
    bigquery.SchemaField("icao24", "STRING"),
    bigquery.SchemaField("registration", "STRING"),
    bigquery.SchemaField("typecode", "STRING"),
    bigquery.SchemaField("origin", "STRING"),
    bigquery.SchemaField("destination", "STRING"),
    bigquery.SchemaField("firstseen", "INT64"),
    bigquery.SchemaField("lastseen", "INT64"),
    bigquery.SchemaField("day", "STRING"),
    bigquery.SchemaField("latitude_1", "FLOAT64"),
    bigquery.SchemaField("longitude_1", "FLOAT64"),
    bigquery.SchemaField("altitude_1", "FLOAT64"),
    bigquery.SchemaField("latitude_2", "FLOAT64"),
    bigquery.SchemaField("longitude_2", "FLOAT64"),
    bigquery.SchemaField("altitude_2", "FLOAT64"),
]


def main() -> None:
    client = bigquery.Client(project=BQ_PROJECT)
    full_table = f"{BQ_PROJECT}.{BQ_DATASET}.{BQ_TABLE}"

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        schema=FLIGHTS_SCHEMA,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    log.info("Loading %s into %s", GCS_URI, full_table)
    job = client.load_table_from_uri(GCS_URI, full_table, job_config=job_config)
    log.info("Load job %s started, waiting...", job.job_id)
    job.result()

    table = client.get_table(full_table)
    log.info(
        "Done: %s rows, %d partitions approx, %.2f GB",
        f"{table.num_rows:,}",
        table.num_rows // 1_000_000,
        (table.num_bytes or 0) / 1e9,
    )


if __name__ == "__main__":
    main()
