rm(list = ls())

# 06_prep_neighbor_visits_annual_average.R
# Purpose: Aggregates NH visits to tract-level annual averages; restricts
#          to green-space CBGs.

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(dplyr)
library(readr)
library(stringr)
library(sf)
library(tigris)

options(tigris_use_cache = TRUE)

# ---- Paths ------------------------------------------------------------------

# PAD-US Areas of Recreation (Browning et al. 2022) — see README.md "Data" > "green infrastructure" for download link
padus_ar_path <- paste0(raw.data.folder, "green_infrastructure/padus_ar.shp")
crs_proj      <- 2163

cbg_combined_path <- paste0(raw.data.folder,
  "neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv")

output_summary_path <- paste0(generated.data.folder,
  "neighbor_visit_annual_average_2019_full_year_tract.rds")
output_model_path   <- paste0(generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds")

pad_geoid <- function(x, width) {
  stringr::str_pad(gsub("[^0-9]", "", as.character(x)), width = width, side = "left", pad = "0")
}

# ---- Load combined CBG-level NH data ----------------------------------------
# Single canonical file produced by 05b_prep_cbg_nh_combined.R (Step 5b).
# Contains primary (15,483 CBGs) + supplementary (949 CBGs, 258 tracts absent
# from primary). Filter to months_present == 12 before spatial join.

cbg_all <- readr::read_csv(cbg_combined_path, show_col_types = FALSE) |>
  dplyr::filter(months_present == 12) |>
  dplyr::select(
    GEOID_CBG, TRACT_GEOID, city, nh_source,
    avg_neighbor_home_device_counts,
    avg_home_device_counts_total_parsed,
    avg_device_counts_row_total
  )

message("CBGs after 12-month filter: ", nrow(cbg_all))

# ---- Download 2019 TIGER CBG geometries (cached) ----------------------------

message("Loading TIGER 2019 block groups (cached via tigris)...")

nyc_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds")) |>
  sf::st_transform(crs_proj)
la_ice  <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))  |>
  sf::st_transform(crs_proj)
nyc_boundary <- sf::st_union(nyc_ice)
la_boundary  <- sf::st_union(la_ice)

bg_nyc <- tigris::block_groups(
  state = "NY", county = c("005", "047", "061", "081", "085"),
  year = 2019, progress_bar = FALSE
) |> sf::st_transform(crs_proj)

bg_la <- tigris::block_groups(
  state = "CA", county = "037",
  year = 2019, progress_bar = FALSE
) |> sf::st_transform(crs_proj)

in_nyc <- sapply(sf::st_intersects(bg_nyc, nyc_boundary), function(x) length(x) > 0)
in_la  <- sapply(sf::st_intersects(bg_la,  la_boundary),  function(x) length(x) > 0)

bg_sf <- dplyr::bind_rows(
  dplyr::mutate(bg_nyc[in_nyc, ], city = "NYC"),
  dplyr::mutate(bg_la[in_la, ],   city = "LA")
) |>
  dplyr::mutate(GEOID_CBG = pad_geoid(GEOID, 12)) |>
  dplyr::select(GEOID_CBG, city, geometry)

message("Study-area CBGs (TIGER 2019): ",
        sum(bg_sf$city == "NYC"), " NYC | ", sum(bg_sf$city == "LA"), " LA")

# ---- Intersect CBGs with PAD-US AR ------------------------------------------
# A CBG has_greenspace = TRUE if its geometry intersects any PAD-US AR polygon
# (publicly accessible and recreational green space >= 400 m², as used in
# 03_prep_greenspace.R for the proximity outcome).

message("Loading PAD-US AR shapefile...")
padus_ar <- sf::read_sf(padus_ar_path) |> sf::st_transform(crs_proj)

nyc_padus_ids <- sapply(sf::st_intersects(padus_ar, nyc_boundary), function(x) length(x) > 0)
la_padus_ids  <- sapply(sf::st_intersects(padus_ar, la_boundary),  function(x) length(x) > 0)
padus_study   <- padus_ar[nyc_padus_ids | la_padus_ids, ]
padus_union   <- sf::st_union(padus_study)

message("PAD-US AR polygons in study area: ", nrow(padus_study))

has_gs <- sapply(
  sf::st_intersects(bg_sf, padus_union),
  function(x) length(x) > 0
)
bg_sf$has_greenspace <- has_gs

message("CBGs with green space intersection: ",
        sum(bg_sf$has_greenspace), " of ", nrow(bg_sf))

# ---- Join green-space flag to NH data and filter ----------------------------

sf::st_geometry(bg_sf) <- NULL   # drop geometry for the join

cbg_gs <- cbg_all |>
  dplyr::left_join(
    dplyr::select(bg_sf, GEOID_CBG, has_greenspace),
    by = "GEOID_CBG"
  ) |>
  dplyr::filter(!is.na(has_greenspace), has_greenspace == TRUE)

message("CBGs retained (green space + 12-month complete): ", nrow(cbg_gs))

# ---- Aggregate to census tract ----------------------------------------------
# For each tract: sum counts from qualifying CBGs.
# Rename to match the column names expected by 07_models_neighbor_visits_annual_average.R.

tract_gs <- cbg_gs |>
  dplyr::group_by(TRACT_GEOID, city) |>
  dplyr::summarise(
    neighbor_visit_count_annual_avg            = sum(avg_neighbor_home_device_counts,    na.rm = TRUE),
    home_device_counts_total_parsed_annual_avg = sum(avg_home_device_counts_total_parsed, na.rm = TRUE),
    device_counts_row_total_annual_avg         = sum(avg_device_counts_row_total,        na.rm = TRUE),
    neighbor_home_cbg_count_annual_avg         = dplyr::n(),
    nh_source = dplyr::first(nh_source),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    neighbor_visit_share_annual_avg = dplyr::if_else(
      device_counts_row_total_annual_avg > 0,
      neighbor_visit_count_annual_avg / device_counts_row_total_annual_avg,
      NA_real_
    )
  )

message("Tracts with green-space NH data: ", nrow(tract_gs),
        " (NYC: ", sum(tract_gs$city == "NYC"),
        ", LA: ", sum(tract_gs$city == "LA"), ")")

# ---- Tract-level green-space flag -------------------------------------------
# A tract is included in the analytic sample only if at least one of its CBGs
# intersects a PAD-US AR polygon and has 12-month complete NH data.

# All rows in tract_gs meet this criterion; tracts NOT in tract_gs get NA on join.

# ---- Join to base modeling dataset ------------------------------------------

base_dt <- readRDS(paste0(generated.data.folder, "data_models.rds")) |>
  dplyr::mutate(
    GEOID = pad_geoid(GEOID, 11),
    city  = as.character(city)
  )

model_dt <- base_dt |>
  dplyr::left_join(tract_gs, by = c("GEOID" = "TRACT_GEOID", "city" = "city")) |>
  dplyr::mutate(
    has_greenspace_tract = !is.na(neighbor_visit_count_annual_avg)
  )

n_total    <- nrow(model_dt)
n_gs       <- sum(model_dt$has_greenspace_tract)
n_no_gs    <- n_total - n_gs
n_complete <- sum(
  model_dt$has_greenspace_tract &
  !is.na(model_dt$home_device_counts_total_parsed_annual_avg) &
  model_dt$home_device_counts_total_parsed_annual_avg > 0
)

message("Base dataset tracts: ", n_total)
message("Tracts with green-space CBGs (has_greenspace_tract): ", n_gs)
message("Tracts excluded (no green-space CBGs): ", n_no_gs)
message("Tracts with complete NH + offset data: ", n_complete)

saveRDS(tract_gs,  output_summary_path)
saveRDS(model_dt,  output_model_path)
readr::write_csv(tract_gs, stringr::str_replace(output_summary_path, "\\.rds$", ".csv"))

message("NH tract summary saved to: ", output_summary_path)
message("Merged modeling dataset saved to: ", output_model_path)
