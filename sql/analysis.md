# 1. Inspect actual source fields/types

## Question
Inspect the Housing table’s declared schema, including column order, column names, data types and whether NULL values are allowed.

## Solution

```sql
SELECT ordinal_position, column_name, data_type, is_nullable
FROM `project-b9eb342a-20c8-4926-920.1.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'Housing'
ORDER BY ordinal_position;
```

## Output

| ordinal_position | column_name | data_type | is_nullable |
| --- | --- | --- | --- |
| 1 | date | DATE | YES |
| 2 | quarter | STRING | YES |
| 3 | house_id | INT64 | YES |
| 4 | house_type | STRING | YES |
| 5 | sales_type | STRING | YES |
| 6 | year_build | INT64 | YES |
| 7 | purchase_price | INT64 | YES |
| 8 | %_change_between_offer_and_purchase | INT64 | YES |
| 9 | no_rooms | INT64 | YES |
| 10 | sqm | INT64 | YES |
| 11 | sqm_price | FLOAT64 | YES |
| 12 | address | STRING | YES |
| 13 | zip_code | INT64 | YES |
| 14 | city | STRING | YES |
| 15 | area | STRING | YES |
| 16 | region | STRING | YES |
| 17 | nom_interest_rate% | FLOAT64 | YES |
| 18 | dk_ann_infl_rate% | FLOAT64 | YES |
| 19 | yield_on_mortgage_credit_bonds% | FLOAT64 | YES |

## Answer

The Housing table contains 19 columns. The sale date is stored as DATE, categorical fields as STRING, and numeric fields as INT64 or FLOAT64.

All 19 columns allow NULL values. This describes the schema’s rules; it does not mean every column currently contains missing values. Actual missing-value counts are checked in Q02.

---

# 2. Profile data quality and identify potential issues

## Question
Check row counts, house-ID uniqueness, date coverage, missing values, empty city values, construction years later than sale years, and NULL or non-positive purchase prices and property areas.

## Solution

```sql
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
```

## Output

| total_rows | unique_house_ids | missing_house_ids | repeated_nonnull_id_rows | earliest_sale_date | latest_sale_date | missing_dates | city_nulls | city_empty_strings | region_nulls | inflation_nulls | mortgage_yield_nulls | missing_build_years | construction_after_sale | invalid_purchase_prices | invalid_property_areas |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 100000 | 100000 | 0 | 0 | 1992-01-05 | 2024-10-24 | 0 | 11 | 0 | 0 | 77 | 77 | 0 | 6505 | 0 | 0 |

## Answer

- The dataset contains 100,000 rows and 100,000 unique house IDs, with no missing or repeated house IDs.
- Sale dates range from 1992-01-05 to 2024-10-24, with no missing dates. Therefore, 2024 has incomplete annual coverage.
- There are 11 NULL city values, but no empty or whitespace-only city values. Region and construction year have no NULL values.
- Inflation and mortgage bond yield each contain 77 NULL values.
- There are 6,505 records where the construction year is later than the sale year. These require investigation rather than automatic deletion.
- Purchase price and property area contain no NULL, zero or negative values. This confirms these specific checks passed, but does not establish that every value is realistic.

---

# 3. Inspect repeated house IDs

## Question
Identify non-NULL house IDs that appear more than once and report their occurrence counts.

## Solution

```sql
SELECT house_id, COUNT(*) AS row_count
FROM `project-b9eb342a-20c8-4926-920.1.Housing`
WHERE house_id IS NOT NULL
GROUP BY house_id
HAVING COUNT(*) > 1;
```

## Output

There is no data to display.

## Answer

No repeated non-NULL house IDs were found in the dataset. Therefore, no ID-based deduplication was needed.

---

# 4. Locate missing economic values by month

## Question
Group transactions by sale month and identify months containing missing inflation or mortgage bond yield values. Show each affected month’s total transaction count and the missing-value count for each indicator.

## Solution

```sql
SELECT
  DATE_TRUNC(`date`, MONTH) AS sale_month,
  COUNT(*) AS transaction_count,
  COUNTIF(`dk_ann_infl_rate%` IS NULL) AS inflation_nulls,
  COUNTIF(`yield_on_mortgage_credit_bonds%` IS NULL) AS mortgage_yield_nulls
FROM `project-b9eb342a-20c8-4926-920.1.Housing`
GROUP BY sale_month
HAVING inflation_nulls > 0 OR mortgage_yield_nulls > 0
ORDER BY sale_month;

```

## Output

| sale_month | transaction_count | inflation_nulls | mortgage_yield_nulls |
| --- | --- | --- | --- |
| 2024-10-01 | 77 | 77 | 77 |

## Answer

All 77 transactions recorded in October 2024 have NULL values for both inflation and mortgage bond yield. These are the same 77 affected transactions, not 154 separate transactions.

No other months contain NULL values for these two indicators, consistent with the dataset-wide counts from Q02.

The output date 2024-10-01 represents October 2024 as a monthly group, not the individual transaction dates.

---

# 5. Inspect construction-after-sale examples

## Question
Inspect records where the construction year is later than the sale year. Display 15 examples with the most negative calculated property ages, using house ID in ascending order to break ties.

## Solution

```sql
SELECT
  house_id, `date` AS sale_date, year_build,
  EXTRACT(YEAR FROM `date`) - year_build AS unadjusted_age_at_sale,
  house_type, region, purchase_price
FROM `project-b9eb342a-20c8-4926-920.1.Housing`
WHERE year_build > EXTRACT(YEAR FROM `date`)
ORDER BY unadjusted_age_at_sale, house_id
LIMIT 15;
```

## Output

| house_id | sale_date | year_build | unadjusted_age_at_sale | house_type | region | purchase_price |
| --- | --- | --- | --- | --- | --- | --- |
| 1500289 | 1992-04-12 | 2023 | -31 | Villa | Zealand | 638000 |
| 1494641 | 1992-08-03 | 2022 | -30 | Villa | Zealand | 1250000 |
| 1452461 | 1994-11-09 | 2023 | -29 | Apartment | Jutland | 7300000 |
| 1452479 | 1994-11-09 | 2023 | -29 | Apartment | Jutland | 7300000 |
| 1452507 | 1994-11-09 | 2023 | -29 | Apartment | Jutland | 7300000 |
| 1505762 | 1992-01-08 | 2021 | -29 | Townhouse | Jutland | 860000 |
| 1442967 | 1995-03-27 | 2023 | -28 | Villa | Fyn & islands | 871000 |
| 1454470 | 1994-10-04 | 2022 | -28 | Townhouse | Zealand | 2500000 |
| 1459611 | 1994-06-30 | 2022 | -28 | Villa | Zealand | 1103320 |
| 1438619 | 1995-06-04 | 2022 | -27 | Villa | Zealand | 784070 |
| 1489784 | 1992-11-26 | 2019 | -27 | Summerhouse | Jutland | 885000 |
| 1491811 | 1992-10-05 | 2019 | -27 | Villa | Fyn & islands | 289327 |
| 1382608 | 1997-09-24 | 2023 | -26 | Apartment | Jutland | 1600000 |
| 1414859 | 1996-06-18 | 2022 | -26 | Villa | Jutland | 740000 |
| 1422074 | 1996-03-05 | 2022 | -26 | Villa | Fyn & islands | 1850000 |

## Answer

Q02 identified 6,505 records where the construction year is later than the sale year, resulting in a negative calculated property age.

The 15 selected examples have calculated ages ranging from −31 to −26 years. These substantial year gaps require source verification; the query alone cannot establish their cause.

The transactions are retained. In the Power BI report, negative property ages are treated as blank rather than converted into positive ages using ABS.

---

# 6. Preview agreed reporting treatment without modifying source

## Question
Preview the agreed reporting treatment: replace NULL city values with “Unknown” and set missing or negative property ages to NULL, while preserving missing economic values.

Display up to 15 records where the city is “Unknown” or the property age has an issue flag, without modifying the original source table.

## Solution

```sql
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
```

## Output

| house_id | date | house_type | purchase_price | sqm | region | city | year_build | age_at_sale | age_quality_flag | dk_ann_infl_rate% | yield_on_mortgage_credit_bonds% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 81764 | 2023-07-31 | Villa | 850000 | 185 | Jutland | Horsens | 2024 | NULL | Construction after sale - review | 3.31 | 4.79 |
| 93214 | 2023-06-22 | Villa | 1030000 | 130 | Jutland | Hedensted | 2024 | NULL | Construction after sale - review | 3.31 | 4.79 |
| 94600 | 2023-06-18 | Townhouse | 2670000 | 153 | Jutland | Herning | 2024 | NULL | Construction after sale - review | 3.31 | 4.79 |
| 95501 | 2023-06-14 | Villa | 1200000 | 210 | Jutland | Horsens | 2024 | NULL | Construction after sale - review | 3.31 | 4.79 |
| 96847 | 2023-06-08 | Villa | 1700000 | 63 | Jutland | Unknown | 1979 | 44 | Usable age | 3.31 | 4.79 |
| 120519 | 2023-02-28 | Townhouse | 2345000 | 121 | Jutland | Herning | 2024 | NULL | Construction after sale - review | 3.31 | 4.79 |
| 132922 | 2022-12-21 | Villa | 1066000 | 180 | Jutland | StÃ¸vring | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |
| 133729 | 2022-12-18 | Apartment | 3881360 | 76 | Zealand | GrÃ¦sted | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |
| 134336 | 2022-12-14 | Townhouse | 2500000 | 91 | Jutland | VrÃ¥ | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |
| 136296 | 2022-12-04 | Villa | 1100000 | 243 | Jutland | Odder | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |
| 136300 | 2022-12-04 | Villa | 776505 | 189 | Fyn & islands | Morud | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |
| 136853 | 2022-11-30 | Summerhouse | 637500 | 65 | Jutland | SamsÃ¸ | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |
| 137183 | 2022-11-28 | Villa | 2900000 | 181 | Zealand | Glostrup | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |
| 138200 | 2022-11-22 | Villa | 750000 | 164 | Jutland | Horsens | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |
| 138777 | 2022-11-18 | Townhouse | 2145000 | 110 | Jutland | Aabybro | 2023 | NULL | Construction after sale - review | 7.7 | 3.73 |

## Answer

The read-only preview displays 15 flagged records, ordered by house ID.

- In 14 records, the construction year is later than the sale year. Their calculated property ages are set to NULL and labelled “Construction after sale - review”.
- House ID 96847 has its missing city replaced with “Unknown”. Its property age remains 44 and its age status is “Usable age”. It appears because the filter includes records with either an unknown city or an age-related issue.
- Economic indicator values are passed through unchanged. This displayed sample contains no NULL economic values; existing NULLs elsewhere remain NULL.

The original source table is not modified.

---

# 7. Calculate headline KPIs for report validation

## Question
Using the dataset’s latest sale date as a common cutoff, calculate total transactions, all-time sales value, distinct houses sold in the latest quarter, trailing-12-month sales and current-year-to-date sales.

Use these results as benchmarks for checking the corresponding Power BI calculations under matching filters and date windows.

## Solution

```sql
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
```

## Output

| as_of_date | total_transactions | total_sales_value | units_latest_quarter_to_cutoff | trailing_12_month_sales | current_year_to_cutoff_sales |
| --- | --- | --- | --- | --- | --- |
| 2024-10-24 | 100000 | 192599220051 | 77 | 13647671532 | 10552248210 |

## Answer

- Cutoff: 24 October 2024.
- Latest quarter: 1–24 October 2024.
- Trailing 12 months: 25 October 2023–24 October 2024.
- YTD: 1 January–24 October 2024.

The latest-quarter figure covers only the available portion of Q4 2024, not a complete quarter.

These figures provide SQL benchmarks for report validation. A successful reconciliation requires comparing them with the corresponding Power BI values using the same filters and date boundaries.

---

# 8. Compare matched and unmatched YoY periods

## Question
Calculate sales for the current year through the latest available date, the equivalent period in the previous year, and the entire previous year.

Compare the percentage change produced by matched periods with the change produced by comparing the current partial year against the previous full year.

## Solution

```sql
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
```

## Output

| as_of_date | current_ytd_sales | prior_matched_ytd_sales | prior_full_year_sales | matched_period_yoy_pct | unmatched_period_change_pct |
| --- | --- | --- | --- | --- | --- |
| 2024-10-24 | 10552248210 | 10827236133 | 13922659455 | -2.5398 | -24.2081 |

## Answer

The sales totals are:

| Period | Sales value |
| --- | --- | 
| 1 January–24 October 2024 | 10,552,248,210 |
| 1 January–24 October 2023 | 10,827,236,133 |
| Full calendar year 2023 | 13,922,659,455 |

Comparing equivalent year-to-date periods produces a sales-value decline of 2.5398%.

Comparing partial 2024 against full-year 2023 produces a decline of 24.2081%. This comparison includes additional months in the previous-year denominator and therefore does not represent equivalent-period YoY growth.

The matched-period comparison is appropriate for the report’s YTD growth measure.

---

# 9. Compare regional totals, shares and price/SQM definitions

## Question
Across the entire dataset, calculate each region’s transaction count, total sales value, percentage share of overall sales value, average transaction-level price per square metre and area-weighted price per square metre.

Compare the regional results and explain the difference between the two price-per-square-metre calculations.

## Solution

```sql
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
```

## Output

| region | transaction_count | total_sales_value | mean_transaction_price_per_sqm | area_weighted_price_per_sqm | sales_share_pct |
| --- | --- | --- | --- | --- | --- |
| Zealand | 39740 | 94965864139 | 20854.76 | 19593.95 | 49.31 |
| Jutland | 49937 | 81478087433 | 13507.23 | 12082.94 | 42.3 |
| Fyn & islands | 9264 | 14917702973 | 13618.19 | 12236.37 | 7.75 |
| Bornholm | 1059 | 1237565506 | 10601.9 | 9539.62 | 0.64 |

## Answer

- Zealand has the highest total sales value, at 94,965,864,139, representing 49.31% of overall sales value.
- Jutland has the most transactions, at 49,937, but contributes a smaller sales-value share of 42.30%.
- Fyn & islands and Bornholm contribute 7.75% and 0.64% of sales value respectively.
- Zealand also has the highest average transaction-level price per square metre, at 20,854.76.

The two price-per-square-metre measures use different weighting:

- AVG(sqm_price) gives every transaction equal weight.
- SUM(purchase_price) / SUM(sqm) weights the result by property area.

These measures answer different questions, so their values need not match. The Power BI “Average Price SQM” measure uses the first definition.

The results describe the full historical dataset, rather than only the latest year. Price-per-square-metre figures in the output are rounded to two decimals for display.

---

# 10. Rank house types within each region

## Question
For sales recorded from 1 January to 24 October 2024, identify the two highest-ranked house types in each region based on average purchase price per square metre.

Include only region–house-type groups with at least 30 transactions. Display the region, house type, transaction count, average price per square metre and rank. Include ties at the selected ranks.

## Solution

```sql
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
```

## Output

| region | house_type | transaction_count | avg_price_per_sqm | price_rank |
| --- | --- | --- | --- | --- |
| Fyn & islands | Apartment | 38 | 23663.16 | 1 |
| Fyn & islands | Summerhouse | 32 | 23465.73 | 2 |
| Jutland | Apartment | 274 | 28905.57 | 1 |
| Jutland | Summerhouse | 250 | 20844.83 | 2 |
| Zealand | Apartment | 569 | 41374.37 | 1 |
| Zealand | Townhouse | 236 | 30040.22 | 2 |

## Answer

Apartments rank first by average price per square metre in all three regions with eligible groups.

| Region | First-ranked house type | Second-ranked house type |
| --- | --- | --- |
| Fyn & islands | Apartment — 23,663.16 | Summerhouse — 23,465.73 |
| Jutland | Apartment — 28,905.57 | Summerhouse — 20,844.83 |
| Zealand | Apartment — 41,374.37 | Townhouse — 30,040.22 |

Bornholm is excluded because none of its house-type groups reaches the minimum of 30 transactions during the selected period. Its largest group, Villa, has 25 transactions.

The rankings apply only to eligible groups within each region. The 30-transaction threshold is a chosen reporting rule to exclude very small groups, not a guarantee of statistical reliability.

The query retains ties using DENSE_RANK. There are no ties at the selected ranks in this result, so six rows are returned.

---