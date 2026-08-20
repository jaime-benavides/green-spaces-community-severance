rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(mgcv)
library(dplyr)
library(tibble)
library(readr)

# =============================================================================
# extract_ice_effect_modification_contrasts.R
#
# Purpose: Quantify the Q1 (most disadvantaged) vs Q5 (most advantaged) ICE
#          gap for each outcome x city at Q25/Q50/Q75 of the (pooled, primary,
#          outlier-excluded) city-specific CSI distribution, with 95% CIs.
#
# Method:  Q1 and Q5 are fit as SEPARATE GAMs on non-overlapping tract subsets
#          (see generate_linear_ice_outl_figures.R / generate_nh_ice_q1_q5_figure.R),
#          not a single model with an interaction term. For each model, the
#          fitted value at a given CSI is intercept + s(CSI), with all other
#          covariates held at their stratum-specific means (rather than
#          zero; this stratum-mean-covariate convention is reimplemented
#          inline below via build_template()/extract_intercept_csi_lpblock()):
#          a zero-covariate tract is an unrealistic reference point, so the
#          model intercept is replaced with intercept + covariate effects
#          evaluated at the stratum's mean covariate values, added to the
#          (zero-centered) marginal CSI smooth.
#          The gap Q5 - Q1 (or its response-scale analogue) is then a linear
#          (Gaussian) or delta-method (log-link) combination of two
#          INDEPENDENT model fits (disjoint tract sets), so
#            Var(gap) = Var(pred_Q5) + Var(pred_Q1).
#          This mirrors the lpmatrix delta-method approach used in
#          extract_numeric_results.R / main_anchored_quartile_contrasts.R in
#          bne_uncertainty_ses_multiyear, adapted for a between-model (rather
#          than within-model) contrast.
#
# Output:  output/numeric_results_ice_effect_modification.csv
#
# Status:  Diagnostic only. This script's output is not cited by any number
#          in the manuscript and does not feed any manuscript figure — the
#          Q1-vs-Q5 comparison it computes (a baseline-level gap between two
#          independently fit models) is not part of the study design. The
#          manuscript's Secondary analysis reports effect modification via
#          extract_ice_effect_modification_difference_contrasts.R instead
#          (a Q5-vs-Q1 contrast of each stratum's own CSI-quartile effect,
#          not a baseline-level gap). Figure 4 (plot_ice_overlay() in
#          functions.R) uses the same centered/ratio-scale transform as
#          Figures 2/3, not this script's stratum-mean-covariate convention.
# =============================================================================


# =============================================================================
# Helper: intercept + s(CSI) lpmatrix block (all other covariates at 0)
# =============================================================================

extract_intercept_csi_lpblock <- function(model, csi_at, newdata_template) {
  nd <- newdata_template[rep(1L, length(csi_at)), ]
  nd$community_severance_index <- csi_at
  rownames(nd) <- NULL

  Xp <- mgcv::predict.gam(model, newdata = nd, type = "lpmatrix")

  keep_cols <- c(
    "(Intercept)",
    grep("s(community_severance_index)", colnames(Xp), fixed = TRUE, value = TRUE)
  )
  keep_cols <- intersect(keep_cols, colnames(Xp))

  list(X = Xp[, keep_cols, drop = FALSE], coef_names = keep_cols)
}


# =============================================================================
# Main function: Q1 vs Q5 gap at Q25/Q50/Q75 of pooled city CSI, one outcome
# =============================================================================

compute_ice_gap_contrasts <- function(mod_q1, mod_q5, csi_quartiles,
                                       outcome_label, city_label,
                                       offset_var = NULL) {

  if (is.null(mod_q1) || is.null(mod_q5)) {
    warning("Missing Q1 or Q5 model for ", outcome_label, " ", city_label)
    return(NULL)
  }

  # newdata template: adjustment covariates at the stratum's own means
  # (rather than zero), matching the convention in gam_reference_level()
  # (functions.R) used to render Figure 4 / fig:ice_combined
  adj_cols <- c("pop_dens", "perc.black", "perc.hisp", "perc.pov", "building_density")

  build_template <- function(model) {
    dt <- model$model
    ref_neigh <- levels(dt$neighborhood)[1]
    tmpl <- data.frame(
      community_severance_index = NA_real_,
      pop_dens         = mean(dt$pop_dens, na.rm = TRUE),
      perc.black       = mean(dt$perc.black, na.rm = TRUE),
      perc.hisp        = mean(dt$perc.hisp, na.rm = TRUE),
      perc.pov         = mean(dt$perc.pov, na.rm = TRUE),
      building_density = mean(dt$building_density, na.rm = TRUE),
      neighborhood     = ref_neigh,
      stringsAsFactors = FALSE
    )
    if (!is.null(offset_var)) tmpl[[offset_var]] <- 1  # offset(log(1)) = 0
    tmpl
  }

  lp_q1 <- extract_intercept_csi_lpblock(mod_q1, csi_quartiles, build_template(mod_q1))
  lp_q5 <- extract_intercept_csi_lpblock(mod_q5, csi_quartiles, build_template(mod_q5))

  beta_q1 <- coef(mod_q1)[lp_q1$coef_names]
  v_q1    <- vcov(mod_q1)[lp_q1$coef_names, lp_q1$coef_names, drop = FALSE]
  beta_q5 <- coef(mod_q5)[lp_q5$coef_names]
  v_q5    <- vcov(mod_q5)[lp_q5$coef_names, lp_q5$coef_names, drop = FALSE]

  eta_q1 <- as.numeric(lp_q1$X %*% beta_q1)
  eta_q5 <- as.numeric(lp_q5$X %*% beta_q5)

  se_eta_q1 <- sqrt(pmax(diag(lp_q1$X %*% v_q1 %*% t(lp_q1$X)), 0))
  se_eta_q5 <- sqrt(pmax(diag(lp_q5$X %*% v_q5 %*% t(lp_q5$X)), 0))

  fam_name <- family(mod_q1)$family
  link     <- family(mod_q1)$link
  quartile_labels <- c("Q25", "Q50", "Q75")

  rows <- lapply(seq_along(csi_quartiles), function(k) {
    if (link == "identity") {
      # Gaussian: gap on the natural (absolute) scale, independent models
      gap    <- eta_q5[k] - eta_q1[k]
      se_gap <- sqrt(se_eta_q5[k]^2 + se_eta_q1[k]^2)
      tibble(
        outcome        = outcome_label,
        city           = city_label,
        csi_value      = round(csi_quartiles[k], 3),
        csi_quantile   = quartile_labels[k],
        pred_q1        = round(eta_q1[k], 5),
        pred_q5        = round(eta_q5[k], 5),
        gap_q5_minus_q1 = round(gap, 5),
        gap_ci_low_95  = round(gap - 1.96 * se_gap, 5),
        gap_ci_high_95 = round(gap + 1.96 * se_gap, 5),
        gap_scale      = "absolute_difference",
        family         = fam_name,
        link           = link
      )
    } else if (link == "log") {
      # Gamma / NB: back-transform to response scale, delta method for the
      # absolute gap (Var(exp(a)-exp(b)) ~ exp(a)^2*Var(a) + exp(b)^2*Var(b)),
      # plus a ratio summary (Q1/Q5) analogous to the IRR/ratio scale already
      # used for the primary quartile contrasts in Table S2.
      resp_q1   <- exp(eta_q1[k])
      resp_q5   <- exp(eta_q5[k])
      gap_resp  <- resp_q1 - resp_q5
      se_gap_resp <- sqrt((resp_q1 * se_eta_q1[k])^2 + (resp_q5 * se_eta_q5[k])^2)

      log_ratio    <- eta_q1[k] - eta_q5[k]   # Q1 / Q5 on log scale
      se_log_ratio <- sqrt(se_eta_q1[k]^2 + se_eta_q5[k]^2)

      tibble(
        outcome        = outcome_label,
        city           = city_label,
        csi_value      = round(csi_quartiles[k], 3),
        csi_quantile   = quartile_labels[k],
        pred_q1        = round(resp_q1, 5),
        pred_q5        = round(resp_q5, 5),
        gap_q1_minus_q5 = round(gap_resp, 5),
        gap_ci_low_95  = round(gap_resp - 1.96 * se_gap_resp, 5),
        gap_ci_high_95 = round(gap_resp + 1.96 * se_gap_resp, 5),
        ratio_q1_vs_q5 = round(exp(log_ratio), 4),
        ratio_ci_low_95  = round(exp(log_ratio - 1.96 * se_log_ratio), 4),
        ratio_ci_high_95 = round(exp(log_ratio + 1.96 * se_log_ratio), 4),
        gap_scale      = "absolute_difference_response_scale_plus_ratio",
        family         = fam_name,
        link           = link
      )
    } else {
      warning("Unhandled link '", link, "' — skipping.")
      NULL
    }
  })

  bind_rows(rows)
}


# =============================================================================
# Load ICE Q1/Q5 fits
# =============================================================================

ndvi_ice  <- readRDS(paste0(generated.data.folder, "ndvi_ice_q1_q5_fit.rds"))
gs_ice    <- readRDS(paste0(generated.data.folder, "greenspace_ice_q1_q5_fit.rds"))
nh_ice    <- readRDS(paste0(generated.data.folder,
                             "neighbor_visit_ice_q1_q5_fit_2019_full_year.rds"))


# =============================================================================
# Pooled (primary, outlier-excluded) city-specific CSI Q25/Q50/Q75
#   Reuses the same city-level quartiles as Table S2 (extract_numeric_results.R)
#   so the ICE-gap contrasts are evaluated at the same CSI values already
#   reported for the primary (unstratified) analysis.
# =============================================================================

dt_gs_full <- readRDS(paste0(generated.data.folder, "data_models.rds"))
dt_gs_full$closest_greenspace[dt_gs_full$closest_greenspace == 0] <- 1
dt_gs_full <- dt_gs_full |>
  dplyr::group_by(city) |>
  dplyr::mutate(
    z_csi        = (community_severance_index - mean(community_severance_index, na.rm = TRUE)) /
                    sd(community_severance_index, na.rm = TRUE),
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier", "Within")
  ) |>
  dplyr::ungroup()

csi_quartiles_gs <- dt_gs_full |>
  dplyr::filter(outlier_flag == "Within") |>
  dplyr::group_by(city) |>
  dplyr::summarise(
    q25 = quantile(community_severance_index, 0.25, na.rm = TRUE),
    q50 = quantile(community_severance_index, 0.50, na.rm = TRUE),
    q75 = quantile(community_severance_index, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

dt_nh_full <- readRDS(paste0(generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"))
dt_nh_full <- dt_nh_full |>
  dplyr::filter(
    !is.na(neighbor_visit_count_annual_avg),
    !is.na(home_device_counts_total_parsed_annual_avg),
    home_device_counts_total_parsed_annual_avg > 0
  ) |>
  dplyr::group_by(city) |>
  dplyr::mutate(
    z_csi        = (community_severance_index - mean(community_severance_index, na.rm = TRUE)) /
                    sd(community_severance_index, na.rm = TRUE),
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier", "Within")
  ) |>
  dplyr::ungroup()

csi_quartiles_nh <- dt_nh_full |>
  dplyr::filter(outlier_flag == "Within") |>
  dplyr::group_by(city) |>
  dplyr::summarise(
    q25 = quantile(community_severance_index, 0.25, na.rm = TRUE),
    q50 = quantile(community_severance_index, 0.50, na.rm = TRUE),
    q75 = quantile(community_severance_index, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

get_quartiles <- function(tbl, city_label) {
  row <- tbl[tbl$city == city_label, ]
  c(row$q25, row$q50, row$q75)
}


# =============================================================================
# Compute contrasts
# =============================================================================

offset_nh <- "home_device_counts_total_parsed_annual_avg"

results_all <- bind_rows(

  compute_ice_gap_contrasts(ndvi_ice$q1$fit_city_la,  ndvi_ice$q5$fit_city_la,
                             get_quartiles(csi_quartiles_gs, "LA"),
                             "NDVI", "LA"),
  compute_ice_gap_contrasts(ndvi_ice$q1$fit_city_nyc, ndvi_ice$q5$fit_city_nyc,
                             get_quartiles(csi_quartiles_gs, "NYC"),
                             "NDVI", "NYC"),

  compute_ice_gap_contrasts(gs_ice$q1$fit_city_la,    gs_ice$q5$fit_city_la,
                             get_quartiles(csi_quartiles_gs, "LA"),
                             "closest_greenspace", "LA"),
  compute_ice_gap_contrasts(gs_ice$q1$fit_city_nyc,   gs_ice$q5$fit_city_nyc,
                             get_quartiles(csi_quartiles_gs, "NYC"),
                             "closest_greenspace", "NYC"),

  compute_ice_gap_contrasts(nh_ice$q1$fit_city_la,    nh_ice$q5$fit_city_la,
                             get_quartiles(csi_quartiles_nh, "LA"),
                             "neighbor_visit_count_annual_avg", "LA",
                             offset_var = offset_nh),
  compute_ice_gap_contrasts(nh_ice$q1$fit_city_nyc,   nh_ice$q5$fit_city_nyc,
                             get_quartiles(csi_quartiles_nh, "NYC"),
                             "neighbor_visit_count_annual_avg", "NYC",
                             offset_var = offset_nh)

) |>
  dplyr::arrange(outcome, city, csi_quantile)


# =============================================================================
# Save
# =============================================================================

write_csv(results_all,
          paste0(output.folder, "numeric_results_ice_effect_modification.csv"))

message("Saved: output/numeric_results_ice_effect_modification.csv")
print(results_all, n = Inf, width = Inf)
