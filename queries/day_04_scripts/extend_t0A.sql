-- Once we have a sense of the data, we can do create some of the pivot table structures we did in excel
-- by returning a value on each row.


-- 1. Min individual rate within rating area + metal level
--    recreating the minimum rate column from excel: =MINIFS([individual_rate],[rating_area_id],[@rating_area_id],[metal_level],[@metal_level])
--
--    PARTITION BY defines the "criteria" like
-- filters in excel so that the min of that subset is identified
SELECT
     *
    ,MIN(individual_rate) OVER (
        PARTITION BY rating_area_id, metal_level
    ) AS min_rate_area_metal
FROM "public"."t0A"
WHERE market_coverage = 'Individual';


-- 1a adding is_min flag. Rather than using min_rate_area_metal
-- we use the RANK() function 
    ,MIN(individual_rate) OVER (
        PARTITION BY rating_area_id, metal_level
    ) AS min_rate_area_metal
    -- is_min: 1 if this row is at the minimum rate for its rating area + metal level.

    ,CASE WHEN RANK() OVER (
        PARTITION BY rating_area_id, metal_level
        ORDER BY individual_rate ASC
    ) = 1 THEN 1 ELSE 0 END AS is_min
FROM "public"."t0A"
WHERE market_coverage = 'Individual';






-- 1b. Adding is_slcsp: the Second Lowest Cost Silver Plan
--     SLCSP is defined as rank 2 within Silver plans for a rating area.
--     It is used as the ACA benchmark rate for premium tax credit calculations.
SELECT
     *
    ,MIN(individual_rate) OVER (
        PARTITION BY rating_area_id, metal_level
    ) AS min_rate_area_metal
    ,CASE WHEN RANK() OVER (
        PARTITION BY rating_area_id, metal_level
        ORDER BY individual_rate ASC
    ) = 1 THEN 1 ELSE 0 END AS is_min
    ,CASE WHEN RANK() OVER (
        PARTITION BY rating_area_id, metal_level
        ORDER BY individual_rate ASC
    ) = 2 AND metal_level = 'Silver' THEN 1 ELSE 0 END AS is_slcsp
FROM "public"."t0A"
WHERE market_coverage = 'Individual'

-- -------------------------------------------------------------------------
-- 2. Pivot: min individual rate by rating area × metal level
--    Rows = rating_area_id, Columns = metal level, Values = MIN(individual_rate)
--
--    PostgreSQL has no native PIVOT, so we use conditional aggregation:
--    each column is a MIN() that only "sees" rows matching that metal level.
--    This is equivalent to the Excel pivot table shown.
-- -------------------------------------------------------------------------
SELECT
     rating_area_id
    ,MIN(individual_rate) FILTER (WHERE metal_level = 'Catastrophic') AS catastrophic
    ,MIN(individual_rate) FILTER (WHERE metal_level = 'Bronze')       AS bronze
    ,MIN(individual_rate) FILTER (WHERE metal_level = 'Silver')       AS silver
    ,MIN(individual_rate) FILTER (WHERE metal_level = 'Gold')         AS gold
    -- ,MIN(individual_rate) FILTER (WHERE metal_level = 'Platinum')     AS platinum
FROM "public"."t0A"
WHERE market_coverage = 'Individual'
GROUP BY rating_area_id
ORDER BY SPLIT_PART(rating_area_id, ' ', 3)::INT;




-- -------------------------------------------------------------------------
-- 3. Pivot: count of issuer appearances at the minimum rate
--    by issuer × metal level, filtered to is_min rows only
--
--    The CTE adds the min_rate_area_metal column from section 1.
--    We then keep only rows where the plan is AT the minimum for its
--    rating area + metal level (is_min), then pivot count by metal level.
-- -------------------------------------------------------------------------
WITH with_min AS (
    SELECT
         issuer_id
        ,metal_level
        ,individual_rate
        ,RANK() OVER (
            PARTITION BY rating_area_id, metal_level
            ORDER BY individual_rate ASC
        ) AS is_min
    FROM "public"."t0A"
    WHERE market_coverage = 'Individual'
)
-- SELECT *
-- FROM with_min
-- WHERE is_min = 1

SELECT
     issuer_id
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Bronze')       AS bronze
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Silver')       AS silver
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Gold')         AS gold
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Platinum')     AS platinum
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Catastrophic') AS catastrophic
FROM with_min
WHERE is_min = 1
GROUP BY issuer_id
ORDER BY issuer_id;




-- -------------------------------------------------------------------------
-- 3a. Same as section 3 with a grand total column per issuer
--     COUNT(*) across all metal levels = Excel "Grand Total" column
-- -------------------------------------------------------------------------
WITH with_min AS (
    SELECT
         issuer_id
        ,metal_level
        ,individual_rate
        ,RANK() OVER (
            PARTITION BY rating_area_id, metal_level
            ORDER BY individual_rate ASC
        ) AS is_min
    FROM "public"."t0A"
    WHERE market_coverage = 'Individual'
)
SELECT
     issuer_id
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Bronze')       AS bronze
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Silver')       AS silver
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Gold')         AS gold
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Platinum')     AS platinum
    ,COUNT(issuer_id) FILTER (WHERE metal_level = 'Catastrophic') AS catastrophic
    ,COUNT(issuer_id)                                             AS grand_total
FROM with_min
WHERE is_min = 1
GROUP BY issuer_id
ORDER BY issuer_id;


