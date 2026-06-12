"""Re-read weather Parquet files from GCS, cast all numeric columns to float64, re-upload.

Fixes INT32 vs FLOAT64 type inconsistency across airports/years that breaks BQ load.
"""

import csv
import io
import logging
import sys
from pathlib import Path

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from google.cloud import storage

SEED_CSV = Path(__file__).parent.parent / "headwind_dbt" / "seeds" / "seed_top_hubs.csv"
GCS_BUCKET = "headwind-497302-raw"
GCS_PREFIX = "openmeteo"
YEARS = [2019, 2020, 2021, 2022]
FLOAT_COLS = [
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
    "latitude",
    "longitude",
]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)


def main() -> None:
    with open(SEED_CSV, newline="", encoding="utf-8") as f:
        hubs = [row["airport_icao"] for row in csv.DictReader(f)]

    gcs_client = storage.Client()
    bucket = gcs_client.bucket(GCS_BUCKET)
    fixed = 0

    for icao in hubs:
        for year in YEARS:
            gcs_path = f"{GCS_PREFIX}/dt={year}-01-01/{icao}.parquet"
            blob = bucket.blob(gcs_path)
            raw = blob.download_as_bytes()
            df = pd.read_parquet(io.BytesIO(raw))

            for col in FLOAT_COLS:
                if col in df.columns and df[col].dtype != "float64":
                    df[col] = df[col].astype("float64")

            buf = io.BytesIO()
            pq.write_table(pa.Table.from_pandas(df, preserve_index=False), buf)
            blob.upload_from_string(
                buf.getvalue(), content_type="application/octet-stream"
            )
            fixed += 1

    log.info("Re-uploaded %d files with consistent float64 types", fixed)


if __name__ == "__main__":
    main()
