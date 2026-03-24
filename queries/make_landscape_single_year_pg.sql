
-- ============================================================
-- Landscape Compare — Single Year (PostgreSQL)
-- Builds landscape_hpa for one business year.
-- Rates are for a 21-year-old.
-- ============================================================


-- ============================================================
-- Parameters: change these before running
-- ============================================================
DROP TABLE IF EXISTS params;
CREATE TEMP TABLE params AS
SELECT
  '2024'  AS business_year,
  'All' AS state_filter;   -- set to a 2-letter state code, or 'All' for all states


-- ============================================================
-- Pre-query: FIPS-to-rating-area lookup
-- Built from the 2026 marketplace API data.
-- Note: uses 2026 boundary data for all years -- see
-- documentation for limitation details.
-- ============================================================
DROP TABLE IF EXISTS fips_ra;
CREATE TEMP TABLE fips_ra AS
SELECT DISTINCT
   t.fips::text AS fips
  ,t.state
  ,t.rate_area
FROM public."county_zip_rating_area_marketplace" AS t;


-- ============================================================
-- Main CTE chain -> current_year
-- ============================================================


-- ============================================================
-- CTE 1: sa_expanded
-- Expands service area definitions to individual county FIPS codes.
-- Two branches united:
--   Partial state coverage: the county FIPS is already stored in
--     the service area row; use it directly.
--   Full state coverage: the issuer covers every county in the
--     state; cross-join to ref_county_fips to get all FIPS codes.
-- Dental-only plans are excluded via the LEFT(dental_only_plan,1)
-- filter. This approach handles carriage-return variants in the
-- source data that break a direct = 'No' comparison.
-- ============================================================
WITH sa_expanded AS (
  SELECT DISTINCT
     sa.business_year
    ,sa.state_code
    ,sa.issuer_id
    ,sa.service_area_id
    ,RIGHT(sa.county, 5) AS county
  FROM public.aca_service_area_puf AS sa
  WHERE (sa.cover_entire_state = 'No' OR sa.cover_entire_state = 'false')
    AND LEFT(sa.dental_only_plan, 1) = 'N'

  UNION

  SELECT DISTINCT
     sa.business_year
    ,sa.state_code
    ,sa.issuer_id
    ,sa.service_area_id
    ,rcf."GEOID" AS county
  FROM public.aca_service_area_puf AS sa
  JOIN public.county_fips_look_up AS rcf
    ON sa.state_code = rcf."USPS"
  WHERE sa.cover_entire_state = 'Yes'
    AND LEFT(sa.dental_only_plan, 1) = 'N'
)
-- inspect:
--  SELECT * FROM sa_expanded WHERE state_code = 'WI' AND business_year::text = (SELECT business_year FROM params)

-- ============================================================
-- CTE 2: summary
-- Core join. Produces one row per plan x county for age 21.
-- Join chain: rates -> plan attributes -> service area ->
--   county-rating-area map.
-- Key filters:
--   age = '21'               rates for a 21-year-old
--   RIGHT(plan_id, 1) = '1'  base plans only (variant suffix)
--   market_coverage           individual market only
-- Derived columns:
--   metal_level   Expanded Bronze normalized to Bronze
--   deductible    COALESCE across multiple source columns,
--                 with '$' and 'per person' stripped
--   OOPM          same pattern as deductible
-- ============================================================
,summary AS (
  SELECT
     r.business_year
    ,r.state_code
    ,r.issuer_id
    ,pl.issuer_market_place_marketing_name
    ,r.plan_id
    ,pl.plan_marketing_name
    ,pl.plan_type
    ,CASE
       WHEN pl.metal_level = 'Expanded Bronze' THEN 'Bronze'
       ELSE pl.metal_level
     END AS metal_level
    ,r.age
    ,r.rating_area_id
    ,r.individual_rate
    ,REPLACE(REPLACE(COALESCE(
       pl.tehb_ded_inn_tier1_individual,
       pl.mehb_ded_inn_tier1_individual,
       pl.tehb_ded_inn_tier1_family_per_person
     ), 'per person', ''), '$', '') AS deductible
    ,REPLACE(REPLACE(COALESCE(
       pl.tehb_inn_tier1_individual_moop,
       pl.tehb_inn_tier1_family_per_person_moop
     ), 'per person', ''), '$', '') AS oopm
    ,cm."FIPS" AS fips
    ,cm."County" AS county
  FROM public.aca_rate_puf AS r
  JOIN public.aca_plan_attributes_puf AS pl
    ON  r.plan_id       = pl.standard_component_id
    AND r.business_year::text = pl.business_year::text
    AND r.state_code    = pl.state_code
    AND r.issuer_id     = pl.issuer_id
  JOIN sa_expanded AS sa
    ON  pl.service_area_id = sa.service_area_id
    AND pl.issuer_id       = sa.issuer_id
    AND pl.business_year::text = sa.business_year::text
    AND pl.state_code      = sa.state_code
  JOIN public.rating_area_county_map AS cm
    ON  LPAD(cm."FIPS"::varchar, 5, '0') = LPAD(sa.county::varchar, 5, '0')
    AND cm."Rating_Area" = r.rating_area_id
  CROSS JOIN params
  WHERE r.age              = '21'
    AND RIGHT(pl.plan_id, 1) = '1'
    AND r.business_year::text  = params.business_year
    AND pl.business_year::text = params.business_year
    AND sa.business_year::text = params.business_year
    AND (pl.state_code = params.state_filter OR params.state_filter = 'All')
    AND pl.market_coverage = 'Individual'
)
-- inspect: SELECT state_code, COUNT(*) AS plan_county_rows FROM summary GROUP BY state_code

-- ============================================================
-- CTE 3: ranking
-- Adds two rankings to every row in summary:
--   metal_rank   rank within (county, metal tier) by rate
--                metal_rank = 1 is the cheapest plan in that
--                tier in that county
--   issuer_rank  rank within (county, metal tier, issuer) by rate
--                issuer_rank = 1 is that issuer's cheapest plan
--                in that tier in that county
-- ============================================================
,ranking AS (
  SELECT
     *
    ,ROW_NUMBER() OVER (
       PARTITION BY county, metal_level, state_code
       ORDER BY individual_rate
     ) AS metal_rank
    ,ROW_NUMBER() OVER (
       PARTITION BY county, metal_level, issuer_market_place_marketing_name, state_code
       ORDER BY individual_rate
     ) AS issuer_rank
  FROM summary
)
-- inspect: SELECT * FROM ranking WHERE county = 'Adams' AND state_code = 'WI' ORDER BY metal_level, metal_rank

-- ============================================================
-- CTE 4: min_metal
-- The cheapest plan per county + metal tier (metal_rank = 1).
-- Columns renamed for clarity: individual_rate -> min_rate,
-- issuer name -> min_issuer. Used in diffs to calculate how far
-- each plan is above the lowest price in its tier.
-- ============================================================
,min_metal AS (
  SELECT
     county
    ,state_code
    ,metal_level
    ,issuer_market_place_marketing_name AS min_issuer
    ,individual_rate                    AS min_rate
  FROM ranking
  WHERE metal_rank = 1
)
-- inspect: SELECT * FROM min_metal WHERE state_code = 'WI' ORDER BY county, metal_level

-- ============================================================
-- CTE 5: slcsp
-- The second-lowest-cost Silver plan per county (metal_rank = 2,
-- Silver only). This is the SLCSP -- the federal benchmark used
-- to set subsidy amounts. Renamed to slcsp_rate for clarity.
-- Used in diffs to show how far each plan sits above the benchmark.
-- ============================================================
,slcsp AS (
  SELECT
     county
    ,state_code
    ,individual_rate AS slcsp_rate
  FROM ranking
  WHERE metal_rank  = 2
    AND metal_level = 'Silver'
)
-- inspect: SELECT * FROM slcsp WHERE state_code = 'WI' ORDER BY county

-- ============================================================
-- CTE 6: diffs
-- Joins benchmark prices onto every ranking row.
--   diff_from_min   how much more this plan costs vs the cheapest
--                   plan in the same tier and county
--   diff_from_slcsp how much more this plan costs vs the SLCSP
--                   in the same county (NULL if no SLCSP exists)
-- min_metal is an INNER JOIN -- every county + metal tier has a
-- cheapest plan by definition.
-- slcsp is a LEFT JOIN -- preserves counties where no SLCSP
-- exists; diff_from_slcsp will be NULL in those cases.
-- ============================================================
,diffs AS (
  SELECT
     r.*
    ,m.min_issuer
    ,r.individual_rate - m.min_rate   AS diff_from_min
    ,r.individual_rate - s.slcsp_rate AS diff_from_slcsp
  FROM ranking AS r
  JOIN min_metal AS m
    ON  r.county      = m.county
    AND r.state_code  = m.state_code
    AND r.metal_level = m.metal_level
  LEFT JOIN slcsp AS s
    ON  r.county     = s.county
    AND r.state_code = s.state_code
)
-- inspect: SELECT * FROM diffs WHERE county = 'Adams' AND state_code = 'WI' ORDER BY metal_level, metal_rank

-- ============================================================
-- CTE 7: overall_rank
-- Takes each issuer's single cheapest plan per county + metal
-- tier (issuer_rank = 1) and ranks issuers against each other.
-- issuer_overall_rank = 1 is the cheapest issuer in that county
-- and metal tier.
-- Sources from ranking (not diffs) to avoid re-executing the
-- full CTE chain -- PostgreSQL does not cache CTEs by default.
-- Enrollment data is only available for FFE states 2021-2024;
-- all other combinations return NULL.
-- ============================================================
,overall_rank AS (
  SELECT
     r.issuer_id
    ,r.fips
    ,r.metal_level
    ,ROW_NUMBER() OVER (
       PARTITION BY r.county, r.metal_level
       ORDER BY r.individual_rate
     ) AS issuer_overall_rank
    ,iep."AverageMonthlyEnrollment" AS issuer_avg_monthly_enrollment
  FROM ranking AS r
  LEFT JOIN public."issuer_level_detailed_enrollment" AS iep
    ON  r.issuer_id      = iep."IssuerHIOSID"
    AND r.business_year::bigint = iep.year
    AND iep."CountyFIPSCode" = r.fips
  WHERE r.issuer_rank = 1
)
-- inspect: SELECT * FROM overall_rank WHERE fips = '55001' ORDER BY metal_level, issuer_overall_rank

-- ============================================================
-- Final SELECT: assemble current_year
-- ============================================================
SELECT
   d.business_year
  ,d.state_code
  ,d.issuer_id
  ,d.issuer_market_place_marketing_name
  ,d.plan_id
  ,d.plan_marketing_name
  ,d.plan_type
  ,d.metal_level
  ,d.individual_rate
  ,d.deductible
  ,d.oopm
  ,d.county
  ,d.fips
  ,d.metal_rank
  ,d.issuer_rank
  ,o.issuer_overall_rank
  ,o.issuer_avg_monthly_enrollment AS issuer_avg_enrollment
  ,f.rate_area                     AS rating_area
  ,pm.company_name
  ,pm."Parent_Name" AS parent_name
  ,d.business_year                 AS year
FROM ranking AS d
JOIN overall_rank AS o
  ON  d.issuer_id   = o.issuer_id
  AND d.fips        = o.fips
  AND d.metal_level = o.metal_level
JOIN fips_ra AS f
  ON  d.fips       = f.fips
  AND d.state_code = f.state
LEFT JOIN public.parent_mapping_2025 AS pm
  ON d.issuer_id = pm.hios_issuer_id;


-- ============================================================
-- Inspect result
-- ============================================================
-- SELECT * FROM current_year WHERE county = 'Adams' AND state_code = 'WI'
-- ORDER BY metal_level, metal_rank, issuer_rank
-- LIMIT 100;


-- ============================================================
-- Uncomment to write to landscape_hpa
-- ============================================================
-- DROP TABLE IF EXISTS public.landscape_hpa;
-- CREATE TABLE public.landscape_hpa AS
-- SELECT * FROM current_year;



