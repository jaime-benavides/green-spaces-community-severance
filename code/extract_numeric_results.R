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
# Purpose: Extract per-IQR-of-CSI effect estimates from all three primary
#          outcome models (NDVI, distance to nearest green space, neighboring-
#          home count) for use in the results narrative of sn-article.tex.
#
# Method:  Inspired by main_anchored_quartile_contrasts.R in the
#          bne_uncertainty_ses project.  For each city-specific GAM:
#
#          1. extract_csi_lpblock() pulls the s(community_severance_index)
#             columns from predict.gam(type="lpmatrix") at a vector of
#             evaluation CSI values and at the centering value (city median).
#          2. The contrast matrix x_mat = X_at - X_cen mirrors the
#             crossbasis centering in the BNE project.
#          3. compute_csi_contrast_se() computes the exact SE for any
#             pairwise contrast between rows of x_mat via the delta method
#             on the CSI-smooth vcov submatrix.
#
#          Only the s(community_severance_index) coefficient block is used;
#          the neighborhood random effect and covariate terms are not
#          referenced.  Effect: one IQR increase in CSI centered at the city
#          median, covariates fixed at city-specific means.
#
# Effect measures:
#   NDVI (Gaussian, identity link)   -> absolute difference (NDVI units)
#   Proximity (Gamma, log link)      -> distance ratio; percent change
#   NH count (NB, log link)          -> incidence rate ratio (IRR)
#
# Inputs (must exist in data/generated/):
#   ndvi_model_objects_city_adjusted_linear.rds    <- models_linear.R
#   ndvi_model_objects_city_crude_linear.rds       <- models_linear.R
#   greenspace_model_objects_city_adjusted_linear.rds <- models_linear.R
#   greenspace_model_objects_city_crude_linear.rds    <- models_linear.R
#   neighbor_visit_primary_fit_city_{la,nyc}_2019_full_year.rds
#                                         <- models_neighbor_visits_annual_average.R
#   neighbor_visit_primary_crude_fit_city_{la,nyc}_2019_full_year.rds
#                                         <- models_neighbor_visits_annual_average.R
#   data_models.rds                       <- models_linear.R
#   data_models_neighbor_visits_annual_average_2019_full_year.rds
#
# Output:
#   output/numeric_results_per_iqr_csi.csv
#
# Re-run whenever models_linear.R or models_neighbor_visits_annual_average.R
# are re-fitted.
# =============================================================================


# =============================================================================
# Helper 1: extract s(CSI) lpmatrix block at given CSI values
#   Analogous to build_basis_for_x() + align_basis_colnames_to_gam() in BNE.
#   Returns a list with:
#     $X          — matrix of CSI smooth columns, one row per csi_at value
#     $coef_names — model coefficient names for those columns
# =============================================================================

extract_csi_lpblock <- function(model, csi_at, newdata_template) {
  nd <- newdata_template[rep(1L, length(csi_at)), ]
  nd$community_severance_index <- csi_at
  rownames(nd) <- NULL

  Xp <- mgcv::predict.gam(model, newdata = nd, type = "lpmatrix")

  csi_cols <- grep("s(community_severance_index)", colnames(Xp), fixed = TRUE)
  if (length(csi_cols) == 0) {
    stop("No s(community_severance_index) columns in lpmatrix — ",
         "check model formula.")
  }

  list(
    X          = Xp[, csi_cols, drop = FALSE],
    coef_names = colnames(Xp)[csi_cols]
  )
}


# =============================================================================
# Helper 2: SE of the contrast between rows i and j of the x_mat
#   Direct port of compute_contrast_se() from BNE.
# =============================================================================

compute_csi_contrast_se <- function(x_mat, v_csi, i, j) {
  l_vec <- matrix(x_mat[i, ] - x_mat[j, ], nrow = 1)
  sqrt(pmax(as.numeric(l_vec %*% v_csi %*% t(l_vec)), 0))
}


# =============================================================================
# Main function: per-IQR effect for one city-model combination
#   Analogous to compute_pointwise_from_cbblock() in BNE.
# =============================================================================

compute_iqr_effect <- function(model,
                               dt_city,
                               outcome_label,
                               model_spec,
                               city_label,
                               offset_var = NULL) {

  if (is.null(model)) {
    warning("Model is NULL for ", outcome_label, " ", city_label, " — skipping.")
    return(NULL)
  }

  # --- City-specific CSI distribution (centering at median, span = IQR) ---
  csi      <- dt_city$community_severance_index
  csi      <- csi[!is.na(csi)]
  cen_val  <- median(csi)
  iqr      <- IQR(csi)
  at_vec   <- c(cen_val, cen_val + iqr)   # [1] = center, [2] = center + IQR

  # --- Build a template newdata row (covariates at city means) ---
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

  # --- Extract CSI smooth lpmatrix block at evaluation points and at center ---
  # Mirrors: b_at <- build_basis_for_x(basis, at_vec)
  #          b_cen <- build_basis_for_x(basis, rep(cen_val, n))
  lp_at  <- tryCatch(
    extract_csi_lpblock(model, at_vec,           template),
    error = function(e) { warning(e$message); NULL }
  )
  lp_cen <- tryCatch(
    extract_csi_lpblock(model, rep(cen_val, length(at_vec)), template),
    error = function(e) { warning(e$message); NULL }
  )
  if (is.null(lp_at) || is.null(lp_cen)) return(NULL)

  # --- Centered contrast matrix: x_mat = X_at - X_cen ---
  # Row 1: cen - cen = 0 (null contrast at the reference)
  # Row 2: (cen + IQR) - cen = the IQR effect
  x_mat <- lp_at$X - lp_cen$X

  # --- CSI smooth coefficient block and its vcov submatrix ---
  beta_csi <- coef(model)[lp_at$coef_names]
  v_csi    <- vcov(model)[lp_at$coef_names, lp_at$coef_names, drop = FALSE]

  # --- Pointwise effects and SEs (row-wise, as in BNE) ---
  fit_all <- as.numeric(x_mat %*% beta_csi)
  xv      <- x_mat %*% v_csi
  se_all  <- sqrt(pmax(rowSums(xv * x_mat), 0))

  # IQR effect = contrast between row 2 (center + IQR) and row 1 (center)
  # SE via compute_csi_contrast_se — mirrors compute_contrast_se() in BNE
  est_lp <- fit_all[2] - fit_all[1]   # = fit_all[2] since row 1 is 0
  se_lp  <- compute_csi_contrast_se(x_mat, v_csi, i = 2, j = 1)
  lo_lp  <- est_lp - 1.96 * se_lp
  hi_lp  <- est_lp + 1.96 * se_lp

  # --- Build result row depending on link function ---
  fam_name <- family(model)$family
  link     <- family(model)$link

  if (link == "identity") {
    tibble(
      outcome         = outcome_label,
      model_spec      = model_spec,
      city            = city_label,
      family          = fam_name,
      link            = link,
      csi_median      = round(cen_val, 3),
      csi_iqr         = round(iqr,     3),
      effect_estimate = round(est_lp,  5),
      ci_low_95       = round(lo_lp,   5),
      ci_high_95      = round(hi_lp,   5),
      effect_scale    = "absolute_difference",
      interpretation  = paste0(
        "Absolute NDVI difference per IQR increase in CSI ",
        "(covariates at city-specific means, centered at city median)"
      )
    )

  } else if (link == "log") {
    ratio    <- exp(est_lp)
    ratio_lo <- exp(lo_lp)
    ratio_hi <- exp(hi_lp)

    if (grepl("neighbor", outcome_label, ignore.case = TRUE)) {
      eff_scale <- "IRR"
      interp    <- paste0(
        "Incidence rate ratio (IRR) per IQR increase in CSI ",
        "(covariates at city-specific means, centered at city median)"
      )
    } else {
      eff_scale <- "ratio"
      interp    <- paste0(
        "Distance ratio per IQR increase in CSI; >1 = farther from green space ",
        "(covariates at city-specific means, centered at city median)"
      )
    }

    tibble(
      outcome         = outcome_label,
      model_spec      = model_spec,
      city            = city_label,
      family          = fam_name,
      link            = link,
      csi_median      = round(cen_val, 3),
      csi_iqr         = round(iqr,     3),
      effect_estimate = round(ratio,    4),
      ci_low_95       = round(ratio_lo, 4),
      ci_high_95      = round(ratio_hi, 4),
      effect_scale    = eff_scale,
      interpretation  = interp
    )

  } else {
    warning("Unhandled link '", link, "' for ", outcome_label, " ", city_label)
    return(NULL)
  }
}


# =============================================================================
# Load model objects
# =============================================================================

ndvi_adj   <- readRDS(paste0(generated.data.folder,
                              "ndvi_model_objects_city_adjusted_linear.rds"))
gs_adj     <- readRDS(paste0(generated.data.folder,
                              "greenspace_model_objects_city_adjusted_linear.rds"))
nh_la_adj  <- readRDS(paste0(generated.data.folder,
                              "neighbor_visit_primary_fit_city_la_2019_full_year.rds"))
nh_nyc_adj <- readRDS(paste0(generated.data.folder,
                              "neighbor_visit_primary_fit_city_nyc_2019_full_year.rds"))

ndvi_crude   <- readRDS(paste0(generated.data.folder,
                                "ndvi_model_objects_city_crude_linear.rds"))
gs_crude     <- readRDS(paste0(generated.data.folder,
                                "greenspace_model_objects_city_crude_linear.rds"))
nh_la_crude  <- readRDS(paste0(generated.data.folder,
                                "neighbor_visit_primary_crude_fit_city_la_2019_full_year.rds"))
nh_nyc_crude <- readRDS(paste0(generated.data.folder,
                                "neighbor_visit_primary_crude_fit_city_nyc_2019_full_year.rds"))


# =============================================================================
# Load modeling datasets (for city-specific covariate means and CSI IQR)
# =============================================================================

# NDVI / proximity dataset — saved before closest_greenspace == 0 recoding
dt_ndvi_gs <- readRDS(paste0(generated.data.folder, "data_models.rds"))
dt_ndvi_gs$closest_greenspace[dt_ndvi_gs$closest_greenspace == 0] <- 1

dt_la_gs  <- dt_ndvi_gs[dt_ndvi_gs$city == "LA",  ]
dt_nyc_gs <- dt_ndvi_gs[dt_ndvi_gs$city == "NYC", ]

# NH dataset
dt_nh <- readRDS(paste0(generated.data.folder,
                         "data_models_neighbor_visits_annual_average_2019_full_year.rds"))

dt_nh_primary <- dt_nh |>
  dplyr::filter(
    !is.na(neighbor_visit_count_annual_avg),
    !is.na(home_device_counts_total_parsed_annual_avg),
    home_device_counts_total_parsed_annual_avg > 0
  )

dt_la_nh  <- dt_nh_primary[dt_nh_primary$city == "LA",  ]
dt_nyc_nh <- dt_nh_primary[dt_nh_primary$city == "NYC", ]


# =============================================================================
# Compute per-IQR effects — adjusted models
# =============================================================================

offset_nh <- "home_device_counts_total_parsed_annual_avg"

results_adjusted <- bind_rows(

  compute_iqr_effect(ndvi_adj$fit_city_la,   dt_la_gs,  "NDVI",
                     "adjusted", "LA"),
  compute_iqr_effect(ndvi_adj$fit_city_nyc,  dt_nyc_gs, "NDVI",
                     "adjusted", "NYC"),

  compute_iqr_effect(gs_adj$fit_city_la,     dt_la_gs,  "closest_greenspace",
                     "adjusted", "LA"),
  compute_iqr_effect(gs_adj$fit_city_nyc,    dt_nyc_gs, "closest_greenspace",
                     "adjusted", "NYC"),

  compute_iqr_effect(nh_la_adj,  dt_la_nh,  "neighbor_visit_count_annual_avg",
                     "adjusted", "LA",  offset_var = offset_nh),
  compute_iqr_effect(nh_nyc_adj, dt_nyc_nh, "neighbor_visit_count_annual_avg",
                     "adjusted", "NYC", offset_var = offset_nh)
)


# =============================================================================
# Compute per-IQR effects — crude models
# =============================================================================

results_crude <- bind_rows(

  compute_iqr_effect(ndvi_crude$fit_city_la,   dt_la_gs,  "NDVI",
                     "crude", "LA"),
  compute_iqr_effect(ndvi_crude$fit_city_nyc,  dt_nyc_gs, "NDVI",
                     "crude", "NYC"),

  compute_iqr_effect(gs_crude$fit_city_la,     dt_la_gs,  "closest_greenspace",
                     "crude", "LA"),
  compute_iqr_effect(gs_crude$fit_city_nyc,    dt_nyc_gs, "closest_greenspace",
                     "crude", "NYC"),

  compute_iqr_effect(nh_la_crude,  dt_la_nh,  "neighbor_visit_count_annual_avg",
                     "crude", "LA",  offset_var = offset_nh),
  compute_iqr_effect(nh_nyc_crude, dt_nyc_nh, "neighbor_visit_count_annual_avg",
                     "crude", "NYC", offset_var = offset_nh)
)


# =============================================================================
# Combine and save
# =============================================================================

results_all <- bind_rows(results_adjusted, results_crude) |>
  dplyr::arrange(outcome, model_spec, city)

write_csv(results_all,
          paste0(output.folder, "numeric_results_per_iqr_csi.csv"))

message("Saved: output/numeric_results_per_iqr_csi.csv")
print(results_all)
