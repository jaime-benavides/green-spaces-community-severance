rm(list = ls())

# 07d_generate_figure1_maps.R
# Purpose: Builds Figure 1 (2-row x 4-col city/variable map grid) and
#          supplementary spatial maps (Fig S1).

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(tmap)
library(dplyr)
library(sf)

manuscript.folder <- paste0(project.folder, "manuscript/")
tmap_mode("plot")

# ── Load city boundaries (500 Cities project) ─────────────────────────────────
city_nyc <- readRDS(paste0(generated.data.folder, "city_boundary_nyc.rds"))
city_la  <- readRDS(paste0(generated.data.folder, "city_boundary_la.rds"))

# ── Load geometry, clip to city boundary (land only) ──────────────────────────
geom_nyc_raw <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds"))
city_nyc_tr  <- city_nyc |> sf::st_transform(sf::st_crs(geom_nyc_raw)) |>
  sf::st_make_valid() |> sf::st_union()
geom_nyc <- geom_nyc_raw |>
  select(GEOID, geometry) |> sf::st_make_valid() |>
  sf::st_intersection(city_nyc_tr)

geom_la_raw <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))
city_la_tr   <- city_la |> sf::st_transform(sf::st_crs(geom_la_raw)) |>
  sf::st_make_valid() |> sf::st_union()
geom_la <- geom_la_raw |>
  select(GEOID, geometry) |> sf::st_make_valid() |>
  sf::st_intersection(city_la_tr)

# ── Load and join data ─────────────────────────────────────────────────────────
csi_nyc <- readRDS(paste0(generated.data.folder, "community_severance_nyc_census_tract.rds"))
csi_la  <- readRDS(paste0(generated.data.folder, "community_severance_la_census_tract.rds"))

nh_all <- readRDS(paste0(generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds")) |>
  select(GEOID, city, neighbor_visit_count_annual_avg, neighbor_visit_share_annual_avg)

nh_nyc <- nh_all |> filter(city == "NYC") |> select(-city)
nh_la  <- nh_all |> filter(city == "LA")  |> select(-city)

dm <- readRDS(paste0(generated.data.folder, "data_models.rds")) |>
  mutate(GEOID = ifelse(nchar(GEOID) == 10, paste0("0", GEOID), GEOID))

dm_nyc <- dm |> filter(city == "NYC")
dm_la  <- dm |> filter(city == "LA")

# ── Build sf objects per city ──────────────────────────────────────────────────
sf_nyc <- geom_nyc |>
  left_join(csi_nyc, by = "GEOID") |>
  left_join(nh_nyc,  by = "GEOID") |>
  left_join(dm_nyc  |> select(GEOID, NDVI, closest_greenspace,
                               ICE_inc, ICE_inc_quintile,
                               perc.black, perc.hisp,
                               perc.pov, pop_dens, building_density),
            by = "GEOID")

sf_la <- geom_la |>
  left_join(csi_la, by = "GEOID") |>
  left_join(nh_la,  by = "GEOID") |>
  left_join(dm_la   |> select(GEOID, NDVI, closest_greenspace,
                               ICE_inc, ICE_inc_quintile,
                               perc.black, perc.hisp,
                               perc.pov, pop_dens, building_density),
            by = "GEOID")

# ICE Q1/Q5 categorical variable (Q1 = most deprived, Q5 = most advantaged)
make_ice_q1q5 <- function(sf_data) {
  sf_data |>
    mutate(ice_q1q5 = factor(
      case_when(
        grepl("Q1", ICE_inc_quintile) ~ "Q1 (Most Deprived)",
        grepl("Q5", ICE_inc_quintile) ~ "Q5 (Most Advantaged)",
        !is.na(ICE_inc_quintile)      ~ "Q2–Q4",
        TRUE ~ NA_character_
      ),
      levels = c("Q1 (Most Deprived)", "Q2–Q4", "Q5 (Most Advantaged)")
    ))
}

sf_nyc <- make_ice_q1q5(sf_nyc)
sf_la  <- make_ice_q1q5(sf_la)

# NH-only subsets: omit tracts outside the NH analytic sample entirely
sf_nyc_nh <- sf_nyc |> dplyr::filter(!is.na(neighbor_visit_count_annual_avg))
sf_la_nh  <- sf_la  |> dplyr::filter(!is.na(neighbor_visit_count_annual_avg))

# ICE Q1/Q5 subsets: omit tracts with missing ICE quintile data
sf_nyc_ice <- sf_nyc |> dplyr::filter(!is.na(ice_q1q5))
sf_la_ice  <- sf_la  |> dplyr::filter(!is.na(ice_q1q5))

# ── Map helper functions ───────────────────────────────────────────────────────
# Legends are placed OUTSIDE the map frame (to the right of each panel) so
# they never overlap the tract polygons; panels carry a small a/b/c... label
# in the top-left corner instead of a full descriptive title (kept out of the
# map area too, via tm_pos_out, to avoid ever sitting on top of data).
# Note: tm_legend(orientation = "landscape") with tm_pos_out(..., "bottom")
# throws an internal tmap 4.1 grid error for 10-item legends; the vertical
# outside-right legend below is a stable equivalent.
make_panel <- function(sf_data, var, palette, city_title,
                       show_legend = TRUE, legend_title = "",
                       reverse = FALSE, panel_label = "") {
  pal <- if (reverse) paste0("-", palette) else palette
  leg <- if (show_legend) {
    tm_legend(title = legend_title,
              position = tm_pos_out("right", "center"),
              frame = FALSE,
              item.height = 1.1, item.width = 1.1,
              text.size = 1.1, title.size = 1.3)
  } else {
    tm_legend(show = FALSE)
  }

  tm_shape(sf_data) +
    tm_polygons(
      fill = var,
      fill.scale = tm_scale_intervals(
        n = 10, style = "quantile",
        values = pal,
        value.na = NA
      ),
      fill.legend = leg,
      col_alpha = 0,
      lwd = 0
    ) +
    tm_layout(
      frame        = FALSE,
      bg.color     = "white",
      inner.margins = 0.02,
      title        = panel_label,
      title.position = tm_pos_in("left", "top"),
      title.size   = 1.3,
      title.fontface = "bold"
    )
}

# Categorical panel for ICE Q1/Q5 map
make_panel_cat <- function(sf_data, var, palette_vals, cat_labels, city_title,
                           show_legend = TRUE, legend_title = "") {
  leg <- if (show_legend) {
    tm_legend(title = legend_title,
              position = tm_pos_out("right", "center"),
              frame = FALSE,
              item.height = 1.2, item.width = 1.2,
              text.size = 1.2, title.size = 1.4)
  } else {
    tm_legend(show = FALSE)
  }

  tm_shape(sf_data) +
    tm_polygons(
      fill = var,
      fill.scale = tm_scale_categorical(
        values = palette_vals,
        labels = cat_labels,
        value.na = NA
      ),
      fill.legend = leg,
      col_alpha = 0,
      lwd = 0
    ) +
    tm_layout(
      frame        = FALSE,
      bg.color     = "white",
      inner.margins = 0.02
    )
}

save_tmap <- function(tmap_obj, path, width = 3000, height = 1400) {
  png(path, width = width, height = height, res = 300, type = "quartz")
  print(tmap_obj)
  dev.off()
  message("Saved: ", basename(path))
}

# ── FIGURE 1: shared-legend decile grid (rows = LA, NYC; columns = NH, NDVI,
# proximity, CSI). Follows the layout convention of Benavides et al. 2026
# (Environ Epidemiol): a single decile-percentage legend at the top, variable
# names as column headers, and city names as row headers, rather than a
# separate legend and title on every one of the eight panels. ──────────────
message("Building Figure 1 composite map (shared decile-percentage legend, faceted by city x variable)...")

library(ggplot2)

decile_rank <- function(x) {
  r <- rep(NA_integer_, length(x))
  ok <- !is.na(x)
  r[ok] <- dplyr::ntile(x[ok], 10)
  r
}

decile_labels <- paste0(seq(0, 90, 10), "%–", seq(10, 100, 10), "%")
decile_pal    <- colorRampPalette(RColorBrewer::brewer.pal(9, "Purples"))(10)

var_levels <- c("Neighboring-home visit rate", "NDVI",
                 "Distance to green space", "Community Severance Index")

# One row per tract x variable, with a within-city decile rank (1-10) computed
# separately for each variable; the neighboring-home visit rate is ranked
# within the NH analytic sample only (sf_data_nh), the other three variables
# within the full city sample (sf_data), matching the original per-panel maps.
build_fig1_df <- function(sf_data, sf_data_nh, city_name) {
  nh_dec <- sf_data_nh |>
    sf::st_drop_geometry() |>
    dplyr::transmute(GEOID, decile = decile_rank(neighbor_visit_count_annual_avg),
                      variable = var_levels[1])

  base <- sf_data |>
    dplyr::mutate(
      ndvi_dec = decile_rank(NDVI),
      prox_dec = decile_rank(closest_greenspace),
      csi_dec  = decile_rank(community_severance_index)
    )
  geom_lookup <- base |> dplyr::select(GEOID, geometry)

  other_dec <- dplyr::bind_rows(
    base |> sf::st_drop_geometry() |>
      dplyr::transmute(GEOID, decile = ndvi_dec, variable = var_levels[2]),
    base |> sf::st_drop_geometry() |>
      dplyr::transmute(GEOID, decile = prox_dec, variable = var_levels[3]),
    base |> sf::st_drop_geometry() |>
      dplyr::transmute(GEOID, decile = csi_dec,  variable = var_levels[4])
  )

  dplyr::bind_rows(nh_dec, other_dec) |>
    dplyr::left_join(geom_lookup, by = "GEOID") |>
    sf::st_as_sf() |>
    dplyr::mutate(city = city_name,
                  variable = factor(variable, levels = var_levels))
}

fig1_df <- dplyr::bind_rows(
  build_fig1_df(sf_la,  sf_la_nh,  "Los Angeles"),
  build_fig1_df(sf_nyc, sf_nyc_nh, "New York City")
) |>
  dplyr::mutate(
    city     = factor(city, levels = c("Los Angeles", "New York City")),
    decile_f = factor(decile_labels[decile], levels = decile_labels)
  )

# coord_sf() does not support facet_grid(scales = "free"), and LA/NYC are far
# enough apart that shared map scales shrink both cities to specks, so the
# grid is built panel-by-panel with patchwork instead of via faceting.
map_panel <- function(city_name, var_name) {
  d <- dplyr::filter(fig1_df, city == city_name, variable == var_name)
  ggplot(d) +
    geom_sf(aes(fill = decile_f), color = NA) +
    scale_fill_manual(values = decile_pal, na.value = "white",
                       drop = FALSE, name = NULL) +
    theme_void() +
    theme(legend.position = "none")
}

text_panel <- function(label, angle = 0, size = 5) {
  ggplot() +
    annotate("text", x = 0, y = 0, label = label, angle = angle,
             fontface = "bold", size = size) +
    xlim(-1, 1) + ylim(-1, 1) +
    theme_void()
}

legend_src <- map_panel("Los Angeles", var_levels[1]) +
  scale_fill_manual(values = decile_pal, na.value = "white", drop = FALSE,
                     name = NULL,
                     guide = guide_legend(nrow = 1, byrow = TRUE,
                                          keywidth = unit(1.1, "lines"),
                                          keyheight = unit(1.1, "lines"))) +
  theme(legend.position = "right", legend.direction = "horizontal",
        legend.text = element_text(size = 11))
shared_legend <- cowplot::get_legend(legend_src)

row_label_w <- 0.10
col_w       <- (1 - row_label_w) / 4
row_widths  <- c(row_label_w, col_w, col_w, col_w, col_w)

build_row <- function(row_label_plot, city_name = NULL) {
  panels <- if (is.null(city_name)) {
    lapply(var_levels, text_panel)
  } else {
    lapply(var_levels, function(v) map_panel(city_name, v))
  }
  row <- patchwork::wrap_plots(c(list(row_label_plot), panels), nrow = 1)
  row + patchwork::plot_layout(widths = row_widths)
}

header_row <- build_row(text_panel(""))
la_row     <- build_row(text_panel("Los Angeles", angle = 90), "Los Angeles")
nyc_row    <- build_row(text_panel("New York City", angle = 90), "New York City")

fig1 <- patchwork::wrap_elements(shared_legend) / header_row / la_row / nyc_row +
  patchwork::plot_layout(heights = c(0.08, 0.06, 1, 1))

ggsave(paste0(output.folder, "figure1_nh_csi_maps.png"), fig1,
       width = 14, height = 8, dpi = 300, bg = "white")
message("Saved: figure1_nh_csi_maps.png")

# ── SUPPLEMENTARY: ICE Q1/Q5 categorical map (Supp Fig S2b) ───────────────────
message("Building Supp Figure S2b: ICE Q1/Q5 categorical map...")

ice_pal    <- c("#D73027", "#D9D9D9", "#4575B4")  # red, gray, blue
ice_labels <- c("Q1 (Most Deprived)", "Q2–Q4", "Q5 (Most Advantaged)")

p_ice_q1q5_la  <- make_panel_cat(sf_la_ice,  "ice_q1q5", ice_pal, ice_labels,
                                   "Los Angeles", show_legend = FALSE)
p_ice_q1q5_nyc <- make_panel_cat(sf_nyc_ice, "ice_q1q5", ice_pal, ice_labels,
                                   "New York City", show_legend = TRUE,
                                   legend_title = "")

supp_ice_q1q5 <- tmap_arrange(p_ice_q1q5_la, p_ice_q1q5_nyc, nrow = 1, ncol = 2,
                               widths = c(1, 1.7))

save_tmap(supp_ice_q1q5,
          paste0(output.folder, "supp_map_ice_q1_q5.png"),
          width = 3200, height = 1400)

# ── OTHER SUPPLEMENTARY MAPS ───────────────────────────────────────────────────

save_supp_map <- function(var, palette, leg_title,
                          fname, width = 3200, height = 1400,
                          reverse = FALSE) {
  p_la  <- make_panel(sf_la,  var, palette, "Los Angeles",
                      show_legend = FALSE, reverse = reverse)
  p_nyc <- make_panel(sf_nyc, var, palette, "New York City",
                      show_legend = TRUE, legend_title = leg_title,
                      reverse = reverse)
  out <- tmap_arrange(p_la, p_nyc, nrow = 1, ncol = 2, widths = c(1, 1.7))
  save_tmap(out, paste0(output.folder, fname), width = width, height = height)
}

message("Generating supplementary descriptive maps...")

# NDVI and distance-to-green-space spatial maps are NOT regenerated here: they
# duplicated Figure 1 (which already maps both variables) and were removed
# from the manuscript as Figs S1a/S1b on 2026-07-13.

save_supp_map("ICE_inc", "RdBu", "Income ICE\n(decile)", "supp_map_ice_inc.png")

message("All maps generated and saved to output/")
