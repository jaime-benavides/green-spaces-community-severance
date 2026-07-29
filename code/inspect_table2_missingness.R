rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(sf)
library(ggplot2)
library(patchwork)

# ---- Purpose ---------------------------------------------------------------
# Diagnoses missingness in Table 2 (exposure and covariates): for each
# variable with missing values, reports (a) the share of missing-value
# tracts that are non-residential (population density = 0), and (b) maps
# the location of the missing tracts in each city. Written to verify the
# manuscript's stated explanation for Table 2 missingness (sn-article.tex,
# Results, Table 2 paragraph). Logged in CODE_REVIEW.md.

# ---- Load analytic dataset and geometry ------------------------------------

dt <- readRDS(paste0(
  generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"
))

city_nyc <- readRDS(paste0(generated.data.folder, "city_boundary_nyc.rds"))
city_la  <- readRDS(paste0(generated.data.folder, "city_boundary_la.rds"))

geom_nyc_raw <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds"))
city_nyc_tr  <- city_nyc |> sf::st_transform(sf::st_crs(geom_nyc_raw)) |>
  sf::st_make_valid() |> sf::st_union()
geom_nyc <- geom_nyc_raw |>
  select(GEOID, geometry) |> sf::st_make_valid() |>
  sf::st_intersection(city_nyc_tr)

geom_la_raw <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))
city_la_tr   <- city_la |> sf::st_transform(sf::st_crs(geom_la_raw)) |>
  sf::st_make_valid() |> sf::st_union()
geom_la <- geom_la_raw |>
  select(GEOID, geometry) |> sf::st_make_valid() |>
  sf::st_intersection(city_la_tr)

geom_all <- bind_rows(geom_la, geom_nyc)

# ---- Variables under diagnosis ---------------------------------------------

vars <- c(
  community_severance_index = "Community Severance Index",
  perc.black                = "Percent Black",
  perc.hisp                 = "Percent Hispanic",
  perc.pov                  = "Percent poverty",
  ICE_inc                   = "ICE"
)

# ---- (a) Tabular diagnosis: is missingness explained by non-residential
# (zero population density) tracts? ------------------------------------------

diagnosis <- bind_rows(lapply(names(vars), function(v) {
  bind_rows(lapply(c("LA", "NYC"), function(city_i) {
    sub  <- dt[dt$city == city_i, ]
    miss <- is.na(sub[[v]])
    n    <- sum(miss)
    if (n == 0) return(NULL)
    popdens <- sub$pop_dens[miss]
    data.frame(
      variable            = vars[[v]],
      city                = city_i,
      n_missing           = n,
      pct_nonresidential  = round(100 * mean(popdens == 0, na.rm = TRUE), 1),
      median_totpop_nonNA = suppressWarnings(median(sub$TotPop[miss], na.rm = TRUE)),
      n_totpop_also_na    = sum(is.na(sub$TotPop[miss]))
    )
  }))
}))

print(diagnosis, row.names = FALSE)

write.csv(
  diagnosis,
  paste0(output.folder, "table2_missingness_diagnosis.csv"),
  row.names = FALSE
)
message("Saved: ", output.folder, "table2_missingness_diagnosis.csv")

# ---- (b) Maps of missing-tract locations ------------------------------------

miss_flags <- dt |>
  select(GEOID, city, all_of(names(vars))) |>
  mutate(across(all_of(names(vars)), \(x) is.na(x), .names = "miss_{.col}"))

sf_miss <- geom_all |>
  left_join(miss_flags, by = "GEOID") |>
  filter(!is.na(city))

map_panel <- function(city_name, var_col, var_label) {
  d <- sf_miss |> filter(city == city_name)
  ggplot(d) +
    geom_sf(aes(fill = .data[[var_col]]), color = NA) +
    scale_fill_manual(
      values = c(`FALSE` = "grey90", `TRUE` = "firebrick"),
      labels = c("Present", "Missing"),
      name = NULL, drop = FALSE
    ) +
    labs(title = paste0(city_name, ": ", var_label)) +
    theme_void() +
    theme(legend.position = "bottom",
          plot.title = element_text(size = 9, hjust = 0.5))
}

panels <- list()
for (v in names(vars)) {
  col <- paste0("miss_", v)
  panels[[paste0(v, "_LA")]]  <- map_panel("LA",  col, vars[[v]])
  panels[[paste0(v, "_NYC")]] <- map_panel("NYC", col, vars[[v]])
}

missingness_maps <- patchwork::wrap_plots(panels, ncol = 2, guides = "collect") &
  theme(legend.position = "bottom")

ggsave(
  paste0(output.folder, "table2_missingness_maps.png"),
  missingness_maps,
  width = 10, height = 5 * length(vars), dpi = 300, bg = "white", limitsize = FALSE
)
message("Saved: ", output.folder, "table2_missingness_maps.png")
