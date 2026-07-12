rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(ggplot2)
library(patchwork)

save_png <- function(plot_list, path, width = 1400, height = 600) {
  if (length(plot_list) == 0) {
    warning("No plots to save for: ", path)
    return(invisible(NULL))
  }
  png(path, width = width, height = height)
  print(patchwork::wrap_plots(plot_list))
  dev.off()
  message("Saved: ", basename(path))
}

save_fig <- function(p, path, width = 1400, height = 600) {
  png(path, width = width, height = height)
  print(p)
  dev.off()
  message("Saved: ", basename(path))
}

# ---- Load all saved model objects ----
ndvi_adj   <- readRDS(paste0(generated.data.folder, "ndvi_model_objects_city_adjusted_linear.rds"))
ndvi_crude <- readRDS(paste0(generated.data.folder, "ndvi_model_objects_city_crude_linear.rds"))
gs_adj     <- readRDS(paste0(generated.data.folder, "greenspace_model_objects_city_adjusted_linear.rds"))
gs_crude   <- readRDS(paste0(generated.data.folder, "greenspace_model_objects_city_crude_linear.rds"))

nh_models  <- readRDS(paste0(generated.data.folder,
  "neighbor_visit_annual_average_model_objects_2019_full_year.rds"))
nh_ice     <- readRDS(paste0(generated.data.folder,
  "neighbor_visit_ice_q1_q5_fit_2019_full_year.rds"))

# ---- NH: crude (S4a = Sensitivity 1) and adjusted full sample (S5a = Sensitivity 2) ----
save_fig(
  plot_city_comparison(nh_models$primary$fits_city_crude, log_y = TRUE, rug = TRUE),
  paste0(output.folder,
    "models_result_neighbor_visit_annual_avg_primary_crude_2019_full_year.png")
)
save_fig(
  plot_city_comparison(nh_models$primary$fits_city, log_y = TRUE, rug = TRUE),
  paste0(output.folder,
    "models_result_neighbor_visit_annual_avg_primary_adjusted_2019_full_year.png")
)

# ---- NDVI + proximity: crude (S4b = Sensitivity 1) and adjusted full sample (S5b = Sensitivity 2) ----
save_fig(
  plot_city_comparison(ndvi_adj,  log_y = FALSE, rug = TRUE) /
  plot_city_comparison(gs_adj,    log_y = TRUE,  rug = TRUE),
  paste0(output.folder, "models_result_ndvi_proximity_full_sample.png"),
  width = 1400, height = 1200
)
save_fig(
  plot_city_comparison(ndvi_crude, log_y = FALSE, rug = TRUE) /
  plot_city_comparison(gs_crude,   log_y = TRUE,  rug = TRUE),
  paste0(output.folder, "models_result_ndvi_proximity_crude.png"),
  width = 1400, height = 1200
)

# ---- ICE Q1/Q5 combined figure (Fig 4): NH (top), NDVI (middle), proximity (bottom) ----
# Uses plot_ice_overlay() so intercepts are added back and Q1/Q5 are shown at
# absolute predicted values on a shared y-axis within each row.
ndvi_ice_path <- paste0(generated.data.folder, "ndvi_ice_q1_q5_fit.rds")
gs_ice_path   <- paste0(generated.data.folder, "greenspace_ice_q1_q5_fit.rds")

# Compute shared y-limits from absolute predicted values (smooth + intercept)
ice_ylim <- function(q1_list, q5_list,
                     smooth_term = "s(community_severance_index)") {
  all_vals <- unlist(lapply(names(q1_list), function(city) {
    m1 <- q1_list[[city]]; m5 <- q5_list[[city]]
    int1 <- coef(m1)[1];   int5 <- coef(m5)[1]
    linkinv <- m1$family$linkinv
    fam     <- m1$family$family
    trf <- function(x, int) {
      if (grepl("gaussian", fam, ignore.case = TRUE)) x + int
      else linkinv(x + int)
    }
    sm1 <- gratia::smooth_estimates(m1, smooth = smooth_term) |>
      gratia::add_confint()
    sm5 <- gratia::smooth_estimates(m5, smooth = smooth_term) |>
      gratia::add_confint()
    c(trf(sm1$.lower_ci, int1), trf(sm1$.upper_ci, int1),
      trf(sm5$.lower_ci, int5), trf(sm5$.upper_ci, int5))
  }))
  rng <- diff(range(all_vals, na.rm = TRUE))
  c(min(all_vals, na.rm = TRUE) - 0.05 * rng,
    max(all_vals, na.rm = TRUE) + 0.05 * rng)
}

# Wrap overlay plots: shared y-axis, right-panel y-label removed
make_ice_row <- function(q1_list, q5_list) {
  ylim  <- ice_ylim(q1_list, q5_list)
  plots <- plot_ice_overlay(q1_list, q5_list, rug = TRUE, y_limits = ylim)
  if (length(plots) > 1)
    plots[[length(plots)]] <- plots[[length(plots)]] +
      ggplot2::theme(axis.title.y = ggplot2::element_blank())
  patchwork::wrap_plots(plots)
}

if (file.exists(ndvi_ice_path) && file.exists(gs_ice_path)) {
  ndvi_ice <- readRDS(ndvi_ice_path)
  gs_ice   <- readRDS(gs_ice_path)
  save_fig(
    make_ice_row(nh_ice$q1,   nh_ice$q5)   /
    make_ice_row(ndvi_ice$q1, ndvi_ice$q5) /
    make_ice_row(gs_ice$q1,   gs_ice$q5),
    paste0(output.folder, "models_result_ice_q1_q5_combined.png"),
    width = 1400, height = 1800
  )
} else {
  message("Skipping Fig 4 (ICE combined): NDVI or proximity ICE file not found.")
}

# ---- NH share (not in manuscript) ----
save_png(
  plot_smooth_gam(nh_models$share$fits_city, rug = TRUE, y_limits = c(0, 1)),
  paste0(output.folder,
    "models_result_neighbor_visit_annual_avg_share_adjusted_2019_full_year.png")
)

# ---- Outlier-excluded: NDVI + proximity combined (Fig 3), NH (Fig 2) ----
ndvi_outl_path <- paste0(generated.data.folder, "ndvi_outl_city_adjusted_linear.rds")
gs_outl_path   <- paste0(generated.data.folder, "greenspace_outl_city_adjusted_linear.rds")
nh_outl_path   <- paste0(generated.data.folder,
  "neighbor_visit_outl_city_adjusted_2019_full_year.rds")

if (file.exists(ndvi_outl_path) && file.exists(gs_outl_path)) {
  save_fig(
    plot_city_comparison(readRDS(ndvi_outl_path), log_y = FALSE, rug = TRUE) /
    plot_city_comparison(readRDS(gs_outl_path),   log_y = TRUE,  rug = TRUE),
    paste0(output.folder, "models_result_ndvi_proximity_primary.png"),
    width = 1400, height = 1200
  )
} else {
  message("Skipping Fig 3 (NDVI+proximity outlier-excluded): one or both files not found.")
}

if (file.exists(nh_outl_path)) {
  save_fig(
    plot_city_comparison(readRDS(nh_outl_path), log_y = TRUE, rug = TRUE),
    paste0(output.folder,
      "models_result_neighbor_visit_annual_avg_no_outliers_2019_full_year.png")
  )
} else {
  message("Skipping Fig 2 (NH outlier-excluded): file not found.")
}

# ---- Copy all updated figures to manuscript/figs/ ----
manuscript_figs <- paste0(project.folder, "manuscript/figs/")
figs_to_copy <- c(
  "models_result_neighbor_visit_annual_avg_no_outliers_2019_full_year.png",
  "models_result_ndvi_proximity_primary.png",
  "models_result_neighbor_visit_annual_avg_primary_adjusted_2019_full_year.png",
  "models_result_ndvi_proximity_full_sample.png",
  "models_result_neighbor_visit_annual_avg_primary_crude_2019_full_year.png",
  "models_result_ndvi_proximity_crude.png",
  "models_result_ice_q1_q5_combined.png"
)
for (f in figs_to_copy) {
  src <- paste0(output.folder, f)
  if (file.exists(src)) {
    file.copy(src, paste0(manuscript_figs, f), overwrite = TRUE)
    message("Copied to manuscript/figs/: ", f)
  }
}

message("Done. All updated figures copied to manuscript/figs/")
