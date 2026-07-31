rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(dplyr)
library(tibble)
library(readr)

# =============================================================================
# extract_ice_effect_modification_difference_contrasts.R
#
# Purpose: Replace the informal "the two ICE-stratum CIs overlapped, so this
#          does not provide clear evidence of effect modification" heuristic
#          in the Secondary analysis Results (sn-article.tex) with an
#          explicit Q1-vs-Q5 CONTRAST-OF-CONTRASTS estimate that has its own
#          95% CI, for the Q25-to-Q75 CSI quartile contrast within each ICE
#          stratum, city, and outcome.
#
#          This follows the same convention as bne_uncertainty_ses_multiyear
#          (03_explore_results/contrast_main_rev.R, compute_strata_delta()):
#          the Q1 and Q5 stratum-specific quartile-contrast estimates are
#          from two SEPARATE models fit on disjoint (non-overlapping) tract
#          subsets, so they are statistically independent, and
#            Var(contrast_Q5 - contrast_Q1) = Var(contrast_Q5) + Var(contrast_Q1).
#          Each stratum's SE is recovered from its already-reported 95% CI
#          width (CI = estimate +/- 1.96*SE), on the scale the stratum
#          estimate was originally computed on (log scale for ratio/IRR
#          outcomes, natural scale for the Gaussian NDVI estimate), i.e. the
#          same ci_to_se() logic used in contrast_main_rev.R.
#
# Inputs:  output/numeric_results_ice_nh_quartile_contrasts.csv
#          output/numeric_results_ice_ndvi_quartile_contrasts.csv
#          output/numeric_results_ice_distance_quartile_contrasts.csv
#          (produced by extract_ice_nh_quartile_contrasts.R,
#           extract_ice_ndvi_quartile_contrasts.R,
#           extract_ice_distance_quartile_contrasts.R)
#
# Output:  output/numeric_results_ice_effect_modification_difference_contrasts.csv
# =============================================================================

ci_to_se <- function(low, high) (high - low) / (2 * 1.96)

get_stratum <- function(df, city_label, stratum_label) {
  out <- df |> dplyr::filter(city == city_label, ice_stratum == stratum_label)
  stopifnot(nrow(out) == 1)
  out
}

# -----------------------------------------------------------------------
# Ratio-scale outcomes (NH visits IRR, distance ratio): contrast the
# Q25-to-Q75 CSI effect on the log scale, back-transform to a ratio of
# ratios (RR_Q5 / RR_Q1) with its own 95% CI.
# -----------------------------------------------------------------------
ratio_of_ratios_contrast <- function(df, city_label, outcome_label,
                                     estimate_col = "irr") {
  q1 <- get_stratum(df, city_label, "Q1 (Most Disadvantaged)")
  q5 <- get_stratum(df, city_label, "Q5 (Most Advantaged)")

  log_q1 <- log(q1[[estimate_col]])
  log_q5 <- log(q5[[estimate_col]])
  se_q1  <- ci_to_se(log(q1$ci_low_95), log(q1$ci_high_95))
  se_q5  <- ci_to_se(log(q5$ci_low_95), log(q5$ci_high_95))

  diff_log <- log_q5 - log_q1
  se_diff  <- sqrt(se_q1^2 + se_q5^2)

  tibble(
    outcome           = outcome_label,
    city              = city_label,
    contrast_q1       = q1[[estimate_col]],
    contrast_q5       = q5[[estimate_col]],
    ratio_q5_vs_q1    = round(exp(diff_log), 3),
    ratio_ci_low_95   = round(exp(diff_log - 1.96 * se_diff), 3),
    ratio_ci_high_95  = round(exp(diff_log + 1.96 * se_diff), 3),
    contrast_scale    = "ratio_of_quartile_contrast_ratios"
  )
}

# -----------------------------------------------------------------------
# Absolute-scale outcome (NDVI, Gaussian): contrast the Q25-to-Q75 CSI
# effect directly, a difference-of-differences (Q5 minus Q1) with its
# own 95% CI.
# -----------------------------------------------------------------------
difference_of_differences_contrast <- function(df, city_label, outcome_label,
                                               estimate_col = "estimate") {
  q1 <- get_stratum(df, city_label, "Q1 (Most Disadvantaged)")
  q5 <- get_stratum(df, city_label, "Q5 (Most Advantaged)")

  se_q1 <- ci_to_se(q1$ci_low_95, q1$ci_high_95)
  se_q5 <- ci_to_se(q5$ci_low_95, q5$ci_high_95)

  diff    <- q5[[estimate_col]] - q1[[estimate_col]]
  se_diff <- sqrt(se_q1^2 + se_q5^2)

  tibble(
    outcome           = outcome_label,
    city              = city_label,
    contrast_q1       = q1[[estimate_col]],
    contrast_q5       = q5[[estimate_col]],
    diff_q5_minus_q1  = round(diff, 5),
    diff_ci_low_95    = round(diff - 1.96 * se_diff, 5),
    diff_ci_high_95   = round(diff + 1.96 * se_diff, 5),
    contrast_scale    = "difference_of_quartile_contrast_estimates"
  )
}

# =============================================================================
# NH visits (IRR/RR scale)
# =============================================================================

nh_df <- read_csv(paste0(output.folder, "numeric_results_ice_nh_quartile_contrasts.csv"),
                   show_col_types = FALSE)

nh_results <- bind_rows(
  ratio_of_ratios_contrast(nh_df, "LA",  "neighbor_visit_count_annual_avg"),
  ratio_of_ratios_contrast(nh_df, "NYC", "neighbor_visit_count_annual_avg")
)

# =============================================================================
# NDVI (Gaussian, absolute scale)
# =============================================================================

ndvi_df <- read_csv(paste0(output.folder, "numeric_results_ice_ndvi_quartile_contrasts.csv"),
                     show_col_types = FALSE)

ndvi_results <- bind_rows(
  difference_of_differences_contrast(ndvi_df, "LA",  "NDVI"),
  difference_of_differences_contrast(ndvi_df, "NYC", "NDVI")
)

# =============================================================================
# Distance to nearest green space (ratio scale, Q75_vs_Q25 contrast only,
# matching the contrast reported in the Secondary analysis text)
# =============================================================================

gs_df_all <- read_csv(paste0(output.folder, "numeric_results_ice_distance_quartile_contrasts.csv"),
                       show_col_types = FALSE)
gs_df <- gs_df_all |> dplyr::filter(contrast == "Q75_vs_Q25")

gs_results <- bind_rows(
  ratio_of_ratios_contrast(gs_df, "LA",  "closest_greenspace", estimate_col = "ratio"),
  ratio_of_ratios_contrast(gs_df, "NYC", "closest_greenspace", estimate_col = "ratio")
)

# =============================================================================
# Save
# =============================================================================

results_all <- bind_rows(nh_results, ndvi_results, gs_results)

print(results_all, n = Inf, width = Inf)

write_csv(results_all,
          paste0(output.folder,
                 "numeric_results_ice_effect_modification_difference_contrasts.csv"))

message("Saved: output/numeric_results_ice_effect_modification_difference_contrasts.csv")
