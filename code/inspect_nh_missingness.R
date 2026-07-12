rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(ggplot2)
library(tidyr)

# ---- Load analytic dataset ------------------------------------------------

dt <- readRDS(paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"
))

dt <- dt |>
  mutate(nh_missing = is.na(neighbor_visit_count_annual_avg))

missing <- filter(dt, nh_missing)
present <- filter(dt, !nh_missing)

cat("=== NH MISSINGNESS OVERVIEW ===\n")
cat("Total tracts:          ", nrow(dt), "\n")
cat("Analytic (non-missing):", nrow(present), "\n")
cat("Missing:               ", nrow(missing), "(", round(mean(dt$nh_missing) * 100, 1), "%)\n\n")

# ---- By city ---------------------------------------------------------------

cat("--- By city ---\n")
dt |>
  group_by(city, nh_missing) |>
  summarise(n = n(), .groups = "drop") |>
  mutate(pct = round(n / sum(n) * 100, 1)) |>
  print()

# ---- Continuous variable comparison ----------------------------------------

vars <- c(
  "pop_dens", "building_density", "TotPop",
  "community_severance_index",
  "perc.black", "perc.hisp", "perc.pov",
  "NDVI", "closest_greenspace",
  "ICE_inc"
)

labels <- c(
  "Population density (per sq mi)",
  "Building density",
  "Total population",
  "Community Severance Index",
  "% Black",
  "% Hispanic",
  "% Poverty",
  "NDVI",
  "Distance to nearest green space (m)",
  "ICE income"
)

cat("\n--- Continuous characteristics: missing vs. analytic sample ---\n")
cat(sprintf("%-42s %10s %10s %10s %10s\n",
            "Variable", "Miss.med", "Pres.med", "Miss.mn", "Pres.mn"))
cat(strrep("-", 85), "\n")
for (i in seq_along(vars)) {
  v <- vars[i]
  if (!v %in% names(dt)) next
  cat(sprintf("%-42s %10.3f %10.3f %10.3f %10.3f\n",
              labels[i],
              median(missing[[v]], na.rm = TRUE),
              median(present[[v]], na.rm = TRUE),
              mean(missing[[v]], na.rm = TRUE),
              mean(present[[v]], na.rm = TRUE)))
}

# ---- Population extremes ---------------------------------------------------

cat("\n--- Population size of missing tracts ---\n")
cat("TotPop == 0:    ", sum(missing$TotPop == 0, na.rm = TRUE), "\n")
cat("TotPop < 100:   ", sum(missing$TotPop < 100, na.rm = TRUE), "\n")
cat("TotPop < 500:   ", sum(missing$TotPop < 500, na.rm = TRUE), "\n")
cat("TotPop < 1000:  ", sum(missing$TotPop < 1000, na.rm = TRUE), "\n")

cat("\n--- Pop density < 1,000 ---\n")
cat("Missing:", sum(missing$pop_dens < 1000, na.rm = TRUE), "of", nrow(missing),
    "(", round(mean(missing$pop_dens < 1000, na.rm = TRUE) * 100, 1), "%)\n")
cat("Present:", sum(present$pop_dens < 1000, na.rm = TRUE), "of", nrow(present),
    "(", round(mean(present$pop_dens < 1000, na.rm = TRUE) * 100, 1), "%)\n")

# ---- ICE quintile distribution ---------------------------------------------

cat("\n--- ICE income quintile distribution of missing tracts ---\n")
print(table(missing$ICE_inc_quintile, useNA = "always"))

cat("\n--- ICE income quintile distribution of analytic sample ---\n")
print(table(present$ICE_inc_quintile, useNA = "always"))

# ---- n_months in missing tracts (all should be NA) -------------------------

cat("\n--- n_months for missing tracts (expected: all NA) ---\n")
print(table(missing$n_months_neighbor_visit, useNA = "always"))

# ---- CSI distribution check: are missing tracts skewed toward high CSI? ---

cat("\n--- CSI quartiles (missing vs present) ---\n")
cat("Missing: ", paste(round(quantile(missing$community_severance_index,
                                      c(0.25, 0.5, 0.75), na.rm = TRUE), 3),
                       collapse = " / "), "\n")
cat("Present: ", paste(round(quantile(present$community_severance_index,
                                      c(0.25, 0.5, 0.75), na.rm = TRUE), 3),
                       collapse = " / "), "\n")

# ---- Plot: density of pop_dens by missingness status ----------------------

p1 <- ggplot(dt, aes(x = log1p(pop_dens), fill = nh_missing)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(
    values = c("FALSE" = "#2c7bb6", "TRUE" = "#d7191c"),
    labels = c("FALSE" = "Analytic sample", "TRUE" = "Missing NH")
  ) +
  labs(
    title = "Population density distribution by NH missingness",
    x = "log(1 + population density)",
    y = "Density",
    fill = NULL
  ) +
  theme_bw()

p2 <- ggplot(dt, aes(x = community_severance_index, fill = nh_missing)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(
    values = c("FALSE" = "#2c7bb6", "TRUE" = "#d7191c"),
    labels = c("FALSE" = "Analytic sample", "TRUE" = "Missing NH")
  ) +
  labs(
    title = "CSI distribution by NH missingness",
    x = "Community Severance Index",
    y = "Density",
    fill = NULL
  ) +
  theme_bw()

p3 <- dt |>
  filter(!is.na(ICE_inc_quintile)) |>
  group_by(ICE_inc_quintile, nh_missing) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(ICE_inc_quintile) |>
  mutate(pct = n / sum(n) * 100) |>
  filter(nh_missing) |>
  ggplot(aes(x = ICE_inc_quintile, y = pct)) +
  geom_col(fill = "#d7191c") +
  labs(
    title = "% of tracts with missing NH by ICE income quintile",
    x = "ICE income quintile",
    y = "% missing NH data"
  ) +
  theme_bw()

png(paste0(output.folder, "nh_missingness_diagnostic.png"), 1200, 400)
gridExtra::grid.arrange(p1, p2, p3, ncol = 3)
dev.off()

message("Diagnostic plot saved to: ", output.folder, "nh_missingness_diagnostic.png")
