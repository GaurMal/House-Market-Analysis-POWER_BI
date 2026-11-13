-- Housing market analysis | BigQuery GoogleSQL
-- Run the numbered statements separately. All statements are read-only.
-- Replace project-b9eb342a-20c8-4926-920.1 with your project and dataset.

-- Q01: Inspect actual source fields/types
SELECT ordinal_position, column_name, data_type, is_nullable
FROM `project-b9eb342a-20c8-4926-920.1.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'Housing'
ORDER BY ordinal_position;

-- Q02: Profile data quality and identify potential issues
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT house_id) AS unique_house_ids,
  COUNTIF(house_id IS NULL) AS missing_house_ids,
  COUNT(house_id) - COUNT(DISTINCT house_id) AS repeated_nonnull_id_rows,
  MIN(`date`) AS earliest_sale_date,
  MAX(`date`) AS latest_sale_date,
  COUNTIF(`date` IS NULL) AS missing_dates,
  COUNTIF(city IS NULL) AS city_nulls,
  COUNTIF(city IS NOT NULL AND TRIM(city) = '') AS city_empty_strings,
  COUNTIF(region IS NULL) AS region_nulls,
  COUNTIF(`dk_ann_infl_rate%` IS NULL) AS inflation_nulls,
  COUNTIF(`yield_on_mortgage_credit_bonds%` IS NULL) AS mortgage_yield_nulls,
  COUNTIF(year_build IS NULL) AS missing_build_years,
  COUNTIF(year_build > EXTRACT(YEAR FROM `date`)) AS construction_after_sale,
  COUNTIF(purchase_price IS NULL OR purchase_price <= 0) AS invalid_purchase_prices,
  COUNTIF(sqm IS NULL OR sqm <= 0) AS invalid_property_areas
FROM `project-b9eb342a-20c8-4926-920.1.Housing`;

-- Q03: Inspect repeated house IDs
SELECT house_id, COUNT(*) AS row_count
FROM `project-b9eb342a-20c8-4926-920.1.Housing`
WHERE house_id IS NOT NULL
GROUP BY house_id
HAVING COUNT(*) > 1;

-- Q04: Locate missing economic values by month
SELECT
  DATE_TRUNC(`date`, MONTH) AS sale_month,
  COUNT(*) AS transaction_count,
  COUNTIF(`dk_ann_infl_rate%` IS NULL) AS inflation_nulls,
  COUNTIF(`yield_on_mortgage_credit_bonds%` IS NULL) AS mortgage_yield_nulls
FROM `project-b9eb342a-20c8-4926-920.1.Housing`
GROUP BY sale_month
HAVING inflation_nulls > 0 OR mortgage_yield_nulls > 0
ORDER BY sale_month;

-- Q05: Inspect construction-after-sale examples
SELECT
  house_id, `date` AS sale_date, year_build,
  EXTRACT(YEAR FROM `date`) - year_build AS unadjusted_age_at_sale,
  house_type, region, purchase_price
FROM `project-b9eb342a-20c8-4926-920.1.Housing`
WHERE year_build > EXTRACT(YEAR FROM `date`)
ORDER BY unadjusted_age_at_sale, house_id
LIMIT 15;

-- Q06: Preview agreed reporting treatment without modifying source
WITH reporting_preview AS (
  SELECT
    house_id, `date`, house_type, purchase_price, sqm, region,
    COALESCE(city, 'Unknown') AS city,
    year_build,
    CASE
      WHEN `date` IS NULL OR year_build IS NULL THEN NULL
      WHEN year_build > EXTRACT(YEAR FROM `date`) THEN NULL
      ELSE EXTRACT(YEAR FROM `date`) - year_build
    END AS age_at_sale,
    CASE
      WHEN `date` IS NULL OR year_build IS NULL THEN 'Missing age input'
      WHEN year_build > EXTRACT(YEAR FROM `date`) THEN 'Construction after sale - review'
      ELSE 'Usable age'
    END AS age_quality_flag,
    `dk_ann_infl_rate%`, `yield_on_mortgage_credit_bonds%`
  FROM `project-b9eb342a-20c8-4926-920.1.Housing`
)
SELECT *
FROM reporting_preview
WHERE city = 'Unknown' OR age_quality_flag != 'Usable age'
ORDER BY house_id
LIMIT 15;

-- Q07: Calculate headline KPIs for report validation
WITH bounds AS (
  SELECT MAX(`date`) AS as_of_date
  FROM `project-b9eb342a-20c8-4926-920.1.Housing`
)
SELECT
  b.as_of_date,
  COUNT(*) AS total_transactions,
  SUM(h.purchase_price) AS total_sales_value,
  COUNT(DISTINCT IF(
    DATE_TRUNC(h.`date`, QUARTER) = DATE_TRUNC(b.as_of_date, QUARTER),
    h.house_id, NULL
  )) AS units_latest_quarter_to_cutoff,
  SUM(IF(
    h.`date` > DATE_SUB(b.as_of_date, INTERVAL 12 MONTH)
    AND h.`date` <= b.as_of_date,
    h.purchase_price, 0
  )) AS trailing_12_month_sales,
  SUM(IF(
    h.`date` BETWEEN DATE_TRUNC(b.as_of_date, YEAR) AND b.as_of_date,
    h.purchase_price, 0
  )) AS current_year_to_cutoff_sales
FROM `project-b9eb342a-20c8-4926-920.1.Housing` AS h
CROSS JOIN bounds AS b
GROUP BY b.as_of_date;

-- Q08: Compare matched and unmatched YoY periods
WITH bounds AS (
  SELECT MAX(`date`) AS as_of_date
  FROM `project-b9eb342a-20c8-4926-920.1.Housing`
), totals AS (
  SELECT
    b.as_of_date,
    SUM(IF(
      h.`date` BETWEEN DATE_TRUNC(b.as_of_date, YEAR) AND b.as_of_date,
      h.purchase_price, 0
    )) AS current_ytd_sales,
    SUM(IF(
      h.`date` BETWEEN DATE_SUB(DATE_TRUNC(b.as_of_date, YEAR), INTERVAL 1 YEAR)
                  AND DATE_SUB(b.as_of_date, INTERVAL 1 YEAR),
      h.purchase_price, 0
    )) AS prior_matched_ytd_sales,
    SUM(IF(
      EXTRACT(YEAR FROM h.`date`) = EXTRACT(YEAR FROM b.as_of_date) - 1,
      h.purchase_price, 0
    )) AS prior_full_year_sales
  FROM `project-b9eb342a-20c8-4926-920.1.Housing` AS h
  CROSS JOIN bounds AS b
  GROUP BY b.as_of_date
)
SELECT
  *,
  ROUND(100 * SAFE_DIVIDE(
    current_ytd_sales - prior_matched_ytd_sales, prior_matched_ytd_sales
  ), 4) AS matched_period_yoy_pct,
  ROUND(100 * SAFE_DIVIDE(
    current_ytd_sales - prior_full_year_sales, prior_full_year_sales
  ), 4) AS unmatched_period_change_pct
FROM totals;

-- Q09: Compare regional totals, shares and price/SQM definitions
WITH region_summary AS (
  SELECT
    COALESCE(region, 'Unknown') AS region,
    COUNT(*) AS transaction_count,
    SUM(purchase_price) AS total_sales_value,
    AVG(sqm_price) AS mean_transaction_price_per_sqm,
    SAFE_DIVIDE(SUM(purchase_price), SUM(sqm)) AS area_weighted_price_per_sqm
  FROM `project-b9eb342a-20c8-4926-920.1.Housing`
  GROUP BY region
)
SELECT
  *,
  ROUND(100 * SAFE_DIVIDE(total_sales_value, SUM(total_sales_value) OVER()), 2)
    AS sales_share_pct
FROM region_summary
ORDER BY total_sales_value DESC;

-- Q10: Rank house types within each region
WITH house_type_summary AS (
    SELECT
        region,
        house_type,
        COUNT(*) AS transaction_count,
        AVG(sqm_price) AS avg_price_per_sqm
    FROM `project-b9eb342a-20c8-4926-920.1.Housing`
    WHERE `date` BETWEEN DATE '2024-01-01' AND DATE '2024-10-24'
    GROUP BY region, house_type
    HAVING COUNT(*) >= 30
),

ranked_house_types AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY region
            ORDER BY avg_price_per_sqm DESC
        ) AS price_rank
    FROM house_type_summary
)

SELECT
    region,
    house_type,
    transaction_count,
    ROUND(avg_price_per_sqm, 2) AS avg_price_per_sqm,
    price_rank
FROM ranked_house_types
WHERE price_rank <= 2
ORDER BY region, price_rank, house_type;

