# Case Study 7 – Tourism Demand Forecasting

This project analyzes actual World Bank World Development Indicators data for international tourism arrivals in India (`IND`), indicator `ST.INT.ARVL`, from 2000 through 2019. The complete reproducible workflow is in [analysis.R](./analysis.R). The report interpretation is in [report_notes.md](./report_notes.md).

The numbers, tables, and images shown in this README are from the last successful run of `Rscript analysis.R`, not example or placeholder results. Re-running the script regenerates the CSV and PNG outputs.

## Requirements

- R for Windows (run verified with R 4.6.1)
- `ggplot2` (run verified with version 4.0.3)
- The original World Bank CSV files listed below

The script uses base R for data loading, cleaning, statistics, regression, and prediction. It checks for `ggplot2`; if missing, it attempts to install it in the user R library. That installation requires internet access.

## Project files

```text
Tourism_Demand_Forecasting/
|-- analysis.R
|-- README.md
|-- report_notes.md
|-- API_ST.INT.ARVL_DS2_en_csv_v2_2265.csv
|-- Metadata_Country_API_ST.INT.ARVL_DS2_en_csv_v2_2265.csv
|-- Metadata_Indicator_API_ST.INT.ARVL_DS2_en_csv_v2_2265.csv
|-- data/
|-- figures/
`-- outputs/
```

The three downloaded CSVs remain in the project root and are neither renamed nor modified. The `data/` folder is created by the script for project organization; the original data are not duplicated there. The script finds its project folder from its own file path, rather than relying on the terminal's current directory.

## Run from VS Code

Open the project folder in VS Code, open a new integrated terminal, and run this exact command:

```powershell
Rscript analysis.R
```

If PowerShell does not resolve `Rscript`, run:

```powershell
Rscript.exe analysis.R
```

For an R version check in PowerShell, use `R.exe --version`. A bare `R` command may resolve to PowerShell's built-in history alias.

### Data-loading code used by the project

The downloaded World Bank CSV has four metadata lines before its header. This is the actual loading and extraction pattern used in [analysis.R](./analysis.R):

```r
world_bank <- read.csv(
  source_file,
  skip = 4,
  check.names = FALSE,
  na.strings = c("", ".."),
  stringsAsFactors = FALSE
)

india_rows <- world_bank[world_bank[["Country Code"]] == "IND", , drop = FALSE]
target_years <- 2000:2019
source_values <- as.numeric(india_rows[1L, as.character(target_years), drop = TRUE])

tourism <- data.frame(
  year = target_years,
  arrivals_m = source_values / 1000000,
  stringsAsFactors = FALSE
)
```

The code block above is an excerpt for readability; `analysis.R` is the complete executable script and performs source metadata checks, validation, modeling, plotting, and output-file verification.

## Verified run results

The completed run used R 4.6.1 and reported:

```text
Main CSV dimensions: 266 rows x 71 columns
Country-code field: Country Code
Annual source columns: 1960 to 2025
India metadata region: South Asia
Indicator: International tourism, number of arrivals (ST.INT.ARVL)
Dimensions: 20 x 2
Column names: year, arrivals_m
Missing arrivals: 0
Training observations: 16 ; year range: 2000-2015
Testing observations: 4 ; year range: 2016-2019
Extracted data dimensions: 20 x 2 ; years: 2000 - 2019
Verified output CSV files: 14
Verified figure PNG files: 6
```

### Extracted observations

These are the actual 20 India observations written to [tourism_india_2000_2019.csv](./outputs/tourism_india_2000_2019.csv). Arrivals are expressed in millions.

| Year | Arrivals (millions) | Year | Arrivals (millions) |
|---:|---:|---:|---:|
| 2000 | 2.649 | 2010 | 5.776 |
| 2001 | 2.537 | 2011 | 6.309 |
| 2002 | 2.384 | 2012 | 6.578 |
| 2003 | 2.726 | 2013 | 6.968 |
| 2004 | 3.457 | 2014 | 13.107 |
| 2005 | 3.919 | 2015 | 13.284 |
| 2006 | 4.447 | 2016 | 14.570 |
| 2007 | 5.082 | 2017 | 15.543 |
| 2008 | 5.283 | 2018 | 17.423 |
| 2009 | 5.168 | 2019 | 17.914 |

### Descriptive results from the run

| Statistic | Actual result |
|---|---:|
| Observation count | 20 |
| Mean arrivals (millions) | 7.7562 |
| Median arrivals (millions) | 5.5295 |
| Standard deviation (millions) | 5.34353782471974 |
| Minimum (millions) | 2.384 |
| First quartile (millions) | 3.8035 |
| Third quartile (millions) | 13.15125 |
| Maximum (millions) | 17.914 |
| Skewness (population third moment) | 0.743108305072662 |

| Period | CAGR (%) |
|---|---:|
| 2000–2013 | 7.72331421290477 |
| 2014–2019 | 6.44808529380183 |
| 2000–2019 | 10.5834238207837 |

Data quality checks found 0 missing arrival values, no duplicate years or extracted records, no missing target years, no non-finite arrivals, and no zero or negative arrivals. The IQR growth screen and the absolute-change-over-50% check both flag 2014. The value is retained: this flag does not prove an error or a change in statistical definition.

## Regression code and actual model results

The training split is chronological: 2000–2015 for training and 2016–2019 for testing. The regression code used is:

```r
single_train <- lm(ln ~ t, data = train)
multi_train <- lm(ln ~ t + post2014 + shock, data = train)

single_final <- lm(ln ~ t, data = tourism_model)
multi_final <- lm(ln ~ t + post2014 + shock, data = tourism_model)
```

The following training results are taken from the coefficient CSVs generated by that run. Percentage equivalents are calculated as `100 * (exp(coefficient) - 1)`. They describe model associations, not causal effects.

| Model | Term | Estimate | Std. error | p-value | Percentage equivalent |
|---|---|---:|---:|---:|---:|
| Single-variable | Intercept | 0.793760949243539 | 0.0731266464641606 | 3.35199390128787e-08 | 121.16988911667% |
| Single-variable | t | 0.105735090526517 | 0.00830662885162426 | 4.37157354252344e-09 | 11.1527383367352% |
| Multi-variable | Intercept | 0.920179479826653 | 0.0492588820801853 | 3.08975151976986e-10 | 150.974079735882% |
| Multi-variable | t | 0.0843602181586462 | 0.00588183623874806 | 6.48157179944965e-09 | 8.80207480585153% |
| Multi-variable | post2014 | 0.436450727948932 | 0.0776272745446798 | 0.00011208002057284 | 54.7206006601071% |
| Multi-variable | shock | -0.110204420361055 | 0.0578478736797683 | 0.0810098169329143 | -10.4348972724713% |

| Training model | R-squared | Adjusted R-squared |
|---|---:|---:|
| Single-variable | 0.92046696227522 | 0.914786031009165 |
| Multi-variable | 0.979478056709632 | 0.97434757088704 |

`post2014` is an indicator for years from 2014 onward. `shock` is set to 1 for 2001, 2002, and 2009 as specified in the analysis method. These are modeling assumptions, not verified causal explanations.

## Actual hold-out output

The hold-out predictions in [test_predictions.csv](./outputs/test_predictions.csv) and error metrics in [test_metrics.csv](./outputs/test_metrics.csv) were generated from models trained only on 2000–2015. Error units for MAE and RMSE are millions of arrivals.

```text
                  Model N       MAE      RMSE MAPE_percent MAPE_excluded
        Single-variable 4 2.1928629 2.2426485    13.631227             0
         Multi-variable 4 0.7084375 0.8226804     4.256135             0
 Naive last observation 4 1.1575000 1.2625377     7.154404             0
```

On the four hold-out years, the multi-variable model had the lowest MAE, RMSE, and MAPE. All four actual values were nonzero, so MAPE excluded no test observations.

## Actual rolling validation output

Expanding-window one-step-ahead validation uses only years before each prediction year. The multi-variable prediction for 2014 is unavailable because the pre-2014 training data cannot estimate a `post2014` effect. That prediction is left missing rather than fabricated, so the multi-variable metric has 11 observations while the other methods have 12.

```text
                  Model  N       MAE      RMSE MAPE_percent MAPE_excluded
        Single-variable 12 1.4140240 1.9766421    12.448200             0
         Multi-variable 11 0.5202382 0.6159688     5.670904             1
 Naive last observation 12 1.0885000 1.9370617     9.289873             0
```

Among available predictions, the multi-variable model has the lowest rolling MAE and RMSE. The different coverage should be considered when comparing models.

## Forecast output from the run

These forecasts are generated by models fitted on all 2000–2019 observations. Future `post2014` is set to 1 and future `shock` to 0. Forecasts and interval bounds are in millions; log-scale predictions and limits are back-transformed with `exp()`.

| Year | Model | Forecast | Lower limit | Upper limit |
|---:|---|---:|---:|---:|
| 2020 | Single-variable | 20.2841410404875 | 14.530704281647 | 28.3156528255871 |
| 2021 | Single-variable | 22.7013060315372 | 16.1891145199942 | 31.8330749282815 |
| 2022 | Single-variable | 25.4065131231764 | 18.0306296800855 | 35.7996875611652 |
| 2023 | Single-variable | 28.434086927924 | 20.0750332173417 | 40.2737714389596 |
| 2024 | Single-variable | 31.822442359759 | 22.3442348941603 | 45.3212133929385 |
| 2025 | Single-variable | 35.6145720559671 | 24.8624992233426 | 51.0165020553852 |
| 2020 | Multi-variable | 20.3424997573116 | 17.0857122630605 | 24.2200787421019 |
| 2021 | Multi-variable | 22.1109963108085 | 18.5235290437851 | 26.393251345408 |
| 2022 | Multi-variable | 24.0332389671464 | 20.0705053405375 | 28.7783772980225 |
| 2023 | Multi-variable | 26.1225938050389 | 21.734516790436 | 31.3965989528385 |
| 2024 | Multi-variable | 28.3935888972721 | 23.5241074189328 | 34.2710512288533 |
| 2025 | Multi-variable | 30.8620153298784 | 25.4485396896458 | 37.427058756113 |

The source data end in 2019. These are historical-trend baselines, not actual recorded arrivals or reliable present-day forecasts; they do not incorporate COVID-19 or other post-2019 disruptions.

## Figures — rendered from the generated PNG files

### Figure 1. Annual arrivals

![Annual international tourist arrivals in India, 2000–2019. The dashed marker indicates 2014 as a possible series break, not a confirmed change.](figures/fig1_series.png)

### Figure 2. Year-on-year growth

![Year-on-year percentage change in arrivals. The first year has no growth value.](figures/fig2_yoy.png)

### Figure 3. Arrivals distribution

![Histogram of annual arrivals in millions.](figures/fig3_dist.png)

### Figure 3b. Log-arrivals distribution

![Histogram of log arrivals, generated because all observed arrivals are positive.](figures/fig3b_log_dist.png)

### Figure 4. Hold-out predictions

![Actual arrivals and one-step-ahead model predictions for the 2016–2019 hold-out years.](figures/fig4_test_predictions.png)

### Figure 5. Historical series and forecasts

![Historical arrivals and model-based 2020–2025 forecasts with prediction intervals.](figures/fig5_forecast.png)

## Generated files

The complete detailed results are written by the script and can be opened in VS Code:

- Extracted observations: [outputs/tourism_india_2000_2019.csv](./outputs/tourism_india_2000_2019.csv)
- Model-ready data: [outputs/tourism_model_data.csv](./outputs/tourism_model_data.csv)
- Descriptive statistics: [outputs/descriptive_statistics.csv](./outputs/descriptive_statistics.csv)
- Year-on-year growth: [outputs/year_on_year_growth.csv](./outputs/year_on_year_growth.csv)
- Compound annual growth: [outputs/compound_annual_growth.csv](./outputs/compound_annual_growth.csv)
- Quality checks: [outputs/data_quality_report.csv](./outputs/data_quality_report.csv)
- Rolling validation design: [outputs/validation_design.csv](./outputs/validation_design.csv)
- Model coefficients: [outputs/single_model_coefficients.csv](./outputs/single_model_coefficients.csv), [outputs/multi_model_coefficients.csv](./outputs/multi_model_coefficients.csv)
- Hold-out predictions and metrics: [outputs/test_predictions.csv](./outputs/test_predictions.csv), [outputs/test_metrics.csv](./outputs/test_metrics.csv)
- Rolling validation predictions and metrics: [outputs/rolling_validation_predictions.csv](./outputs/rolling_validation_predictions.csv), [outputs/rolling_validation_metrics.csv](./outputs/rolling_validation_metrics.csv)
- Forecast table: [outputs/forecasts.csv](./outputs/forecasts.csv)

The generated forecasts are for planning discussion only. Arrivals represent trips rather than unique people, source methods may differ, the 2014 jump has no confirmed explanation in the supplied files, and a short historical series cannot represent future structural changes.
