rm(list = ls())

# 08b1_diagnose_nh_exclusion_reason.R
# Purpose: Classifies each excluded NH tract's reason (structural, data-gap,
#          no CBG data); output feeds Supplementary Table S1.

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(readr)
library(stringr)
library(sf)
library(tigris)

options(tigris_use_cache = TRUE)

# ---- Paths -------------------------------------------------------------------

crs_proj <- 2163
# PAD-US Areas of Recreation (Browning et al. 2022) — see README.md "Data" > "green infrastructure" for download link
padus_ar_path <- paste0(raw.data.folder, "green_infrastructure/padus_ar.shp")
cbg_combined_path <- paste0(
  raw.data.folder,
  "neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv"
)

pad_geoid <- function(x, width) {
  stringr::str_pad(gsub("[^0-9]", "", as.character(x)), width, "left", "0")
}

# ---- Load inputs -------------------------------------------------------------

cbg_all_raw <- read_csv(cbg_combined_path, show_col_types = FALSE) |>
  select(GEOID_CBG, TRACT_GEOID, city, months_present)

nyc_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds")) |>
  st_transform(crs_proj)
la_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds")) |>
  st_transform(crs_proj)
nyc_boundary <- st_union(nyc_ice)
la_boundary  <- st_union(la_ice)

bg_nyc <- block_groups(
  state = "NY", county = c("005", "047", "061", "081", "085"),
  year = 2019, progress_bar = FALSE
) |> st_transform(crs_proj)
bg_la <- block_groups(
  state = "CA", county = "037",
  year = 2019, progress_bar = FALSE
) |> st_transform(crs_proj)

in_nyc <- sapply(st_intersects(bg_nyc, nyc_boundary), function(x) length(x) > 0)
in_la  <- sapply(st_intersects(bg_la, la_boundary), function(x) length(x) > 0)

bg_sf <- bind_rows(
  mutate(bg_nyc[in_nyc, ], city = "NYC"),
  mutate(bg_la[in_la, ], city = "LA")
) |>
  mutate(GEOID_CBG = pad_geoid(GEOID, 12)) |>
  select(GEOID_CBG, city, geometry)

padus_ar <- read_sf(padus_ar_path) |> st_transform(crs_proj)
nyc_ids <- sapply(st_intersects(padus_ar, nyc_boundary), function(x) length(x) > 0)
la_ids  <- sapply(st_intersects(padus_ar, la_boundary), function(x) length(x) > 0)
padus_union <- st_union(padus_ar[nyc_ids | la_ids, ])

bg_sf$has_greenspace <- sapply(
  st_intersects(bg_sf, padus_union), function(x) length(x) > 0
)
st_geometry(bg_sf) <- NULL

# ---- Join green-space match status onto every CBG, regardless of months ------
# has_greenspace is TRUE/FALSE only when the CBG geometry matched a TIGER
# block group inside the study-area boundary; NA means the geometry match
# itself failed (not evidence about proximity to green space either way).

cbg_gs_flag <- cbg_all_raw |>
  left_join(select(bg_sf, GEOID_CBG, has_greenspace), by = "GEOID_CBG")

# ---- Classify each tract's exclusion reason unambiguously --------------------

tract_summary <- cbg_gs_flag |>
  group_by(TRACT_GEOID, city) |>
  summarise(
    n_cbgs                 = n(),
    n_matched               = sum(!is.na(has_greenspace)),
    n_unmatched             = sum(is.na(has_greenspace)),
    n_confirmed_greenspace  = sum(has_greenspace, na.rm = TRUE),
    n_confirmed_no_greenspace = sum(!has_greenspace & !is.na(has_greenspace)),
    n_greenspace_cbg_12mo   = sum(has_greenspace & months_present == 12, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    exclusion_reason = case_when(
      n_confirmed_greenspace > 0 & n_greenspace_cbg_12mo == 0 ~
        "data_gap_greenspace_cbg_incomplete_months",
      n_confirmed_greenspace == 0 & n_unmatched == 0 ~
        "structural_no_greenspace_cbg_confirmed",
      n_confirmed_greenspace == 0 & n_unmatched > 0 ~
        "indeterminate_unmatched_geometry",
      TRUE ~ "included_has_greenspace_12mo"
    )
  )

# ---- Restrict to tracts actually excluded from the NH analytic sample --------

model_dt <- readRDS(paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"
)) |>
  mutate(GEOID = pad_geoid(GEOID, 11))

excluded <- model_dt |>
  filter(is.na(neighbor_visit_count_annual_avg)) |>
  select(GEOID, city) |>
  left_join(tract_summary, by = c("GEOID" = "TRACT_GEOID", "city" = "city"))

cat("Excluded tracts (NA neighboring-home visits):", nrow(excluded), "\n\n")
cat("Exclusion reason breakdown:\n")
print(table(excluded$exclusion_reason, useNA = "always"))

write_csv(
  excluded,
  paste0(output.folder, "nh_exclusion_reason_diagnosis.csv")
)

message("Exclusion-reason diagnosis saved to: ",
        output.folder, "nh_exclusion_reason_diagnosis.csv")
