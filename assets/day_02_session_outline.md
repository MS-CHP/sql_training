# Session 2 — Fundamentals Part 2: Joins, Grain, and Data Modeling
**March 17, 2026 · 10:00 AM – 1:00 PM CT**

## Session focus
We return to the ACA pricing data from Day 1, this time working in SQL. The goal is to build a process for approaching unfamiliar tables: inspect before you query, validate joins before you trust results, and recognize when a problem requires multi-step logic.

The workflow we are practicing: run a query, look at the result, modify, re-run, is non-destructive and gives rapid feedback. Over time this allows you to take small steps towards building very complex analyses.

## Before the session
1. Confirm your database connection is working
2. Have your SQL editor open and connected (VS Code recommended; web-based options available)
3. Complete SQLBolt lessons 1–12 if you haven't already

---

## Activity 1 — Orient to a new table
Start with one table: `aca_rate_puf`. Before writing anything complex, inspect what you're working with.


_starter script_
```sql
-- What does this table look like?
SELECT * FROM public.aca_rate_puf LIMIT 20;

-- How large is it?
SELECT TO_CHAR(COUNT(*), 'FM999,999,999,999') AS total_rows
FROM public.aca_rate_puf;
```

Key questions: What does one row represent? Which columns look like identifiers vs. measures? What combination of columns defines a unique row (the grain)?

---

## Activity 2 — Summaries and introducing plan attributes
Use GROUP BY to ask analytical questions about the rate table, then explore a second table: `aca_plan_attributes_puf`.

_starter script_
```sql
-- Rate summary by age
SELECT age, COUNT(*) AS row_count,
       MIN(individual_rate) AS min_rate,
       MAX(individual_rate) AS max_rate
FROM public.aca_rate_puf
GROUP BY age
ORDER BY age;
```

The plan attributes table has 151 columns. We'll look at which ones matter for analysis and which ones we can ignore for now.

We also introduce the CTE pattern

Discussion: What questions can rate data answer on its own? What questions require plan attributes?

---

## Activity 3 — Attempting a join
Connect rate data to plan attributes. Before joining, look at the join keys in each table.

_starter script_
```sql
-- What does the join key look like in each table?
SELECT DISTINCT plan_id FROM public.aca_rate_puf LIMIT 10;
SELECT DISTINCT standard_component_id FROM public.aca_plan_attributes_puf LIMIT 10;
```

Then attempt the join and compare row counts before and after. Did the count change? Why?

---

*Break: 11:15 – 11:30 AM*

---

## Activity 4 — Detecting and fixing join problems
The join from Activity 3 likely produced more rows than expected. Investigate why and use filters to control it.

Things to try:
- Filter out dental-only plans
- Look at the `csr_variation_type` column — why are there multiple rows per plan?
- Add or remove filters and count rows at each step

This is the core lesson: **joins must respect dataset grain**. If you don't understand the grain of both tables, the join can silently multiply your rows.

---

## Activity 5: Introducing the service area table
Explore `aca_service_area_puf`. The key structural feature is the `cover_entire_state` column.

_starter script_
```sql
-- Statewide vs county-specific: how many of each?
SELECT cover_entire_state, COUNT(*) AS row_count
FROM public.aca_service_area_puf
GROUP BY cover_entire_state;
```

If a row says "covers the entire state," how many counties does it actually represent? For analysis, we need one row per county — which means statewide rows need to be expanded.

---

## Activity 6: demonstration of a useful CTE for county expansion
A CTE (Common Table Expression) lets you organize multi-step logic in a single query. This one solves the statewide expansion problem:

- County-specific rows: keep as-is
- Statewide rows: expand to one row per county using a reference table

The instructor will walk through this pattern. The goal is to understand the structure and purpose of a CTE, not to write one from scratch.

---

## Key takeaways
- **Inspect before you query.** Look at sample rows, count rows, identify keys and grain before writing aggregations or joins.
- **Run, modify, re-run.** SQL scripts are non-destructive. Iterating quickly is the workflow.
- **Validate joins.** Compare row counts before and after. If the count changed unexpectedly, investigate before proceeding.
- **Watch for row explosion.** Joins that don't respect grain can silently multiply rows and corrupt every downstream number.
- **CTEs structure complexity.** When a problem needs multiple steps, CTEs keep the logic readable and testable.

---

## Additional scripts
Full activity scripts will be shared during and after the session.
