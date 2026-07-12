rm(list = ls())

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
make_panel <- function(sf_data, var, palette, city_title,
                       show_legend = TRUE, legend_title = "",
                       reverse = FALSE, panel_title = "") {
  pal <- if (reverse) paste0("-", palette) else palette
  leg <- if (show_legend) {
    tm_legend(title = legend_title, position = tm_pos_in("right", "center"),
              frame = FALSE, bg.color = "white", bg.alpha = 0.7)
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
      title        = panel_title,
      title.position = tm_pos_in("center", "top"),
      title.size   = 1.1,
      title.fontface = "bold"
    )
}

# Categorical panel for ICE Q1/Q5 map
make_panel_cat <- function(sf_data, var, palette_vals, cat_labels, city_title,
                           show_legend = TRUE, legend_title = "") {
  leg <- if (show_legend) {
    tm_legend(title = legend_title, position = tm_pos_in("right", "center"),
              frame = FALSE, bg.color = "white", bg.alpha = 0.7)
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

# ── FIGURE 1: two rows (LA, NYC), each with 4 maps (NH, NDVI, proximity, CSI) ──
message("Building Figure 1 composite map (2 rows: LA, NYC; 4 columns: NH, NDVI, proximity, CSI)...")

# Top row (LA) carries the column headers; bottom row (NYC) repeats no titles,
# so the four map-type captions are shared between both city rows.
p_nh_la  <- make_panel(sf_la_nh,  "neighbor_visit_count_annual_avg",
                        "Greens", "Los Angeles", show_legend = TRUE,
                        legend_title = "NH visits", panel_title = "Neighboring-home visits")
p_ndvi_la  <- make_panel(sf_la,  "NDVI",
                          "YlGn", "Los Angeles", show_legend = TRUE,
                          legend_title = "NDVI", panel_title = "NDVI")
p_prox_la  <- make_panel(sf_la,  "closest_greenspace",
                          "Blues", "Los Angeles", show_legend = TRUE,
                          legend_title = "Distance to\ngreen space (m)",
                          panel_title = "Distance to nearest\ngreen space")
p_csi_la <- make_panel(sf_la, "community_severance_index",
                         "Reds", "Los Angeles", show_legend = TRUE,
                         legend_title = "CSI", panel_title = "Community\nSeverance Index")

p_nh_nyc <- make_panel(sf_nyc_nh, "neighbor_visit_count_annual_avg",
                        "Greens", "New York City", show_legend = TRUE,
                        legend_title = "NH visits")
p_ndvi_nyc <- make_panel(sf_nyc, "NDVI",
                          "YlGn", "New York City", show_legend = TRUE,
                          legend_title = "NDVI")
p_prox_nyc <- make_panel(sf_nyc, "closest_greenspace",
                          "Blues", "New York City", show_legend = TRUE,
                          legend_title = "Distance to\ngreen space (m)")
p_csi_nyc <- make_panel(sf_nyc, "community_severance_index",
                         "Reds", "New York City", show_legend = TRUE,
                         legend_title = "CSI")

fig1 <- tmap_arrange(
  p_nh_la,  p_ndvi_la,  p_prox_la,  p_csi_la,
  p_nh_nyc, p_ndvi_nyc, p_prox_nyc, p_csi_nyc,
  nrow = 2, ncol = 4
)

save_tmap(fig1, paste0(output.folder, "figure1_nh_csi_maps.png"),
          width = 5600, height = 2600)
file.copy(paste0(output.folder, "figure1_nh_csi_maps.png"),
          paste0(manuscript.folder, "figs/figure1_nh_csi_maps.png"),
          overwrite = TRUE)
message("Copied Figure 1 to manuscript/figs/")

# ── SUPPLEMENTARY: ICE Q1/Q5 categorical map (Supp Fig S2b) ───────────────────
message("Building Supp Figure S2b: ICE Q1/Q5 categorical map...")

ice_pal    <- c("#D73027", "#D9D9D9", "#4575B4")  # red, gray, blue
ice_labels <- c("Q1 (Most Deprived)", "Q2–Q4", "Q5 (Most Advantaged)")

p_ice_q1q5_nyc <- make_panel_cat(sf_nyc_ice, "ice_q1q5", ice_pal, ice_labels,
                                   "New York City", show_legend = FALSE)
p_ice_q1q5_la  <- make_panel_cat(sf_la_ice,  "ice_q1q5", ice_pal, ice_labels,
                                   "Los Angeles", show_legend = TRUE,
                                   legend_title = "")

supp_ice_q1q5 <- tmap_arrange(p_ice_q1q5_nyc, p_ice_q1q5_la, nrow = 1, ncol = 2)

save_tmap(supp_ice_q1q5,
          paste0(output.folder, "supp_map_ice_q1_q5.png"),
          width = 3200, height = 1400)
file.copy(paste0(output.folder, "supp_map_ice_q1_q5.png"),
          paste0(manuscript.folder, "figs/supp_map_ice_q1_q5.png"),
          overwrite = TRUE)
message("Copied supp_map_ice_q1_q5.png to manuscript/figs/")

# ── OTHER SUPPLEMENTARY MAPS ───────────────────────────────────────────────────

save_supp_map <- function(var, palette, leg_title,
                          fname, width = 3200, height = 1400,
                          reverse = FALSE) {
  p_nyc <- make_panel(sf_nyc, var, palette, "New York City",
                      show_legend = FALSE, reverse = reverse)
  p_la  <- make_panel(sf_la,  var, palette, "Los Angeles",
                      show_legend = TRUE, legend_title = leg_title,
                      reverse = reverse)
  out <- tmap_arrange(p_nyc, p_la, nrow = 1, ncol = 2)
  save_tmap(out, paste0(output.folder, fname), width = width, height = height)
  file.copy(paste0(output.folder, fname),
            paste0(manuscript.folder, "figs/", fname), overwrite = TRUE)
  message("Copied ", fname, " to manuscript/figs/")
}

message("Generating supplementary descriptive maps...")

save_supp_map("NDVI", "YlGn", "NDVI\n(decile)", "supp_map_ndvi.png")

save_supp_map("closest_greenspace", "Blues", "Distance to\ngreen space (m)\n(decile)",
              "supp_map_proximity.png")

save_supp_map("ICE_inc", "RdBu", "Income ICE\n(decile)", "supp_map_ice_inc.png")

message("All maps generated and copied to manuscript/figs/")
