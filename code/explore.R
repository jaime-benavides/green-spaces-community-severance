# ============================================================
# Green Equity & Environmental Exposure Variables for New York City (2019)
# Author: [Your Name]
# Purpose: Compute NDVI, canopy cover, poverty rate, and extreme temperature
# ============================================================
# 1a Declare root directory, folder locations and load essential stuff
project.folder = paste0(print(here::here()),'/')
source(paste0(project.folder,'init_directory_structure.R'))
source(paste0(functions.folder,'script_initiate.R'))
# -----------------------------
# 1. Load Required Libraries
# -----------------------------
library(sf)
library(dplyr)
library(tigris)
library(stringr)
library(tidyr)
library(tidycensus)
library(mapview)
library(GreenExp)
library(amadeus)

# -----------------------------
# 2. Setup
# -----------------------------
options(tigris_use_cache = TRUE)
options(tigris_class = "sf")

city  <- "New York"
state <- "NY"
year  <- 2021
start_date <- "2019-01-01"
end_date   <- "2019-12-31"
buffer_dist <- 804.672
output_path <- output.folder

# Your Census API key must be set
census_api_key(Sys.getenv("a3811a89de94dfb468fb516d00a6deb93c695ce0"), install = FALSE)

message("---------------------------------------------------")
message("Processing: ", city, ", ", state, " (Year ", year, ")")
message("---------------------------------------------------")

# -----------------------------
# 3. Get City Boundary and Block Groups
# -----------------------------
message("Fetching Census Block Groups for ", city, ", ", state)
place <- tigris::places(state = state, year = year) %>%
  filter(str_detect(NAME, regex(city, ignore_case = TRUE))) %>%
  st_as_sf()

if (nrow(place) == 0) stop("City not found in Census TIGER data.")

cbgs <- tigris::block_groups(state = state, year = year, cb = TRUE) %>% st_as_sf()

# Clip to city boundary
cbgs <- st_transform(cbgs, 4326)
place <- st_transform(place, 4326)
cbgs_city <- st_intersection(cbgs, place)
cbgs_city <- st_make_valid(cbgs_city)
cbgs_city <- cbgs_city[!st_is_empty(cbgs_city), ]

# Compute centroids
cbg_points <- st_centroid(cbgs_city)
cbg_points$UID <- cbgs_city$GEOID

safe_calc_ndvi <- function(points, buffer_distance, start_date, end_date) {
  tryCatch({
    GreenExp::calc_ndvi(
      points,
      buffer_distance = buffer_distance,
      start_date = start_date,
      end_date = end_date
    )
  }, error = function(e) {
    message("⚠️ No NDVI data found for some points (returning NA).")
    points$mean_NDVI <- NA
    return(points)
  })
}

# -----------------------------
# 4. NDVI and Canopy Cover
# -----------------------------

message("Calculating NDVI (this may take a while)...")
cbg_ndvi <- safe_calc_ndvi(
  cbg_points[94:183,],
  buffer_distance = buffer_dist,
  start_date = start_date,
  end_date = end_date
)

message("Calculating canopy cover from OSM tree data...")
cbg_canopy <- GreenExp::canopy_pct(
  cbgs_city,
  address_location_neighborhood = TRUE,
  avgcanopyRedii = 3.5,
  folder_path_osmtrees = output_path
)

# -----------------------------
# 5. Extreme Temperature from Amadeus
# -----------------------------
message("Fetching extreme temperature metrics from amadeus...")

locs <- cbg_points %>%
  mutate(
    lon = sf::st_coordinates(.)[,1],
    lat = sf::st_coordinates(.)[,2]
  ) %>%
  as.data.frame() %>%
  select(UID, lon, lat)

# Calculate covariates using the "weasd" process
weasd_cov <- amadeus::calculate_covariates(
  covariate = "weasd",
  from = amadeus::weasd_process,
  locs = locs,
  locs_id = "UID",
  radius = 0,
  geom = TRUE
)

# -----------------------------
# 6. ACS Poverty and Income
# -----------------------------
message("Downloading ACS socioeconomic data...")
acs_vars <- c(
  median_income = "B19013_001",
  pop_total     = "B01003_001",
  poverty_count = "B17001_002"
)

acs_data <- tidycensus::get_acs(
  geography = "block group",
  variables = acs_vars,
  state = state,
  year = year,
  survey = "acs5",
  geometry = FALSE
)

acs_wide <- acs_data %>%
  select(GEOID, variable, estimate) %>%
  tidyr::pivot_wider(names_from = variable, values_from = estimate) %>%
  mutate(
    poverty_rate = 100 * (poverty_count / pop_total)
  )

# -----------------------------
# 7. Merge All Data
# -----------------------------
message("Merging NDVI, canopy, ACS, and temperature data...")

cbg_final <- cbgs_city %>%
  left_join(st_drop_geometry(cbg_ndvi), by = c("GEOID" = "UID")) %>%
  left_join(st_drop_geometry(cbg_canopy), by = "GEOID") %>%
  left_join(st_drop_geometry(weasd_cov), by = c("GEOID" = "UID")) %>%
  left_join(acs_wide, by = "GEOID")

coords <- st_coordinates(st_centroid(cbg_final))
cbg_final$lon <- coords[,1]
cbg_final$lat <- coords[,2]

cbg_final <- cbg_final %>%
  select(
    GEOID, lon, lat,
    mean_NDVI, canopy_pct,
    poverty_rate, median_income,
    starts_with("weasd_")
  )

# -----------------------------
# 8. Save Outputs
# -----------------------------
outfile <- file.path(output_path, paste0("NYC_CBG_GreenExposure_2019.gpkg"))
st_write(cbg_final, outfile, delete_dsn = TRUE)
message("✅ All data saved to: ", outfile)

# -----------------------------
# 9. Optional: Quick Map
# -----------------------------
mapview::mapview(cbg_final, zcol = "mean_NDVI") +
  mapview::mapview(cbg_final, zcol = "poverty_rate")

