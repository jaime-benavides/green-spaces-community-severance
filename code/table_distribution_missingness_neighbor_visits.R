rm(list = ls())

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(dplyr)
library(readr)
library(stringr)

args <- commandArgs(trailingOnly = TRUE)

default_label <- "2019_full_year"
default_input_path <- paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_",
  default_label,
  ".rds"
)
default_csv_path <- paste0(
  output.folder,
  "table_distribution_missingness_",
  default_label,
  ".csv"
)
default_tex_path <- paste0(
  output.folder,
  "table_distribution_missingness_",
  default_label,
  ".tex"
)

input_path <- if (length(args) >= 1) args[[1]] else default_input_path
output_csv_path <- if (length(args) >= 2) args[[2]] else default_csv_path
output_tex_path <- if (length(args) >= 3) args[[3]] else default_tex_path

if (!file.exists(input_path)) {
  stop("Input dataset not found: ", input_path)
}

dt <- readRDS(input_path)

variable_map <- c(
  community_severance_index = "Community Severance Index",
  pop_dens = "Population density",
  building_density = "Building density",
  perc.black = "Percent Black",
  perc.hisp = "Percent Hispanic",
  perc.pov = "Percent poverty",
  home_device_counts_total_parsed_annual_avg = "Parsed home-device annual average total",
  device_counts_row_total_annual_avg = "Row-total device annual average total"
)

vars_to_summarize <- names(variable_map)[names(variable_map) %in% names(dt)]

if (length(vars_to_summarize) == 0) {
  stop("None of the expected variables were found in the dataset.")
}

summary_table <- bind_rows(lapply(vars_to_summarize, function(var_name) {
  x <- dt[[var_name]]
  data.frame(
    variable = var_name,
    label = variable_map[[var_name]],
    n_nonmissing = sum(!is.na(x)),
    missing = sum(is.na(x)),
    missing_pct = round(mean(is.na(x)) * 100, 1),
    mean = round(mean(x, na.rm = TRUE), 3),
    sd = round(sd(x, na.rm = TRUE), 3),
    median = round(median(x, na.rm = TRUE), 3),
    p25 = round(as.numeric(quantile(x, 0.25, na.rm = TRUE)), 3),
    p75 = round(as.numeric(quantile(x, 0.75, na.rm = TRUE)), 3),
    min = round(min(x, na.rm = TRUE), 3),
    max = round(max(x, na.rm = TRUE), 3),
    stringsAsFactors = FALSE
  )
}))

write_csv(summary_table, output_csv_path)

latex_lines <- c(
  "\\begin{table}[h]",
  "\\centering",
  "\\caption{Distribution and missingness of the exposure, covariates, and neighboring-home denominator variables in the tract-level analytic sample}",
  "\\label{tab:dist_missing_neighbor}",
  "\\resizebox{\\textwidth}{!}{",
  "\\begin{tabular}{lrrrrrrrrrr}",
  "\\toprule",
  "Variable & Non-missing & Missing & Missing \\% & Mean & SD & Median & P25 & P75 & Min & Max \\\\",
  "\\midrule"
)

body_lines <- apply(summary_table, 1, function(row) {
  paste0(
    row[["label"]], " & ",
    row[["n_nonmissing"]], " & ",
    row[["missing"]], " & ",
    row[["missing_pct"]], " & ",
    row[["mean"]], " & ",
    row[["sd"]], " & ",
    row[["median"]], " & ",
    row[["p25"]], " & ",
    row[["p75"]], " & ",
    row[["min"]], " & ",
    row[["max"]], " \\\\"
  )
})

latex_lines <- c(
  latex_lines,
  body_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "}",
  "\\end{table}"
)

writeLines(latex_lines, output_tex_path)

message("Distribution/missingness CSV saved to: ", output_csv_path)
message("Distribution/missingness LaTeX saved to: ", output_tex_path)
