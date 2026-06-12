"""Download OurAirports + OpenFlights reference files, upload to GCS, load into BigQuery."""

import logging
import sys

import requests
from google.cloud import bigquery, storage

GCS_BUCKET = "headwind-497302-raw"
BQ_PROJECT = "headwind-497302"
BQ_DATASET = "headwind_raw"

SOURCES = {
    "ourairports_airports": {
        "url": "https://ourairports.com/data/airports.csv",
        "gcs_path": "reference/ourairports_airports.csv",
        "has_header": True,
        "schema": None,  # autodetect
    },
    "openflights_airlines": {
        "url": "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airlines.dat",
        "gcs_path": "reference/openflights_airlines.csv",
        "has_header": False,
        "header": "airline_id,name,alias,iata,icao,callsign,country,active",
        "schema": [
            bigquery.SchemaField("airline_id", "INTEGER"),
            bigquery.SchemaField("name", "STRING"),
            bigquery.SchemaField("alias", "STRING"),
            bigquery.SchemaField("iata", "STRING"),
            bigquery.SchemaField("icao", "STRING"),
            bigquery.SchemaField("callsign", "STRING"),
            bigquery.SchemaField("country", "STRING"),
            bigquery.SchemaField("active", "STRING"),
        ],
    },
    "openflights_routes": {
        "url": "https://raw.githubusercontent.com/jpatokal/openflights/master/data/routes.dat",
        "gcs_path": "reference/openflights_routes.csv",
        "has_header": False,
        "header": "airline,airline_id,source_airport,source_airport_id,destination_airport,destination_airport_id,codeshare,stops,equipment",
        "schema": [
            bigquery.SchemaField("airline", "STRING"),
            bigquery.SchemaField("airline_id", "STRING"),
            bigquery.SchemaField("source_airport", "STRING"),
            bigquery.SchemaField("source_airport_id", "STRING"),
            bigquery.SchemaField("destination_airport", "STRING"),
            bigquery.SchemaField("destination_airport_id", "STRING"),
            bigquery.SchemaField("codeshare", "STRING"),
            bigquery.SchemaField("stops", "INTEGER"),
            bigquery.SchemaField("equipment", "STRING"),
        ],
    },
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)


def download(session: requests.Session, url: str) -> bytes:
    log.info("Downloading %s", url)
    resp = session.get(url, timeout=60)
    resp.raise_for_status()
    return resp.content


def prepend_header(raw: bytes, header: str) -> bytes:
    return (header + "\n").encode() + raw


def upload_to_gcs(bucket: storage.Bucket, data: bytes, gcs_path: str) -> str:
    blob = bucket.blob(gcs_path)
    blob.upload_from_string(data, content_type="text/csv")
    uri = f"gs://{bucket.name}/{gcs_path}"
    log.info("Uploaded %s (%.1f KB)", uri, len(data) / 1024)
    return uri


def load_to_bq(
    bq_client: bigquery.Client, uri: str, table_id: str, schema: list | None
) -> None:
    full_table = f"{BQ_PROJECT}.{BQ_DATASET}.{table_id}"
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        # Reference tables are small and have no natural date column;
        # partitioning is omitted here (cost rule targets large fact tables).
        autodetect=(schema is None),
    )
    if schema is not None:
        job_config.schema = schema

    job = bq_client.load_table_from_uri(uri, full_table, job_config=job_config)
    job.result()
    table = bq_client.get_table(full_table)
    log.info("Loaded %s: %d rows", full_table, table.num_rows)


def main() -> None:
    gcs_client = storage.Client()
    bq_client = bigquery.Client(project=BQ_PROJECT)
    bucket = gcs_client.bucket(GCS_BUCKET)

    with requests.Session() as session:
        session.headers["User-Agent"] = "headwind-pipeline/1.0"

        for table_id, cfg in SOURCES.items():
            log.info("--- %s ---", table_id)
            raw = download(session, cfg["url"])

            if not cfg["has_header"]:
                raw = prepend_header(raw, cfg["header"])

            uri = upload_to_gcs(bucket, raw, cfg["gcs_path"])
            load_to_bq(bq_client, uri, table_id, cfg["schema"])

    log.info("All reference tables loaded.")


if __name__ == "__main__":
    main()
