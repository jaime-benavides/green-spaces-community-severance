rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(tidycensus)
library(tigris)

options(tigris_use_cache = TRUE)

# ---------------------------------------------------------------------------
# Which tracts are we classifying?
# The 128 tracts (LA n=27, NYC n=101) with NA NDVI in the current analytic
# dataset, i.e. absent from the vendor file
# NDVI_US_MajorCities_Tracts_2000_2010_2019.csv (Brochu et al. 2022).
# ---------------------------------------------------------------------------
dt <- readRDS(paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"
))

missing_ndvi <- dt |>
  filter(is.na(NDVI)) |>
  select(GEOID, city, TotPop, pop_dens)

stopifnot(nrow(missing_ndvi) == 128)

missing_ndvi <- missing_ndvi |>
  mutate(
    state  = if_else(city == "LA", "06", "36"),
    county = case_when(
      city == "LA"  ~ substr(GEOID, 3, 5),
      city == "NYC" ~ substr(GEOID, 3, 5)
    )
  )

# ---------------------------------------------------------------------------
# Criterion 1: population aged 65+ = 0
# ACS 2019 5-year, table S0101 (age/sex), variable S0101_C01_030
# ("Total population, 65 years and over")
# ---------------------------------------------------------------------------
counties <- unique(missing_ndvi$county)

pop65 <- lapply(unique(missing_ndvi$state), function(st) {
  cty <- missing_ndvi$county[missing_ndvi$state == st]
  tidycensus::get_acs(
    geography = "tract",
    variables = "S0101_C01_030",
    state     = st,
    county    = unique(cty),
    year      = 2019,
    survey    = "acs5"
  )
}) |>
  bind_rows() |>
  transmute(GEOID, pop_65_plus = estimate)

# ---------------------------------------------------------------------------
# Criterion 2 (proxy): fraction of tract area that is water (ALAND/AWATER
# from the Census TIGER tract shapefile). Brochu et al. note that tracts
# extending into large water bodies can register negative NDVI; we cannot
# recompute their NDVI directly (that is the value that is missing), so a
# high water-area fraction is used as a traceable, documented proxy for
# "plausibly NDVI < 0", not a confirmation.
# ---------------------------------------------------------------------------
tract_geoms <- lapply(unique(missing_ndvi$state), function(st) {
  cty <- missing_ndvi$county[missing_ndvi$state == st]
  tigris::tracts(state = st, county = unique(cty), year = 2019, cb = FALSE)
}) |>
  bind_rows()

water_frac <- tract_geoms |>
  sf::st_drop_geometry() |>
  transmute(
    GEOID,
    aland = as.numeric(ALAND),
    awater = as.numeric(AWATER),
    water_fraction = awater / (aland + awater)
  )

# ---------------------------------------------------------------------------
# Criterion 3: county-level mortality-data suppression (CDC WONDER suppresses
# a county-year-cause cell when underlying deaths < 10). Not checked directly
# here (would require a CDC WONDER pull for 2019 all-cause mortality, ages
# 65+, by county) -- but NYC's five boroughs and LA County are each among the
# most populous counties in the US, so a priori this criterion is not a
# plausible explanation for any tract in this set. Flagged as "not checked"
# rather than assumed.
# ---------------------------------------------------------------------------

result <- missing_ndvi |>
  left_join(pop65, by = "GEOID") |>
  left_join(water_frac, by = "GEOID") |>
  mutate(
    likely_reason = case_when(
      !is.na(pop_65_plus) & pop_65_plus == 0 ~ "zero_population_65_plus",
      !is.na(water_fraction) & water_fraction >= 0.5 ~ "majority_water_area_likely_ndvi_lt_0",
      TRUE ~ "unresolved_not_explained_by_checked_criteria"
    )
  )

out_path <- paste0(output.folder, "ndvi_missing_exclusion_reason_diagnosis.csv")
readr::write_csv(result, out_path)
message("Saved: ", out_path)

message("\nSummary of likely reason (n = ", nrow(result), "):")
print(table(result$likely_reason, result$city))
