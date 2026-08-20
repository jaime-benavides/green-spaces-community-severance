rm(list = ls())

# 07_models_neighbor_visits_annual_average.R
# Purpose: Fits the neighboring-home visits GAMs (negative binomial).

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(mgcv)
library(ggplot2)
library(dplyr)
library(gratia)
library(tidyr)
library(patchwork)

save_city_model_plot <- function(model, output_path, y_limits = NULL) {
  if (is.null(model)) {
    return(invisible(NULL))
  }
  
  plot_list <- plot_smooth_gam(list(city_model = model), y_limits = y_limits, rug = TRUE)
  if (length(plot_list) == 0) {
    return(invisible(NULL))
  }
  
  png(output_path, 800, 500)
  print(plot_list[[1]])
  dev.off()
}

args <- commandArgs(trailingOnly = TRUE)
default_period_label <- "2019_full_year"
default_input_path <- paste0(generated.data.folder, "data_models_neighbor_visits_annual_average_", default_period_label, ".rds")
input_path <- if (length(args) >= 1) args[[1]] else default_input_path
output_label <- if (length(args) >= 2) args[[2]] else default_period_label

dt <- readRDS(input_path)

required_cols <- c(
  "community_severance_index",
  "pop_dens",
  "neighborhood",
  "city",
  "neighbor_visit_count_annual_avg",
  "home_device_counts_total_parsed_annual_avg",
  "device_counts_row_total_annual_avg",
  "neighbor_visit_share_annual_avg"
)

missing_cols <- setdiff(required_cols, names(dt))
if (length(missing_cols) > 0) {
  stop("Missing required columns in input dataset: ", paste(missing_cols, collapse = ", "))
}

dt <- dt |>
  mutate(
    city = as.factor(city),
    neighborhood = as.factor(neighborhood)
  )

ice_quint_vars <- c("ICE_inc_quintile", "ICE_rewb_quintile")
ice_cont_vars <- c("ICE_inc", "ICE_rewb")

dt_primary <- dt |>
  filter(
    !is.na(neighbor_visit_count_annual_avg),
    !is.na(home_device_counts_total_parsed_annual_avg),
    home_device_counts_total_parsed_annual_avg > 0
  )

# City-specific CSI z-scores, for excluding outlier tracts from the crude
# (sensitivity) models; the primary/adjusted models here use dt_primary
# unfiltered because they feed the full-sample sensitivity figure (S4),
# which is meant to include outlier tracts.
city_csi_stats <- dt_primary |>
  group_by(city) |>
  summarise(
    mean_csi = mean(community_severance_index, na.rm = TRUE),
    sd_csi   = sd(community_severance_index, na.rm = TRUE),
    .groups = "drop"
  )

dt_primary_no_outl <- dt_primary |>
  left_join(city_csi_stats, by = "city") |>
  mutate(
    z_csi        = (community_severance_index - mean_csi) / sd_csi,
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier (|z|>2)", "Within ±2 SD")
  ) |>
  filter(outlier_flag != "Outlier (|z|>2)")

dt_fallback <- dt |>
  filter(
    !is.na(neighbor_visit_count_annual_avg),
    !is.na(device_counts_row_total_annual_avg),
    device_counts_row_total_annual_avg > 0
  )

dt_share <- dt |>
  filter(!is.na(neighbor_visit_share_annual_avg))

model_list_neighbor_visit_primary <- list(
  fit_all = model_gam_mixed_neighbor_visits(
    dt_primary,
    outcome_var = "neighbor_visit_count_annual_avg",
    family_type = "nb",
    offset_var = "home_device_counts_total_parsed_annual_avg"
  ),
  fit_all_crude = model_gam_mixed_neighbor_visits(
    dt_primary_no_outl,
    outcome_var = "neighbor_visit_count_annual_avg",
    family_type = "nb",
    offset_var = "home_device_counts_total_parsed_annual_avg",
    include_city = TRUE,
    crude = TRUE
  ),
  fits_city_crude = lapply(
    split(dt_primary_no_outl, droplevels(dt_primary_no_outl$city)),
    function(x) model_gam_mixed_neighbor_visits(
      x,
      outcome_var = "neighbor_visit_count_annual_avg",
      family_type = "nb",
      offset_var = "home_device_counts_total_parsed_annual_avg",
      crude = TRUE
    )
  )
)

model_list_neighbor_visit_primary$fits_city <- lapply(
  split(dt_primary, droplevels(dt_primary$city)),
  function(x) model_gam_mixed_neighbor_visits(
    x,
    outcome_var = "neighbor_visit_count_annual_avg",
    family_type = "nb",
    offset_var = "home_device_counts_total_parsed_annual_avg"
  )
)
names(model_list_neighbor_visit_primary$fits_city) <- paste0("fit_city_", tolower(names(model_list_neighbor_visit_primary$fits_city)))
names(model_list_neighbor_visit_primary$fits_city_crude) <- paste0("fit_city_", tolower(names(model_list_neighbor_visit_primary$fits_city_crude)))

model_list_neighbor_visit_fallback <- list(
  fit_all = model_gam_mixed_neighbor_visits(
    dt_fallback,
    outcome_var = "neighbor_visit_count_annual_avg",
    family_type = "nb",
    offset_var = "device_counts_row_total_annual_avg"
  ),
  fit_all_crude = model_gam_mixed_neighbor_visits(
    dt_fallback,
    outcome_var = "neighbor_visit_count_annual_avg",
    family_type = "nb",
    offset_var = "device_counts_row_total_annual_avg",
    include_city = TRUE,
    crude = TRUE
  )
)

model_list_neighbor_visit_share <- list(
  fit_all = model_gam_mixed_neighbor_share(
    dt_share,
    outcome_var = "neighbor_visit_share_annual_avg"
  ),
  fit_all_crude = model_gam_mixed_neighbor_share(
    dt_share,
    outcome_var = "neighbor_visit_share_annual_avg",
    include_city = TRUE,
    crude = TRUE
  ),
  fits_city = lapply(
    split(dt_share, droplevels(dt_share$city)),
    function(x) model_gam_mixed_neighbor_share(
      x,
      outcome_var = "neighbor_visit_share_annual_avg"
    )
  )
)
names(model_list_neighbor_visit_share$fits_city) <- paste0("fit_city_", tolower(names(model_list_neighbor_visit_share$fits_city)))

# -----------------------------------------------------------------------
# ICE Q1/Q5 income-stratified models (neighboring-home count, primary offset)
# Q1 = most disadvantaged; Q5 = most advantaged
# Outlier-excluded, consistent with the primary analysis (Methods) and with
# the NDVI/proximity ICE Q1/Q5 models in 07c_generate_linear_ice_outl_figures.R.
# -----------------------------------------------------------------------

dt_nh_q1 <- dt_primary_no_outl[dt_primary_no_outl$ICE_inc_quintile == "Q1 (Most Disadvantaged)", ]
dt_nh_q5 <- dt_primary_no_outl[dt_primary_no_outl$ICE_inc_quintile == "Q5 (Most Advantaged)", ]

fits_nh_ice_q1 <- lapply(
  split(dt_nh_q1, droplevels(dt_nh_q1$city)),
  function(x) model_gam_mixed_neighbor_visits(
    x,
    outcome_var = "neighbor_visit_count_annual_avg",
    family_type = "nb",
    offset_var  = "home_device_counts_total_parsed_annual_avg"
  )
)
names(fits_nh_ice_q1) <- paste0("fit_city_", tolower(names(fits_nh_ice_q1)))

fits_nh_ice_q5 <- lapply(
  split(dt_nh_q5, droplevels(dt_nh_q5$city)),
  function(x) model_gam_mixed_neighbor_visits(
    x,
    outcome_var = "neighbor_visit_count_annual_avg",
    family_type = "nb",
    offset_var  = "home_device_counts_total_parsed_annual_avg"
  )
)
names(fits_nh_ice_q5) <- paste0("fit_city_", tolower(names(fits_nh_ice_q5)))

plot_nh_ice_q1 <- plot_smooth_gam(fits_nh_ice_q1, y_limits = NULL, rug = TRUE)
plot_nh_ice_q5 <- plot_smooth_gam(fits_nh_ice_q5, y_limits = NULL, rug = TRUE)

all_nh_ice_plots <- c(plot_nh_ice_q1, plot_nh_ice_q5)
if (length(all_nh_ice_plots) > 0) {
  png(paste0(output.folder, "models_result_neighbor_visit_q1_q5_ICE_inc_", output_label, ".png"), 1100, 500)
  print(patchwork::wrap_plots(all_nh_ice_plots))
  dev.off()
}

saveRDS(
  list(q1 = fits_nh_ice_q1, q5 = fits_nh_ice_q5),
  paste0(generated.data.folder, "neighbor_visit_ice_q1_q5_fit_", output_label, ".rds")
)

saveRDS(
  list(
    primary = model_list_neighbor_visit_primary,
    fallback = model_list_neighbor_visit_fallback,
    share = model_list_neighbor_visit_share
  ),
  paste0(generated.data.folder, "neighbor_visit_annual_average_model_objects_", output_label, ".rds")
)

png(paste0(output.folder,
    "models_result_neighbor_visit_annual_avg_primary_crude_", output_label, ".png"),
  width = 1400, height = 600)
print(plot_city_comparison(
  model_list_neighbor_visit_primary$fits_city_crude, log_y = TRUE, rug = TRUE))
dev.off()

png(paste0(output.folder,
    "models_result_neighbor_visit_annual_avg_primary_adjusted_", output_label, ".png"),
  width = 1400, height = 600)
print(plot_city_comparison(
  model_list_neighbor_visit_primary$fits_city, log_y = TRUE, rug = TRUE))
dev.off()

plot_share_adjusted <- plot_smooth_gam(
  model_list_neighbor_visit_share$fits_city,
  y_limits = c(0, 1),
  rug = TRUE
)

if (length(plot_share_adjusted) > 0) {
  png(paste0(output.folder, "models_result_neighbor_visit_annual_avg_share_adjusted_", output_label, ".png"), 1100, 500)
  print(patchwork::wrap_plots(plot_share_adjusted))
  dev.off()
}

message("Neighbor-visit annual-average models saved to: ",
        paste0(generated.data.folder, "neighbor_visit_annual_average_model_objects_", output_label, ".rds"))

for (city_name in names(model_list_neighbor_visit_primary$fits_city)) {
  saveRDS(
    model_list_neighbor_visit_primary$fits_city[[city_name]],
    paste0(generated.data.folder, "neighbor_visit_primary_", city_name, "_", output_label, ".rds")
  )
  save_city_model_plot(
    model_list_neighbor_visit_primary$fits_city[[city_name]],
    paste0(output.folder, "models_result_neighbor_visit_primary_", city_name, "_", output_label, ".png")
  )
}

for (city_name in names(model_list_neighbor_visit_primary$fits_city_crude)) {
  saveRDS(
    model_list_neighbor_visit_primary$fits_city_crude[[city_name]],
    paste0(generated.data.folder, "neighbor_visit_primary_crude_", city_name, "_", output_label, ".rds")
  )
  save_city_model_plot(
    model_list_neighbor_visit_primary$fits_city_crude[[city_name]],
    paste0(output.folder, "models_result_neighbor_visit_primary_crude_", city_name, "_", output_label, ".png")
  )
}

for (city_name in names(model_list_neighbor_visit_share$fits_city)) {
  saveRDS(
    model_list_neighbor_visit_share$fits_city[[city_name]],
    paste0(generated.data.folder, "neighbor_visit_share_", city_name, "_", output_label, ".rds")
  )
  save_city_model_plot(
    model_list_neighbor_visit_share$fits_city[[city_name]],
    paste0(output.folder, "models_result_neighbor_visit_share_", city_name, "_", output_label, ".png"),
    y_limits = c(0, 1)
  )
}
