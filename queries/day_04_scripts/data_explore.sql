-- Data Exploration: First look at a new table
-- Replace "public"."t0A" with the actual table name before running.


-- -------------------------------------------------------------------------
-- 1. Sample rows
--    Get eyes on the data before doing anything else.
-- -------------------------------------------------------------------------
SELECT *
FROM "public"."t0A"
LIMIT 20;

-- in the first week we filtered out small group so all exploration should be on
SELECT *
FROM "public"."t0A"
WHERE market_coverage = 'Individual'
LIMIT 20;

-- -------------------------------------------------------------------------
-- 2. Row count
-- -------------------------------------------------------------------------
SELECT TO_CHAR(COUNT(*), 'FM999,999,999,999') AS total_rows
FROM "public"."t0A"
WHERE market_coverage = 'Individual';




-- -------------------------------------------------------------------------
-- 3. Distinct values in key columns
--    Helps you understand cardinality and spot unexpected values early.
-- -------------------------------------------------------------------------
SELECT
     COUNT(DISTINCT business_year)   AS years_count
    ,COUNT(DISTINCT state_code)      AS states_count
    ,COUNT(DISTINCT issuer_id)       AS issuers_count
    ,COUNT(DISTINCT plan_id)         AS plans_count
    ,COUNT(DISTINCT rating_area_id)  AS rating_areas_count
    ,COUNT(DISTINCT metal_level)     AS metal_levels_count
    ,COUNT(DISTINCT age)             AS ages_count
FROM "public"."t0A"
WHERE market_coverage = 'Individual';

-- tall version

SELECT v.metric, v.value
FROM (
    SELECT
         COUNT(DISTINCT business_year)   AS years_count
        ,COUNT(DISTINCT state_code)      AS states_count
        ,COUNT(DISTINCT issuer_id)       AS issuers_count
        ,COUNT(DISTINCT plan_id)         AS plans_count
        ,COUNT(DISTINCT rating_area_id)  AS rating_areas_count
        ,COUNT(DISTINCT metal_level)     AS metal_levels_count
        ,COUNT(DISTINCT age)             AS ages_count
    FROM "public"."t0A"
    WHERE market_coverage = 'Individual'
) t
CROSS JOIN LATERAL (
    VALUES
         ('years_count', t.years_count)
        ,('states_count', t.states_count)
        ,('issuers_count', t.issuers_count)
        ,('plans_count', t.plans_count)
        ,('rating_areas_count', t.rating_areas_count)
        ,('metal_levels_count', t.metal_levels_count)
        ,('ages_count', t.ages_count)
) AS v(metric, value);


-- -------------------------------------------------------------------------
-- 4. Spot-check individual columns
--    Run these one at a time to see what values actually exist.
-- -------------------------------------------------------------------------
SELECT DISTINCT business_year   FROM "public"."t0A" WHERE market_coverage = 'Individual' ORDER BY business_year;
SELECT DISTINCT state_code      FROM "public"."t0A" WHERE market_coverage = 'Individual' ORDER BY state_code;
SELECT DISTINCT metal_level     FROM "public"."t0A" WHERE market_coverage = 'Individual' ORDER BY metal_level;
SELECT DISTINCT age             FROM "public"."t0A" WHERE market_coverage = 'Individual' ORDER BY age;
SELECT DISTINCT tobacco         FROM "public"."t0A" WHERE market_coverage = 'Individual' ORDER BY tobacco;
SELECT DISTINCT csr_variation_type FROM "public"."t0A" WHERE market_coverage = 'Individual' ORDER BY csr_variation_type;




-- -------------------------------------------------------------------------
-- 5. Guess the grain
--    What combination of columns uniquely defines one row?
--    Start with a subset and see how row_counts relate to quantities above
-- -------------------------------------------------------------------------

-- example try
SELECT
     business_year
    ,plan_id
    ,age
    ,tobacco
    ,COUNT(*) AS row_count
FROM "public"."t0A"
WHERE market_coverage = 'Individual'
GROUP BY 
   business_year
  ,plan_id
  ,age
  ,tobacco
ORDER BY row_count DESC -- USE DESC to ensure that highest counts are at the top
LIMIT 20;

-- refinement
-- note we don't have metal level here

SELECT
     business_year
    ,plan_id
    ,rating_area_id
    ,age
    ,tobacco
    ,COUNT(*) AS row_count
FROM "public"."t0A"
WHERE market_coverage = 'Individual'
GROUP BY 
   business_year
  ,plan_id
  ,rating_area_id
  ,age
  ,tobacco
ORDER BY row_count DESC -- USE DESC to ensure that highest counts are at the top
LIMIT 20;

