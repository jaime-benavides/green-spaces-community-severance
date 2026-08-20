rm(list = ls())

# generate_supp_table_s2_per_iqr.R
# Purpose: Formats Supplementary Table S2 (quartile contrasts) as LaTeX
#          from the extracted numeric-results CSV.

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(readr)

csv <- read_csv(
  paste0(output.folder, "numeric_results_quartile_contrasts.csv"),
  show_col_types = FALSE
)

# round-half-away-from-zero, immune to floating-point boundary artifacts
# (e.g. sprintf("%.2f", -0.615) == "-0.61" because -0.615 is stored as
# -0.61499999999999999... in binary; nudging by a tiny epsilon before
# rounding avoids this class of silent off-by-one-digit error)
round_half_up <- function(x, dp) {
  scale <- 10^dp
  sign(x) * floor(abs(x) * scale + 0.5 + 1e-9) / scale
}

fmt_signed <- function(x, dp) {
  s <- sprintf(paste0("%.", dp, "f"), abs(round_half_up(x, dp)))
  if (x < 0) paste0("$-$", s) else paste0("\\phantom{$-$}", s)
}

fmt_plain_signed <- function(x, dp) {
  s <- sprintf(paste0("%.", dp, "f"), abs(round_half_up(x, dp)))
  if (x < 0) paste0("$-$", s) else s
}

# CSI quantile cell: signed, 2dp, no phantom padding
csi_cell <- function(x) fmt_plain_signed(x, 2)

# NDVI contrast cell: signed, 3dp, phantom-padded for column alignment
ndvi_cell <- function(estimate, ci_low, ci_high) {
  paste0(
    fmt_signed(estimate, 3),
    " (", fmt_signed(ci_low, 3), ", ", fmt_signed(ci_high, 3), ")"
  )
}

# IRR/ratio contrast cell: plain, 2dp (always positive)
ratio_cell <- function(estimate, ci_low, ci_high) {
  sprintf(
    "%.2f (%.2f, %.2f)",
    round_half_up(estimate, 2), round_half_up(ci_low, 2), round_half_up(ci_high, 2)
  )
}

get_contrast <- function(outcome, city, contrast) {
  row <- csv[csv$outcome == outcome & csv$city == city & csv$contrast == contrast, ]
  if (nrow(row) != 1) stop(
    "Expected exactly 1 row for ", outcome, "/", city, "/", contrast,
    ", found ", nrow(row)
  )
  row
}

# Build one outcome block: two city rows under an italic outcome header
build_block <- function(outcome, header_text, cell_fun) {
  rows <- character(0)
  for (city in c("LA", "NYC")) {
    c25_50 <- get_contrast(outcome, city, "Q50_vs_Q25")
    c50_75 <- get_contrast(outcome, city, "Q75_vs_Q50")
    c25_75 <- get_contrast(outcome, city, "Q75_vs_Q25")

    city_label <- if (city == "LA") "LA " else "NYC"

    rows <- c(rows, paste0(
      " & ", city_label, " & ",
      csi_cell(c25_50$csi_q25), " & ", csi_cell(c25_50$csi_q50), " & ",
      csi_cell(c50_75$csi_q75),
      "\n   & ", cell_fun(c25_50$estimate, c25_50$ci_low_95, c25_50$ci_high_95),
      "\n   & ", cell_fun(c50_75$estimate, c50_75$ci_low_95, c50_75$ci_high_95),
      "\n   & ", cell_fun(c25_75$estimate, c25_75$ci_low_95, c25_75$ci_high_95),
      " \\\\"
    ))
  }
  c(
    paste0("\\multicolumn{8}{l}{\\textit{", header_text, "}} \\\\[3pt]"),
    rows
  )
}

nh_block <- build_block(
  "neighbor_visit_count_annual_avg",
  "Neighboring-home visits (incidence rate ratio)",
  ratio_cell
)
ndvi_block <- build_block(
  "NDVI",
  "NDVI (absolute difference, NDVI units)",
  ndvi_cell
)
dist_block <- build_block(
  "closest_greenspace",
  "Distance to nearest green space (ratio)",
  ratio_cell
)

header <- c(
  "\\begin{landscape}",
  "\\begin{table}[h]",
  paste0(
    "\\caption{Quartile contrasts for all outcomes from the primary ",
    "analysis (outlier-excluded, fully adjusted models). Estimates ",
    "reflect the predicted change in each outcome when moving between ",
    "the stated CSI quantiles, with all other covariates held at ",
    "city-specific means and the neighborhood random intercept at its ",
    "reference level. CSI quantile values shown are computed from the ",
    "outlier-excluded analytic sample for each outcome within each ",
    "city; NDVI and proximity quantiles are based on all ",
    "outlier-excluded tracts, while NH quantiles are based on the NH ",
    "analytic sample (tracts with at least one destination CBG ",
    "intersecting a PAD-US AR polygon). Contrasts cross the null where ",
    "the 95\\% CI includes 0 (NDVI) or 1 (IRR, ratio). All models are ",
    "penalized smoothing splines (REML) for CSI with neighborhood ",
    "random intercepts.}"
  ),
  "\\label{tab:quartile_contrasts}",
  "\\renewcommand{\\arraystretch}{1.2}",
  "\\begin{tabular}{@{}llccccccc@{}}",
  "\\toprule",
  paste0(
    "Outcome & City & CSI$_{Q25}$ & CSI$_{Q50}$ & CSI$_{Q75}$ & ",
    "\\multicolumn{3}{c}{Contrast (95\\% CI)} \\\\"
  ),
  "\\cmidrule(l){6-8}",
  " &  &  &  &  & Q25$\\to$Q50 & Q50$\\to$Q75 & Q25$\\to$Q75 \\\\",
  "\\midrule"
)

footer <- c(
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}",
  "\\end{landscape}"
)

# insert [6pt] spacing between blocks by tacking onto last row of each
# non-final block
nh_block[length(nh_block)] <- paste0(nh_block[length(nh_block)], "[6pt]")
ndvi_block[length(ndvi_block)] <- paste0(ndvi_block[length(ndvi_block)], "[6pt]")

latex_lines <- c(header, nh_block, ndvi_block, dist_block, footer)

tex_path <- paste0(output.folder, "supp_table_s2_per_iqr.tex")
writeLines(latex_lines, tex_path)
message("Supplementary Table S2 saved to: ", tex_path)
