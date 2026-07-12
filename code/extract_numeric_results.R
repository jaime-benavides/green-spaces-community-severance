rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(mgcv)
library(dplyr)
library(tibble)
library(readr)

# =============================================================================
# extract_numeric_results.R
#
# Purpose: Extract quartile contrasts from the outlier-excluded primary GAMs
#          (NDVI, distance to nearest green space, neighboring-home count) for
#          Supplementary Table S2 of sn-article.tex.
#
# Method:  For each city-specific GAM, evaluate the s(community_severance_index)
#          smooth at Q25, Q50, and Q75 of the city-specific (outlier-excluded)
#          CSI distribution.  The smooth is centered at Q50 (median).
#          Three contrasts are reported per outcome × city:
#            beta_q25_q50 = smooth(Q50) - smooth(Q25)  [lower segment]
#            beta_q50_q75 = smooth(Q75) - smooth(Q50)  [upper segment]
#            beta_q25_q75 = smooth(Q75) - smooth(Q25)  [overall IQR contrast]
#          95% CIs via delta method on the CSI-smooth vcov submatrix, exactly
#          as in main_anchored_quartile_contrasts.R in bne_uncertainty_ses_multiyear.
#
# Models:  Primary (outlier-excluded) adjusted models only:
#            ndvi_outl_city_adjusted_linear.rds
#            greenspace_outl_city_adjusted_linear.rds
#            neighbor_visit_outl_city_adjusted_2019_full_year.rds
#
# Output:
#   output/numeric_results_quartile_contrasts.csv
# =============================================================================


# =============================================================================
# Helper 1: extract s(CSI) lpmatrix block at given CSI values
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


# =============================================================================
# Helper 2: SE of smooth(row_i_CSI) - smooth(row_j_CSI)
#   Direct port of compute_contrast_se() from BNE.
# =============================================================================

compute_csi_contrast_se <- function(x_mat, v_csi, i, j) {
  l_vec <- matrix(x_mat[i, ] - x_mat[j, ], nrow = 1)
  sqrt(pmax(as.numeric(l_vec %*% v_csi %*% t(l_vec)), 0))
}


# =============================================================================
# Main function: Q25/Q50/Q75 quartile contrasts for one city-model combination
#   Mirrors main_anchored_quartile_contrasts.R in bne_uncertainty_ses_multiyear.
#   Smooth centered at Q50 (median); three contrasts: Q50vQ25, Q75vQ50, Q75vQ25.
# =============================================================================

compute_quartile_contrasts <- function(model,
                                       dt_city,
                                       outcome_label,
                                       city_label,
                                       offset_var = NULL) {

  if (is.null(model)) {
    warning("Model is NULL for ", outcome_label, " ", city_label, " — skipping.")
    return(NULL)
  }

  # --- Q25, Q50, Q75 of CSI in the outlier-excluded city data ---
  csi    <- dt_city$community_severance_index[!is.na(dt_city$community_severance_index)]
  q25    <- as.numeric(quantile(csi, 0.25))
  q50    <- as.numeric(quantile(csi, 0.50))  # centering value
  q75    <- as.numeric(quantile(csi, 0.75))
  at_vec <- c(q25, q50, q75)  # rows: 1=Q25, 2=Q50, 3=Q75

  # --- Template newdata row: covariates at city means ---
  adj_cols <- c("pop_dens", "perc.black", "perc.hisp", "perc.pov", "building_density")
  means <- setNames(
    lapply(adj_cols, function(v) {
      if (v %in% names(dt_city)) mean(dt_city[[v]], na.rm = TRUE) else NA_real_
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
  if (!is.null(offset_var)) template[[offset_var]] <- 1

  # --- lpmatrix blocks: at Q25/Q50/Q75 and at Q50 (centering) ---
  lp_at  <- tryCatch(extract_csi_lpblock(model, at_vec,        template),
                     error = function(e) { warning(e$message); NULL })
  lp_cen <- tryCatch(extract_csi_lpblock(model, rep(q50, 3),   template),
                     error = function(e) { warning(e$message); NULL })
  if (is.null(lp_at) || is.null(lp_cen)) return(NULL)

  # --- Centered contrast matrix (all rows relative to Q50) ---
  # Row 1: smooth(Q25) - smooth(Q50)  [negative for increasing association]
  # Row 2: smooth(Q50) - smooth(Q50)  = 0  [reference]
  # Row 3: smooth(Q75) - smooth(Q50)  [positive for increasing association]
  x_mat <- lp_at$X - lp_cen$X

  beta_csi <- coef(model)[lp_at$coef_names]
  v_csi    <- vcov(model)[lp_at$coef_names, lp_at$coef_names, drop = FALSE]

  fit_all <- as.numeric(x_mat %*% beta_csi)
  # fit_all[1] = smooth(Q25) - smooth(Q50)
  # fit_all[2] = 0
  # fit_all[3] = smooth(Q75) - smooth(Q50)

  # --- Three contrasts on the linear predictor scale ---
  # Q50 vs Q25 (lower segment):  smooth(Q50) - smooth(Q25) = -fit_all[1]
  # Q75 vs Q50 (upper segment):  smooth(Q75) - smooth(Q50) =  fit_all[3]
  # Q75 vs Q25 (overall IQR):    smooth(Q75) - smooth(Q25) =  fit_all[3] - fit_all[1]
  est_lp <- c(
    q50_q25 = -fit_all[1],             # lower segment
    q75_q50 =  fit_all[3],             # upper segment
    q75_q25 =  fit_all[3] - fit_all[1] # overall
  )
  se_lp <- c(
    q50_q25 = compute_csi_contrast_se(x_mat, v_csi, i = 2, j = 1),
    q75_q50 = compute_csi_contrast_se(x_mat, v_csi, i = 3, j = 2),
    q75_q25 = compute_csi_contrast_se(x_mat, v_csi, i = 3, j = 1)
  )
  lo_lp <- est_lp - 1.96 * se_lp
  hi_lp <- est_lp + 1.96 * se_lp

  contrast_labels <- c("Q50_vs_Q25", "Q75_vs_Q50", "Q75_vs_Q25")

  # --- Transform to effect scale depending on link ---
  fam_name <- family(model)$family
  link     <- family(model)$link

  rows <- lapply(seq_along(est_lp), function(k) {
    if (link == "identity") {
      tibble(
        outcome      = outcome_label,
        city         = city_label,
        contrast     = contrast_labels[k],
        csi_q25      = round(q25, 3),
        csi_q50      = round(q50, 3),
        csi_q75      = round(q75, 3),
        estimate     = round(est_lp[k], 5),
        ci_low_95    = round(lo_lp[k],  5),
        ci_high_95   = round(hi_lp[k],  5),
        effect_scale = "absolute_difference",
        family       = fam_name,
        link         = link
      )
    } else if (link == "log") {
      eff_scale <- if (grepl("neighbor", outcome_label, ignore.case = TRUE)) "IRR" else "ratio"
      tibble(
        outcome      = outcome_label,
        city         = city_label,
        contrast     = contrast_labels[k],
        csi_q25      = round(q25, 3),
        csi_q50      = round(q50, 3),
        csi_q75      = round(q75, 3),
        estimate     = round(exp(est_lp[k]), 4),
        ci_low_95    = round(exp(lo_lp[k]),  4),
        ci_high_95   = round(exp(hi_lp[k]),  4),
        effect_scale = eff_scale,
        family       = fam_name,
        link         = link
      )
    } else {
      warning("Unhandled link '", link, "' — skipping.")
      NULL
    }
  })

  bind_rows(rows)
}


# =============================================================================
# Load outlier-excluded primary adjusted models
# =============================================================================

ndvi_outl <- readRDS(paste0(generated.data.folder,
                             "ndvi_outl_city_adjusted_linear.rds"))
gs_outl   <- readRDS(paste0(generated.data.folder,
                             "greenspace_outl_city_adjusted_linear.rds"))
nh_outl   <- readRDS(paste0(generated.data.folder,
                             "neighbor_visit_outl_city_adjusted_2019_full_year.rds"))


# =============================================================================
# Load outlier-excluded datasets (for city-specific CSI quantiles and covariate means)
# =============================================================================

# NDVI / proximity: derive outlier flags from data_models.rds
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

dt_la_gs  <- dplyr::filter(dt_gs_full, city == "LA",  outlier_flag == "Within")
dt_nyc_gs <- dplyr::filter(dt_gs_full, city == "NYC", outlier_flag == "Within")

# NH: outlier flags already applied in generate_linear_ice_outl_figures.R logic
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

dt_la_nh  <- dplyr::filter(dt_nh_full, city == "LA",  outlier_flag == "Within")
dt_nyc_nh <- dplyr::filter(dt_nh_full, city == "NYC", outlier_flag == "Within")


# =============================================================================
# Compute quartile contrasts — outlier-excluded adjusted models
# =============================================================================

offset_nh <- "home_device_counts_total_parsed_annual_avg"

results_all <- bind_rows(

  compute_quartile_contrasts(ndvi_outl$fit_city_la,  dt_la_gs,
                             "NDVI", "LA"),
  compute_quartile_contrasts(ndvi_outl$fit_city_nyc, dt_nyc_gs,
                             "NDVI", "NYC"),

  compute_quartile_contrasts(gs_outl$fit_city_la,    dt_la_gs,
                             "closest_greenspace", "LA"),
  compute_quartile_contrasts(gs_outl$fit_city_nyc,   dt_nyc_gs,
                             "closest_greenspace", "NYC"),

  compute_quartile_contrasts(nh_outl$fit_city_la,    dt_la_nh,
                             "neighbor_visit_count_annual_avg", "LA",
                             offset_var = offset_nh),
  compute_quartile_contrasts(nh_outl$fit_city_nyc,   dt_nyc_nh,
                             "neighbor_visit_count_annual_avg", "NYC",
                             offset_var = offset_nh)

) |>
  dplyr::arrange(outcome, city, contrast)


# =============================================================================
# Save
# =============================================================================

write_csv(results_all,
          paste0(output.folder, "numeric_results_quartile_contrasts.csv"))

message("Saved: output/numeric_results_quartile_contrasts.csv")
print(results_all, n = Inf)
