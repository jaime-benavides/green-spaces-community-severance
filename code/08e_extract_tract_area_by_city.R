rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(sf)
library(dplyr)
library(readr)

# 08e_extract_tract_area_by_city.R
# Purpose: Quantifies how much smaller NYC tracts are than LA tracts in land
#          area, for context on the LA-vs-NYC distance comparison.

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
