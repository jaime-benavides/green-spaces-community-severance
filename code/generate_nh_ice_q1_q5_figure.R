rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(mgcv)
library(patchwork)

args <- commandArgs(trailingOnly = TRUE)
default_label <- "2019_full_year"
default_input <- paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_",
  default_label,
  ".rds"
)
input_path   <- if (length(args) >= 1) args[[1]] else default_input
output_label <- if (length(args) >= 2) args[[2]] else default_label

if (!file.exists(input_path)) stop("Input dataset not found: ", input_path)

dt <- readRDS(input_path)

dt <- dt |>
  dplyr::mutate(
    city         = as.factor(city),
    neighborhood = as.factor(neighborhood)
  )

dt_primary <- dt |>
  dplyr::filter(
    !is.na(neighbor_visit_count_annual_avg),
    !is.na(home_device_counts_total_parsed_annual_avg),
    home_device_counts_total_parsed_annual_avg > 0
  )

dt_nh_q1 <- dt_primary[dt_primary$ICE_inc_quintile == "Q1 (Most Disadvantaged)", ]
dt_nh_q5 <- dt_primary[dt_primary$ICE_inc_quintile == "Q5 (Most Advantaged)", ]

message("Fitting NH ICE Q1 city models...")
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

message("Fitting NH ICE Q5 city models...")
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

saveRDS(
  list(q1 = fits_nh_ice_q1, q5 = fits_nh_ice_q5),
  paste0(generated.data.folder, "neighbor_visit_ice_q1_q5_fit_", output_label, ".rds")
)

all_plots <- plot_ice_overlay(fits_nh_ice_q1, fits_nh_ice_q5, rug = TRUE)

out_path <- paste0(
  output.folder,
  "models_result_neighbor_visit_q1_q5_ICE_inc_",
  output_label,
  ".png"
)

if (length(all_plots) > 0) {
  png(out_path, width = 1400, height = 600, type = "quartz")
  print(patchwork::wrap_plots(all_plots, ncol = 2))
  dev.off()
  message("Figure saved to: ", out_path)
} else {
  warning("No plots were generated — check model fitting.")
}
