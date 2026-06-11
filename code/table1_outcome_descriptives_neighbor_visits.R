rm(list = ls())

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

# ---- Variable sets ----
outcomes_map <- c(
  NDVI = "NDVI",
  closest_greenspace = "Distance to nearest green space (m)",
  neighbor_visit_count_annual_avg =
    "Neighboring-home visits (annual avg count)",
  neighbor_visit_share_annual_avg =
    "Neighboring-home visits (annual avg share)"
)

exposure_covariates_map <- c(
  community_severance_index = "Community Severance Index",
  perc.black                = "Percent Black",
  perc.hisp                 = "Percent Hispanic",
  perc.pov                  = "Percent poverty",
  pop_dens                  = "Population density",
  building_density          = "Building density",
  ICE_inc                   = "Income ICE"
)

# section_breaks for Table 2: named integer vector row-index -> section label
# header is inserted before that row
tbl2_breaks <- c("Exposure" = 1L, "Covariates" = 2L)

city_n <- c(
  NYC = sum(dt$city == "NYC"),
  LA  = sum(dt$city == "LA")
)

summarise_var <- function(x) {
  n_miss   <- sum(is.na(x))
  miss_pct <- round(100 * n_miss / length(x), 1)
  list(
    n_nonmissing = sum(!is.na(x)),
    n_missing    = n_miss,
    missing_pct  = miss_pct,
    median       = round(median(x, na.rm = TRUE), 3),
    p25          = round(quantile(x, 0.25, na.rm = TRUE), 3),
    p75          = round(quantile(x, 0.75, na.rm = TRUE), 3)
  )
}

build_summary <- function(var_map) {
  rows <- lapply(names(var_map), function(var) {
    label <- var_map[[var]]
    if (!var %in% names(dt)) return(NULL)
    out <- data.frame(label = label, stringsAsFactors = FALSE)
    for (city in c("NYC", "LA")) {
      x <- dt[[var]][dt$city == city]
      s <- summarise_var(x)
      out[[paste0(city, "_n")]]        <- s$n_nonmissing
      out[[paste0(city, "_n_miss")]]   <- s$n_missing
      out[[paste0(city, "_miss_pct")]] <- s$missing_pct
      out[[paste0(city, "_median")]]   <- s$median
      out[[paste0(city, "_p25")]]      <- s$p25
      out[[paste0(city, "_p75")]]      <- s$p75
    }
    out
  })
  bind_rows(rows)
}

fmt_cell <- function(median, p25, p75, n_miss) {
  cell <- paste0(median, " [", p25, ", ", p75, "]")
  if (n_miss > 0) {
    cell <- paste0(cell, "\\textsuperscript{*}")
  }
  cell
}

write_table <- function(summary_tbl, caption, label,
                        csv_path, tex_path,
                        section_breaks = NULL) {
  write_csv(summary_tbl, csv_path)

  nyc_col <- paste0(
    "NYC ($n$ = ",
    formatC(city_n[["NYC"]], format = "d", big.mark = "{,}"),
    ")"
  )
  la_col <- paste0(
    "LA ($n$ = ",
    formatC(city_n[["LA"]], format = "d", big.mark = "{,}"),
    ")"
  )

  header <- paste(
    "\\begin{table}[ht]",
    "\\centering",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{", label, "}"),
    "\\small",
    "\\begin{tabular}{lcc}",
    "\\toprule",
    paste0("Variable & ", nyc_col, " & ", la_col, " \\\\"),
    "\\midrule",
    sep = "\n"
  )

  body_lines <- character(0)

  for (i in seq_len(nrow(summary_tbl))) {
    if (!is.null(section_breaks) && i %in% section_breaks) {
      sec_name <- names(section_breaks)[section_breaks == i]
      body_lines <- c(
        body_lines,
        paste0(
          "\\multicolumn{3}{l}{\\textbf{", sec_name, "}} \\\\"
        )
      )
    }
    row      <- summary_tbl[i, ]
    nyc_cell <- fmt_cell(
      row$NYC_median, row$NYC_p25, row$NYC_p75, row$NYC_n_miss
    )
    la_cell <- fmt_cell(
      row$LA_median, row$LA_p25, row$LA_p75, row$LA_n_miss
    )
    body_lines <- c(
      body_lines,
      paste0(
        "\\quad ", row$label,
        " & ", nyc_cell,
        " & ", la_cell, " \\\\"
      )
    )
  }

  miss_rows <- summary_tbl$NYC_n_miss > 0 | summary_tbl$LA_n_miss > 0
  if (any(miss_rows)) {
    miss_parts <- vapply(which(miss_rows), function(i) {
      row <- summary_tbl[i, ]
      parts <- character(0)
      if (row$NYC_n_miss > 0) parts <- c(parts, paste0("NYC $n$ = ", row$NYC_n_miss))
      if (row$LA_n_miss  > 0) parts <- c(parts, paste0("LA $n$ = ",  row$LA_n_miss))
      paste0(row$label, " (", paste(parts, collapse = ", "), ")")
    }, character(1))
    footnote <- paste0(
      "\\multicolumn{3}{p{0.9\\textwidth}}{",
      "\\textsuperscript{*}Missing: ",
      paste(miss_parts, collapse = "; "),
      ".} \\\\"
    )
  } else {
    footnote <- ""
  }

  footer <- paste(
    "\\bottomrule",
    if (nchar(footnote) > 0) footnote else "",
    "\\end{tabular}",
    "\\end{table}",
    sep = "\n"
  )

  writeLines(c(header, body_lines, footer), tex_path)
}

# ---- Table 1: Outcomes ----
tbl1 <- build_summary(outcomes_map)

write_table(
  summary_tbl = tbl1,
  caption     = paste0(
    "Descriptive statistics for study outcomes in the 2019 ",
    "analytic sample, separately for NYC and LA. ",
    "Values are median [P25, P75]."
  ),
  label    = "tab:outcomes_descriptives",
  csv_path = paste0(output.folder, "table1_outcomes_", output_label, ".csv"),
  tex_path = paste0(output.folder, "table1_outcomes_", output_label, ".tex")
)

message(
  "Table 1 (outcomes) saved to: ",
  output.folder, "table1_outcomes_", output_label, ".{csv,tex}"
)

# ---- Table 2: Exposure and Covariates ----
tbl2 <- build_summary(exposure_covariates_map)

write_table(
  summary_tbl    = tbl2,
  caption        = paste0(
    "Descriptive statistics for the exposure and covariates ",
    "in the 2019 analytic sample, separately for NYC and LA. ",
    "Values are median [P25, P75]."
  ),
  label          = "tab:exposure_covariates_descriptives",
  csv_path       = paste0(
    output.folder, "table2_exposure_covariates_", output_label, ".csv"
  ),
  tex_path       = paste0(
    output.folder, "table2_exposure_covariates_", output_label, ".tex"
  ),
  section_breaks = tbl2_breaks
)

message(
  "Table 2 (exposure & covariates) saved to: ",
  output.folder, "table2_exposure_covariates_", output_label, ".{csv,tex}"
)
