rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(sf)
library(dplyr)
library(readr)

# =============================================================================
# extract_tract_area_by_city.R
#
# Purpose: Quantify how much smaller NYC census tracts are than LA census
#          tracts in land area, for the descriptive-statistics paragraph of
#          sn-article.tex (Results, tract-level descriptives). Provides
#          context for interpreting the LA-vs-NYC median distance-to-nearest-
#          green-space comparison: part of any absolute-distance difference
#          between cities is mechanically related to tract geometry (larger
#          tracts place the population-weighted centroid farther, on average,
#          from any fixed point feature), independent of green space
#          accessibility itself.
#
# Inputs:  data/generated/krieger_ice_la.rds  (n = 1,148 LA tracts)
#          data/generated/krieger_ice_nyc.rds (n = 2,164 NYC tracts)
#          Together these are the full 3,312-tract analytic universe cited
#          at sn-article.tex line 154 (1,148 + 2,164 = 3,312).
#
# Output:  output/numeric_results_tract_area_by_city.csv
# =============================================================================

la  <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))
nyc <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds"))

area_summary <- function(sf_obj, city_name) {
  area_km2 <- as.numeric(sf::st_area(sf_obj)) / 1e6
  tibble::tibble(
    city          = city_name,
    n_tracts      = nrow(sf_obj),
    median_km2    = median(area_km2, na.rm = TRUE),
    q25_km2       = quantile(area_km2, 0.25, na.rm = TRUE),
    q75_km2       = quantile(area_km2, 0.75, na.rm = TRUE)
  )
}

results <- dplyr::bind_rows(
  area_summary(la, "LA"),
  area_summary(nyc, "NYC")
)

write_csv(results, paste0(output.folder, "numeric_results_tract_area_by_city.csv"))
print(results)
