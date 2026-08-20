rm(list = ls())

# models_linear.R
# Purpose: Fits the NDVI (Gaussian GAM) and proximity (Gamma GAM) models.

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(mgcv)
library(ggplot2)
library(dplyr)
library(gratia)
library(tidyr)

crs <- 2163
# community severance
nyc_csi <- readRDS(paste0(generated.data.folder, "community_severance_nyc_census_tract.rds"))
la_csi <- readRDS(paste0(generated.data.folder, "community_severance_la_census_tract.rds"))
la_csi$GEOID <- substring(la_csi$GEOID, 2)

path_demography <- paste0(raw.data.folder, "demography/")
# NYC UHF42 neighborhood boundaries — see README.md "Data" > "demography" for download link
neigh_nyc <- sf::st_read(paste0(path_demography, "uhf42_dohmh_2009/UHF_42_DOHMH_2009.shp"))
neigh_nyc <- sf::st_transform(neigh_nyc, crs)
# LA Community Plan Area boundaries — see README.md "Data" > "demography" for download link
neigh_la <- sf::st_read(paste0(path_demography,"Community_Plan_Areas_la/Community_Plan_Areas.shp"))
neigh_la <- sf::st_transform(neigh_la, crs)

# building density
nyc_build_dens <- readRDS(paste0(generated.data.folder, "building_dens_nyc.rds"))
la_build_dens <- readRDS(paste0(generated.data.folder, "building_dens_la.rds"))
la_build_dens$GEOID <- substring(la_build_dens$GEOID, 2)
# ses
nyc_ses <- readRDS(paste0(generated.data.folder, "ses_ice_nyc.rds"))
la_ses <- readRDS(paste0(generated.data.folder, "ses_ice_la.rds"))
la_ses$GEOID <- substring(la_ses$GEOID, 2)
nyc_ses_df <- nyc_ses
sf::st_geometry(nyc_ses_df) <- NULL
nyc_ses_df <- nyc_ses_df[,c("GEOID", "ICE_inc",  "ICE_rewb", 
                            "perc.black", "perc.hisp", "perc.pov", "pop_dens")]
la_ses_df <- la_ses
sf::st_geometry(la_ses_df) <- NULL
la_ses_df <- la_ses_df[,c("GEOID",  "ICE_inc",  "ICE_rewb", 
                          "perc.black", "perc.hisp", "perc.pov", "pop_dens")]

# green spaces
# ndvi_*_census_tract.rds are plain data.frames (geometry stripped by prep_greenspace.R).
# Attach tract geometry from krieger_ice before the spatial operations below.
nyc_ndvi <- readRDS(paste0(generated.data.folder, "ndvi_nyc_census_tract.rds"))
nyc_ice_geom <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds")) |>
  dplyr::select(GEOID, geometry)                          # 11-digit GEOID, matches nyc_ndvi
nyc_ndvi <- sf::st_as_sf(dplyr::left_join(nyc_ice_geom, nyc_ndvi, by = "GEOID"))
nyc_ndvi <- sf::st_transform(nyc_ndvi, crs)

la_ndvi <- readRDS(paste0(generated.data.folder, "ndvi_la_census_tract.rds"))
la_ice_geom <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds")) |>
  dplyr::mutate(GEOID = substring(as.character(GEOID), 2)) |>  # strip leading 0 to match 10-digit la_ndvi GEOID
  dplyr::select(GEOID, geometry)
la_ndvi <- sf::st_as_sf(dplyr::left_join(la_ice_geom, la_ndvi, by = "GEOID"))
la_ndvi <- sf::st_transform(la_ndvi, crs)

# euclidean distance to green spaces
cs_access_euclidean_la <- readRDS(paste0(generated.data.folder, "cs_access_euclidean_la.rds"))
cs_access_euclidean_la_df <- cs_access_euclidean_la

cs_access_euclidean_la_df <- cs_access_euclidean_la_df[,c("GEOID", "closest_greenspace")]
cs_access_euclidean_nyc <- readRDS(paste0(generated.data.folder, "cs_access_euclidean_nyc.rds"))
cs_access_euclidean_nyc_df <- cs_access_euclidean_nyc

cs_access_euclidean_nyc_df <- cs_access_euclidean_nyc_df[,c("GEOID", "closest_greenspace")]

# assign neighborhoods


# --- LOS ANGELES ---
# Intersect NDVI polygons with neighborhood boundaries
# Make sure each NDVI feature has a unique ID
# 1️⃣ Make sure each NDVI polygon has a unique ID
la_ndvi$id <- seq_len(nrow(la_ndvi))

# 2️⃣ Intersect with neighborhoods
la_ndvi_inter <- sf::st_intersection(la_ndvi, neigh_la["NAME_ALF"])
la_ndvi_inter$int_area <- as.numeric(sf::st_area(la_ndvi_inter))

# 3️⃣ For each NDVI ID, keep the neighborhood with the largest intersection area
la_ndvi_clean <- la_ndvi_inter |>
  dplyr::group_by(id) |>
  dplyr::slice_max(order_by = int_area, n = 1, with_ties = FALSE) |>
  dplyr::ungroup()

# 4️⃣ Clean up: ensure one row per NDVI polygon
la_ndvi_clean <- la_ndvi_clean |>
  dplyr::distinct(id, .keep_all = TRUE)

# 5️⃣ Rename neighborhood column
colnames(la_ndvi_clean)[colnames(la_ndvi_clean) == "NAME_ALF"] <- "neighborhood"

# ✅ Check results again
nrow(la_ndvi_clean)
length(unique(la_ndvi_clean$id))


# --- NYC ---

nyc_ndvi$id <- seq_len(nrow(nyc_ndvi))

# 2️⃣ Intersect with neighborhoods
nyc_ndvi_inter <- sf::st_intersection(nyc_ndvi, neigh_nyc["UHF_NEIGH"])
nyc_ndvi_inter$int_area <- as.numeric(sf::st_area(nyc_ndvi_inter))

# 3️⃣ For each NDVI ID, keep the neighborhood with the nycrgest intersection area
nyc_ndvi_clean <- nyc_ndvi_inter |>
  dplyr::group_by(id) |>
  dplyr::slice_max(order_by = int_area, n = 1, with_ties = FALSE) |>
  dplyr::ungroup()

# 4️⃣ Clean up: ensure one row per NDVI polygon
nyc_ndvi_clean <- nyc_ndvi_clean |>
  dplyr::distinct(id, .keep_all = TRUE)

# 5️⃣ Rename neighborhood column
colnames(nyc_ndvi_clean)[colnames(nyc_ndvi_clean) == "UHF_NEIGH"] <- "neighborhood"

# ✅ Check results again
nrow(nyc_ndvi_clean)
length(unique(nyc_ndvi_clean$id))

nyc_ndvi_df <- nyc_ndvi_clean
sf::st_geometry(nyc_ndvi_df) <- NULL
la_ndvi_df <- la_ndvi_clean
sf::st_geometry(la_ndvi_df) <- NULL
#sf_cntxt <- sapply(sf::st_intersects(sf::st_transform(la_ice, sf::st_crs(la_shape)), la_shape),function(x){length(x)>0})
#la_ice <- la_ice[sf_cntxt, ]

# combine
dta_la <- dplyr::left_join(la_ndvi_df, la_ses_df)
dta_la <- dplyr::left_join(dta_la, la_csi)
dta_la <- dplyr::left_join(dta_la, la_build_dens)
dta_la <- dplyr::left_join(dta_la, cs_access_euclidean_la_df)

dta_nyc <- dplyr::left_join(nyc_ndvi_df, nyc_ses_df)
dta_nyc <- dplyr::left_join(dta_nyc, nyc_csi)
dta_nyc <- dplyr::left_join(dta_nyc, nyc_build_dens)
dta_nyc <- dplyr::left_join(dta_nyc, cs_access_euclidean_nyc_df)


dta_nyc$city <- "NYC"
dta_la$city <- "LA"
dt <- rbind(dta_la, dta_nyc)
vars <- c("NDVI", "closest_greenspace", "community_severance_index", "perc.black",
          "perc.hisp", "perc.pov", "pop_dens", "building_density", "ICE_inc", "ICE_rewb")
groups <- c("NYC", "LA") 
table_df <- data.frame(group = groups, NDVI = rep(NA, length(groups)),
                       closest_greenspace = rep(NA, length(groups)), 
                       community_severance_index = rep(NA, length(groups)), 
                       perc.black = rep(NA, length(groups)), 
                       perc.hisp = rep(NA, length(groups)),
                       perc.pov = rep(NA, length(groups)),
                       pop_dens = rep(NA, length(groups)),
                       building_density = rep(NA, length(groups)),
                       ICE_inc = rep(NA, length(groups)),
                       ICE_rewb = rep(NA, length(groups)))
table_1 <- table_desc(dta = dt, vars = vars, groups = groups, 
                      table_df = table_df)
t_table_1 <- data.table::transpose(table_1)
# get row and colnames in order
colnames(t_table_1) <- rownames(table_1)
rownames(t_table_1) <- colnames(table_1)
html_string <- knitr::kable(t_table_1, format = "html")
writeLines(html_string, paste0(output.folder, "data_descriptives.html"))
# potential outliers 

# City-specific CSI z-scores: mean and SD computed separately per city
city_csi_stats <- dt %>%
  group_by(city) %>%
  summarise(
    mean_csi = mean(community_severance_index, na.rm = TRUE),
    sd_csi   = sd(community_severance_index, na.rm = TRUE),
    .groups = "drop"
  )

dt <- dt %>%
  left_join(city_csi_stats, by = "city") %>%
  mutate(
    z_csi        = (community_severance_index - mean_csi) / sd_csi,
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier (|z|>2)", "Within ±2 SD")
  ) %>%
  dplyr::select(-mean_csi, -sd_csi)


dt <- dt |>
  dplyr::group_by(city) |>
  dplyr::mutate(
    dplyr::across(
      .cols = c(ICE_inc, ICE_rewb),
      .fns = ~ dplyr::ntile(., 5) |>
        factor(
          levels = 1:5,
          labels = c("Q1 (Most Disadvantaged)",
                     "Q2",
                     "Q3",
                     "Q4",
                     "Q5 (Most Advantaged)")
        ),
      .names = "{.col}_quintile"
    )
  ) |>
  dplyr::ungroup()

# Convert all *_group variables to ordered factors
group_vars <- grep("_quintile$", names(dt), value = TRUE)

dt <- dt |>
  dplyr::mutate(
    dplyr::across(
      dplyr::all_of(group_vars),
      ~ factor(.x, levels = c("Q1 (Most Disadvantaged)", "Q2", "Q3", "Q4", "Q5 (Most Advantaged)"))
    )
  )



# neighborhoods as factors
dt$neighborhood <- as.factor(dt$neighborhood)
dt$city <- as.factor(dt$city)


saveRDS(dt, paste0(generated.data.folder, "data_models.rds"))
# ============================================================
# --- Main Model Fitting Procedures ---
# ============================================================

# Categorical ICE quintiles
ice_quint_vars <- c("ICE_inc_quintile", "ICE_rewb_quintile")

# Continuous ICE variables
ice_cont_vars <- c("ICE_inc", "ICE_rewb")


# NDVI models ------------------------------------------------
model_list_ndvi <- list(
  # City-level models
  fits_city     = fit_by(dt, by = "city",family_type = "linear", model_fun =  model_gam_mixed_ndvi),

  # City-level models
  fits_city_crude = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "city",family_type = "linear", crude = TRUE, model_fun =  model_gam_mixed_ndvi),

  # sens anal no outliers
  fits_outl_city     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "city", family_type = "linear", model_fun =  model_gam_mixed_ndvi),
  # ICE quintile (categorical) models
  fits_ice_quint_nyc = setNames(
    lapply(ice_quint_vars, function(v)
      fit_by(dt[which(dt$city == "NYC"),], by = v, model_fun =  model_gam_mixed_ndvi, family_type = "linear", include_city = FALSE)
    ),
    ice_quint_vars
  ),
  # ICE quintile (categorical) models
  fits_ice_quint_la = setNames(
    lapply(ice_quint_vars, function(v)
      fit_by(dt[which(dt$city == "LA"),], by = v, model_fun =  model_gam_mixed_ndvi, family_type = "linear", include_city = FALSE)
    ),
    ice_quint_vars
  ),
  
  # ICE continuous models with tensor interactions
  fits_ice_cont = setNames(
    lapply(ice_cont_vars, function(v)
      fit_by(dt, by = "none", model_fun =  model_gam_mixed_ndvi, family_type = "linear", include_city = TRUE, ice_cont = v)
    ),
    ice_cont_vars
  ),
  
  # City × ICE models
  fits_city_ice = fit_city_ice(
    data          = dt,
    model_fun     =  model_gam_mixed_ndvi,
    city_var      = "city",
    ice_vars      = ice_quint_vars,    # categorical ICE
    ice_cont_vars = ice_cont_vars       # continuous ICE
  )
)

saveRDS(model_list_ndvi$fits_city,
        paste0(generated.data.folder, "ndvi_model_objects_city_adjusted_linear.rds"))
saveRDS(model_list_ndvi$fits_city_crude,
        paste0(generated.data.folder, "ndvi_model_objects_city_crude_linear.rds"))

# get numbers
bind_rows(
  estimate_75_vs_median(data = dt, city_name = "LA", predictor = "community_severance_index",  outcome = "NDVI", lag = 0, family_type = "gaussian", df_var = 3),
  estimate_75_vs_median(data = dt, city_name = "NYC", predictor = "community_severance_index", outcome = "NDVI",  lag = 0, family_type = "gaussian", df_var = 3)
)



# primary analysis

dt$closest_greenspace[which(dt$closest_greenspace ==0)] <- 1
# greenspace distance models ------------------------------------------------
model_list_greenspace <- list(

  # City-level models
  fits_city     = fit_by(dt, by = "city", model_fun = model_gam_mixed_greenspace,family_type = "gamma",
                         include_city = FALSE),
  
  # City-level models
  fits_city_crude     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "city", model_fun = model_gam_mixed_greenspace,family_type = "gamma", crude = TRUE,
                               include_city = FALSE)
)

saveRDS(model_list_greenspace$fits_city,
        paste0(generated.data.folder, "greenspace_model_objects_city_adjusted_linear.rds"))
saveRDS(model_list_greenspace$fits_city_crude,
        paste0(generated.data.folder, "greenspace_model_objects_city_crude_linear.rds"))

# get numbers
bind_rows(
  estimate_75_vs_median(data = dt, city_name = "LA", predictor = "community_severance_index",  outcome = "closest_greenspace", lag = 0, family_type = "gamma", df_var = 3),
  estimate_75_vs_median(data = dt, city_name = "NYC", predictor = "community_severance_index",  outcome = "closest_greenspace", lag = 0, family_type = "gamma", df_var = 3)
)



