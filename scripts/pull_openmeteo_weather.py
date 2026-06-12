"""Pull Open-Meteo historical hourly weather for each top-20 hub, upload to GCS, load into BQ.

One request per hub per year (4 years x 20 hubs = 80 requests).
Parquet written to gs://headwind-497302-raw/openmeteo/dt=YYYY-MM-01/airport_icao.parquet
Then bq load into headwind_raw.weather partitioned by obs_date (MONTH).
"""

import csv
import io
import logging
import sys
import time
from pathlib import Path

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import requests
from google.cloud import bigquery, storage

SEED_CSV = Path(__file__).parent.parent / "headwind_dbt" / "seeds" / "seed_top_hubs.csv"
GCS_BUCKET = "headwind-497302-raw"
GCS_PREFIX = "openmeteo"
BQ_PROJECT = "headwind-497302"
BQ_DATASET = "headwind_raw"
BQ_TABLE = "weather"
YEARS = [2019, 2020, 2021, 2022]
BASE_URL = "https://archive-api.open-meteo.com/v1/archive"
HOURLY_VARS = [
    "temperature_2m",
    "relative_humidity_2m",
    "wind_speed_10m",
    "wind_gusts_10m",
    "wind_direction_10m",
    "precipitation",
    "rain",
    "snowfall",
    "snow_depth",
    "cloud_cover",
    "surface_pressure",
]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)


def load_hubs() -> list[dict]:
    with open(SEED_CSV, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def fetch_weather(
    session: requests.Session, icao: str, lat: float, lon: float, year: int
) -> pd.DataFrame:
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": f"{year}-01-01",
        "end_date": f"{year}-12-31",
        "hourly": ",".join(HOURLY_VARS),
        "timezone": "UTC",
        "wind_speed_unit": "ms",
    }
    resp = session.get(BASE_URL, params=params, timeout=60)
    resp.raise_for_status()
    data = resp.json()
    hourly = data["hourly"]
    df = pd.DataFrame(hourly)
    df.rename(columns={"time": "obs_time"}, inplace=True)
    df["obs_time"] = pd.to_datetime(df["obs_time"])
    df["obs_date"] = df["obs_time"].dt.date
    df["airport_icao"] = icao
    df["latitude"] = lat
    df["longitude"] = lon
    return df


def df_to_parquet_bytes(df: pd.DataFrame) -> bytes:
    table = pa.Table.from_pandas(df, preserve_index=False)
    buf = io.BytesIO()
    pq.write_table(table, buf)
    return buf.getvalue()


def upload_parquet(bucket: storage.Bucket, data: bytes, gcs_path: str) -> str:
    blob = bucket.blob(gcs_path)
    blob.upload_from_string(data, content_type="application/octet-stream")
    return f"gs://{bucket.name}/{gcs_path}"


def load_gcs_to_bq(bq_client: bigquery.Client, uris: list[str]) -> None:
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
    log.info("Loading %d files into %s", len(uris), full_table)
    # Pass explicit URIs; GCS folders with '=' in the name break BQ wildcards.
    job = bq_client.load_table_from_uri(uris, full_table, job_config=job_config)
    job.result()
    table = bq_client.get_table(full_table)
    log.info(
        "Done: %s rows, %.2f GB", f"{table.num_rows:,}", (table.num_bytes or 0) / 1e9
    )


def main() -> None:
    hubs = load_hubs()
    log.info("Loaded %d hubs from seed", len(hubs))

    gcs_client = storage.Client()
    bq_client = bigquery.Client(project=BQ_PROJECT)
    bucket = gcs_client.bucket(GCS_BUCKET)
    uploaded_uris: list[str] = []

    with requests.Session() as session:
        session.headers["User-Agent"] = "headwind-pipeline/1.0"

        for hub in hubs:
            icao = hub["airport_icao"]
            lat = float(hub["latitude"])
            lon = float(hub["longitude"])

            for year in YEARS:
                log.info("Fetching %s %d", icao, year)
                df = fetch_weather(session, icao, lat, lon, year)
                parquet_bytes = df_to_parquet_bytes(df)
                gcs_path = f"{GCS_PREFIX}/dt={year}-01-01/{icao}.parquet"
                uri = upload_parquet(bucket, parquet_bytes, gcs_path)
                uploaded_uris.append(uri)
                log.info(
                    "  Uploaded %s (%d rows, %.1f KB)",
                    uri,
                    len(df),
                    len(parquet_bytes) / 1024,
                )
                # small delay to be polite to the free API
                time.sleep(0.3)

    log.info(
        "All weather data uploaded (%d files). Loading into BigQuery...",
        len(uploaded_uris),
    )
    load_gcs_to_bq(bq_client, uploaded_uris)


if __name__ == "__main__":
    main()
