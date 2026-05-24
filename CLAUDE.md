# CLAUDE.md — headwind

Proyecto portfolio: pipeline end-to-end de aviación EU + clima → análisis de resiliencia de hubs.
Stack: **dbt-bigquery + BigQuery + GCS + Python + Looker Studio/Evidence**.
Plan detallado del proyecto: [proyecto_aviation_dbt.md](proyecto_aviation_dbt.md).

---

## Estado actual (2026-05-24)

**Hecho:**
- `.venv/` creado con Python 3.11
- `requirements.txt` con dbt-core 1.10, dbt-bigquery 1.10, google-cloud-storage/bigquery, pyarrow, pandas, requests, sqlfluff, pre-commit
- `.gitignore` y `.vscode/settings.json` configurados (interpreter apunta a `.venv`)
- Extensión **dbt Power User** (Innoverio) instalada en VS Code
- **Google Cloud SDK** instalado, `gcloud init` corrido, autenticado como `joacoferrer00@gmail.com`
- GCP project existe: **`headwind-497302`**

**Pendiente inmediato (próxima sesión):**
1. Terminar `gcloud init` → elegir project `[4] headwind-497302`
2. Activar **billing alert en $1 USD** antes de cualquier otra cosa (paranoia justificada)
3. `gcloud auth application-default login` — esto deja creds que dbt va a usar (distinto del login normal)
4. Crear bucket GCS para landing raw (ej: `headwind-497302-raw`)
5. Crear dataset BQ inicial (ej: `headwind_raw`, location: `EU`)
6. `dbt init headwind_dbt` dentro del repo → configurar `~/.dbt/profiles.yml` apuntando al project
7. `dbt debug` → si dice "All checks passed", el setup está completo

---

## Arquitectura (cómo se conecta todo)

```
TU LAPTOP (repo)                    GCP project headwind-497302
─────────────────                   ──────────────────────────
Python ingest scripts  ──HTTPS──▶   GCS bucket (parquets raw, bronze)
                                            │
                                            ▼  bq load
                                    BigQuery dataset: raw
                                            │
dbt models (.sql/.yml) ──HTTPS──▶   BigQuery: staging → intermediate → marts
                                            │
                                            ▼
                                    Looker Studio / Evidence ◀── dashboard
```

**Importante entender:**
- El código (Python + dbt) **solo vive en local + GitHub**. El proyecto GCP no tiene "repo adentro" — solo data y queries guardadas.
- dbt corre en tu laptop pero **no procesa data**: compila SQL y se lo manda a BQ. BQ hace el trabajo pesado.
- La data nunca baja a tu disco (salvo `SELECT LIMIT 100` para debug).
- Auth: `gcloud auth application-default login` deja creds en `%APPDATA%\gcloud\` que las libs de Google y dbt usan automáticamente. **No metas service-account JSON al repo.**

---

## Costos — paranoia mode

BigQuery free tier (permanente, sin caducidad):
- **1 TB query/mes** — se consume por **bytes escaneados**, no por filas. `SELECT *` sin filtro sobre partition column = enemigo.
- **10 GB storage/mes**
- Cualquier scan >1TB en el mes empieza a cobrar.

GCS: prácticamente gratis al volumen del proyecto (céntimos/mes).

**Reglas autoimpuestas:**
- Toda tabla en BQ debe tener `PARTITION BY` (típicamente DATE).
- Toda tabla grande agrega `CLUSTER BY` (hasta 4 columnas).
- Antes de correr una query nueva: mirar el "This will process X" en la UI.
- Billing alert en $1 USD configurado en GCP.

---

## Capacitación — hacer antes de arrancar hands-on

**Sesión 1 — BigQuery (1h):**
- Console: https://console.cloud.google.com/bigquery?project=headwind-497302
- Free tier / sandbox: https://cloud.google.com/bigquery/docs/sandbox
- Partitioning: https://cloud.google.com/bigquery/docs/partitioned-tables
- Clustering: https://cloud.google.com/bigquery/docs/clustered-tables
- Public datasets para practicar: https://console.cloud.google.com/marketplace/browse?filter=solution-type:dataset

**Sesión 2 — dbt (1h):**
- dbt Fundamentals (curso gratis, los primeros 2 módulos alcanzan): https://learn.getdbt.com/courses/dbt-fundamentals
- dbt-bigquery setup: https://docs.getdbt.com/docs/core/connect-data-platform/bigquery-setup
- Conceptos `ref()` / `source()`: https://docs.getdbt.com/docs/build/sql-models
- Tests: https://docs.getdbt.com/docs/build/data-tests

**Plan de 1h cada sesión** (los pasos concretos a ejecutar) están en el chat anterior — pedírmelos cuando arranques con "dame el plan de la sesión de BigQuery / dbt".

---

## Links útiles del proyecto

- GCP console (home): https://console.cloud.google.com/home/dashboard?project=headwind-497302
- BigQuery Studio: https://console.cloud.google.com/bigquery?project=headwind-497302
- Cloud Storage: https://console.cloud.google.com/storage/browser?project=headwind-497302
- Billing: https://console.cloud.google.com/billing
- IAM (cuando haya que agregar service accounts): https://console.cloud.google.com/iam-admin/iam?project=headwind-497302

---

## APIs que se van a consumir (no requieren setup todavía)

- OpenSky Network — vuelos. Free, requiere registrarse: https://opensky-network.org/
- Open-Meteo Historical — clima. Free, sin auth: https://open-meteo.com/en/docs/historical-weather-api
- OurAirports — CSV one-shot: https://ourairports.com/data/
- OpenFlights — datasets one-shot: https://openflights.org/data.html

---

## Notas para Claude

- Joaquin **no maneja dbt/BigQuery a nivel experto** — explicar el "por qué" de las decisiones, no solo el "qué".
- Pragmatismo > elegancia. Si algo funciona, seguimos.
- Default de respuesta corta. Si pide detalle, dárselo.
- No avanzar a "hands-on con data" hasta que las sesiones de capacitación estén hechas (o que Joaquin lo pida explícito).
