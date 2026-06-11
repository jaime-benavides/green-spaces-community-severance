rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(readr)

dt <- readRDS(paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"
))

missing <- filter(dt, is.na(neighbor_visit_count_annual_avg))
present <- filter(dt, !is.na(neighbor_visit_count_annual_avg))

fmt_med_iqr <- function(x) {
  med <- median(x, na.rm = TRUE)
  q1  <- quantile(x, 0.25, na.rm = TRUE)
  q3  <- quantile(x, 0.75, na.rm = TRUE)
  # pick decimal places based on magnitude
  dp <- if (abs(med) >= 100) 0 else if (abs(med) >= 1) 1 else 3
  sprintf(paste0("%.", dp, "f (%.", dp, "f--%.", dp, "f)"), med, q1, q3)
}

fmt_n_pct <- function(n, total) {
  sprintf("%d (%.1f\\%%)", n, n / total * 100)
}

n_miss <- nrow(missing)
n_pres <- nrow(present)

rows <- list()

# --- City ---
rows[["City: NYC"]] <- c(
  fmt_n_pct(sum(missing$city == "NYC"), n_miss),
  fmt_n_pct(sum(present$city == "NYC"), n_pres)
)
rows[["City: LA"]] <- c(
  fmt_n_pct(sum(missing$city == "LA"), n_miss),
  fmt_n_pct(sum(present$city == "LA"), n_pres)
)

# --- Continuous ---
cont_vars <- list(
  "Population density (per sq mi)"       = "pop_dens",
  "Total population"                      = "TotPop",
  "Building density"                      = "building_density",
  "Community Severance Index"             = "community_severance_index",
  "NDVI"                                  = "NDVI",
  "Distance to nearest green space (m)"  = "closest_greenspace",
  "ICE income"                            = "ICE_inc",
  "\\% Poverty"                           = "perc.pov",
  "\\% Black"                             = "perc.black",
  "\\% Hispanic"                          = "perc.hisp"
)

for (label in names(cont_vars)) {
  v <- cont_vars[[label]]
  rows[[label]] <- c(fmt_med_iqr(missing[[v]]), fmt_med_iqr(present[[v]]))
}

# --- ICE income quintile ---
quintile_levels <- c(
  "Q1 (Most Disadvantaged)", "Q2", "Q3", "Q4", "Q5 (Most Advantaged)"
)
for (ql in quintile_levels) {
  rows[[paste0("\\hspace{1em}", ql)]] <- c(
    fmt_n_pct(sum(missing$ICE_inc_quintile == ql, na.rm = TRUE), n_miss),
    fmt_n_pct(sum(present$ICE_inc_quintile == ql, na.rm = TRUE), n_pres)
  )
}

# --- Build LaTeX ---
header <- c(
  "\\begin{table}[h]",
  "\\centering",
  paste0(
    "\\caption{Characteristics of census tracts excluded for missing ",
    "neighboring-home visits data compared with the analytic sample, ",
    "New York City and Los Angeles, 2019}"
  ),
  "\\label{tab:nh_missingness}",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  paste0(
    "Characteristic & Missing NH data & Analytic sample \\\\"
  ),
  paste0(
    " & ($n$ = ", n_miss, ") & ($n$ = ", n_pres, ") \\\\"
  ),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Categorical variables, $N$ (\\%)}} \\\\"
)

body <- character(0)
categorical_done <- FALSE
continuous_started <- FALSE
quintile_started <- FALSE

for (label in names(rows)) {
  vals <- rows[[label]]
  # insert section headers
  if (label == "Population density (per sq mi)" && !continuous_started) {
    body <- c(body, "\\multicolumn{3}{l}{\\textit{Continuous variables, median (IQR)}} \\\\")
    continuous_started <- TRUE
  }
  if (grepl("Q1", label) && !quintile_started) {
    body <- c(body, "ICE income quintile & & \\\\")
    quintile_started <- TRUE
  }
  body <- c(body, paste0(label, " & ", vals[1], " & ", vals[2], " \\\\"))
}

footer <- c(
  "\\bottomrule",
  "\\end{tabular}",
  "\\par\\vspace{0.5em}",
  paste0(
    "{\\footnotesize IQR = interquartile range. ICE = Index of Concentration ",
    "at the Extremes. NDVI = Normalized Difference Vegetation Index. ",
    "Continuous variables presented as median (Q1--Q3). Missing rate by ",
    "ICE income quintile: Q1 = 6.6\\%, Q2 = 7.3\\%, Q3 = 8.3\\%, ",
    "Q4 = 8.7\\%, Q5 = 8.7\\%.}"
  ),
  "\\end{table}"
)

latex_lines <- c(header, body, footer)

out_path <- paste0(output.folder, "supp_table_nh_missingness.tex")
writeLines(latex_lines, out_path)
message("Supplementary missingness table saved to: ", out_path)

# Copy to manuscript/tables/ for Overleaf compilation (consistent with Tables 1 and 2)
ms_tables_path <- paste0(project.folder, "manuscript/tables/supp_table_nh_missingness.tex")
file.copy(out_path, ms_tables_path, overwrite = TRUE)
message("Copied to: ", ms_tables_path)
