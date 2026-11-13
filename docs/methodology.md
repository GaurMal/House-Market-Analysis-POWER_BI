# Methodology and interpretation

## Source and scope

The course-provided Housing dataset has 100,000 rows and 19 source columns. Each non-NULL house ID appears once in this extract. The data covers 5 January 1992 through 24 October 2024; this does not establish that the extract represents every transaction in the market.

The original Housing CSV is included at [data/Housing.csv](../data/Housing.csv), and the PBIX also contains imported data. Column names and BigQuery types are documented in SQL Q01. Source CSV dates use `MM/DD/YYYY`; parse them accordingly when importing into BigQuery.

The source definitions do not establish a verified currency or the provenance of every field. Amounts in the SQL outputs are therefore described in source monetary units.

## Data-quality decisions

| Issue | Evidence | Treatment |
| --- | --- | --- |
| Missing city | 11 NULLs; no empty/whitespace-only values | `Unknown` in Power Query; `COALESCE` preview in SQL Q06 |
| Missing economic indicators | 77 NULL inflation values and 77 NULL mortgage-yield values, on the same October 2024 rows | Preserve missing values; do not invent a replacement |
| Construction after sale | 6,505 rows; inspected examples include gaps of up to 31 years | Retain transactions; blank negative property age for age analysis; investigate source meaning |
| Repeated house IDs | None in this extract | No ID-based deduplication |
| Invalid price or area | No NULL, zero or negative values in these fields | Checks pass; this does not prove all positive values are realistic |
| Encoding anomalies | Examples include strings such as `StÃ¸vring` and `GrÃ¦sted` | Retain source text pending verified spellings; do not convert these into `Unknown` |

The SQL queries are read-only. Q06 applies expressions to its result set and does not update the BigQuery source. In the current report, missing cities are treated in Power Query and negative age is handled in a DAX calculated column.

## Time windows and KPI validation

SQL Q07 uses the maximum source date, **24 October 2024**, as its common cutoff:

| Metric | Date window | SQL benchmark |
| --- | --- | ---: |
| All-time transactions | Entire extract | 100,000 |
| All-time sales value | Entire extract | 192,599,220,051 |
| Latest-quarter units | 1–24 October 2024 | 77 |
| Trailing 12-month sales | 25 October 2023–24 October 2024 | 13,647,671,532 |
| Current YTD sales | 1 January–24 October 2024 | 10,552,248,210 |

Q08 compares current YTD with **1 January–24 October 2023**, yielding −2.5398% sales-value growth. The latest-quarter result is only the available portion of Q4.

These SQL results are validation benchmarks, not a claim that every Power BI measure has been reconciled under every slicer combination. The YTD growth measures use a global `Data As Of`; the rolling-sales and latest-quarter measures use the maximum date in their current filter context. A filtered segment can therefore have a different latest date. The report uses an automatic date hierarchy rather than an explicit Date dimension.

## Price per square metre

- `AVG(sqm_price)` gives each transaction equal weight.
- `SUM(purchase_price) / SUM(sqm)` is the aggregate price per square metre, weighted by property area.

SQL Q09 reports both definitions. Power BI's `Average Price SQM` uses the first. They are not interchangeable, and regional averages should not be represented as shares of a total.

Q10 ranks house types within each region for the 2024 YTD period. Groups need at least 30 transactions, an explicit reporting threshold rather than a statistical guarantee. `DENSE_RANK` retains ties. Bornholm has no eligible group, so it does not appear in that ranking.

## Offer-price assumption

The course formula is retained:

```text
offer_price = 100 × purchase_price / (100 − change_pct)
```

This assumes positive `change_pct` means a discount relative to the offer. If the source instead defines signed change as `(purchase − offer) / offer × 100`, the denominator would be `100 + change_pct`. The available definition does not resolve this sign convention, so no verified discount or negotiation claim is made.

Offer price is derived from purchase price and a percentage field. Their close relationship in a scatter plot is not independent evidence of market efficiency.

## Descriptive interpretation

- Property age is approximate age at sale, not buyer age. Calendar-year subtraction does not calculate an exact anniversary-based age.
- Key Influencers shows associations within the filtered dataset; it does not establish causation.
- Economic indicators averaged by house type reflect the mix of transaction dates and repeated observations. House type does not cause different inflation or interest rates.
- Text-encoding anomalies remain unresolved. Repair requires checking the intended Danish spelling against a reliable source.

## Validation performed

The ten statements were checked as GoogleSQL syntax. Q02–Q10 were also independently recalculated against the supplied source CSV in a local SQL engine, with the results compared to the documented outputs. Q01 records the schema obtained from BigQuery. This validation did not execute the Power BI DAX engine or refresh the report against a live cloud account.
