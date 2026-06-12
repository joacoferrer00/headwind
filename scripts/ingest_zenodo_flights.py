"""Download OpenSky COVID-19 flight CSVs from Zenodo, convert to Parquet, upload to GCS."""

import gzip
import logging
import re
import sys
import tempfile
import time
from pathlib import Path

import pyarrow.csv as pcsv
import pyarrow.parquet as pq
import requests
from google.api_core import retry as api_retry
from google.cloud import storage

ZENODO_RECORD_ID = "7923702"
ZENODO_API_URL = f"https://zenodo.org/api/records/{ZENODO_RECORD_ID}"
GCS_BUCKET = "headwind-497302-raw"
GCS_PREFIX = "zenodo_flights"
DOWNLOAD_CHUNK = 8 * 1024 * 1024  # 8 MB

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)

GCS_RETRY = api_retry.Retry(
    initial=1.0,
    maximum=60.0,
    multiplier=2.0,
    deadline=600.0,
)


def list_zenodo_files(session: requests.Session) -> list[dict]:
    resp = session.get(ZENODO_API_URL, timeout=30)
    resp.raise_for_status()
    return resp.json()["files"]


def dt_from_filename(filename: str) -> str | None:
    match = re.search(r"flightlist_(\d{8})_\d{8}", filename)
    if not match:
        return None
    raw = match.group(1)
    return f"{raw[:4]}-{raw[4:6]}-01"


def blob_exists(bucket: storage.Bucket, blob_name: str) -> bool:
    return bucket.blob(blob_name).exists()


def download_gz_to_file(
    session: requests.Session,
    url: str,
    dest: Path,
    filename: str,
) -> None:
    """Stream a URL to a local file with exponential-backoff retry on transient errors."""
    for attempt in range(1, 4):
        try:
            with session.get(url, stream=True, timeout=300) as resp:
                resp.raise_for_status()
                with dest.open("wb") as fh:
                    for chunk in resp.iter_content(chunk_size=DOWNLOAD_CHUNK):
                        fh.write(chunk)
            return
        except (requests.ConnectionError, requests.Timeout) as exc:
            if attempt == 3:
                raise
            wait = 15 * attempt
            log.warning(
                "Download attempt %d failed (%s), retrying in %ds", attempt, exc, wait
            )
            time.sleep(wait)


def convert_gz_to_parquet(gz_path: Path, parquet_path: Path) -> int:
    """Decompress a .csv.gz and write as Parquet. Returns row count."""
    convert_opts = pcsv.ConvertOptions(
        column_types={
            "callsign": "string",
            "number": "string",
            "icao24": "string",
            "registration": "string",
            "typecode": "string",
            "origin": "string",
            "destination": "string",
            "day": "string",
        },
        null_values=["", "nan", "NaN", "null", "None"],
    )
    with gzip.open(gz_path, "rb") as gz:
        table = pcsv.read_csv(gz, convert_options=convert_opts)

    pq.write_table(table, parquet_path, compression="snappy")
    return len(table)


def upload_parquet(bucket: storage.Bucket, parquet_path: Path, blob_name: str) -> None:
    blob = bucket.blob(blob_name)
    with parquet_path.open("rb") as fh:
        blob.upload_from_file(
            fh,
            content_type="application/octet-stream",
            retry=GCS_RETRY,
            timeout=300,
        )
    size_mb = parquet_path.stat().st_size / 1e6
    log.info("Uploaded %s (%.1f MB)", blob_name, size_mb)


def process_file(
    session: requests.Session,
    bucket: storage.Bucket,
    file_info: dict,
    tmp_dir: Path,
) -> None:
    filename = file_info["key"]
    if not filename.endswith(".csv.gz"):
        return

    dt = dt_from_filename(filename)
    if dt is None:
        log.warning("Could not parse dt from %s, skipping", filename)
        return

    blob_name = f"{GCS_PREFIX}/dt={dt}/data.parquet"
    if blob_exists(bucket, blob_name):
        log.info("Already exists, skipping: %s", blob_name)
        return

    gz_path = tmp_dir / filename
    parquet_path = tmp_dir / filename.replace(".csv.gz", ".parquet")

    try:
        log.info("Downloading %s", filename)
        download_gz_to_file(session, file_info["links"]["self"], gz_path, filename)

        log.info("Converting to Parquet")
        rows = convert_gz_to_parquet(gz_path, parquet_path)
        gz_path.unlink(missing_ok=True)

        upload_parquet(bucket, parquet_path, blob_name)
        log.info("Done %s: %d rows", dt, rows)
    finally:
        gz_path.unlink(missing_ok=True)
        parquet_path.unlink(missing_ok=True)


def main() -> None:
    gcs_client = storage.Client()
    bucket = gcs_client.bucket(GCS_BUCKET)

    with requests.Session() as session:
        session.headers["User-Agent"] = "headwind-pipeline/1.0"
        files = list_zenodo_files(session)
        flight_files = sorted(
            [f for f in files if f["key"].endswith(".csv.gz")],
            key=lambda f: f["key"],
        )
        log.info("Found %d flight files on Zenodo", len(flight_files))

        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            for i, file_info in enumerate(flight_files, 1):
                log.info("--- %d/%d: %s ---", i, len(flight_files), file_info["key"])
                try:
                    process_file(session, bucket, file_info, tmp_dir)
                except Exception:
                    log.exception("Failed on %s, continuing", file_info["key"])


if __name__ == "__main__":
    main()
