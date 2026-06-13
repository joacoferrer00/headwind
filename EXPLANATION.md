# headwind, explained (for Joaquin)

This is the catch-up doc. You built this project by orchestrating Claude Code and did not
read every line of SQL, which is fine. This file gets you to the point where you can open
the repo, look someone in the eye, and explain what it is and why it is good, both
technically and commercially. Read it in one sitting. It assumes you have never used dbt
or BigQuery.

It is deliberately separate from `README.md`. The README is the public storefront ("what
is this, how do I run it"). This file is your private briefing.

---

## 1. What the project is, and why it is worth showing

Airports (hubs) get stressed two ways:

- **Chronic stress:** bad weather, all the time. Snow, wind, fog, storms slow operations
  down a little, every week.
- **Acute stress:** a sudden shock. The COVID-19 collapse of 2020 wiped out most air
  traffic almost overnight, then it recovered unevenly over the next two years.

The project crosses four years of European flight data (2019 to 2022) with hourly weather
at the top 20 EU hubs and asks one question:

> **Are the hubs that handle weather well the same ones that absorbed the COVID shock
> well, or are these two different kinds of resilience?**

Why this is a credible portfolio piece (the commercial angle):

- It is a **real question on messy real data**, not a tidy tutorial dataset. The flight
  data has missing values, duplicates, and quirks you have to handle.
- It is **end to end**: raw downloaded files all the way to a live, public dashboard, with
  automated testing and deployment in between. Most portfolio projects stop at a notebook.
- It uses **production practices**: version control, data tests, CI/CD, documentation,
  cost controls. This is what a real data team cares about.
- The subject (**operational resilience**) is something airlines, airport operators, and
  aviation analytics firms actually pay for. The framing is business-relevant, not just a
  data exercise.

The honest headline finding (more in section 4) is interesting in its own right: weather
resilience and shock resilience barely correlate. They are mostly separate problems.

---

## 2. The tools, and what each one actually does

You use a few names a lot. Here is what each one is, in one breath:

- **BigQuery** is Google's **data warehouse**: a giant SQL database in the cloud built for
  analytics. All the tables live here. The important quirk: Google bills you by **how much
  data each query reads**, not by how much you store. That is why the project is obsessive
  about partitioning and clustering tables (so queries read less).

- **Google Cloud Storage (GCS)** is cloud **file storage**, like a big shared folder
  ("bucket"). The raw downloaded data (flight files, weather files) lands here as files
  before it is loaded into BigQuery.

- **dbt** is the **transformation layer**. You write `SELECT` statements in files; dbt runs
  them against BigQuery in the right order, turns each one into a table or view, **tests**
  them, and **documents** them with a browsable diagram of how everything connects. dbt does
  not store data itself. It orchestrates SQL that runs inside BigQuery. The one-liner:
  **dbt turns raw tables into clean, tested, business-ready tables, with software
  discipline (modular, version-controlled, tested).**

- **Evidence.dev** turns SQL + markdown into a **website of charts**. You write a page in
  markdown with SQL queries in it, and it builds a static dashboard. That is the live site.

- **GitHub Actions** is **automation that runs when you push code**. Here it rebuilds and
  tests the whole pipeline on every change, and publishes the documentation and the
  dashboard. This is the "CI/CD" part.

- **Workload Identity Federation (WIF)** is a **keyless login**. It lets GitHub prove its
  identity to Google Cloud so the automation can use BigQuery, without storing a password
  or key file in the repo. (Storing cloud keys in a repo is the classic security mistake;
  this avoids it entirely.)

---

## 3. How the data flows (the whole architecture in one pass)

```
raw sources  ->  GCS (raw files)  ->  BigQuery raw tables  ->  dbt models  ->  dashboard
```

The dbt part is built in **layers**, each one cleaner than the last. This is a standard
pattern (sometimes called medallion): you never transform raw data in one giant messy
query; you build it up in readable, reusable, testable steps.

1. **Staging** (5 models): take each raw source and clean it. Fix data types, rename
   columns, drop garbage rows. One cleaned table per source.
2. **Dimensions and intermediate** (6 + 2 models): dimensions are the reference tables
   (airports, airlines, aircraft, a calendar, weather categories, pandemic phases). The
   intermediate models do the heavy lifting, especially `int_flights_with_weather`, which
   joins every hub flight to the weather at its airport at its specific hour.
3. **Marts** (4 models): the final, answer-shaped tables that the dashboard reads.

Then **Evidence** reads the marts and renders the charts, and **dbt docs** publishes a
browsable map of every table and how they connect. Both are deployed automatically.

---

## 4. What got built, and what it found

**The data.** About 117 million flight observations (2019 to 2022) from the OpenSky
project, hourly weather from Open-Meteo, plus airport and airline reference data. Narrowed
to the **top 20 EU hubs**.

**The four marts** (each answers part of the question):

- `mart_hub_resilience`: how much each hub's flight durations degrade under each weather
  type. (Chronic stress.)
- `mart_hub_recovery`: each hub's monthly traffic versus its 2019 baseline, so you can see
  the 2020 collapse and the recovery. (Acute shock.)
- `mart_route_risk`: which origin-to-destination routes are most sensitive to weather and
  to the shock.
- `mart_airline_performance`: how each carrier's network changed through the shock.

**The technical centerpiece** is the flight-to-weather join: matching each of ~13 million
hub flights to the weather observation at the right airport and the right hour. Doing that
correctly and cheaply over 117M rows is the hard part of the project.

**The 120 tests.** A test here is an automated assertion about the data, for example "every
flight has a unique id", "no flight lands before it takes off", "every hub has a 2019
baseline". If any fails, the build goes red. This is what lets you trust the numbers. 117
pass, 3 are warnings on purpose (see caveats), 0 fail.

**The finding.** Across the 20 hubs, weather resilience and shock resilience correlate at
about **0.30**, which is weak. In plain terms: **knowing a hub handles weather well tells
you almost nothing about how it handled COVID.** They are largely independent kinds of
resilience. That is a genuine, slightly counterintuitive result, which is exactly what you
want from an analysis.

**The honesty caveats** (and why they are a strength, not a weakness):

- OpenSky cannot always tell where a flight started or ended, so many flights have a
  missing origin or destination. The project counts a hub's traffic only from flights where
  that hub is clearly one end.
- The airline is guessed from the flight's callsign, and about 60% of those codes do not
  match a known airline.

These limits are surfaced as **warning-level tests and documented in the README**, not
hidden. Stating the limits of your data is a senior-analyst move; pretending they do not
exist is a junior one.

---

## 5. What this says about how you work

You did not hand-write the SQL. You **architected and steered**: you set the scope, made
the decisions (which hubs, which time window, how to handle the missing data, where to
host things, how to keep cloud costs near zero), and drove Claude Code to build, test, and
deploy it. The agent wrote the code; you ran the project.

That is the actual modern skill on display: **you can stand up a complete, tested, deployed
data and analytics system at speed**, across the whole stack:

- ingestion (Python, pulling and loading raw data),
- dimensional modeling (dbt, designing the tables),
- data quality (a real test suite),
- cost-aware cloud engineering (BigQuery partitioning and a hard byte cap),
- CI/CD with keyless cloud auth (GitHub Actions + WIF),
- BI delivery (Evidence dashboard),
- and documentation (dbt docs, README, this file).

The differentiator is not any single tool. It is that you can orchestrate the whole thing.

---

## 6. If someone asks you about it (talking points)

- **"What is it?"** An end-to-end data pipeline that crosses European flight data with
  weather to measure how resilient airport hubs are to two kinds of stress: everyday
  weather and the COVID shock. It ends in a live dashboard.

- **"Why dbt and BigQuery?"** BigQuery is a serverless warehouse with a generous free tier,
  good for a large public dataset. dbt is the industry-standard way to build tested,
  documented, version-controlled SQL transformations on top of it.

- **"What was the hard part?"** Joining 117 million flights to hourly weather at the right
  place and time, correctly and within a tight query-cost budget. And handling the messy
  reality that a lot of flights have missing endpoints.

- **"What did you find?"** That weather resilience and shock resilience are mostly
  unrelated (correlation about 0.30). A hub being good at one does not predict the other.

- **"What would you do next?"** Add a metrics/semantic layer, weight the COVID effect by
  how hard each country actually locked down (using the Oxford stringency index), and
  extend it to live flight data instead of the frozen 2019 to 2022 window.

- **"How did you build it so fast?"** By orchestrating Claude Code: steering the
  architecture and decisions while the agent generated and iterated on the code.

---

For the public version and how to run it, see [README.md](README.md). For scope and the
full plan, see [PLANNING.md](PLANNING.md). For the architecture in depth, see
[PIPELINE.md](PIPELINE.md).
