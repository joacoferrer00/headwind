# Proyecto Portfolio — Resiliencia Operativa de Hubs Aéreos EU

> Stack: dbt + BigQuery + GCS + Python + Looker Studio
> Timeline: 2 semanas part-time (~2h/día), arranca semana del 2026-05-25
> Objetivo dual: portfolio piece para roles EU + cerrar gap dbt/BigQuery del stack

---

## Pitch en una frase

Pipeline end-to-end que cruza datos reales de vuelos europeos con clima histórico para identificar qué hubs son más resilientes a disrupciones operativas — y qué rutas tienen mayor riesgo de conexión perdida cuando un hub se cae.

---

## Preguntas de negocio que el proyecto responde

1. **Resiliencia por hub:** ¿Qué top-20 aeropuertos EU tienen mejor on-time performance ajustada por severidad de clima? (no es lo mismo Madrid en julio que Frankfurt en enero)
2. **Estacionalidad:** ¿Qué hubs colapsan en qué época y por qué tipo de evento (nieve, viento, niebla, tormenta)?
3. **Propagación de delays:** Cuando un hub principal se demora, ¿qué rutas downstream pierden más conexiones?
4. **Hubs alternativos:** Si sos head of ops de una aerolínea, ¿qué hub de respaldo conviene tener pre-aprobado para cada época del año?
5. **Aerolíneas:** Ajustando por hubs operados, ¿qué aerolínea EU performa mejor en condiciones adversas?

---

## Stack técnico

| Capa | Herramienta | Por qué |
|------|-------------|---------|
| Ingestion | Python scripts | OpenSky API + Open-Meteo, paginación, rate limits |
| Landing | GCS (Parquet, particionado por fecha) | bronze layer, cheap storage, replayable |
| Warehouse | BigQuery | free tier alcanza, particionado + clustering obligatorios |
| Transformation | dbt-bigquery | staging → intermediate → marts, medallion en dbt |
| Tests | dbt generic + singular + dbt-expectations | rigor, no solo not_null/unique |
| Docs | dbt docs site → GitHub Pages | navegable, profesional |
| Orchestration | GitHub Actions (cron diario) | CI/CD + scheduled runs sin orchestrator pesado |
| Linting | sqlfluff + pre-commit hooks | discipline visible en el repo |
| Serving | Evidence.dev | SQL + markdown |
| Metric layer | dbt semantic layer (si el tiempo da) | bonus técnico fuerte |

---

## Fuentes de datos

- **OpenSky Network API** — vuelos europeos histórico, free, requiere auth básica. Timestamps reales takeoff/landing (no schedules).
- **Open-Meteo Historical Weather API** — free, sin auth, clima por lat/long + timestamp.
- **OurAirports.com** — CSV con todos los aeropuertos del mundo (lat, long, IATA, ICAO, country) → dim_airport.
- **OpenFlights.org** — dataset de aerolíneas y rutas → dim_airline.
- **Eurocontrol Public Dashboards** — métricas agregadas oficiales de puntualidad → para validation cruzada de los modelos.

---

## Modelo dimensional (boceto)

**Facts:**
- `fact_flights` — grano: 1 vuelo. Particionado por departure_date, clustered por origin_airport_code.
- `fact_weather_observations` — grano: 1 observación horaria por aeropuerto.

**Dimensions:**
- `dim_airport` (SCD Type 2 — capacity/runways pueden cambiar)
- `dim_airline`
- `dim_aircraft` (por tail number cuando esté disponible)
- `dim_date`
- `dim_weather_event` (categoriza condiciones: clear / windy / snow / fog / storm)

**Intermediate models notables:**
- `int_flights_with_weather` — el join temporal flight × weather (ventana ±30min, aeropuerto más cercano). El modelo más interesante técnicamente.
- `int_delay_cascades` — agrupa vuelos por aircraft tail number para trackear propagación.

**Marts:**
- `mart_hub_resilience` — métricas agregadas por aeropuerto × mes × condición climática
- `mart_route_risk` — par origen-destino con índice de riesgo de conexión perdida
- `mart_airline_performance` — performance por aerolínea ajustada por hubs operados

---

## Preguntas abiertas (decidir antes de arrancar)

1. **Scope de aeropuertos:** ¿Top 20 EU, top 30, o todo Europa? Top 20 mantiene volumen tratable para BigQuery free tier — recomiendo arrancar con 20 y expandir si sobra tiempo.
2. **Ventana temporal:** ¿1 año, 2 años, 5 años? Más tiempo = más insights estacionales pero más costos de ingest y storage. Recomiendo 2 años para tener YoY comparison.
3. **Refresh cadence:** ¿Daily incremental o weekly batch? Daily incremental es más demostrable como Analytics Engineer pero requiere más setup.
4. **Metric layer:** ¿dbt semantic layer (más profesional, más nuevo, más complejo) o dejar las métricas en marts SQL puros? Semantic layer suma mucho al portfolio si el tiempo alcanza.
5. **Dashboard:** ¿Looker Studio (más fácil, free) o levantar un Streamlit/Evidence.dev (más diferenciador, más trabajo)? Evidence.dev es interesante porque renderea SQL → markdown reports, muy en línea con Analytics Engineering.
6. **CI/CD scope:** ¿Solo `dbt build` en PR, o también deploy de docs site + schedule de prod runs? Full pipeline suma pero es el último 20% en tiempo.
7. **¿Incluir flight pricing scraping?** Sería una segunda fase muy interesante para vincular con análisis de ruta, pero scope creep — dejar para fase 2.

---

## Timeline propuesto (2 semanas)

| Día | Foco |
|-----|------|
| 1–2 | Setup repo, GCP project, BigQuery dataset, dbt init, OpenSky exploration, decisión de scope |
| 3–5 | Ingestion pipeline Python → GCS → BigQuery raw tables |
| 6–9 | dbt: staging + intermediate + dimensional model + el join flight × weather |
| 10–11 | Tests serios (dbt-expectations, freshness, singulars) + docs site |
| 12–13 | Dashboard + GitHub Actions CI/CD |
| 14 | README killer con story de negocio, screenshots, insights destacados |

---

## Naming — opciones

Ordenadas de mi favorito a menos favorito:

1. **`headwind`** — término aeronáutico (viento de frente que retrasa al avión). Metáfora directa con disrupciones operativas. Una palabra, memorable, profesional. Mi favorito.
2. **`metar`** — código real de reportes meteorológicos aeronáuticos. Niche-cool: cualquiera que sepa de aviación lo reconoce, cualquiera que no, googlea y aprende. Diferenciador.
3. **`holding-pattern`** — el patrón circular que vuelan los aviones esperando aterrizar. Referencia a delays. Más narrativa, menos punchy.
4. **`crosswind`** — viento cruzado, condición que más cancela aterrizajes. Más técnico aviation, menos memorable para no-iniciados.
5. **`eu-hub-resilience`** — descriptivo, sin personalidad, pero muy claro para un recruiter que escanea GitHub. Safe bet.
6. **`tarmac`** — la pista donde los aviones esperan. Corto, memorable, pero quizás demasiado abstracto del contenido del proyecto.

**Mi voto:** `headwind`. El repo se llamaría `headwind` o `headwind-eu-aviation`. Subtítulo en el README: *"European aviation operational resilience analytics — dbt + BigQuery + weather correlation."*

---

## Notas para Claude (cuando arranque el proyecto)

- Este es un proyecto de **learning + delivery** — Joaquin no maneja dbt/BigQuery a nivel experto todavía. Explicar decisiones técnicas, no solo ejecutarlas.
- Costos: BigQuery free tier es 1TB query/mes + 10GB storage. Diseñar particiones + clustering desde el día 1 para no romper el límite.
- OpenSky tiene rate limits agresivos en su tier free — diseñar el ingest con backoff y persistir checkpoints para reanudar.
- El join flight × weather temporal-espacial es el corazón técnico del proyecto. Vale la pena diseñarlo con cuidado (window functions, ARRAY_AGG con LIMIT, o approximate joins).
- El README final debe abrir con la pregunta de negocio, no con el stack. Recruiters skimean — el primer screen tiene que decir "este tipo resuelve un problema real con datos".
