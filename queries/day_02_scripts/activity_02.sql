-- Activity 2: Summaries and introducing plan attributes

-- PART A: Aggregations on rate_puf

-- Rate summary by age
SELECT
     age
    ,COUNT(*)                        AS row_count
    ,MIN(individual_rate)            AS min_rate
    ,MAX(individual_rate)            AS max_rate
    ,ROUND(AVG(individual_rate), 2)  AS avg_rate
FROM public.aca_rate_puf
GROUP BY age
ORDER BY age;










-- Tobacco: base rate vs tobacco rate
SELECT
     tobacco
    ,COUNT(*)                                AS row_count
    ,ROUND(AVG(individual_rate), 2)          AS avg_individual_rate
    ,ROUND(AVG(individual_tobacco_rate), 2)  AS avg_tobacco_rate
FROM public.aca_rate_puf
GROUP BY tobacco
ORDER BY tobacco;










-- Rate effective date: how many rate periods?
SELECT
     rate_effective_date
    ,COUNT(*)                AS row_count
    ,COUNT(DISTINCT plan_id) AS distinct_plans
FROM public.aca_rate_puf
GROUP BY rate_effective_date
ORDER BY rate_effective_date;










-- PART B: Introduce plan_attributes

-- Sample rows (151 columns total)
SELECT * FROM public.aca_plan_attributes_puf LIMIT 20;

SELECT 
         business_year
    ,state_code
    ,standard_component_id     -- joins to rate_puf.plan_id
    ,plan_id                   -- full variant id (standard + CSR suffix)
    ,service_area_id           -- joins to service_area table
    ,metal_level
    ,plan_type
    ,csr_variation_type
    ,dental_only_plan
    ,plan_marketing_name
FROM public.aca_plan_attributes_puf
WHERE business_year = '2024'
AND  RIGHT(plan_id, 1) = '1';








-- A curated selection of useful columns
SELECT
     business_year
    ,state_code
    ,standard_component_id     -- joins to rate_puf.plan_id
    ,plan_id                   -- full variant id (standard + CSR suffix)
    ,service_area_id           -- joins to service_area table
    ,metal_level
    ,plan_type
    ,csr_variation_type
    ,dental_only_plan
    ,plan_marketing_name
FROM public.aca_plan_attributes_puf
    WHERE state_code = 'MS'
    AND dental_only_plan = 'No'
    AND metal_level = 'Gold'
-- LIMIT 20;










-- Row count and distinct key values
SELECT
     COUNT(DISTINCT state_code)            AS distinct_states
    ,COUNT(DISTINCT standard_component_id) AS distinct_standard_components
    ,COUNT(DISTINCT plan_id)               AS distinct_plan_variants
    ,COUNT(DISTINCT service_area_id)       AS distinct_service_areas
FROM public.aca_plan_attributes_puf;



-- Row count and distinct key values
SELECT
    COUNT(DISTINCT standard_component_id)               AS distinct_plan_variants
FROM public.aca_plan_attributes_puf
WHERE business_year = '2025';
SELECT
    COUNT(DISTINCT plan_id)               AS distinct_plan_variants
FROM public.aca_rate_puf
WHERE business_year = '2025';





-- PART C: Aggregations on plan_attributes

-- Plans by metal level
SELECT metal_level, COUNT(*) AS row_count
FROM public.aca_plan_attributes_puf
-- WHERE dental_only_plan = 'No'
GROUP BY metal_level
ORDER BY metal_level;










-- Plans by plan type
SELECT plan_type, COUNT(*) AS row_count
FROM public.aca_plan_attributes_puf
WHERE business_year = '2025'
AND state_code = 'AL'
GROUP BY plan_type
ORDER BY row_count DESC;


WITH no_dental AS (
    SELECT 
     business_year
    ,state_code
    ,standard_component_id     -- joins to rate_puf.plan_id
    ,plan_id                   -- full variant id (standard + CSR suffix)
    ,service_area_id           -- joins to service_area table
    ,metal_level
    ,plan_type
    ,csr_variation_type
    ,dental_only_plan
    ,plan_marketing_name
    FROM public.aca_plan_attributes_puf
    WHERE dental_only_plan = 'No'
)
SELECT *
FROM no_dental
JOIN public.aca_rate_puf






-- CTE example: clean up metal_level before aggregating
WITH metal_mapped AS (
    SELECT
         state_code
        ,CASE
            WHEN metal_level = 'Expanded Bronze' THEN 'Bronze'
            -- WHEN dental_only_plan = 'Yes' THEN 'Dental'
            ELSE metal_level
        END AS metal_level
    FROM public.aca_plan_attributes_puf
    -- WHERE state_code = 'MS'
    -- AND dental_only_plan = 'No'
)
SELECT
     state_code
    -- ,metal_level
    ,CASE
            WHEN metal_level = 'Expanded Bronze' THEN 'Bronze'
            -- WHEN dental_only_plan = 'Yes' THEN 'Dental'
            ELSE metal_level
        END AS metal_level
    ,COUNT(*) AS row_count
FROM public.aca_plan_attributes_puf
GROUP BY state_code, metal_level
ORDER BY state_code, metal_level;
