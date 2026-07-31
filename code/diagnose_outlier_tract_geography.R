rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(sf)
library(ggplot2)
library(patchwork)

# =============================================================================
# diagnose_outlier_tract_geography.R
#
# Purpose: Coauthor question on the sensitivity-analysis paragraph of
#          sn-article.tex asked whether the tracts excluded by the primary
#          |z_CSI| > 2 rule (whose inclusion in the full sample drives the
#          non-linearity seen in Supplementary Figure S4) have obvious
#          geographic characteristics -- e.g., unusually large tracts, or
#          tracts on the fringes of the city. This is a diagnostic check,
#          not part of the manuscript pipeline, to decide whether such a
#          pattern is worth reporting or mapping formally.
#
# Inputs:  data/generated/data_models.rds (has outlier_flag, community_severance_index)
#          data/generated/krieger_ice_la.rds, krieger_ice_nyc.rds (tract geometries)
#
# Output:  output/diagnostic_outlier_tract_map.png
#          output/diagnostic_outlier_tract_geography_stats.csv (printed + saved)
# =============================================================================

dt <- readRDS(paste0(generated.data.folder, "data_models.rds"))

la_geom  <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))  |>
  dplyr::select(GEOID, geometry) |> mutate(GEOID = sub("^0", "", GEOID))
nyc_geom <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds")) |>
  dplyr::select(GEOID, geometry) |> mutate(GEOID = sub("^0", "", GEOID))

la  <- dt |> filter(city == "LA")  |> left_join(la_geom,  by = "GEOID") |> st_as_sf() |>
  filter(!is.na(outlier_flag))
nyc <- dt |> filter(city == "NYC") |> left_join(nyc_geom, by = "GEOID") |> st_as_sf() |>
  filter(!is.na(outlier_flag))

la$area_km2  <- as.numeric(st_area(la))  / 1e6
nyc$area_km2 <- as.numeric(st_area(nyc)) / 1e6

la_boundary  <- st_union(st_geometry(la))
nyc_boundary <- st_union(st_geometry(nyc))

la_cent  <- st_centroid(la)
nyc_cent <- st_centroid(nyc)

la$dist_to_edge_km  <- as.numeric(st_distance(la_cent,  st_boundary(la_boundary)))  / 1000
nyc$dist_to_edge_km <- as.numeric(st_distance(nyc_cent, st_boundary(nyc_boundary))) / 1000

geo_stats <- function(x, city_name) {
  x |>
    st_drop_geometry() |>
    group_by(outlier_flag) |>
    summarise(
      n                       = n(),
      median_area_km2         = median(area_km2, na.rm = TRUE),
      median_dist_to_edge_km  = median(dist_to_edge_km, na.rm = TRUE),
      median_pop_dens         = median(pop_dens, na.rm = TRUE),
      median_building_density = median(building_density, na.rm = TRUE),
      median_csi              = median(community_severance_index, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(city = city_name, .before = 1)
}

stats <- bind_rows(geo_stats(la, "LA"), geo_stats(nyc, "NYC"))
write.csv(stats, paste0(output.folder, "diagnostic_outlier_tract_geography_stats.csv"), row.names = FALSE)
print(stats)

map_city <- function(x, title) {
  ggplot(x) +
    geom_sf(aes(fill = outlier_flag), color = "grey40", linewidth = 0.05) +
    scale_fill_manual(values = c("Outlier (|z|>2)" = "firebrick", "Within ±2 SD" = "grey85"),
                       name = NULL) +
    labs(title = title) +
    theme_void() +
    theme(legend.position = "bottom", plot.title = element_text(hjust = 0.5))
}

png(paste0(output.folder, "diagnostic_outlier_tract_map.png"), width = 1600, height = 900, res = 150)
print(map_city(la, "LA: outlier tracts (|z_CSI| > 2)") + map_city(nyc, "NYC: outlier tracts (|z_CSI| > 2)"))
dev.off()

message("Saved: output/diagnostic_outlier_tract_map.png")
message("Saved: output/diagnostic_outlier_tract_geography_stats.csv")
