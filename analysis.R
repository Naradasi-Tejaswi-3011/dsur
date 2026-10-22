# Case Study 7 - Tourism Demand Forecasting
# Reproducible analysis of World Bank international tourism arrivals for India.

# 1. Project setup -------------------------------------------------------------

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) == 0L) {
  stop("Could not locate analysis.R. Run this project with: Rscript analysis.R")
}

script_path <- normalizePath(sub("^--file=", "", script_argument[[1L]]), winslash = "/", mustWork = TRUE)
project_dir <- dirname(script_path)
setwd(project_dir)

output_dir <- file.path(project_dir, "outputs")
figure_dir <- file.path(project_dir, "figures")
data_dir <- file.path(project_dir, "data")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

user_library <- Sys.getenv("R_LIBS_USER")
if (nzchar(user_library)) {
  dir.create(user_library, recursive = TRUE, showWarnings = FALSE)
  .libPaths(unique(c(user_library, .libPaths())))
}
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  if (!nzchar(user_library)) {
    stop("ggplot2 is missing and R_LIBS_USER is not set. Install ggplot2, then rerun.")
  }
  message("ggplot2 is missing; installing it in the user R library.")
  install.packages("ggplot2", lib = user_library, repos = "https://cloud.r-project.org")
}
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("ggplot2 is still unavailable after installation. Check your internet connection and R library.")
}

source_file <- file.path(project_dir, "API_ST.INT.ARVL_DS2_en_csv_v2_2265.csv")
country_file <- file.path(project_dir, "Metadata_Country_API_ST.INT.ARVL_DS2_en_csv_v2_2265.csv")
indicator_file <- file.path(project_dir, "Metadata_Indicator_API_ST.INT.ARVL_DS2_en_csv_v2_2265.csv")
required_files <- c(source_file, country_file, indicator_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop("Required World Bank CSV file(s) not found: ", paste(basename(missing_files), collapse = ", "))
}

# 2. Data loading and source verification -------------------------------------

# The downloaded World Bank file has four metadata lines before its CSV header.
world_bank <- read.csv(
  source_file,
  skip = 4,
  check.names = FALSE,
  na.strings = c("", ".."),
  stringsAsFactors = FALSE
)
country_metadata <- read.csv(country_file, check.names = FALSE, stringsAsFactors = FALSE)
indicator_metadata <- read.csv(indicator_file, check.names = FALSE, stringsAsFactors = FALSE)

required_columns <- c("Country Name", "Country Code", "Indicator Name", "Indicator Code")
if (!all(required_columns %in% names(world_bank))) {
  stop("The main CSV does not contain the expected country and indicator columns.")
}
year_columns <- names(world_bank)[grepl("^\\d{4}$", names(world_bank))]
if (length(year_columns) == 0L) {
  stop("No annual year columns were found in the main CSV.")
}
target_years <- 2000:2019
if (!all(as.character(target_years) %in% year_columns)) {
  stop("The source CSV does not contain every requested year from 2000 to 2019.")
}

india_rows <- world_bank[world_bank[["Country Code"]] == "IND", , drop = FALSE]
if (nrow(india_rows) != 1L) {
  stop("Expected exactly one source row for India (IND); found ", nrow(india_rows), ".")
}
if (india_rows[["Indicator Code"]][[1L]] != "ST.INT.ARVL") {
  stop("The India row does not match the requested ST.INT.ARVL indicator.")
}
if (!all(c("Country Code", "Region", "IncomeGroup", "TableName") %in% names(country_metadata))) {
  stop("The country metadata CSV does not have its expected columns.")
}
india_country_metadata <- country_metadata[country_metadata[["Country Code"]] == "IND", , drop = FALSE]
indicator_record <- indicator_metadata[indicator_metadata[["INDICATOR_CODE"]] == "ST.INT.ARVL", , drop = FALSE]
if (nrow(india_country_metadata) != 1L || nrow(indicator_record) != 1L) {
  stop("Could not uniquely verify India and ST.INT.ARVL in the metadata CSV files.")
}

cat("R version:", R.version.string, "\n")
cat("Main CSV dimensions:", nrow(world_bank), "rows x", ncol(world_bank), "columns\n")
cat("Country-code field: Country Code\n")
cat("Annual source columns:", min(as.integer(year_columns)), "to", max(as.integer(year_columns)), "\n")
cat("India metadata region:", india_country_metadata[["Region"]][[1L]], "\n")
cat("Indicator:", indicator_record[["INDICATOR_NAME"]][[1L]], "(ST.INT.ARVL)\n")

# 3. Extract India and prepare descriptive statistics -------------------------

source_values <- as.numeric(india_rows[1L, as.character(target_years), drop = TRUE])
tourism <- data.frame(
  year = target_years,
  arrivals_m = source_values / 1000000,
  stringsAsFactors = FALSE
)
names(tourism) <- c("year", "arrivals_m")
extracted_dimensions <- dim(tourism)

if (anyDuplicated(tourism$year) > 0L) {
  stop("Duplicate years were found in the extracted India series.")
}
if (any(!is.finite(tourism$arrivals_m) & !is.na(tourism$arrivals_m))) {
  stop("The extracted series contains non-finite values.")
}

cat("\nExtracted tourism data structure:\n")
str(tourism)
cat("\nFirst rows:\n")
print(head(tourism))
cat("\nDimensions:", paste(dim(tourism), collapse = " x "), "\n")
cat("Column names:", paste(names(tourism), collapse = ", "), "\n")
cat("\nSummary:\n")
print(summary(tourism))
cat("Missing arrivals:", sum(is.na(tourism$arrivals_m)), "\n")
write.csv(tourism, file.path(output_dir, "tourism_india_2000_2019.csv"), row.names = FALSE, na = "")

valid_arrivals <- tourism$arrivals_m[is.finite(tourism$arrivals_m)]
if (length(valid_arrivals) == 0L) {
  stop("There are no valid arrivals observations for analysis.")
}
arrival_quartiles <- quantile(valid_arrivals, probs = c(0, 0.25, 0.5, 0.75, 1), names = FALSE)
skewness <- if (length(valid_arrivals) > 2L && sd(valid_arrivals) > 0) {
  mean((valid_arrivals - mean(valid_arrivals))^3) / sd(valid_arrivals)^3
} else {
  NA_real_
}
descriptive_stats <- data.frame(
  Statistic = c("Observation count", "First year", "Last year", "Mean arrivals (millions)",
                "Median arrivals (millions)", "Standard deviation (millions)", "Minimum (millions)",
                "First quartile (millions)", "Third quartile (millions)", "Maximum (millions)",
                "Skewness (population moment)"),
  Value = c(length(valid_arrivals), min(tourism$year), max(tourism$year), mean(valid_arrivals),
            median(valid_arrivals), sd(valid_arrivals), arrival_quartiles[[1L]],
            arrival_quartiles[[2L]], arrival_quartiles[[4L]], arrival_quartiles[[5L]], skewness)
)
write.csv(descriptive_stats, file.path(output_dir, "descriptive_statistics.csv"), row.names = FALSE)

tourism$yoy_pct <- c(NA_real_, diff(tourism$arrivals_m) / head(tourism$arrivals_m, -1L) * 100)
write.csv(tourism[c("year", "yoy_pct")], file.path(output_dir, "year_on_year_growth.csv"),
          row.names = FALSE, na = "")

cagr_for_period <- function(start_year, end_year) {
  start_value <- tourism$arrivals_m[tourism$year == start_year]
  end_value <- tourism$arrivals_m[tourism$year == end_year]
  if (length(start_value) != 1L || length(end_value) != 1L ||
      !is.finite(start_value) || !is.finite(end_value) ||
      start_value <= 0 || end_value <= 0) {
    return(NA_real_)
  }
  (end_value / start_value)^(1 / (end_year - start_year)) - 1
}
cagr_table <- data.frame(
  Period = c("2000-2013", "2014-2019", "2000-2019"),
  CAGR_percent = 100 * c(cagr_for_period(2000, 2013), cagr_for_period(2014, 2019),
                          cagr_for_period(2000, 2019))
)
write.csv(cagr_table, file.path(output_dir, "compound_annual_growth.csv"), row.names = FALSE)
cat("\nDescriptive statistics:\n")
print(descriptive_stats, row.names = FALSE)
cat("\nCompound annual growth rates:\n")
print(cagr_table, row.names = FALSE)

# 4. Data quality checks -------------------------------------------------------

expected_years <- target_years
observed_years <- tourism$year
missing_years <- setdiff(expected_years, observed_years)
growth_values <- tourism$yoy_pct[is.finite(tourism$yoy_pct)]
growth_quartiles <- if (length(growth_values) > 0L) quantile(growth_values, c(0.25, 0.75), names = FALSE) else c(NA, NA)
growth_iqr <- growth_quartiles[[2L]] - growth_quartiles[[1L]]
growth_outliers <- if (is.finite(growth_iqr)) {
  tourism$year[is.finite(tourism$yoy_pct) &
                 (tourism$yoy_pct < growth_quartiles[[1L]] - 1.5 * growth_iqr |
                    tourism$yoy_pct > growth_quartiles[[2L]] + 1.5 * growth_iqr)]
} else {
  integer(0)
}
large_changes <- tourism$year[is.finite(tourism$yoy_pct) & abs(tourism$yoy_pct) > 50]
gap_description <- if (length(missing_years) == 0L) "No missing years from 2000 through 2019." else paste("Missing years:", paste(missing_years, collapse = ", "))
quality_report <- data.frame(
  Check = c("Missing arrival values", "Duplicate years", "Duplicate extracted records",
            "Missing target years", "Year range",
            "Year and arrival data types", "Non-finite arrivals", "Zero or negative arrivals",
            "Year-on-year IQR outlier years", "Absolute year-on-year changes above 50%",
            "Source precision and coverage"),
  Finding = c(as.character(sum(is.na(tourism$arrivals_m))),
              as.character(anyDuplicated(tourism$year) > 0L),
              as.character(sum(duplicated(tourism[c("year", "arrivals_m")]))),
              gap_description,
              paste(min(tourism$year), "to", max(tourism$year)),
              paste("year:", typeof(tourism$year), "; arrivals_m:", typeof(tourism$arrivals_m)),
              as.character(sum(!is.finite(tourism$arrivals_m) & !is.na(tourism$arrivals_m))),
              as.character(sum(tourism$arrivals_m <= 0, na.rm = TRUE)),
              if (length(growth_outliers)) paste(growth_outliers, collapse = ", ") else "None",
              if (length(large_changes)) paste(large_changes, collapse = ", ") else "None",
              "World Bank source values are retained at supplied precision; arrivals are divided by 1,000,000."),
  Handling = c("Preserved as missing; no imputation.",
               "No duplicate years expected; records retained unless invalid.",
               "No duplicate extracted year-arrival records expected.",
               if (length(missing_years) == 0L) "Complete requested annual coverage." else "Missing years are not fabricated.",
               "Use only requested period 2000-2019.",
               "Years are integers and arrivals are numeric.",
               "Non-finite source values are not used in modeling.",
               "Exclude non-positive values from log modeling; no valid outlier is automatically removed.",
               "IQR rule is a screening flag, not evidence of an error; retain valid observations.",
               "Flag for investigation; do not infer a methodological change without evidence.",
               "Indicator caveat: arrivals count trips/arrivals, not unique people; country methods can differ.")
)
write.csv(quality_report, file.path(output_dir, "data_quality_report.csv"), row.names = FALSE)
cat("\nData quality report:\n")
print(quality_report, row.names = FALSE)
if (length(missing_years) > 0L) {
  warning("Missing target year(s) are preserved; related splits and model predictions will be checked.")
}

# 5. Visual exploration --------------------------------------------------------

library(ggplot2)
base_theme <- theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank())

fig1 <- ggplot(tourism, aes(x = year, y = arrivals_m)) +
  geom_line(color = "#176B87", linewidth = 1) +
  geom_point(color = "#176B87", size = 2) +
  geom_vline(xintercept = 2013.5, linetype = "dashed", color = "gray45") +
  annotate("text", x = 2013.2, y = max(tourism$arrivals_m, na.rm = TRUE),
           label = "2014: possible series break", hjust = 1, vjust = -0.4, size = 3.3) +
  labs(title = "International Tourist Arrivals in India, 2000-2019",
       x = "Year", y = "Arrivals (millions)") + base_theme
ggsave(file.path(figure_dir, "fig1_series.png"), fig1, width = 9, height = 5, dpi = 300)

fig2 <- ggplot(tourism[is.finite(tourism$yoy_pct), ], aes(x = year, y = yoy_pct)) +
  geom_col(fill = "#4C956C") +
  geom_hline(yintercept = 0, color = "gray35") +
  labs(title = "Year-on-Year Change in Arrivals", x = "Year", y = "Change (%)") + base_theme
ggsave(file.path(figure_dir, "fig2_yoy.png"), fig2, width = 9, height = 5, dpi = 300)

fig3 <- ggplot(tourism[is.finite(tourism$arrivals_m), ], aes(x = arrivals_m)) +
  geom_histogram(bins = 10, fill = "#F4A259", color = "white") +
  labs(title = "Distribution of Annual Tourist Arrivals",
       x = "Arrivals (millions)", y = "Number of years") + base_theme
ggsave(file.path(figure_dir, "fig3_dist.png"), fig3, width = 8, height = 5, dpi = 300)

if (all(tourism$arrivals_m[!is.na(tourism$arrivals_m)] > 0)) {
  tourism$ln <- log(tourism$arrivals_m)
  fig_log <- ggplot(tourism, aes(x = ln)) +
    geom_histogram(bins = 10, fill = "#8E7DBE", color = "white") +
    labs(title = "Distribution of Log Arrivals", x = "log(Arrivals in millions)",
         y = "Number of years") + base_theme
  ggsave(file.path(figure_dir, "fig3b_log_dist.png"), fig_log, width = 8, height = 5, dpi = 300)
} else {
  message("Log-arrivals histogram skipped because one or more observed arrivals are not positive.")
}

# 6. Model-ready data and time-ordered validation design ----------------------

tourism_model <- tourism[is.finite(tourism$arrivals_m) & tourism$arrivals_m > 0, c("year", "arrivals_m")]
tourism_model$ln <- log(tourism_model$arrivals_m)
tourism_model$t <- tourism_model$year - 2000
tourism_model$post2014 <- as.integer(tourism_model$year >= 2014)
tourism_model$shock <- as.integer(tourism_model$year %in% c(2001, 2002, 2009))
if (!all(is.finite(tourism_model$ln)) || any(tourism_model$arrivals_m <= 0)) {
  stop("Model-ready data failed the positive-arrivals/log-value checks.")
}
write.csv(tourism_model, file.path(output_dir, "tourism_model_data.csv"), row.names = FALSE)

train <- tourism_model[tourism_model$year >= 2000 & tourism_model$year <= 2015, , drop = FALSE]
test <- tourism_model[tourism_model$year >= 2016 & tourism_model$year <= 2019, , drop = FALSE]
cat("\nTraining observations:", nrow(train), "; year range:",
    if (nrow(train)) paste(min(train$year), max(train$year), sep = "-") else "none", "\n")
cat("Testing observations:", nrow(test), "; year range:",
    if (nrow(test)) paste(min(test$year), max(test$year), sep = "-") else "none", "\n")

validation_years <- 2008:2019
validation_design <- data.frame(
  prediction_year = validation_years,
  training_start = NA_integer_,
  training_end = NA_integer_,
  training_observations = integer(length(validation_years)),
  prediction_method = "Expanding window; one-step ahead; no random shuffling",
  stringsAsFactors = FALSE
)
for (i in seq_along(validation_years)) {
  prior <- tourism_model[tourism_model$year < validation_years[[i]], , drop = FALSE]
  validation_design$training_observations[[i]] <- nrow(prior)
  if (nrow(prior)) {
    validation_design$training_start[[i]] <- min(prior$year)
    validation_design$training_end[[i]] <- max(prior$year)
  }
}
write.csv(validation_design, file.path(output_dir, "validation_design.csv"), row.names = FALSE)

# 7. Regression models ---------------------------------------------------------

single_formula <- ln ~ t
multi_formula <- ln ~ t + post2014 + shock
if (nrow(train) <= 2L) {
  stop("Insufficient training observations to fit the single-variable model.")
}
if (nrow(train) <= 4L) {
  stop("Insufficient training observations to fit the multi-variable model.")
}
single_train <- lm(single_formula, data = train)
multi_train <- lm(multi_formula, data = train)
single_final <- lm(single_formula, data = tourism_model)
multi_final <- lm(multi_formula, data = tourism_model)

coefficient_table <- function(model, model_name) {
  coefficient_summary <- summary(model)$coefficients
  data.frame(
    Model = model_name,
    Term = rownames(coefficient_summary),
    Estimate = coefficient_summary[, "Estimate"],
    Standard_Error = coefficient_summary[, "Std. Error"],
    t_value = coefficient_summary[, "t value"],
    p_value = coefficient_summary[, "Pr(>|t|)"],
    Percentage_effect = 100 * (exp(coefficient_summary[, "Estimate"]) - 1),
    R_squared = summary(model)$r.squared,
    Adjusted_R_squared = summary(model)$adj.r.squared,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}
single_coefficients <- coefficient_table(single_train, "Single-variable training model")
multi_coefficients <- coefficient_table(multi_train, "Multi-variable training model")
single_final_coefficients <- coefficient_table(single_final, "Single-variable full-data model")
multi_final_coefficients <- coefficient_table(multi_final, "Multi-variable full-data model")
write.csv(rbind(single_coefficients, single_final_coefficients),
          file.path(output_dir, "single_model_coefficients.csv"), row.names = FALSE)
write.csv(rbind(multi_coefficients, multi_final_coefficients),
          file.path(output_dir, "multi_model_coefficients.csv"), row.names = FALSE)

cat("\nSingle-variable training model: lm(ln ~ t)\n")
print(summary(single_train))
cat("\nMulti-variable training model: lm(ln ~ t + post2014 + shock)\n")
print(summary(multi_train))
cat("\nSingle-variable full-data model used for forecasting:\n")
print(summary(single_final))
cat("\nMulti-variable full-data model used for forecasting:\n")
print(summary(multi_final))
if (anyNA(coef(single_train)) || anyNA(coef(multi_train))) {
  warning("At least one fitted model has aliased coefficients; inspect saved coefficient tables.")
}

# 8. Hold-out and rolling-origin predictions ----------------------------------

if (nrow(test) == 0L) {
  stop("No valid observations are available in the specified 2016-2019 test period.")
}
test_predictions <- data.frame(
  year = test$year,
  actual = test$arrivals_m,
  single_variable = exp(predict(single_train, newdata = test)),
  multi_variable = exp(predict(multi_train, newdata = test)),
  naive_last_observation = NA_real_
)
for (i in seq_len(nrow(test_predictions))) {
  prior <- tourism_model[tourism_model$year < test_predictions$year[[i]], , drop = FALSE]
  if (nrow(prior) > 0L) {
    test_predictions$naive_last_observation[[i]] <- prior$arrivals_m[[which.max(prior$year)]]
  }
}
write.csv(test_predictions, file.path(output_dir, "test_predictions.csv"), row.names = FALSE)

calculate_metrics <- function(actual, predicted, model_name) {
  usable <- is.finite(actual) & is.finite(predicted)
  actual_use <- actual[usable]
  predicted_use <- predicted[usable]
  if (length(actual_use) == 0L) {
    return(data.frame(Model = model_name, N = 0L, MAE = NA_real_, RMSE = NA_real_,
                      MAPE_percent = NA_real_, MAPE_excluded = length(actual)))
  }
  mape_valid <- is.finite(actual_use) & actual_use != 0
  data.frame(
    Model = model_name,
    N = length(actual_use),
    MAE = mean(abs(actual_use - predicted_use)),
    RMSE = sqrt(mean((actual_use - predicted_use)^2)),
    MAPE_percent = if (any(mape_valid)) {
      100 * mean(abs(actual_use[mape_valid] - predicted_use[mape_valid]) / abs(actual_use[mape_valid]))
    } else {
      NA_real_
    },
    MAPE_excluded = sum(!mape_valid) + sum(!usable)
  )
}
test_metrics <- rbind(
  calculate_metrics(test_predictions$actual, test_predictions$single_variable, "Single-variable"),
  calculate_metrics(test_predictions$actual, test_predictions$multi_variable, "Multi-variable"),
  calculate_metrics(test_predictions$actual, test_predictions$naive_last_observation, "Naive last observation")
)
write.csv(test_metrics, file.path(output_dir, "test_metrics.csv"), row.names = FALSE)
cat("\nHold-out test metrics (arrivals in millions):\n")
print(test_metrics, row.names = FALSE)

rolling_predictions <- data.frame(
  year = validation_years,
  actual = NA_real_,
  single_variable = NA_real_,
  multi_variable = NA_real_,
  naive_last_observation = NA_real_
)
for (i in seq_along(validation_years)) {
  prediction_year <- validation_years[[i]]
  prior <- tourism_model[tourism_model$year < prediction_year, , drop = FALSE]
  observed <- tourism_model[tourism_model$year == prediction_year, , drop = FALSE]
  if (nrow(prior) < 3L || nrow(observed) != 1L) {
    next
  }
  rolling_predictions$actual[[i]] <- observed$arrivals_m[[1L]]
  rolling_predictions$naive_last_observation[[i]] <- prior$arrivals_m[[which.max(prior$year)]]
  rolling_single <- lm(single_formula, data = prior)
  rolling_predictions$single_variable[[i]] <- exp(predict(rolling_single, newdata = observed))
  if (nrow(prior) > 4L) {
    # Before the regime indicator varies in training, its effect is not estimable.
    # For pre-2014 targets its known contribution is zero, so fit the identifiable terms.
    if (prediction_year < 2014L && length(unique(prior$shock)) > 1L) {
      rolling_multi <- lm(ln ~ t + shock, data = prior)
      rolling_predictions$multi_variable[[i]] <- exp(predict(rolling_multi, newdata = observed))
    } else if (length(unique(prior$post2014)) > 1L && length(unique(prior$shock)) > 1L) {
      rolling_multi <- lm(multi_formula, data = prior)
      if (!anyNA(coef(rolling_multi))) {
        rolling_predictions$multi_variable[[i]] <- exp(predict(rolling_multi, newdata = observed))
      }
    }
  }
}
write.csv(rolling_predictions, file.path(output_dir, "rolling_validation_predictions.csv"),
          row.names = FALSE, na = "")
rolling_metrics <- rbind(
  calculate_metrics(rolling_predictions$actual, rolling_predictions$single_variable, "Single-variable"),
  calculate_metrics(rolling_predictions$actual, rolling_predictions$multi_variable, "Multi-variable"),
  calculate_metrics(rolling_predictions$actual, rolling_predictions$naive_last_observation, "Naive last observation")
)
write.csv(rolling_metrics, file.path(output_dir, "rolling_validation_metrics.csv"), row.names = FALSE)
cat("\nExpanding-window one-step rolling-origin metrics (arrivals in millions):\n")
print(rolling_metrics, row.names = FALSE)

fig4_data <- rbind(
  data.frame(year = test_predictions$year, arrivals_m = test_predictions$actual, Series = "Actual"),
  data.frame(year = test_predictions$year, arrivals_m = test_predictions$single_variable, Series = "Single-variable"),
  data.frame(year = test_predictions$year, arrivals_m = test_predictions$multi_variable, Series = "Multi-variable"),
  data.frame(year = test_predictions$year, arrivals_m = test_predictions$naive_last_observation, Series = "Naive benchmark")
)
fig4 <- ggplot(fig4_data, aes(x = year, y = arrivals_m, color = Series, linetype = Series)) +
  geom_line(linewidth = 0.9) + geom_point(size = 2) +
  labs(title = "Hold-Out Actual Arrivals and One-Step-Ahead Predictions",
       x = "Year", y = "Arrivals (millions)", color = "Series", linetype = "Series") +
  base_theme
ggsave(file.path(figure_dir, "fig4_test_predictions.png"), fig4, width = 9, height = 5, dpi = 300)

# 9. Forecasts from models fitted to all valid historical observations ---------

future_years <- 2020:2025
future_data <- data.frame(
  year = future_years,
  t = future_years - 2000,
  post2014 = as.integer(future_years >= 2014),
  shock = 0L
)
single_interval <- predict(single_final, newdata = future_data, interval = "prediction")
multi_interval <- predict(multi_final, newdata = future_data, interval = "prediction")
forecast_rows <- function(interval_matrix, model_name) {
  data.frame(
    year = future_years,
    model = model_name,
    forecast = exp(interval_matrix[, "fit"]),
    lower_limit = exp(interval_matrix[, "lwr"]),
    upper_limit = exp(interval_matrix[, "upr"]),
    stringsAsFactors = FALSE
  )
}
forecasts <- rbind(
  forecast_rows(single_interval, "Single-variable"),
  forecast_rows(multi_interval, "Multi-variable")
)
if (any(!is.finite(as.matrix(forecasts[c("forecast", "lower_limit", "upper_limit")]))) ||
    any(forecasts$lower_limit > forecasts$upper_limit)) {
  stop("Forecast values or prediction interval limits are invalid.")
}
write.csv(forecasts, file.path(output_dir, "forecasts.csv"), row.names = FALSE)
cat("\n2020-2025 historical-trend baseline forecasts (millions; log-scale prediction intervals exponentiated):\n")
print(forecasts, row.names = FALSE)

fig5 <- ggplot() +
  geom_line(data = tourism_model, aes(x = year, y = arrivals_m), color = "gray35", linewidth = 0.8) +
  geom_point(data = tourism_model, aes(x = year, y = arrivals_m), color = "gray35", size = 1.5) +
  geom_ribbon(data = forecasts, aes(x = year, ymin = lower_limit, ymax = upper_limit,
                                    fill = model, group = model), alpha = 0.16) +
  geom_line(data = forecasts, aes(x = year, y = forecast, color = model), linewidth = 0.9) +
  geom_point(data = forecasts, aes(x = year, y = forecast, color = model), size = 1.8) +
  geom_vline(xintercept = 2019.5, linetype = "dashed", color = "gray45") +
  labs(title = "Historical Arrivals and Model-Based Forecasts",
       subtitle = "Forecasts are historical-trend baselines and omit post-2019 shocks",
       x = "Year", y = "Arrivals (millions)", color = "Forecast model", fill = "Forecast model") +
  base_theme
ggsave(file.path(figure_dir, "fig5_forecast.png"), fig5, width = 10, height = 6, dpi = 300)

# 10. Final artifact verification ---------------------------------------------

expected_outputs <- c(
  "tourism_india_2000_2019.csv", "tourism_model_data.csv", "descriptive_statistics.csv",
  "year_on_year_growth.csv", "compound_annual_growth.csv", "data_quality_report.csv",
  "validation_design.csv", "single_model_coefficients.csv", "multi_model_coefficients.csv",
  "test_metrics.csv", "rolling_validation_metrics.csv", "rolling_validation_predictions.csv",
  "test_predictions.csv", "forecasts.csv"
)
expected_figures <- c("fig1_series.png", "fig2_yoy.png", "fig3_dist.png",
                      "fig4_test_predictions.png", "fig5_forecast.png")
if (all(tourism$arrivals_m[!is.na(tourism$arrivals_m)] > 0)) {
  expected_figures <- c(expected_figures, "fig3b_log_dist.png")
}
output_paths <- file.path(output_dir, expected_outputs)
figure_paths <- file.path(figure_dir, expected_figures)
missing_artifacts <- c(output_paths[!file.exists(output_paths)], figure_paths[!file.exists(figure_paths)])
if (length(missing_artifacts) > 0L) {
  stop("Analysis finished with missing expected artifact(s): ", paste(basename(missing_artifacts), collapse = ", "))
}
cat("\nVerification complete.\n")
cat("Extracted data dimensions:", extracted_dimensions[[1L]], "x", extracted_dimensions[[2L]],
    "; years:", min(tourism$year), "-", max(tourism$year), "\n")
cat("Verified output CSV files:", length(output_paths), "\n")
cat("Verified figure PNG files:", length(figure_paths), "\n")
cat("All analysis outputs are saved under outputs/ and figures/.\n")
