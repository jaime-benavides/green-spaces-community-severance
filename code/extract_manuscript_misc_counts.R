rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(mgcv)
library(readr)

# =============================================================================
# extract_manuscript_misc_counts.R
#
# Purpose: Permanent, rerunnable source for a set of small manuscript claims
#          that previously had no saved script + CSV (Methods/Results, various
#          lines). Each block below computes one claim and appends a row to
#          output/numeric_results_misc_counts.csv. Added as part of the
#          zero-tolerance numeric audit (see CODE_REVIEW.md).
# =============================================================================

results <- list()

# ---- 1. ICE income quintile boundaries (Methods, Sec. 2.5) -----------------
# Boundary = midpoint between the two tracts straddling the quintile cut,
# computed on the full (non-NH-restricted) analytic sample, matching how
# ICE_inc_quintile itself is assigned (dplyr::ntile-style equal-count bins).

dt_full <- readRDS(paste0(generated.data.folder, "data_models.rds"))

for (ct in c("LA", "NYC")) {
  v <- sort(dt_full$ICE_inc[dt_full$city == ct & !is.na(dt_full$ICE_inc_quintile)])
  n <- length(v)
  b1 <- round(n * 0.2)
  b4 <- round(n * 0.8)
  results[[paste0("ice_boundary_q1q2_", ct)]] <- data.frame(
    metric = "ice_quintile_boundary_q1_q2", city = ct,
    value = mean(v[c(b1, b1 + 1)])
  )
  results[[paste0("ice_boundary_q4q5_", ct)]] <- data.frame(
    metric = "ice_quintile_boundary_q4_q5", city = ct,
    value = mean(v[c(b4, b4 + 1)])
  )
}

# ---- 2. Primary NH model spline edf (Results, Sec. 3.2) --------------------

nh_fits <- readRDS(paste0(
  generated.data.folder, "neighbor_visit_outl_city_adjusted_2019_full_year.rds"
))
for (ct in c("LA", "NYC")) {
  fit <- if (ct == "LA") nh_fits$fit_city_la else nh_fits$fit_city_nyc
  edf <- summary(fit)$s.table["s(community_severance_index)", "edf"]
  results[[paste0("edf_", ct)]] <- data.frame(
    metric = "nh_primary_csi_spline_edf", city = ct, value = edf
  )
}

# ---- 3. Gamma zero-distance reassignment (Methods, Sec. 2.5) ---------------

zero_dist <- dt_full |>
  filter(!is.na(closest_greenspace)) |>
  group_by(city) |>
  summarise(value = sum(closest_greenspace == 0), .groups = "drop") |>
  mutate(metric = "gamma_zero_distance_reassigned_n") |>
  rename(city = city) |>
  select(metric, city, value)
results[["zero_dist"]] <- as.data.frame(zero_dist)

# ---- 4. NH analytic sample size, outlier-excluded retained %, 300m share ---

dt_nh <- readRDS(paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"
))

dt_primary <- dt_nh |>
  filter(
    !is.na(neighbor_visit_count_annual_avg),
    !is.na(home_device_counts_total_parsed_annual_avg),
    home_device_counts_total_parsed_annual_avg > 0
  )

for (ct in c("LA", "NYC")) {
  results[[paste0("nh_analytic_n_", ct)]] <- data.frame(
    metric = "nh_analytic_sample_n", city = ct,
    value = sum(dt_primary$city == ct)
  )
}

city_csi_stats <- dt_primary |>
  group_by(city) |>
  summarise(
    mean_csi = mean(community_severance_index, na.rm = TRUE),
    sd_csi   = sd(community_severance_index, na.rm = TRUE),
    .groups = "drop"
  )

dt_no_outl <- dt_primary |>
  left_join(city_csi_stats, by = "city") |>
  mutate(
    z_csi = (community_severance_index - mean_csi) / sd_csi,
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier (|z|>2)", "Within +/-2 SD")
  ) |>
  filter(outlier_flag != "Outlier (|z|>2)")

results[["nh_retained_n"]] <- data.frame(
  metric = "nh_primary_retained_n", city = "combined", value = nrow(dt_no_outl)
)
results[["nh_retained_pct"]] <- data.frame(
  metric = "nh_primary_retained_pct", city = "combined",
  value = round(100 * nrow(dt_no_outl) / 3312, 1)
)
results[["nh_excluded_n"]] <- data.frame(
  metric = "nh_primary_excluded_n", city = "combined",
  value = 3312 - nrow(dt_no_outl)
)
results[["nh_excluded_pct"]] <- data.frame(
  metric = "nh_primary_excluded_pct", city = "combined",
  value = round(100 * (3312 - nrow(dt_no_outl)) / 3312, 1)
)
for (ct in c("LA", "NYC")) {
  results[[paste0("nh_retained_n_", ct)]] <- data.frame(
    metric = "nh_primary_retained_n_by_city", city = ct,
    value = sum(dt_no_outl$city == ct)
  )
}

outlier_counts <- read_csv(
  paste0(output.folder, "numeric_results_outlier_exclusion_counts.csv"),
  show_col_types = FALSE
)
ndvi_within <- sum(outlier_counts$Within[outlier_counts$outcome == "NDVI"])
gs_within   <- sum(outlier_counts$Within[
  outlier_counts$outcome == "Distance to green space"
])
results[["ndvi_retained_pct"]] <- data.frame(
  metric = "ndvi_primary_retained_pct", city = "combined",
  value = round(100 * ndvi_within / 3312, 1)
)
results[["gs_retained_pct"]] <- data.frame(
  metric = "distance_primary_retained_pct", city = "combined",
  value = round(100 * gs_within / 3312, 1)
)
results[["ndvi_excluded_pct"]] <- data.frame(
  metric = "ndvi_primary_excluded_pct", city = "combined",
  value = round(100 - 100 * ndvi_within / 3312, 1)
)
results[["gs_excluded_pct"]] <- data.frame(
  metric = "distance_primary_excluded_pct", city = "combined",
  value = round(100 - 100 * gs_within / 3312, 1)
)

la_dist <- dt_full$closest_greenspace[
  dt_full$city == "LA" & !is.na(dt_full$closest_greenspace)
]
results[["la_300m_pct"]] <- data.frame(
  metric = "la_pct_tracts_over_300m", city = "LA",
  value = round(100 * mean(la_dist > 300), 1)
)

# ---- 5. Population totals (Discussion, Sec. 4 "Strengths") -----------------
# Uses the `population` column (ACS tract population), not `TotPop` (a
# separate, smaller derived variable used only for pop_dens calculations) --
# confirmed by cross-checking both against the manuscript's stated totals.

results[["total_pop_full_sample"]] <- data.frame(
  metric = "total_population_full_sample_millions", city = "combined",
  value = sum(dt_nh$population, na.rm = TRUE) / 1e6
)
results[["total_pop_nh_sample"]] <- data.frame(
  metric = "total_population_nh_sample_millions", city = "combined",
  value = sum(dt_nh$population[dt_nh$has_greenspace_tract], na.rm = TRUE) / 1e6
)

# ---- Assemble and save ------------------------------------------------------

out <- bind_rows(results)
print(out, row.names = FALSE)

write_csv(out, paste0(output.folder, "numeric_results_misc_counts.csv"))
message("Saved: ", output.folder, "numeric_results_misc_counts.csv")
