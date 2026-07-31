rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(readr)

dt <- readRDS(paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"
))

fmt_med_iqr <- function(x) {
  med <- median(x, na.rm = TRUE)
  q1  <- quantile(x, 0.25, na.rm = TRUE)
  q3  <- quantile(x, 0.75, na.rm = TRUE)
  # pick decimal places based on magnitude (max 2)
  dp <- if (abs(med) >= 100) 0 else if (abs(med) >= 1) 1 else 2
  sprintf(paste0("%.", dp, "f (%.", dp, "f, %.", dp, "f)"), med, q1, q3)
}

fmt_n_pct <- function(n, total) {
  sprintf("%d (%.1f\\%%)", n, n / total * 100)
}

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

quintile_levels <- c(
  "Q1 (Most Disadvantaged)", "Q2", "Q3", "Q4", "Q5 (Most Advantaged)"
)

# exclusion-reason breakdown, traced to output/nh_exclusion_reason_diagnosis.csv
# (code/diagnose_nh_exclusion_reason.R), split by city
excl_reason <- read_csv(
  paste0(output.folder, "nh_exclusion_reason_diagnosis.csv"),
  show_col_types = FALSE
)

build_city_subtable <- function(city_label, city_name, label_suffix) {
  missing <- filter(dt, city == city_label, is.na(neighbor_visit_count_annual_avg))
  present <- filter(dt, city == city_label, !is.na(neighbor_visit_count_annual_avg))

  n_miss <- nrow(missing)
  n_pres <- nrow(present)

  rows <- list()

  for (label in names(cont_vars)) {
    v <- cont_vars[[label]]
    rows[[label]] <- c(fmt_med_iqr(missing[[v]]), fmt_med_iqr(present[[v]]))
  }

  for (ql in quintile_levels) {
    rows[[paste0("\\hspace{1em}", ql)]] <- c(
      fmt_n_pct(sum(missing$ICE_inc_quintile == ql, na.rm = TRUE), n_miss),
      fmt_n_pct(sum(present$ICE_inc_quintile == ql, na.rm = TRUE), n_pres)
    )
  }

  header <- c(
    "\\begin{subtable}{\\textwidth}",
    "\\centering",
    paste0("\\subcaption{", city_name, "}"),
    paste0("\\label{tab:nh_missingness_", label_suffix, "}"),
    "\\small",
    "\\begin{tabular}{lcc}",
    "\\toprule",
    "Characteristic & Excluded tracts & Analytic sample \\\\",
    paste0(
      " & ($n$ = ", n_miss, ") & ($n$ = ", n_pres, ") \\\\"
    ),
    "\\midrule",
    "\\multicolumn{3}{c}{\\textit{Continuous variables, median (IQR)}} \\\\"
  )

  body <- character(0)
  quintile_started <- FALSE

  for (label in names(rows)) {
    vals <- rows[[label]]
    if (grepl("Q1", label) && !quintile_started) {
      body <- c(
        body,
        "\\multicolumn{3}{c}{\\textit{Categorical variables, $N$ (\\%)}} \\\\",
        "ICE income quintile & & \\\\"
      )
      quintile_started <- TRUE
    }
    body <- c(body, paste0(label, " & ", vals[1], " & ", vals[2], " \\\\"))
  }

  city_excl <- filter(excl_reason, city == city_label)
  n_structural <- sum(city_excl$exclusion_reason ==
    "structural_no_greenspace_cbg_confirmed", na.rm = TRUE)
  n_data_gap <- sum(is.na(city_excl$exclusion_reason))

  reason_sentence <- if (n_data_gap > 0) {
    paste0(
      "Of the $n$ = ", formatC(n_miss, big.mark = ","),
      " excluded tracts, ", n_structural, " (",
      sprintf("%.1f", 100 * n_structural / n_miss),
      "\\%) have no destination census block group intersecting an ",
      "accessible green space; the remaining ", n_data_gap, " (",
      sprintf("%.1f", 100 * n_data_gap / n_miss),
      "\\%) have no Advan device-location data reported for any census ",
      "block group in the tract."
    )
  } else {
    paste0(
      "Of the $n$ = ", formatC(n_miss, big.mark = ","),
      " excluded tracts, all ", n_structural,
      " (100\\%) have no destination census block group intersecting an ",
      "accessible green space."
    )
  }

  footer <- c(
    "\\bottomrule",
    "\\end{tabular}",
    "\\par\\vspace{0.5em}",
    paste0(
      "{\\footnotesize ", reason_sentence, "}"
    ),
    "\\end{subtable}"
  )

  c(header, body, footer)
}

la_subtable  <- build_city_subtable("LA", "Los Angeles", "la")
nyc_subtable <- build_city_subtable("NYC", "New York City", "nyc")

outer_header <- c(
  "\\begin{table}[h]",
  "\\centering",
  paste0(
    "\\caption{Characteristics of census tracts excluded from the ",
    "neighboring-home visits analysis compared with the analytic sample, ",
    "New York City and Los Angeles, 2019}"
  ),
  "\\label{tab:nh_missingness}"
)

outer_footer <- c(
  "\\par\\vspace{0.5em}",
  paste0(
    "{\\footnotesize IQR = interquartile range. ICE = Index of ",
    "Concentration at the Extremes. NDVI = Normalized Difference ",
    "Vegetation Index. Continuous variables presented as median ",
    "(Q1, Q3). \\textsuperscript{*}ICE income quintile was missing for a ",
    "small number of tracts in each group (LA: 5 excluded, 7 analytic; ",
    "NYC: 11 excluded, 37 analytic) and is not shown as a separate row; ",
    "quintile counts therefore do not sum to the column $n$.}"
  ),
  "\\end{table}"
)

latex_lines <- c(
  outer_header,
  la_subtable, "", "\\vspace{1em}", "",
  nyc_subtable,
  outer_footer
)

out_path <- paste0(output.folder, "supp_table_nh_missingness.tex")
writeLines(latex_lines, out_path)
message("Supplementary missingness table saved to: ", out_path)

# Copy to manuscript/tables/ for Overleaf compilation (consistent with Tables 1 and 2)
ms_tables_path <- paste0(project.folder, "manuscript/tables/supp_table_nh_missingness.tex")
file.copy(out_path, ms_tables_path, overwrite = TRUE)
message("Copied to: ", ms_tables_path)
