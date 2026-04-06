-- Activity 1: Orient to a new table (aca_rate_puf)

-- Sample rows
SELECT * 
FROM public.aca_rate_puf 
LIMIT 20;







-- Total row count
SELECT COUNT(*) AS total_rows
FROM public.aca_rate_puf;
-- Total row count
SELECT TO_CHAR(COUNT(*), 'FM999,999,999,999') AS total_rows
FROM public.aca_rate_puf;










-- Count distinct values in key columns
SELECT
    COUNT(DISTINCT business_year)    AS distinct_years
    ,COUNT(DISTINCT state_code)      AS distinct_states
    ,COUNT(DISTINCT plan_id)         AS distinct_plans
    ,COUNT(DISTINCT issuer_id)       AS distinct_issuers
    ,COUNT(DISTINCT rating_area_id)  AS distinct_rating_areas
    ,COUNT(DISTINCT age)             AS distinct_ages
FROM public.aca_rate_puf;



SELECT *
FROM federal_age_curve






-- Look at individual column values
SELECT DISTINCT business_year FROM public.aca_rate_puf;










SELECT DISTINCT age FROM public.aca_rate_puf;


SELECT DISTINCT rate_effective_date 
FROM public.aca_rate_puf;

SELECT DISTINCT rate_effective_date ,version_number
FROM public.aca_rate_puf
WHERE business_year = '2024';


aca_plan_attributes_puf







-- First guess at grain: do these columns uniquely define a row?
SELECT
    business_year
    ,plan_id
    ,rating_area_id
    ,age
    ,COUNT(*) AS row_count
FROM public.aca_rate_puf
GROUP BY business_year, plan_id, rating_area_id, age
ORDER BY row_count ASC
LIMIT 20;










-- Second guess: add rate_effective_date
SELECT
    business_year
    ,rate_effective_date
    ,plan_id
    ,rating_area_id
    ,age
    ,COUNT(*) AS row_count
FROM public.aca_rate_puf
GROUP BY business_year, rate_effective_date, plan_id, rating_area_id, age
ORDER BY row_count DESC
LIMIT 20;
