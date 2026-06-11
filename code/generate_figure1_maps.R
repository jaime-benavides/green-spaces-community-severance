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
# CSI: 11-digit GEOIDs for both cities (match geometry directly)
csi_nyc <- readRDS(paste0(generated.data.folder, "community_severance_nyc_census_tract.rds"))
csi_la  <- readRDS(paste0(generated.data.folder, "community_severance_la_census_tract.rds"))

# NH outcome: 11-digit GEOIDs for both cities
nh_all <- readRDS(paste0(generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds")) |>
  select(GEOID, city, neighbor_visit_count_annual_avg, neighbor_visit_share_annual_avg)

nh_nyc <- nh_all |> filter(city == "NYC") |> select(-city)
nh_la  <- nh_all |> filter(city == "LA")  |> select(-city)

# data_models (NDVI, covariates): LA has 10-digit GEOIDs — pad to 11-digit
dm <- readRDS(paste0(generated.data.folder, "data_models.rds")) |>
  mutate(GEOID = ifelse(nchar(GEOID) == 10, paste0("0", GEOID), GEOID))

dm_nyc <- dm |> filter(city == "NYC")
dm_la  <- dm |> filter(city == "LA")

# ── Build sf objects per city ──────────────────────────────────────────────────
sf_nyc <- geom_nyc |>
  left_join(csi_nyc, by = "GEOID") |>
  left_join(nh_nyc,  by = "GEOID") |>
  left_join(dm_nyc  |> select(GEOID, NDVI, closest_greenspace,
                               ICE_inc, perc.black, perc.hisp,
                               perc.pov, pop_dens, building_density),
            by = "GEOID")

sf_la <- geom_la |>
  left_join(csi_la, by = "GEOID") |>
  left_join(nh_la,  by = "GEOID") |>
  left_join(dm_la   |> select(GEOID, NDVI, closest_greenspace,
                               ICE_inc, perc.black, perc.hisp,
                               perc.pov, pop_dens, building_density),
            by = "GEOID")

# ── Map helper functions ───────────────────────────────────────────────────────
make_panel <- function(sf_data, var, palette, city_title,
                       show_legend = TRUE, legend_title = "Decile",
                       reverse = FALSE) {
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
        labels = paste0("D", 1:10),
        value.na = NA
      ),
      fill.legend = leg,
      col_alpha = 0,   # no tract borders
      lwd = 0
    ) +
    tm_title(city_title, size = 1.3, fontface = "bold") +
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

# ── FIGURE 1: NH (top, greens) + CSI (bottom, reds) ──────────────────────────
message("Building Figure 1 composite map...")

p_nh_nyc <- make_panel(sf_nyc, "neighbor_visit_count_annual_avg",
                        "Greens", "New York City", show_legend = FALSE)
p_nh_la  <- make_panel(sf_la,  "neighbor_visit_count_annual_avg",
                        "Greens", "Los Angeles", show_legend = TRUE,
                        legend_title = "NH visits\n(decile)")

p_csi_nyc <- make_panel(sf_nyc, "community_severance_index",
                         "Reds", "New York City", show_legend = FALSE)
p_csi_la  <- make_panel(sf_la,  "community_severance_index",
                         "Reds", "Los Angeles", show_legend = TRUE,
                         legend_title = "CSI\n(decile)")

fig1 <- tmap_arrange(p_nh_nyc, p_nh_la, p_csi_nyc, p_csi_la,
                     nrow = 2, ncol = 2)

save_tmap(fig1, paste0(output.folder, "figure1_nh_csi_maps.png"),
          width = 3200, height = 2400)
file.copy(paste0(output.folder, "figure1_nh_csi_maps.png"),
          paste0(manuscript.folder, "figs/figure1_nh_csi_maps.png"),
          overwrite = TRUE)
message("Copied Figure 1 to manuscript/figs/")

# ── SUPPLEMENTARY MAPS ────────────────────────────────────────────────────────

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

# Outcome maps (not in Fig 1)
save_supp_map("NDVI", "YlGn", "NDVI\n(decile)",
              "supp_map_ndvi.png")

save_supp_map("closest_greenspace", "Blues", "Distance to\ngreen space (m)\n(decile)",
              "supp_map_proximity.png")

# Covariate maps
save_supp_map("ICE_inc", "RdBu", "Income ICE\n(decile)",
              "supp_map_ice_inc.png")

save_supp_map("perc.black", "Purples", "% Black\n(decile)",
              "supp_map_pct_black.png")

save_supp_map("perc.hisp", "Oranges", "% Hispanic\n(decile)",
              "supp_map_pct_hisp.png")

save_supp_map("perc.pov", "YlOrRd", "% Poverty\n(decile)",
              "supp_map_pct_pov.png")

save_supp_map("pop_dens", "Blues", "Population\ndensity (decile)",
              "supp_map_pop_density.png")

save_supp_map("building_density", "Greys", "Building\ndensity (decile)",
              "supp_map_building_density.png")

message("All maps generated and copied to manuscript/figs/")
