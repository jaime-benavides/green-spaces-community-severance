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
# Uses plot_ice_overlay() on the same centered ratio/RR scale as
# plot_smooth_gam() (Figures 2/3, via compute_shared_ylim()), so a coauthor
# comparing this ICE-stratified figure against the main-analysis figures is
# reading the same axis quantity for a given outcome. log_y matches the
# corresponding main figure's setting per outcome (see below).
ndvi_ice_path <- paste0(generated.data.folder, "ndvi_ice_q1_q5_fit.rds")
gs_ice_path   <- paste0(generated.data.folder, "greenspace_ice_q1_q5_fit.rds")

# Wrap overlay plots: shared y-axis, right-panel y-label removed.
# show_title is TRUE only for the top data row so the city names appear once,
# above the combined figure, rather than repeated on every row.
make_ice_row <- function(q1_list, q5_list, log_y = FALSE, show_title = FALSE) {
  ylim  <- compute_shared_ylim(list(q1 = q1_list, q5 = q5_list))
  plots <- plot_ice_overlay(q1_list, q5_list, rug = TRUE, y_limits = ylim,
                             show_title = show_title, log_y = log_y)
  if (length(plots) > 1)
    plots[[length(plots)]] <- plots[[length(plots)]] +
      ggplot2::theme(axis.title.y = ggplot2::element_blank())
  patchwork::wrap_plots(plots)
}

if (file.exists(ndvi_ice_path) && file.exists(gs_ice_path)) {
  ndvi_ice <- readRDS(ndvi_ice_path)
  gs_ice   <- readRDS(gs_ice_path)

  # Extract a single shared Q1/Q5 legend (identical across all panels) and
  # place it once above the combined figure instead of repeating it per panel.
  legend_plot <- plot_ice_overlay(nh_ice$q1, nh_ice$q5, rug = FALSE)[[1]] +
    ggplot2::theme(legend.position = "right", legend.direction = "horizontal")
  shared_legend <- cowplot::get_legend(legend_plot)

  save_fig(
    patchwork::wrap_elements(shared_legend) /
    make_ice_row(nh_ice$q1,   nh_ice$q5,   log_y = TRUE,  show_title = TRUE) /
    make_ice_row(ndvi_ice$q1, ndvi_ice$q5, log_y = FALSE, show_title = FALSE) /
    make_ice_row(gs_ice$q1,   gs_ice$q5,   log_y = TRUE,  show_title = FALSE) +
    patchwork::plot_layout(heights = c(0.12, 1, 1, 1)),
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
