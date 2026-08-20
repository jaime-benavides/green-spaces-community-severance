rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(sf)
  library(tigris)
  library(tmap)
  library(readr)
})

options(tigris_use_cache = TRUE)

# PAD-US Areas of Recreation (Browning et al. 2022) — see README.md "Data" > "green infrastructure" for download link
padus_ar_path <- paste0(raw.data.folder, "green_infrastructure/padus_ar.shp")
crs_proj      <- 2163

# ---- Load study-area tract geometry (krieger_ice = 500 Cities boundary) ----

nyc_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds")) |>
  sf::st_transform(crs_proj)
la_ice  <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))  |>
  sf::st_transform(crs_proj)

nyc_tracts <- str_pad(as.character(nyc_ice$GEOID), 11, "left", "0")
la_tracts  <- str_pad(as.character(la_ice$GEOID),  11, "left", "0")
study_tracts <- c(nyc_tracts, la_tracts)

nyc_boundary <- sf::st_union(nyc_ice)
la_boundary  <- sf::st_union(la_ice)

# ---- Download 2019 TIGER CBGs and intersect with 500 Cities boundaries ------
# This is the canonical upstream CBG list: all 2019 Census block groups whose
# geometry intersects the 500 Cities boundary for NYC or LA.

cat("Downloading TIGER block groups (cached)...\n")
bg_nyc <- tigris::block_groups(
  state = "NY", county = c("005", "047", "061", "081", "085"),
  year = 2019, progress_bar = FALSE
) |> sf::st_transform(crs_proj)

bg_la <- tigris::block_groups(
  state = "CA", county = "037",
  year = 2019, progress_bar = FALSE
) |> sf::st_transform(crs_proj)

# Intersect with 500 Cities boundaries (same criterion as prep_ses.R for tracts)
in_nyc <- sapply(sf::st_intersects(bg_nyc, nyc_boundary), function(x) length(x) > 0)
in_la  <- sapply(sf::st_intersects(bg_la,  la_boundary),  function(x) length(x) > 0)

bg_all <- dplyr::bind_rows(
  dplyr::mutate(bg_nyc[in_nyc, ], city = "NYC"),
  dplyr::mutate(bg_la[in_la, ],   city = "LA")
) |>
  dplyr::mutate(
    GEOID_CBG   = stringr::str_pad(GEOID, 12, "left", "0"),
    TRACT_GEOID = substr(GEOID_CBG, 1, 11),
    aland_km2   = as.numeric(ALAND) / 1e6,
    awater_km2  = as.numeric(AWATER) / 1e6,
    pct_water   = ifelse(
      (aland_km2 + awater_km2) > 0,
      awater_km2 / (aland_km2 + awater_km2),
      NA_real_
    )
  )

cat("Study-area CBGs (TIGER 2019 within 500 Cities):",
    sum(bg_all$city == "NYC"), "NYC |", sum(bg_all$city == "LA"), "LA\n")

# ---- Check NH data coverage against TIGER CBG tracts -----------------------
# Source: pre-merged tract-level NH estimates (primary Advan + supplementary).
# Tracts absent from this file have no NH data in the analytic dataset.

nh_tracts <- readr::read_csv(
  paste0(raw.data.folder, "neigh_home/2019_full_year_neighbor_home_nyc_la_tract_average.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(TRACT_GEOID = stringr::str_pad(as.character(TRACT_GEOID), 11, "left", "0"))

bg_all <- bg_all |>
  dplyr::mutate(
    has_nh_data = TRACT_GEOID %in% nh_tracts$TRACT_GEOID
  )

uncovered <- dplyr::filter(bg_all, !has_nh_data)
cat("CBGs with no NH data:", nrow(uncovered),
    "(NYC:", sum(uncovered$city == "NYC"), "| LA:", sum(uncovered$city == "LA"), ")\n")

# ---- Load PAD-US AR and filter to study cities -----------------------------

cat("Loading PAD-US AR from SSD...\n")
padus_ar <- sf::read_sf(padus_ar_path) |>
  sf::st_transform(crs_proj)

padus_ar <- padus_ar[as.numeric(sf::st_area(padus_ar)) >= 400, ]

nyc_ids <- sapply(sf::st_intersects(padus_ar, nyc_boundary), function(x) length(x) > 0)
la_ids  <- sapply(sf::st_intersects(padus_ar, la_boundary),  function(x) length(x) > 0)

padus_nyc <- padus_ar[nyc_ids, ]
padus_la  <- padus_ar[la_ids,  ]

cat("PAD-US AR polygons — NYC:", nrow(padus_nyc), "| LA:", nrow(padus_la), "\n")

# ---- Intersect uncovered CBGs with PAD-US AR --------------------------------

uncov_nyc <- dplyr::filter(uncovered, city == "NYC")
uncov_la  <- dplyr::filter(uncovered, city == "LA")

overlap_nyc <- sapply(sf::st_intersects(uncov_nyc, padus_nyc), function(x) length(x) > 0)
overlap_la  <- sapply(sf::st_intersects(uncov_la,  padus_la),  function(x) length(x) > 0)

uncov_nyc <- dplyr::mutate(uncov_nyc, intersects_padus = overlap_nyc)
uncov_la  <- dplyr::mutate(uncov_la,  intersects_padus = overlap_la)
uncovered <- dplyr::bind_rows(uncov_nyc, uncov_la)

cat("\n=== PAD-US AR intersection results ===\n")
cat("NYC uncovered CBGs intersecting PAD-US AR:", sum(overlap_nyc), "of", nrow(uncov_nyc), "\n")
cat("LA  uncovered CBGs intersecting PAD-US AR:", sum(overlap_la),  "of", nrow(uncov_la),  "\n")
cat("\nCBG details (uncovered, with PAD-US flag):\n")
print(
  sf::st_drop_geometry(uncovered) |>
    dplyr::select(GEOID_CBG, TRACT_GEOID, city, aland_km2, pct_water, intersects_padus) |>
    dplyr::arrange(desc(intersects_padus), desc(aland_km2))
)

# ---- Build interactive maps (one per city) ---------------------------------

tmap_mode("view")

make_city_map <- function(city_label, padus_city) {

  city_cbgs  <- dplyr::filter(bg_all,   city == city_label) |> sf::st_transform(4326)
  city_uncov <- dplyr::filter(uncovered, city == city_label) |>
    dplyr::mutate(
      padus_label = ifelse(intersects_padus, "No NH data + PAD-US AR", "No NH data (no PAD-US)")
    ) |>
    sf::st_transform(4326)
  padus_layer <- sf::st_transform(padus_city, 4326)

  tm_basemap(c("OpenStreetMap", "Esri.WorldImagery")) +
    tm_shape(city_cbgs, name = "All study-area CBGs") +
      tm_borders(col = "grey70", lwd = 0.3) +
    tm_shape(padus_layer, name = "PAD-US AR green spaces") +
      tm_fill(col = "#1a9641", alpha = 0.35) +
      tm_borders(col = "#1a9641", lwd = 0.5) +
    tm_shape(city_uncov, name = "CBGs with no NH data") +
      tm_fill(col = "padus_label",
              palette = c("No NH data + PAD-US AR"    = "#d73027",
                          "No NH data (no PAD-US)" = "#fc8d59"),
              alpha = 0.75,
              title = "NH coverage") +
      tm_borders(col = "black", lwd = 1) +
      tm_text("GEOID_CBG", size = 0.5, col = "black")
}

nyc_map <- make_city_map("NYC", padus_nyc)
la_map  <- make_city_map("LA",  padus_la)

# ---- Save ----------------------------------------------------------------

tmap_save(nyc_map, filename = paste0(output.folder, "map_uncovered_cbgs_nh_nyc.html"))
tmap_save(la_map,  filename = paste0(output.folder, "map_uncovered_cbgs_nh_la.html"))

message("Saved: output/map_uncovered_cbgs_nh_nyc.html")
message("Saved: output/map_uncovered_cbgs_nh_la.html")
message(
  "Red (dark)   = CBG with no NH data overlapping PAD-US AR green space\n",
  "Red (light)  = CBG with no NH data, no PAD-US overlap\n",
  "Green        = PAD-US AR green spaces"
)
