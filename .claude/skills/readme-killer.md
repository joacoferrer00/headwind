---
name: readme-killer
description: "Write or polish the portfolio README for headwind, leading with the business question (not the stack), recruiter-skimmable, with insights and screenshots. TRIGGERS: 'readme', '/readme-killer', 'polish the readme', 'write the portfolio readme'. Use near the end of the project (milestone 6)."
---

# readme-killer

Produce the final portfolio README. Recruiters skim; the first screen must say "this
person solves a real problem with data."

## Structure

1. **Open with the business question**, not the stack. One or two lines on what the
   project answers (hub resilience to weather disruption). See the questions in
   [PLANNING.md](../../PLANNING.md).
2. **Headline insights** (2 to 4 bullets) with concrete findings from the marts.
3. **Screenshots / GIF** of the Evidence dashboard and the dbt lineage DAG.
4. **Architecture diagram** (reuse/condense the one in [PIPELINE.md](../../PIPELINE.md)).
5. **Stack** as a compact table, with one-line "why" per choice.
6. **How to run it** (env vars, ingest, `dbt build`, serve), reproducible.
7. **What I would do next** (semantic layer, more hubs, pricing) to show judgment.

## Rules

- English, no em-dashes.
- Lead with impact, keep the stack lower. No walls of text.
- Every claimed insight must be backed by a real mart query, not invented.
- Link to the live dbt docs site (GitHub Pages) and the dashboard.
