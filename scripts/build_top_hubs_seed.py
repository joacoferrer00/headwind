"""Query 2019 flights, rank EU airports by movements, write seed_top_hubs.csv."""

import csv
import logging
import sys
from pathlib import Path

from google.cloud import bigquery

BQ_PROJECT = "headwind-497302"
SEED_PATH = (
    Path(__file__).parent.parent / "headwind_dbt" / "seeds" / "seed_top_hubs.csv"
)

# EU-27 + UK + CH + NO (ISO alpha-2 as stored in OurAirports iso_country)
EU_SCOPE = {
    "AT",
    "BE",
    "BG",
    "CY",
    "CZ",
    "DE",
    "DK",
    "EE",
    "ES",
    "FI",
    "FR",
    "GR",
    "HR",
    "HU",
    "IE",
    "IT",
    "LT",
    "LU",
    "LV",
    "MT",
    "NL",
    "PL",
    "PT",
    "RO",
    "SE",
    "SI",
    "SK",
    "GB",
    "CH",
    "NO",
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)

QUERY = """
WITH movements AS (
  SELECT origin AS icao, COUNT(*) AS cnt
  FROM `headwind-497302.headwind_raw.flights`
  WHERE day LIKE '2019-%' AND origin IS NOT NULL
  GROUP BY origin

  UNION ALL

  SELECT destination AS icao, COUNT(*) AS cnt
  FROM `headwind-497302.headwind_raw.flights`
  WHERE day LIKE '2019-%' AND destination IS NOT NULL
  GROUP BY destination
),
ranked AS (
  SELECT
    icao,
    SUM(cnt) AS total_movements
  FROM movements
  GROUP BY icao
),
joined AS (
  SELECT
    r.icao              AS airport_icao,
    a.iata_code         AS iata,
    a.name              AS name,
    a.iso_country       AS country,
    a.latitude_deg      AS latitude,
    a.longitude_deg     AS longitude,
    r.total_movements
  FROM ranked r
  JOIN `headwind-497302.headwind_raw.ourairports_airports` a
    ON r.icao = a.ident
  WHERE a.iso_country IN UNNEST(@eu_countries)
)
SELECT
  airport_icao,
  iata,
  name,
  country,
  latitude,
  longitude,
  total_movements
FROM joined
ORDER BY total_movements DESC
LIMIT 20
"""


def main() -> None:
    client = bigquery.Client(project=BQ_PROJECT)

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ArrayQueryParameter("eu_countries", "STRING", sorted(EU_SCOPE)),
        ],
        maximum_bytes_billed=20 * 1024**3,  # 20 GB cap
    )

    log.info("Running top-hub query against 2019 flights...")
    rows = list(client.query(QUERY, job_config=job_config).result())
    log.info("Query returned %d rows", len(rows))

    SEED_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(SEED_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(
            ["airport_icao", "iata", "name", "country", "latitude", "longitude"]
        )
        for row in rows:
            writer.writerow(
                [
                    row.airport_icao,
                    row.iata,
                    row.name,
                    row.country,
                    row.latitude,
                    row.longitude,
                ]
            )

    log.info("Wrote %s", SEED_PATH)
    log.info("Top hubs:")
    for i, row in enumerate(rows, 1):
        log.info(
            "  %2d. %s (%s) %s: %s movements",
            i,
            row.airport_icao,
            row.iata,
            row.name,
            f"{row.total_movements:,}",
        )


if __name__ == "__main__":
    main()
