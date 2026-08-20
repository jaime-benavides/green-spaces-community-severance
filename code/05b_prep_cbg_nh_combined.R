rm(list = ls())

# 05b_prep_cbg_nh_combined.R
# Purpose: Merges the primary and supplementary Advan CBG-level NH files.

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))

library(dplyr)
library(readr)
library(stringr)

# Canonical CBG-level sources from the dewey_dta_walking project, copied into
# data/raw/neigh_home/ (see PROVENANCE.md there).
# Primary: 15,483 CBGs (NYC + LA) from the main Advan pipeline.
# Supplementary: 949 CBGs from a second pipeline run covering 258 tracts
#   absent from the primary output (no GEOID overlap between the two sources).
# Both files are archival outputs; do not edit them here.

primary_path <- paste0(raw.data.folder,
  "neigh_home/2019_full_year_neighbor_home_nyc_la_annual_average.csv")
supp_path <- paste0(raw.data.folder,
  "neigh_home/2019_full_year_neighbor_home_supplementary_annual_average.csv")

output_path <- paste0(raw.data.folder,
  "neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv")

pad_geoid <- function(x, width) {
  stringr::str_pad(gsub("[^0-9]", "", as.character(x)), width = width,
                   side = "left", pad = "0")
}

cols_keep <- c("GEOID_CBG", "TRACT_GEOID", "city", "nh_source",
               "months_present",
               "avg_neighbor_home_device_counts",
               "avg_home_device_counts_total_parsed",
               "avg_device_counts_row_total")

prim <- readr::read_csv(primary_path, show_col_types = FALSE) |>
  dplyr::mutate(
    GEOID_CBG   = pad_geoid(GEOID, 12),
    TRACT_GEOID = substr(GEOID_CBG, 1, 11),
    nh_source   = "primary"
  ) |>
  dplyr::select(dplyr::all_of(cols_keep))

supp <- readr::read_csv(supp_path, show_col_types = FALSE) |>
  dplyr::mutate(
    GEOID_CBG   = pad_geoid(GEOID, 12),
    TRACT_GEOID = pad_geoid(TRACT_GEOID, 11),
    city = dplyr::case_when(
      substr(TRACT_GEOID, 1, 2) == "06" ~ "LA",
      substr(TRACT_GEOID, 1, 2) == "36" ~ "NYC",
      TRUE ~ NA_character_
    ),
    nh_source = "supplementary_barrier_ref"
  ) |>
  dplyr::select(dplyr::all_of(cols_keep))

stopifnot(length(intersect(prim$GEOID_CBG, supp$GEOID_CBG)) == 0)

combined <- dplyr::bind_rows(prim, supp)

readr::write_csv(combined, output_path)

message("Combined CBG file saved to: ", output_path)
message("Rows: ", nrow(combined),
        " | primary: ", nrow(prim),
        " | supplementary: ", nrow(supp))
message("Unique tracts: ", dplyr::n_distinct(combined$TRACT_GEOID))
message("months_present distribution:")
print(table(combined$months_present))
