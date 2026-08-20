rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(dplyr)
library(readr)

# extract_outlier_exclusion_counts.R
# Purpose: Reports, per city and outcome, how many tracts are excluded by
#          the |z_CSI| > 2 outlier rule stated in the manuscript's Methods.

flag_outliers <- function(data) {
  city_csi_stats <- data |>
    group_by(city) |>
    summarise(
      mean_csi = mean(community_severance_index, na.rm = TRUE),
      sd_csi   = sd(community_severance_index, na.rm = TRUE),
      .groups  = "drop"
    )
  data |>
    left_join(city_csi_stats, by = "city") |>
    mutate(
      z_csi        = (community_severance_index - mean_csi) / sd_csi,
      outlier_flag = ifelse(abs(z_csi) > 2, "Outlier", "Within")
    ) |>
    dplyr::select(-mean_csi, -sd_csi)
}

count_by_outlier <- function(data, outcome_label) {
  data |>
    count(city, outlier_flag) |>
    tidyr::pivot_wider(names_from = outlier_flag, values_from = n, values_fill = 0) |>
    mutate(outcome = outcome_label, .before = 1)
}

dt <- readRDS(paste0(generated.data.folder, "data_models.rds")) |>
  mutate(city = as.factor(city)) |>
  flag_outliers()

ndvi_counts <- dt |>
  filter(!is.na(NDVI)) |>
  count_by_outlier("NDVI")

dt_dist <- dt |>
  mutate(closest_greenspace = ifelse(closest_greenspace == 0, 1, closest_greenspace))

distance_counts <- dt_dist |>
  filter(!is.na(closest_greenspace)) |>
  count_by_outlier("Distance to green space")

dt_nh <- readRDS(paste0(generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds")) |>
  mutate(city = as.factor(city)) |>
  flag_outliers() |>
  filter(
    !is.na(neighbor_visit_count_annual_avg),
    !is.na(home_device_counts_total_parsed_annual_avg),
    home_device_counts_total_parsed_annual_avg > 0
  )

nh_counts <- dt_nh |> count_by_outlier("Neighboring-home visits")

results <- bind_rows(nh_counts, ndvi_counts, distance_counts)

write_csv(results, paste0(output.folder, "numeric_results_outlier_exclusion_counts.csv"))
print(results)
