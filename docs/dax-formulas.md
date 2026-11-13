# DAX formulas in the report

Extracted from the included PBIX snapshot. These are the current formulas, including the limitations noted below.

## Measures

### Last 12 Month Sales

```dax
Last 12 Month Sales =
Calculate(SUM(Housing[purchase_price]),DATESINPERIOD(Housing[date].[Date],MAX(Housing[date]),-12,MONTH))
```

### Sales By Region

```dax
Sales By Region =
Calculate(SUM(Housing[purchase_price]))
```

### Median Sales Price Change

```dax
Median Sales Price Change =
VAR Cutoff = [Data As Of]
VAR PreviousCutoff = EDATE(Cutoff, -12)

VAR CurrentValue =
    CALCULATE(
        MEDIAN(Housing[purchase_price]),
        FILTER(
            ALL(Housing[date]),
            Housing[date] >= DATE(YEAR(Cutoff), 1, 1)
                && Housing[date] <= Cutoff
        )
    )

VAR PreviousValue =
    CALCULATE(
        MEDIAN(Housing[purchase_price]),
        FILTER(
            ALL(Housing[date]),
            Housing[date] >= DATE(YEAR(PreviousCutoff), 1, 1)
                && Housing[date] <= PreviousCutoff
        )
    )

RETURN
    IF(
        ISBLANK(CurrentValue) || ISBLANK(PreviousValue),
        BLANK(),
        DIVIDE(CurrentValue - PreviousValue, PreviousValue)
    )
```

### Units Sold Latest Year & Quarter

```dax
Units Sold Latest Year & Quarter =
CALCULATE(DISTINCTCOUNT(Housing[house_id]),YEAR(Housing[date])=YEAR(MAX(Housing[date])) && QUARTER(Housing[date])=QUARTER(MAX(Housing[date])))
```

### YOY Sales Growth

```dax
YOY Sales Growth =
VAR Cutoff = [Data As Of]
VAR PreviousCutoff = EDATE(Cutoff, -12)

VAR CurrentValue =
    CALCULATE(
        SUM(Housing[purchase_price]),
        FILTER(
            ALL(Housing[date]),
            Housing[date] >= DATE(YEAR(Cutoff), 1, 1)
                && Housing[date] <= Cutoff
        )
    )

VAR PreviousValue =
    CALCULATE(
        SUM(Housing[purchase_price]),
        FILTER(
            ALL(Housing[date]),
            Housing[date] >= DATE(YEAR(PreviousCutoff), 1, 1)
                && Housing[date] <= PreviousCutoff
        )
    )

RETURN
    IF(
        ISBLANK(CurrentValue) || ISBLANK(PreviousValue),
        BLANK(),
        DIVIDE(CurrentValue - PreviousValue, PreviousValue)
    )
```

### TotalYTDSale

```dax
TotalYTDSale =
TOTALYTD(SUM(Housing[purchase_price]),Housing[date].[Date])
```

### Average Price SQM

```dax
Average Price SQM =
AVERAGE(Housing[sqm_price])
```

### Offer to SQM Ratio

```dax
Offer to SQM Ratio =
DIVIDE(SUM(Housing[Offer Price]),SUM((Housing[sqm])))
```

### Data As Of

```dax
Data As Of =
CALCULATE(
    MAX(Housing[date]),
    REMOVEFILTERS()
)
```

## Calculated columns

### Offer Price

```dax
Offer Price =
(100*Housing[purchase_price])/(100-Housing[%_change_between_offer_and_purchase])
```

### Age

```dax
Age =
VAR AgeAtSale =
    YEAR(Housing[date]) - Housing[year_build]
RETURN
    IF(AgeAtSale < 0, BLANK(), AgeAtSale)
```

## Reading these measures correctly

- `YOY Sales Growth` and `Median Sales Price Change` compare matched YTD periods using the global `Data As Of` date. Their results are decimal ratios, formatted as percentages in Power BI.
- `Last 12 Month Sales` and `Units Sold Latest Year & Quarter` use the latest date in their current filter context. Their cutoff can differ from the global cutoff after filtering.
- `TotalYTDSale` is a cumulative measure in the selected date context.
- The model uses Power BI's automatic date hierarchy. The fixed-snapshot YTD measures are not a general replacement for a dedicated Date table and year-by-year time intelligence.
- `Offer Price` retains the course formula. Its sign convention has not been verified against authoritative source documentation; offer-related visuals are conditional on that assumption.
- `Age` is the approximate property age at sale, calculated using calendar years. Negative results are blank. This is not buyer age.
