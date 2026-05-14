rm(list = ls())

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(dplyr)
library(readr)
library(stringr)

args <- commandArgs(trailingOnly = TRUE)

default_input_path <- paste0(raw.data.folder, "neighbor_home_nyc_la_values.csv")
default_period_label <- "2019_full_year"
default_output_summary <- paste0(generated.data.folder, "neighbor_visit_annual_average_", default_period_label, "_tract.rds")
default_output_model <- paste0(generated.data.folder, "data_models_neighbor_visits_annual_average_", default_period_label, ".rds")

input_path <- if (length(args) >= 1) args[[1]] else Sys.getenv("NEIGHBOR_HOME_INPUT", unset = default_input_path)
output_summary_path <- if (length(args) >= 2) args[[2]] else default_output_summary
output_model_path <- if (length(args) >= 3) args[[3]] else default_output_model
target_year <- if (length(args) >= 4) suppressWarnings(as.integer(args[[4]])) else 2019L
start_month <- if (length(args) >= 5) suppressWarnings(as.integer(args[[5]])) else 1L
end_month <- if (length(args) >= 6) suppressWarnings(as.integer(args[[6]])) else 12L
period_label <- if (length(args) >= 7) args[[7]] else default_period_label

normalize_geoid <- function(x) {
  gsub("[^0-9]", "", as.character(x))
}

pad_geoid <- function(x, width) {
  stringr::str_pad(normalize_geoid(x), width = width, side = "left", pad = "0")
}

standardize_city <- function(x) {
  x <- tolower(trimws(as.character(x)))
  dplyr::case_when(
    x %in% c("nyc", "new york city", "new york") ~ "NYC",
    x %in% c("la", "los angeles") ~ "LA",
    TRUE ~ NA_character_
  )
}

read_neighbor_home_table <- function(path) {
  if (!file.exists(path) && !dir.exists(path)) {
    stop("Input file or directory does not exist: ", path)
  }
  
  if (dir.exists(path)) {
    if (!requireNamespace("arrow", quietly = TRUE)) {
      stop("Package 'arrow' is required to read parquet directories.")
    }
    parquet_files <- list.files(path, pattern = "\\.parquet$", full.names = TRUE, recursive = TRUE)
    parquet_files <- parquet_files[!startsWith(basename(parquet_files), "._")]
    if (length(parquet_files) == 0) {
      stop("No parquet files found in directory: ", path)
    }
    return(arrow::open_dataset(parquet_files, format = "parquet") |> dplyr::collect())
  }
  
  ext <- tolower(tools::file_ext(path))
  
  if (ext == "csv") {
    return(readr::read_csv(path, show_col_types = FALSE))
  }
  
  if (ext == "rds") {
    return(readRDS(path))
  }
  
  if (ext == "parquet") {
    if (!requireNamespace("arrow", quietly = TRUE)) {
      stop("Package 'arrow' is required to read parquet files.")
    }
    return(arrow::read_parquet(path, as_data_frame = TRUE))
  }
  
  stop("Unsupported input extension: ", ext)
}

neighbor_dt <- read_neighbor_home_table(input_path)

geoid_col <- dplyr::case_when(
  "GEOID" %in% names(neighbor_dt) ~ "GEOID",
  "AREA" %in% names(neighbor_dt) ~ "AREA",
  TRUE ~ NA_character_
)

if (is.na(geoid_col)) {
  stop("Input must contain either GEOID or AREA.")
}

required_cols <- c(
  "NEIGHBOR_HOME_DEVICE_COUNTS",
  "HOME_DEVICE_COUNTS_TOTAL_PARSED",
  "DEVICE_COUNTS_ROW_TOTAL"
)

missing_cols <- setdiff(required_cols, names(neighbor_dt))
if (length(missing_cols) > 0) {
  stop("Input is missing required columns: ", paste(missing_cols, collapse = ", "))
}

has_metro_key <- "metro_key" %in% names(neighbor_dt)
has_metro_label <- "metro_label" %in% names(neighbor_dt)
has_city_col <- "city" %in% names(neighbor_dt)
has_neighbor_share <- "NEIGHBOR_HOME_DEVICE_SHARE" %in% names(neighbor_dt)
has_neighbor_cbg_count <- "NEIGHBOR_HOME_CBG_COUNT" %in% names(neighbor_dt)
has_year_col <- "YEAR" %in% names(neighbor_dt)
has_month_col <- "MONTH" %in% names(neighbor_dt)

neighbor_dt <- neighbor_dt |>
  mutate(
    GEOID_CBG = pad_geoid(.data[[geoid_col]], 12),
    TRACT_GEOID = substr(GEOID_CBG, 1, 11),
    city = dplyr::coalesce(
      if (has_metro_key) standardize_city(metro_key) else NA_character_,
      if (has_metro_label) standardize_city(metro_label) else NA_character_,
      if (has_city_col) standardize_city(city) else NA_character_
    ),
    YEAR = if (has_year_col) suppressWarnings(as.integer(YEAR)) else NA_integer_,
    MONTH = if (has_month_col) suppressWarnings(as.integer(MONTH)) else NA_integer_,
    NEIGHBOR_HOME_DEVICE_COUNTS = as.numeric(NEIGHBOR_HOME_DEVICE_COUNTS),
    HOME_DEVICE_COUNTS_TOTAL_PARSED = as.numeric(HOME_DEVICE_COUNTS_TOTAL_PARSED),
    DEVICE_COUNTS_ROW_TOTAL = as.numeric(DEVICE_COUNTS_ROW_TOTAL),
    NEIGHBOR_HOME_DEVICE_SHARE = if (has_neighbor_share) as.numeric(NEIGHBOR_HOME_DEVICE_SHARE) else NA_real_,
    NEIGHBOR_HOME_CBG_COUNT = if (has_neighbor_cbg_count) as.numeric(NEIGHBOR_HOME_CBG_COUNT) else NA_real_
  ) |>
  filter(
    !is.na(city),
    str_length(TRACT_GEOID) == 11
  )

if (nrow(neighbor_dt) == 0) {
  stop("No valid NYC/LA rows remained after city and GEOID filtering.")
}

has_period_cols <- all(c("YEAR", "MONTH") %in% names(neighbor_dt)) &&
  any(!is.na(neighbor_dt$YEAR)) &&
  any(!is.na(neighbor_dt$MONTH))

if (has_period_cols) {
  message("Using YEAR and MONTH to compute tract-month totals before annual averaging.")
  
  tract_month_dt <- neighbor_dt |>
    filter(
      !is.na(YEAR),
      !is.na(MONTH),
      YEAR == target_year,
      MONTH >= start_month,
      MONTH <= end_month
    ) |>
    group_by(city, TRACT_GEOID, YEAR, MONTH) |>
    summarise(
      neighbor_visit_count_monthly = sum(NEIGHBOR_HOME_DEVICE_COUNTS, na.rm = TRUE),
      home_device_counts_total_parsed_monthly = sum(HOME_DEVICE_COUNTS_TOTAL_PARSED, na.rm = TRUE),
      device_counts_row_total_monthly = sum(DEVICE_COUNTS_ROW_TOTAL, na.rm = TRUE),
      neighbor_home_cbg_count_monthly = sum(NEIGHBOR_HOME_CBG_COUNT, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      neighbor_visit_share_monthly = dplyr::if_else(
        home_device_counts_total_parsed_monthly > 0,
        neighbor_visit_count_monthly / home_device_counts_total_parsed_monthly,
        NA_real_
      )
    )
  
  if (nrow(tract_month_dt) == 0) {
    stop(
      "No rows remained after filtering YEAR == ", target_year,
      " and MONTH in [", start_month, ", ", end_month, "]."
    )
  }
  
  tract_annual_dt <- tract_month_dt |>
    group_by(city, TRACT_GEOID) |>
    summarise(
      neighbor_visit_count_annual_avg = mean(neighbor_visit_count_monthly, na.rm = TRUE),
      home_device_counts_total_parsed_annual_avg = mean(home_device_counts_total_parsed_monthly, na.rm = TRUE),
      device_counts_row_total_annual_avg = mean(device_counts_row_total_monthly, na.rm = TRUE),
      neighbor_home_cbg_count_annual_avg = mean(neighbor_home_cbg_count_monthly, na.rm = TRUE),
      neighbor_visit_share_annual_avg = mean(neighbor_visit_share_monthly, na.rm = TRUE),
      neighbor_visit_count_annual_total = sum(neighbor_visit_count_monthly, na.rm = TRUE),
      home_device_counts_total_parsed_annual_total = sum(home_device_counts_total_parsed_monthly, na.rm = TRUE),
      device_counts_row_total_annual_total = sum(device_counts_row_total_monthly, na.rm = TRUE),
      n_months_neighbor_visit = dplyr::n(),
      .groups = "drop"
    ) |>
    mutate(
      neighbor_visit_share_annual_weighted = dplyr::if_else(
        home_device_counts_total_parsed_annual_total > 0,
        neighbor_visit_count_annual_total / home_device_counts_total_parsed_annual_total,
        NA_real_
      ),
      target_year = target_year,
      start_month = start_month,
      end_month = end_month,
      period_label = period_label
    )
} else {
  message("YEAR/MONTH columns not available. Building tract summaries from the provided rows only.")
  
  tract_annual_dt <- neighbor_dt |>
    group_by(city, TRACT_GEOID) |>
    summarise(
      neighbor_visit_count_annual_avg = mean(NEIGHBOR_HOME_DEVICE_COUNTS, na.rm = TRUE),
      home_device_counts_total_parsed_annual_avg = mean(HOME_DEVICE_COUNTS_TOTAL_PARSED, na.rm = TRUE),
      device_counts_row_total_annual_avg = mean(DEVICE_COUNTS_ROW_TOTAL, na.rm = TRUE),
      neighbor_home_cbg_count_annual_avg = mean(NEIGHBOR_HOME_CBG_COUNT, na.rm = TRUE),
      neighbor_visit_share_annual_avg = mean(NEIGHBOR_HOME_DEVICE_SHARE, na.rm = TRUE),
      neighbor_visit_count_annual_total = sum(NEIGHBOR_HOME_DEVICE_COUNTS, na.rm = TRUE),
      home_device_counts_total_parsed_annual_total = sum(HOME_DEVICE_COUNTS_TOTAL_PARSED, na.rm = TRUE),
      device_counts_row_total_annual_total = sum(DEVICE_COUNTS_ROW_TOTAL, na.rm = TRUE),
      n_months_neighbor_visit = dplyr::n(),
      .groups = "drop"
    ) |>
    mutate(
      neighbor_visit_share_annual_weighted = dplyr::if_else(
        home_device_counts_total_parsed_annual_total > 0,
        neighbor_visit_count_annual_total / home_device_counts_total_parsed_annual_total,
        NA_real_
      ),
      target_year = target_year,
      start_month = start_month,
      end_month = end_month,
      period_label = period_label
    )
}

base_dt <- readRDS(paste0(generated.data.folder, "data_models.rds")) |>
  mutate(
    GEOID = pad_geoid(GEOID, 11),
    city = as.character(city)
  )

model_dt <- base_dt |>
  left_join(
    tract_annual_dt,
    by = c("GEOID" = "TRACT_GEOID", "city" = "city")
  )

saveRDS(tract_annual_dt, output_summary_path)
saveRDS(model_dt, output_model_path)

readr::write_csv(
  tract_annual_dt,
  str_replace(output_summary_path, "\\.rds$", ".csv")
)

message("Neighbor annual-average tract summary saved to: ", output_summary_path)
message("Merged modeling dataset saved to: ", output_model_path)
message("Rows in tract summary: ", nrow(tract_annual_dt))
message("Rows in merged modeling dataset: ", nrow(model_dt))
message("Period label: ", period_label)
