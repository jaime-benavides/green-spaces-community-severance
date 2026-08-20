rm(list = ls())

# generate_linear_ice_outl_figures.R
# Purpose: Builds the primary NDVI/proximity figures (Figs 2, 3) and fits
#          the ICE Q1/Q5 stratified models (used in Fig 4).

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(mgcv)
library(ggplot2)
library(patchwork)
library(dplyr)

save_png <- function(plot_list, path, width = 1400, height = 600, ncol = NULL) {
  if (length(plot_list) == 0) {
    warning("No plots to save: ", path)
    return(invisible(NULL))
  }
  png(path, width = width, height = height, type = "quartz")
  if (is.null(ncol)) {
    print(patchwork::wrap_plots(plot_list))
  } else {
    print(patchwork::wrap_plots(plot_list, ncol = ncol))
  }
  dev.off()
  message("Saved: ", basename(path))
}

dt <- readRDS(paste0(generated.data.folder, "data_models.rds"))

dt <- dt |>
  mutate(
    city         = as.factor(city),
    neighborhood = as.factor(neighborhood)
  )

# Recode zero distances to 1m for Gamma models
dt <- dt |>
  mutate(closest_greenspace = ifelse(closest_greenspace == 0, 1, closest_greenspace))

# City-specific CSI outlier z-scores (consistent with models_linear.R)
city_csi_stats <- dt |>
  group_by(city) |>
  summarise(
    mean_csi = mean(community_severance_index, na.rm = TRUE),
    sd_csi   = sd(community_severance_index,   na.rm = TRUE),
    .groups  = "drop"
  )
dt <- dt |>
  left_join(city_csi_stats, by = "city") |>
  mutate(
    z_csi       = (community_severance_index - mean_csi) / sd_csi,
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier", "Within")
  ) |>
  dplyr::select(-mean_csi, -sd_csi)

dt_no_outl <- dt |> filter(outlier_flag != "Outlier")

# ---- ICE Q1/Q5: NDVI (Fig S7) — outlier-excluded within each stratum ----
message("Fitting NDVI ICE Q1/Q5 city models (outlier-excluded)...")
dt_ndvi_q1 <- dt_no_outl |> filter(ICE_inc_quintile == "Q1 (Most Disadvantaged)",
                                     !is.na(NDVI))
dt_ndvi_q5 <- dt_no_outl |> filter(ICE_inc_quintile == "Q5 (Most Advantaged)",
                                     !is.na(NDVI))

fits_ndvi_q1 <- lapply(
  split(dt_ndvi_q1, droplevels(dt_ndvi_q1$city)),
  function(x) model_gam_mixed_ndvi(x, family_type = "linear")
)
names(fits_ndvi_q1) <- paste0("fit_city_", tolower(names(fits_ndvi_q1)))

fits_ndvi_q5 <- lapply(
  split(dt_ndvi_q5, droplevels(dt_ndvi_q5$city)),
  function(x) model_gam_mixed_ndvi(x, family_type = "linear")
)
names(fits_ndvi_q5) <- paste0("fit_city_", tolower(names(fits_ndvi_q5)))

saveRDS(list(q1 = fits_ndvi_q1, q5 = fits_ndvi_q5),
        paste0(generated.data.folder, "ndvi_ice_q1_q5_fit.rds"))

save_png(
  plot_ice_overlay(fits_ndvi_q1, fits_ndvi_q5, rug = TRUE),
  paste0(output.folder, "models_result_q1_q5_ICE_inc_linear.png"),
  ncol = 2
)

# ---- ICE Q1/Q5: Proximity (Fig S8) — outlier-excluded within each stratum ----
message("Fitting proximity ICE Q1/Q5 city models (outlier-excluded)...")
dt_gs_q1 <- dt_no_outl |> filter(ICE_inc_quintile == "Q1 (Most Disadvantaged)",
                                   !is.na(closest_greenspace))
dt_gs_q5 <- dt_no_outl |> filter(ICE_inc_quintile == "Q5 (Most Advantaged)",
                                   !is.na(closest_greenspace))

fits_gs_q1 <- lapply(
  split(dt_gs_q1, droplevels(dt_gs_q1$city)),
  function(x) model_gam_mixed_greenspace(x, family_type = "gamma", include_city = FALSE)
)
names(fits_gs_q1) <- paste0("fit_city_", tolower(names(fits_gs_q1)))

fits_gs_q5 <- lapply(
  split(dt_gs_q5, droplevels(dt_gs_q5$city)),
  function(x) model_gam_mixed_greenspace(x, family_type = "gamma", include_city = FALSE)
)
names(fits_gs_q5) <- paste0("fit_city_", tolower(names(fits_gs_q5)))

saveRDS(list(q1 = fits_gs_q1, q5 = fits_gs_q5),
        paste0(generated.data.folder, "greenspace_ice_q1_q5_fit.rds"))

save_png(
  plot_ice_overlay(fits_gs_q1, fits_gs_q5, rug = TRUE),
  paste0(output.folder, "models_result_q1_q5_ICE_inc_green_dist_linear.png"),
  ncol = 2
)

# ---- Outlier-excluded: NDVI (Fig S3a) ----
message("Fitting NDVI outlier-excluded city models...")
fits_ndvi_outl <- lapply(
  split(dt_no_outl, droplevels(dt_no_outl$city)),
  function(x) model_gam_mixed_ndvi(x, family_type = "linear")
)
names(fits_ndvi_outl) <- paste0("fit_city_", tolower(names(fits_ndvi_outl)))

saveRDS(fits_ndvi_outl,
        paste0(generated.data.folder, "ndvi_outl_city_adjusted_linear.rds"))

save_png(
  plot_smooth_gam(fits_ndvi_outl, rug = TRUE),
  paste0(output.folder,
    "models_result_ndvi_crude_sensitivity_analysis_no_outliers.png")
)

# ---- Outlier-excluded: Proximity (Fig S3b) ----
message("Fitting proximity outlier-excluded city models...")
fits_gs_outl <- lapply(
  split(dt_no_outl, droplevels(dt_no_outl$city)),
  function(x) model_gam_mixed_greenspace(x, family_type = "gamma", include_city = FALSE)
)
names(fits_gs_outl) <- paste0("fit_city_", tolower(names(fits_gs_outl)))

saveRDS(fits_gs_outl,
        paste0(generated.data.folder, "greenspace_outl_city_adjusted_linear.rds"))

save_png(
  plot_smooth_gam(fits_gs_outl, rug = TRUE),
  paste0(output.folder,
    "models_result_greenspace_close_effect_modif_cities_no_outl.png")
)

# ---- Outlier-excluded: NH visits (Fig S3c) ----
message("Fitting NH visits outlier-excluded city models...")

dt_nh <- readRDS(paste0(generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"))

dt_nh <- dt_nh |>
  mutate(city = as.factor(city), neighborhood = as.factor(neighborhood))

city_csi_stats_nh <- dt_nh |>
  group_by(city) |>
  summarise(
    mean_csi = mean(community_severance_index, na.rm = TRUE),
    sd_csi   = sd(community_severance_index,   na.rm = TRUE),
    .groups  = "drop"
  )
dt_nh <- dt_nh |>
  left_join(city_csi_stats_nh, by = "city") |>
  mutate(
    z_csi        = (community_severance_index - mean_csi) / sd_csi,
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier", "Within")
  ) |>
  dplyr::select(-mean_csi, -sd_csi)

dt_nh_no_outl <- dt_nh |>
  filter(
    !is.na(neighbor_visit_count_annual_avg),
    !is.na(home_device_counts_total_parsed_annual_avg),
    home_device_counts_total_parsed_annual_avg > 0,
    outlier_flag != "Outlier"
  )

fits_nh_outl <- lapply(
  split(dt_nh_no_outl, droplevels(dt_nh_no_outl$city)),
  function(x) model_gam_mixed_neighbor_visits(
    x,
    outcome_var = "neighbor_visit_count_annual_avg",
    family_type = "nb",
    offset_var  = "home_device_counts_total_parsed_annual_avg"
  )
)
names(fits_nh_outl) <- paste0("fit_city_", tolower(names(fits_nh_outl)))

saveRDS(fits_nh_outl,
        paste0(generated.data.folder,
          "neighbor_visit_outl_city_adjusted_2019_full_year.rds"))

png(paste0(output.folder,
    "models_result_neighbor_visit_annual_avg_no_outliers_2019_full_year.png"),
  width = 1400, height = 600, type = "quartz")
print(plot_city_comparison(fits_nh_outl, log_y = TRUE, rug = TRUE))
dev.off()
message("NH outlier-excluded figure saved (Fig 2).")

message("All ICE and outlier-excluded figures done.")
