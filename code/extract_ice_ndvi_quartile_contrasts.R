rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(mgcv)
library(dplyr)
library(tibble)
library(readr)

# =============================================================================
# extract_ice_ndvi_quartile_contrasts.R
#
# Purpose: Quantify the CSI-NDVI slope within each ICE stratum (Q1 most
#          disadvantaged, Q5 most advantaged) for each city, so the Secondary
#          analysis paragraph of sn-article.tex can describe the LA vs. NYC
#          pattern (similar magnitude in LA; larger decrease in NYC Q5 than
#          Q1) with the same quartile-segment contrast (estimate + CI) format
#          already used for the primary and NH-stratified results. A coauthor
#          flagged (2026-07-31) that citing spline edf per stratum is not a
#          helpful way to communicate this comparison to readers; the
#          manuscript now reports the estimate/CI columns below instead (edf
#          is still computed and retained in the output for reference).
#          Computed within each stratum's own model (NOT the Q1-vs-Q5
#          baseline gap, which is already reported in
#          extract_ice_effect_modification_contrasts.R).
#
# Method:  Same lpmatrix/delta-method approach as extract_numeric_results.R
#          (Q25-to-Q50, Q50-to-Q75, Q25-to-Q75 contrasts, smooth centered at
#          Q50), applied separately to each of the four stratum-city models.
#
# Models:  ndvi_ice_q1_q5_fit.rds
#          (fit in generate_linear_ice_outl_figures.R: fully adjusted linear
#          GAMs, fit separately per city within each ICE quintile stratum, on
#          the outlier-excluded sample.)
#
# Output:  output/numeric_results_ice_ndvi_quartile_contrasts.csv
# =============================================================================


# =============================================================================
# Helpers (same approach as extract_numeric_results.R)
# =============================================================================

extract_csi_lpblock <- function(model, csi_at, newdata_template) {
  nd <- newdata_template[rep(1L, length(csi_at)), ]
  nd$community_severance_index <- csi_at
  rownames(nd) <- NULL

  Xp <- mgcv::predict.gam(model, newdata = nd, type = "lpmatrix")

  csi_cols <- grep("s(community_severance_index)", colnames(Xp), fixed = TRUE)
  if (length(csi_cols) == 0) {
    stop("No s(community_severance_index) columns in lpmatrix — check model formula.")
  }

  list(
    X          = Xp[, csi_cols, drop = FALSE],
    coef_names = colnames(Xp)[csi_cols]
  )
}

compute_csi_contrast_se <- function(x_mat, v_csi, i, j) {
  l_vec <- matrix(x_mat[i, ] - x_mat[j, ], nrow = 1)
  sqrt(pmax(as.numeric(l_vec %*% v_csi %*% t(l_vec)), 0))
}

compute_q75_q25_diff <- function(model, dt_stratum, ice_stratum_label, city_label) {

  if (is.null(model)) {
    warning("Model is NULL for ", ice_stratum_label, " ", city_label, " — skipping.")
    return(NULL)
  }

  csi <- dt_stratum$community_severance_index[!is.na(dt_stratum$community_severance_index)]
  q25 <- as.numeric(quantile(csi, 0.25))
  q50 <- as.numeric(quantile(csi, 0.50))
  q75 <- as.numeric(quantile(csi, 0.75))

  adj_cols <- c("pop_dens", "perc.black", "perc.hisp", "perc.pov", "building_density")
  means <- setNames(
    lapply(adj_cols, function(v) {
      if (v %in% names(dt_stratum)) mean(dt_stratum[[v]], na.rm = TRUE) else NA_real_
    }),
    adj_cols
  )

  ref_neigh <- levels(model$model$neighborhood)[1]

  template <- data.frame(
    community_severance_index = NA_real_,
    pop_dens         = means[["pop_dens"]],
    perc.black       = means[["perc.black"]],
    perc.hisp        = means[["perc.hisp"]],
    perc.pov         = means[["perc.pov"]],
    building_density = means[["building_density"]],
    neighborhood     = ref_neigh,
    stringsAsFactors = FALSE
  )

  lp_at  <- extract_csi_lpblock(model, c(q25, q75), template)
  lp_cen <- extract_csi_lpblock(model, c(q50, q50), template)

  x_mat <- lp_at$X - lp_cen$X  # row 1: smooth(Q25)-smooth(Q50); row 2: smooth(Q75)-smooth(Q50)

  beta_csi <- coef(model)[lp_at$coef_names]
  v_csi    <- vcov(model)[lp_at$coef_names, lp_at$coef_names, drop = FALSE]

  fit_all <- as.numeric(x_mat %*% beta_csi)
  est_lp  <- fit_all[2] - fit_all[1]                       # Q75 vs Q25
  se_lp   <- compute_csi_contrast_se(x_mat, v_csi, i = 2, j = 1)
  lo_lp   <- est_lp - 1.96 * se_lp
  hi_lp   <- est_lp + 1.96 * se_lp

  edf <- summary(model)$s.table["s(community_severance_index)", "edf"]

  tibble(
    ice_stratum = ice_stratum_label,
    city        = city_label,
    n_tracts    = nrow(dt_stratum),
    csi_q25     = round(q25, 3),
    csi_q75     = round(q75, 3),
    edf         = round(edf, 3),
    estimate    = round(est_lp, 5),
    ci_low_95   = round(lo_lp, 5),
    ci_high_95  = round(hi_lp, 5),
    effect_scale = "absolute_difference"
  )
}

# =============================================================================
# Rebuild the Q1/Q5 stratum subsets exactly as in
# generate_linear_ice_outl_figures.R (outlier-excluded sample)
# =============================================================================

dt <- readRDS(paste0(generated.data.folder, "data_models.rds")) |>
  mutate(city = as.factor(city), neighborhood = as.factor(neighborhood))

city_csi_stats <- dt |>
  group_by(city) |>
  summarise(
    mean_csi = mean(community_severance_index, na.rm = TRUE),
    sd_csi   = sd(community_severance_index, na.rm = TRUE),
    .groups = "drop"
  )

dt_no_outl <- dt |>
  left_join(city_csi_stats, by = "city") |>
  mutate(
    z_csi        = (community_severance_index - mean_csi) / sd_csi,
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier (|z|>2)", "Within ±2 SD")
  ) |>
  filter(outlier_flag != "Outlier (|z|>2)")

dt_ndvi_q1 <- dt_no_outl |>
  filter(ICE_inc_quintile == "Q1 (Most Disadvantaged)", !is.na(NDVI))
dt_ndvi_q5 <- dt_no_outl |>
  filter(ICE_inc_quintile == "Q5 (Most Advantaged)", !is.na(NDVI))

# =============================================================================
# Load the Q1/Q5-stratified NDVI models and compute Q25-to-Q75 contrast per city
# =============================================================================

fits <- readRDS(paste0(generated.data.folder, "ndvi_ice_q1_q5_fit.rds"))

results_all <- bind_rows(
  compute_q75_q25_diff(
    fits$q1$fit_city_la, dplyr::filter(dt_ndvi_q1, city == "LA"),
    "Q1 (Most Disadvantaged)", "LA"
  ),
  compute_q75_q25_diff(
    fits$q1$fit_city_nyc, dplyr::filter(dt_ndvi_q1, city == "NYC"),
    "Q1 (Most Disadvantaged)", "NYC"
  ),
  compute_q75_q25_diff(
    fits$q5$fit_city_la, dplyr::filter(dt_ndvi_q5, city == "LA"),
    "Q5 (Most Advantaged)", "LA"
  ),
  compute_q75_q25_diff(
    fits$q5$fit_city_nyc, dplyr::filter(dt_ndvi_q5, city == "NYC"),
    "Q5 (Most Advantaged)", "NYC"
  )
) |>
  dplyr::arrange(city, ice_stratum)

print(results_all, n = Inf)

write_csv(results_all,
          paste0(output.folder, "numeric_results_ice_ndvi_quartile_contrasts.csv"))

message("Saved: output/numeric_results_ice_ndvi_quartile_contrasts.csv")
