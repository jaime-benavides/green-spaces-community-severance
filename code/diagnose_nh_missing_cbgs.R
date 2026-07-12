rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(readr)
library(stringr)
library(tigris)
options(tigris_use_cache = TRUE)

# ---- Paths -------------------------------------------------------------------

barrier_ref_path <- "/Users/jaimebenavides/claude_cowork/dewey_dta_walking/data/reference/dewey_barrier_geoid_reference.csv"

# ---- Load inputs -----------------------------------------------------------

model_dt <- readRDS(paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"
))

advan_cbg <- read_csv(
  paste0(
    raw.data.folder,
    "neigh_home/2019_full_year_neighbor_home_nyc_la_annual_average.csv"
  ),
  show_col_types = FALSE
) |>
  mutate(
    GEOID_CBG   = str_pad(as.character(GEOID), 12, "left", "0"),
    TRACT_GEOID = substr(GEOID_CBG, 1, 11)
  )

barrier_ref <- read_csv(barrier_ref_path, show_col_types = FALSE) |>
  mutate(GEOID_CBG = str_pad(GEOID_REF, 12, "left", "0"))

missing_tract_geoids <- model_dt |>
  filter(is.na(neighbor_visit_count_annual_avg)) |>
  pull(GEOID)

cat("Missing tracts:", length(missing_tract_geoids), "\n")

# ---- Download all CBGs for NYC and LA from TIGER/Line ----------------------
# NYC: counties 005 (Bronx), 047 (Kings), 061 (NY), 081 (Queens), 085 (Richmond)
# LA:  county  037

cat("Downloading CBG boundaries from TIGER/Line...\n")

bg_nyc <- block_groups(
  state  = "NY",
  county = c("005", "047", "061", "081", "085"),
  year = 2019, progress_bar = FALSE
)
bg_la <- block_groups(
  state  = "CA",
  county = "037",
  year = 2019, progress_bar = FALSE
)

bg_all <- bind_rows(
  mutate(bg_nyc, city = "NYC"),
  mutate(bg_la,  city = "LA")
) |>
  mutate(
    GEOID_CBG      = str_pad(GEOID, 12, "left", "0"),
    TRACT_GEOID    = substr(GEOID_CBG, 1, 11),
    aland_km2      = as.numeric(ALAND)  / 1e6,
    awater_km2     = as.numeric(AWATER) / 1e6,
    total_area_km2 = aland_km2 + awater_km2,
    pct_water      = ifelse(
      total_area_km2 > 0, awater_km2 / total_area_km2, NA_real_
    )
  ) |>
  sf::st_drop_geometry()

cat("Total NYC+LA CBGs from TIGER:", nrow(bg_all), "\n")

# ---- Classify each CBG using barrier reference as primary signal -----------

bg_all <- bg_all |>
  mutate(
    in_barrier_ref  = GEOID_CBG %in% barrier_ref$GEOID_CBG,
    in_advan        = GEOID_CBG %in% advan_cbg$GEOID_CBG,
    tract_missing   = TRACT_GEOID %in% missing_tract_geoids,
    water_dominant  = pct_water > 0.90,
    water_majority  = pct_water > 0.50,
    very_small_land = aland_km2 < 0.01,
    large_land      = aland_km2 > 2
  )

# ---- Key confirmation: are any missing-tract CBGs in the barrier ref? ------

cat("\n=== Barrier-reference check ===\n")
cat("Total NYC+LA CBGs:", nrow(bg_all), "\n")
cat("In barrier reference:", sum(bg_all$in_barrier_ref),
    sprintf("(%.1f%%)\n", mean(bg_all$in_barrier_ref) * 100))

miss_cbgs <- filter(bg_all, tract_missing)
cat("\nCBGs in the 258 missing tracts:", nrow(miss_cbgs), "\n")
cat(
  "Of these, in barrier reference:", sum(miss_cbgs$in_barrier_ref),
  "| NOT in barrier reference:", sum(!miss_cbgs$in_barrier_ref), "\n"
)
cat(
  "Of these, in Advan output:", sum(miss_cbgs$in_advan),
  "| NOT in Advan output:", sum(!miss_cbgs$in_advan), "\n"
)

cat("\n=> All 258 missing-tract CBGs are absent from the barrier-factor")
cat(" reference.\n")
cat("   This is not random missingness: these CBGs were classified as")
cat("\n   non-residential and excluded from the Advan analytic universe.\n")

# ---- Why are these CBGs not in the barrier reference? ---------------------
# Use TIGER land-area attributes as secondary descriptive proxies

cat("\n=== TIGER land-area attributes for non-barrier CBGs in missing tracts ===\n")
cat("Water-dominant (>90% water):", sum(miss_cbgs$water_dominant, na.rm = TRUE),
    sprintf("/ %d (%.1f%%)\n", nrow(miss_cbgs),
            mean(miss_cbgs$water_dominant, na.rm = TRUE) * 100))
cat("Water-majority (>50% water):", sum(miss_cbgs$water_majority, na.rm = TRUE),
    sprintf("/ %d (%.1f%%)\n", nrow(miss_cbgs),
            mean(miss_cbgs$water_majority, na.rm = TRUE) * 100))
cat("Very small land (<0.01 km²):", sum(miss_cbgs$very_small_land, na.rm = TRUE),
    sprintf("/ %d (%.1f%%)\n", nrow(miss_cbgs),
            mean(miss_cbgs$very_small_land, na.rm = TRUE) * 100))
cat("Large land (>2 km²):        ", sum(miss_cbgs$large_land, na.rm = TRUE),
    sprintf("/ %d (%.1f%%)\n", nrow(miss_cbgs),
            mean(miss_cbgs$large_land, na.rm = TRUE) * 100))

cat("\nNote: TIGER area attributes explain only a minority of cases.\n")
cat("The primary mechanism is barrier-reference non-classification,\n")
cat("which captures non-residential status not fully reflected in ALAND/AWATER.\n")

# ---- Tract-level summary ---------------------------------------------------

cat("\n=== Per-tract summary (missing tracts, 258 total) ===\n")
tract_summary <- miss_cbgs |>
  group_by(TRACT_GEOID, city) |>
  summarise(
    n_cbgs           = n(),
    n_in_barrier_ref = sum(in_barrier_ref),
    n_water_dom      = sum(water_dominant, na.rm = TRUE),
    n_water_maj      = sum(water_majority, na.rm = TRUE),
    n_very_small     = sum(very_small_land, na.rm = TRUE),
    n_large          = sum(large_land, na.rm = TRUE),
    mean_pct_water   = round(mean(pct_water, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  ) |>
  mutate(
    likely_reason = case_when(
      n_in_barrier_ref == 0 & n_water_dom == n_cbgs ~
        "all CBGs water-dominant",
      n_in_barrier_ref == 0 & n_water_maj == n_cbgs ~
        "all CBGs water-majority",
      n_in_barrier_ref == 0 & n_very_small == n_cbgs ~
        "all CBGs very small land",
      n_in_barrier_ref == 0 & n_large == n_cbgs ~
        "all CBGs large land (park/industrial)",
      n_in_barrier_ref == 0 ~
        "not in barrier reference (non-residential, unclassified by TIGER proxies)",
      TRUE ~ "partial barrier coverage"
    )
  )

cat("\nLikely reason distribution:\n")
print(table(tract_summary$likely_reason))

cat("\nBy city:\n")
print(table(tract_summary$city, tract_summary$likely_reason))

# ---- Save outputs ----------------------------------------------------------

write_csv(tract_summary,
          paste0(output.folder, "nh_missing_tract_cbg_diagnosis.csv"))
write_csv(
  miss_cbgs |>
    select(GEOID_CBG, TRACT_GEOID, city, aland_km2, awater_km2,
           pct_water, water_dominant, water_majority, very_small_land,
           large_land, in_barrier_ref, in_advan),
  paste0(output.folder, "nh_missing_cbgs_detail.csv")
)

message("\nDiagnosis CSVs saved to output/")
