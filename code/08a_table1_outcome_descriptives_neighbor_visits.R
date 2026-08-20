rm(list = ls())

# 08a_table1_outcome_descriptives_neighbor_visits.R
# Purpose: Builds Table 1 (outcomes, exposure & covariates).

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(dplyr)
library(readr)

args <- commandArgs(trailingOnly = TRUE)

default_label <- "2019_full_year"
default_input <- paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_",
  default_label,
  ".rds"
)

input_path   <- if (length(args) >= 1) args[[1]] else default_input
output_label <- if (length(args) >= 2) args[[2]] else default_label

if (!file.exists(input_path)) stop("Input dataset not found: ", input_path)

dt <- readRDS(input_path)

city_n <- c(
  LA  = sum(dt$city == "LA"),
  NYC = sum(dt$city == "NYC")
)

stats_for <- function(x) {
  list(
    n_missing = sum(is.na(x)),
    median    = median(x, na.rm = TRUE),
    p25       = quantile(x, 0.25, na.rm = TRUE),
    p75       = quantile(x, 0.75, na.rm = TRUE)
  )
}

# variable, city -> raw stats
row_stats <- function(var, transform = identity) {
  out <- list()
  for (city in c("LA", "NYC")) {
    x <- transform(dt[[var]][dt$city == city])
    out[[city]] <- stats_for(x)
  }
  out
}

fmt_num <- function(s, dp) {
  sprintf(
    paste0("%.", dp, "f [%.", dp, "f, %.", dp, "f]"),
    s$median, s$p25, s$p75
  )
}

fmt_pct <- function(s) {
  sprintf(
    "%.1f\\%% [%.1f\\%%, %.1f\\%%]",
    100 * s$median, 100 * s$p25, 100 * s$p75
  )
}

# ---- Rows: variable name, formatter, decimal places / transform, footnote letter ----
rows <- list(
  list(
    section = "Outcomes",
    label   = "Neighboring-home visits (annual avg count)",
    stats   = row_stats("neighbor_visit_count_annual_avg"),
    fmt     = function(s) fmt_num(s, 0),
    footnote_letter = "a",
    footnote_text = paste0(
      "Neighboring-home visits: census tracts without a destination ",
      "census block group intersecting an accessible green space (see ",
      "Methods) were excluded from the analysis: LA $n$ = %s, NYC $n$ = %s."
    )
  ),
  list(
    section = "Outcomes",
    label   = "NDVI",
    stats   = row_stats("NDVI"),
    fmt     = function(s) fmt_num(s, 2),
    footnote_letter = "b",
    footnote_text = paste0(
      "NDVI: values were obtained from an external greenness dataset ",
      "\\cite{Brochu2022Benefits}, whose tract coverage excludes tracts ",
      "with zero population aged 65 and older, negative mean NDVI, or ",
      "county-level mortality-data suppression; tracts outside that ",
      "coverage were excluded from this variable: LA $n$ = %s, NYC $n$ = %s."
    )
  ),
  list(
    section = "Outcomes",
    label   = "Distance to nearest green space (m)",
    stats   = row_stats("closest_greenspace"),
    fmt     = function(s) fmt_num(s, 0),
    footnote_letter = NA,
    footnote_text = NA
  ),
  list(
    section = "Exposure",
    label   = "Community Severance Index",
    stats   = row_stats("community_severance_index"),
    fmt     = function(s) fmt_num(s, 2),
    footnote_letter = "c",
    footnote_text = "Missing Community Severance Index: LA $n$ = %s, NYC $n$ = %s."
  ),
  list(
    section = "Covariates",
    label   = "Percent Black",
    stats   = row_stats("perc.black"),
    fmt     = fmt_pct,
    footnote_letter = "d",
    footnote_text = "Missing Percent Black: LA $n$ = %s, NYC $n$ = %s."
  ),
  list(
    section = "Covariates",
    label   = "Percent Hispanic",
    stats   = row_stats("perc.hisp"),
    fmt     = fmt_pct,
    footnote_letter = "e",
    footnote_text = "Missing Percent Hispanic: LA $n$ = %s, NYC $n$ = %s."
  ),
  list(
    section = "Covariates",
    label   = "Percent poverty",
    stats   = row_stats("perc.pov"),
    fmt     = fmt_pct,
    footnote_letter = "f",
    footnote_text = "Missing Percent poverty: LA $n$ = %s, NYC $n$ = %s."
  ),
  list(
    section = "Covariates",
    label   = "Population density (thousands per km\\textsuperscript{2})",
    stats   = row_stats("pop_dens", transform = function(x) x / 1000),
    fmt     = function(s) fmt_num(s, 2),
    footnote_letter = NA,
    footnote_text = NA
  ),
  list(
    section = "Covariates",
    label   = "Building density (footprint/tract area)",
    stats   = row_stats("building_density"),
    fmt     = function(s) fmt_num(s, 2),
    footnote_letter = NA,
    footnote_text = NA
  ),
  list(
    section = "Covariates",
    label   = "ICE",
    stats   = row_stats("ICE_inc"),
    fmt     = function(s) fmt_num(s, 2),
    footnote_letter = "g",
    footnote_text = "Missing ICE: LA $n$ = %s, NYC $n$ = %s."
  )
)

nyc_col <- paste0(
  "NYC ($n$ = ", formatC(city_n[["NYC"]], format = "d", big.mark = ","), ")"
)
la_col <- paste0(
  "LA ($n$ = ", formatC(city_n[["LA"]], format = "d", big.mark = ","), ")"
)

header <- c(
  "\\begin{table}[ht]",
  "\\centering",
  paste0(
    "\\caption{Descriptive statistics for the study outcomes, exposure, ",
    "and covariates in the 2019 analytic sample, separately for LA and ",
    "NYC. Values are median [P25, P75].}"
  ),
  "\\label{tab:outcomes_exposure_covariates_descriptives}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  paste0("Variable & ", la_col, " & ", nyc_col, " \\\\"),
  "\\midrule"
)

body <- character(0)
footnotes <- character(0)
current_section <- ""

for (row in rows) {
  if (row$section != current_section) {
    body <- c(body, paste0("\\multicolumn{3}{l}{\\textbf{", row$section, "}} \\\\"))
    current_section <- row$section
  }

  la_cell  <- row$fmt(row$stats[["LA"]])
  nyc_cell <- row$fmt(row$stats[["NYC"]])

  label <- row$label
  if (!is.na(row$footnote_letter)) {
    label <- paste0(label, "\\textsuperscript{", row$footnote_letter, "}")
    footnotes <- c(
      footnotes,
      paste0(
        "\\multicolumn{3}{p{0.9\\textwidth}}{\\textsuperscript{",
        row$footnote_letter, "}",
        sprintf(
          row$footnote_text,
          row$stats[["LA"]]$n_missing, row$stats[["NYC"]]$n_missing
        ),
        "} \\\\"
      )
    )
  }

  body <- c(body, paste0("\\quad ", label, " & ", la_cell, " & ", nyc_cell, " \\\\"))
}

footer <- c(
  "\\bottomrule",
  footnotes,
  "\\end{tabular}",
  "\\end{table}"
)

latex_lines <- c(header, body, footer)

tex_path <- paste0(output.folder, "table1_descriptives_", output_label, ".tex")
writeLines(latex_lines, tex_path)
message("Table 1 (outcomes, exposure & covariates) saved to: ", tex_path)
