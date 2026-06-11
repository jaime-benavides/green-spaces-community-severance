rm(list = ls())
project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(mgcv)
library(ggplot2)
library(dplyr)
library(gratia)
library(tidyr)
library(plotly)

crs <- 2163
# community severance
nyc_csi <- readRDS(paste0(generated.data.folder, "community_severance_nyc_census_tract.rds"))
la_csi <- readRDS(paste0(generated.data.folder, "community_severance_la_census_tract.rds"))
la_csi$GEOID <- substring(la_csi$GEOID, 2)

path_demography <- "/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/demography/us/"
neigh_nyc <- sf::st_read(paste0(path_demography, "nyc/uhf42_dohmh_2009/UHF_42_DOHMH_2009.shp"))
neigh_nyc <- sf::st_transform(neigh_nyc, crs)
neigh_la <- sf::st_read(paste0(path_demography,"urban/Community_Plan_Areas_la/Community_Plan_Areas.shp")) 
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
  # Global model
  #fit_all       = model_gam_mixed_ndvi(dt, by = "none",family_type = "linear"),
  
  # City-level models
  fits_city     = fit_by(dt, by = "city",family_type = "linear", model_fun =  model_gam_mixed_ndvi),
  
  #fit_all_crude = model_gam_mixed_ndvi(dt, by = "none",family_type = "linear", include_city = TRUE, crude = TRUE),
  
  # City-level models
  fits_city_crude = fit_by(dt, by = "city",family_type = "linear", crude = TRUE, model_fun =  model_gam_mixed_ndvi),
  
  
  # sens anal no outliers
  #fits_outl     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], family_type = "linear", by = "none", model_fun =  model_gam_mixed_ndvi),
  fits_outl_city     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "city", family_type = "linear", model_fun =  model_gam_mixed_ndvi),
  # ICE quintile (categorical) models
  #fits_ice_quint = setNames(
  #  lapply(ice_quint_vars, function(v)
  #    fit_by(dt, by = v, model_fun =  model_gam_mixed_ndvi, family_type = "linear", include_city = TRUE)
  #  ),
  #  ice_quint_vars
  #),
  
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
  
  # ICE continuous models with tensor interactions
  #fits_ice_cont_no_outl = setNames(
   # lapply(ice_cont_vars, function(v)
   #   fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "none", family_type = "linear", model_fun =  model_gam_mixed_ndvi, include_city = TRUE, ice_cont = v)
   # ),
  #  ice_cont_vars
 # ),
  
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



# --- Example usage ---
#summary(model_list_ndvi$fit_all)
#plot(model_list_ndvi$fit_all, select = 1, shade = TRUE)
#gam.check(model_list_ndvi$fit_all)



# generate plots
#png(paste0(output.folder, "models_result_", "ndvi_main_linear.png"), 900, 460)
#plot_smooth_gam(model_list_ndvi$fit_all, y_limits = c(0, .6), rug = TRUE)
#dev.off()
#png(paste0(output.folder, "models_result_", "ndvi_crude_linear.png"), 900, 460)
#plot_smooth_gam(model_list_ndvi$fit_all_crude, y_limits = c(0, .6), rug = TRUE)
#dev.off()
# generate plots
#png(paste0(output.folder, "models_result_", "ndvi_ses_outl_linear.png"), 900, 460)
#plot_smooth_gam(model_list_ndvi$fits_outl, y_limits = c(0, .6), rug = TRUE)
#dev.off()

#appraise(model_list_ndvi$fit_all)
#draw(model_list_ndvi$fit_all, residuals = TRUE)

# primary analysis

plots_city_crude <- plot_smooth_gam(model_list_ndvi$fits_city_crude, y_limits = c(-0.2, .2), rug = T)

png(paste0(output.folder, "models_result_", "ndvi_crude_primary_analysis.png"), 900, 460)
patchwork::wrap_plots(plots_city_crude)
dev.off()

plots_city <- plot_smooth_gam(model_list_ndvi$fits_city, y_limits = c(-0.2, .2), rug = T)

png(paste0(output.folder, "models_result_", "ndvi_adjusted_sensitivity_analysis.png"), 900, 460)
patchwork::wrap_plots(plots_city)
dev.off()



plots_city_no_outl <- plot_smooth_gam(model_list_ndvi$fits_outl_city, y_limits = c(-0.2, .2), rug = T)

png(paste0(output.folder, "models_result_", "ndvi_crude_sensitivity_analysis_no_outliers.png"), 900, 460)
patchwork::wrap_plots(plots_city_no_outl)
dev.off()

#plots_ice_quint <- plot_smooth_gam(model_list_ndvi$fits_ice_quint, y_limits = c(0, .6))
#png(paste0(output.folder, "models_result_", "ndvi_effect_modif_ice_linear.png"), 900, 460)
#patchwork::wrap_plots(plots_ice_quint)
#dev.off()



#plot_3d_ice_inc <- plot_tensor3D_gam(
#  gam_model = model_list_ndvi$fits_ice_cont$ICE_inc$fit_all,
#  smooth_name = "te(community_severance_index,ICE_inc)",
#  n = 50,
#  xlab = "Community Severance Index",
#  ylab = "ICE_inc",
#  zlab = "Predicted NDVI"
#)

#htmlwidgets::saveWidget(plot_3d_ice_inc, paste0(output.folder, "plot_3d_ice_inc_csi_ndvi_linear.html")) 


#plot_3d_ice_rewb <- plot_tensor3D_gam(
#  gam_model = model_list_ndvi$fits_ice_cont$ICE_rewb$fit_all,
#  smooth_name = "te(community_severance_index,ICE_rewb)",
#  n = 50,
#  xlab = "Community Severance Index",
#  ylab = "ICE_rewb",
 # zlab = "Predicted NDVI"
#)
# 
# htmlwidgets::saveWidget(plot_3d_ice_rewb, paste0(output.folder, "plot_3d_ice_rewb_csi_ndvi_linear.html")) 
# 
# 
# 
# plot_3d_ice_inc_no_outl <- plot_tensor3D_gam(
#   gam_model = model_list_ndvi$fits_ice_cont_no_outl$ICE_inc$fit_all,
#   smooth_name = "te(community_severance_index,ICE_inc)",
#   n = 50,
#   xlab = "Community Severance Index",
#   ylab = "ICE_inc",
#   zlab = "Predicted NDVI"
# )
# 
# htmlwidgets::saveWidget(plot_3d_ice_inc_no_outl, paste0(output.folder, "plot_3d_ice_inc_csi_ndvi_no_outl_linear.html")) 
# 
# 
# plot_3d_ice_rewb_no_outl <- plot_tensor3D_gam(
#   gam_model = model_list_ndvi$fits_ice_cont_no_outl$ICE_rewb$fit_all,
#   smooth_name = "te(community_severance_index,ICE_rewb)",
#   n = 50,
#   xlab = "Community Severance Index",
#   ylab = "ICE_rewb",
#   zlab = "Predicted NDVI"
# )
# 
# htmlwidgets::saveWidget(plot_3d_ice_rewb_no_outl, paste0(output.folder, "plot_3d_ice_rewb_csi_ndvi_no_outl_linear.html")) 
# 


#plots_city_ice <- plot_smooth_gam(model_list_ndvi$fits_city_ice, y_limits = c(0, .6))
#png(paste0(output.folder, "models_result_", "ndvi_effect_modif_city_ice_linear.png"), 900, 460)
#patchwork::wrap_plots(plots_city_ice)
#dev.off()


png(paste0(output.folder, "models_result_", "q1_q5_ICE_inc_linear.png"), 900, 460)
plot_q1_q5_categorical(model_list_ndvi, ice_var = "ICE_inc_quintile", group = "all")
dev.off()
png(paste0(output.folder, "models_result_", "q1_q5_ICE_rewb_linear.png"), 900, 460)
plot_q1_q5_categorical(model_list_ndvi, ice_var = "ICE_rewb_quintile", group = "all")
dev.off()

png(paste0(output.folder, "models_result_", "q1_q5_ICE_inc_linear_nyc.png"), 900, 460)
plot_q1_q5_categorical(model_list_ndvi, ice_var = "ICE_inc_quintile", group = "nyc")
dev.off()
png(paste0(output.folder, "models_result_", "q1_q5_ICE_rewb_linear_nyc.png"), 900, 460)
plot_q1_q5_categorical(model_list_ndvi, ice_var = "ICE_rewb_quintile", group = "nyc")
dev.off()

png(paste0(output.folder, "models_result_", "q1_q5_ICE_inc_linear_la.png"), 900, 460)
plot_q1_q5_categorical(model_list_ndvi, ice_var = "ICE_inc_quintile", group = "la")
dev.off()
png(paste0(output.folder, "models_result_", "q1_q5_ICE_rewb_linear_la.png"), 900, 460)
plot_q1_q5_categorical(model_list_ndvi, ice_var = "ICE_rewb_quintile", group = "la")
dev.off()

mdl <- model_list_ndvi$fit_all
dt_in <- dt[,c("GEOID")]
dt_in$orig_row_id <- seq_len(nrow(dt_in))
dt_res <- res_gen(dt_res = dt_in, mdl = mdl)
data_with_residuals_ndvi_all <- dplyr::left_join(dt_in, dt_res, by = "orig_row_id")%>%
  dplyr::select(-orig_row_id)

# nyc
mdl <- model_list_ndvi$fits_city$fit_city_nyc
dt_in <- dt[which(dt$city == "NYC"),c("GEOID")]
dt_in$orig_row_id <- seq_len(nrow(dt_in))
dt_res <- res_gen(dt_res = dt_in, mdl = mdl)
data_with_residuals_ndvi_nyc <- dplyr::left_join(dt_in, dt_res, by = "orig_row_id")%>%
  dplyr::select(-orig_row_id)

# la
mdl <- model_list_ndvi$fits_city$fit_city_la
dt_in <- dt[which(dt$city == "LA"),c("GEOID")]
dt_in$orig_row_id <- seq_len(nrow(dt_in))
dt_res <- res_gen(dt_res = dt_in, mdl = mdl)
data_with_residuals_ndvi_la <- dplyr::left_join(dt_in, dt_res, by = "orig_row_id") %>%
  dplyr::select(-orig_row_id)



sim <- "both cities"
dt_residuals <- data_with_residuals_ndvi_all

dt_residuals_sf_nyc_all <- dplyr::left_join(nyc_ses[,"GEOID"], dt_residuals[,c("GEOID","fitted", "residual")])
dt_residuals_sf_la_all <- dplyr::left_join(la_ses[,"GEOID"], dt_residuals[,c("GEOID", "fitted", "residual")])

png(paste0(output.folder, "models_result_", "residuals_main_both_cities_nyc.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_nyc_all,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "NYC GAM Residual Diagnostics - Both cities"
)
dev.off()
png(paste0(output.folder, "models_result_", "residuals_main_both_cities_la.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_la_all,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "LA GAM Residual Diagnostics - Both cities"
)
dev.off()
sim <- "nyc"
dt_residuals <- data_with_residuals_ndvi_nyc

dt_residuals_sf_nyc <- dplyr::left_join(nyc_ses[,"GEOID"], dt_residuals[,c("GEOID","fitted", "residual")])
png(paste0(output.folder, "models_result_", "residuals_stratified_nyc.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_nyc,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "NYC GAM Residual Diagnostics"
)
dev.off()
sim <- "la"
dt_residuals <- data_with_residuals_ndvi_la

dt_residuals_sf_la <- dplyr::left_join(la_ses[,"GEOID"], dt_residuals[,c("GEOID","fitted", "residual")])

png(paste0(output.folder, "models_result_", "residuals_stratified_la.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_la,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "Los Angeles GAM Residual Diagnostics"
)
dev.off()

dt$closest_greenspace[which(dt$closest_greenspace ==0)] <- 1
# greenspace distance models ------------------------------------------------
model_list_greenspace <- list(

  # City-level models
  fits_city     = fit_by(dt, by = "city", model_fun = model_gam_mixed_greenspace,family_type = "gamma",
                         include_city = FALSE),
  
  # City-level models
  fits_city_crude     = fit_by(dt, by = "city", model_fun = model_gam_mixed_greenspace,family_type = "gamma", crude = TRUE,
                               include_city = FALSE),
  
  # sens anal no outliers

  fits_outl_city     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "city", model_fun = model_gam_mixed_greenspace, family_type = "gamma",
                              include_city = FALSE)
  
  # # ICE quintile (categorical) models
  # fits_ice_quint = setNames(
  #   lapply(ice_quint_vars, function(v)
  #     fit_by(dt, by = v, model_fun = model_gam_mixed_greenspace, include_city = TRUE,family_type = "gamma")
  #   ),
  #   ice_quint_vars
  # ),
  # 
  # # ICE quintile (categorical) models
  # fits_ice_quint_nyc = setNames(
  #   lapply(ice_quint_vars, function(v)
  #     fit_by(dt[which(dt$city == "NYC"),], by = v, model_fun = model_gam_mixed_greenspace, include_city = FALSE,family_type = "gamma")
  #   ),
  #   ice_quint_vars
  # ),
  # 
  # # ICE quintile (categorical) models
  # fits_ice_quint_la = setNames(
  #   lapply(ice_quint_vars, function(v)
  #     fit_by(dt[which(dt$city == "LA"),], by = v, model_fun = model_gam_mixed_greenspace, include_city = FALSE,family_type = "gamma")
  #   ),
  #   ice_quint_vars
  # ),
  # 
  # # ICE continuous models with tensor interactions
  # fits_ice_cont = setNames(
  #   lapply(ice_cont_vars, function(v)
  #     fit_by(dt, by = "none", model_fun = model_gam_mixed_greenspace, include_city = TRUE, ice_cont = v,family_type = "gamma")
  #   ),
  #   ice_cont_vars
  # ),
  # 
  # # ICE continuous models with tensor interactions
  # fits_ice_cont_no_outl = setNames(
  #   lapply(ice_cont_vars, function(v)
  #     fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "none", model_fun = model_gam_mixed_greenspace, include_city = TRUE, ice_cont = v,family_type = "gamma")
  #   ),
  #   ice_cont_vars
  # ),
  # # # Q1 vs Q5 comparisons ---------------------------------------
  # # fits_q1_q5 = setNames(
  # #   lapply(ice_quint_vars, function(ice_var)
  # #     fit_q1_q5_models(
  # #       data          = dt,
  # #       ice_quint_var = ice_var,
  # #       model_fun     = model_gam_mixed_greenspace,
  # #       ice_cont_vars = ice_cont_vars,
  # #       family_type = "linear"
  # #     )
  # #   ),
  # #   paste0("q1_q5_", ice_quint_vars)
  # # ),
  # # 
  # # # Q1 vs Q5 comparisons ---------------------------------------
  # # fits_q1_q5_nyc = setNames(
  # #   lapply(ice_quint_vars, function(ice_var)
  # #     fit_q1_q5_models(
  # #       data          = dt[which(dt$city == "NYC"),],
  # #       ice_quint_var = ice_var,
  # #       model_fun     = model_gam_mixed_greenspace,
  # #       ice_cont_vars = ice_cont_vars,
  # #       family_type = "linear"
  # #     )
  # #   ),
  # #   paste0("q1_q5_", ice_quint_vars)
  # # ),
  # # 
  # # # Q1 vs Q5 comparisons ---------------------------------------
  # # fits_q1_q5_la = setNames(
  # #   lapply(ice_quint_vars, function(ice_var)
  # #     fit_q1_q5_models(
  # #       data          = dt[which(dt$city == "LA"),],
  # #       ice_quint_var = ice_var,
  # #       model_fun     = model_gam_mixed_greenspace,
  # #       ice_cont_vars = ice_cont_vars,
  # #       family_type = "linear"
  # #     )
  # #   ),
  # #   paste0("q1_q5_", ice_quint_vars)
  # # ),
  # # 
  # # City × ICE models
  # fits_city_ice = fit_city_ice(
  #   data          = dt,
  #   model_fun     = model_gam_mixed_greenspace,
  #   city_var      = "city",
  #   ice_vars      = ice_quint_vars,    # categorical ICE
  #   ice_cont_vars = ice_cont_vars,       # continuous ICE
  #   family_type = "linear"
  # )
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


plots_city_crude <- plot_smooth_gam(model_list_greenspace$fits_city_crude, y_limits = c(0, 2), rug = T)

png(paste0(output.folder, "models_result_", "greenspace_primary_crude_gamma.png"), 900, 460)
patchwork::wrap_plots(plots_city_crude)
dev.off()


plots_city <- plot_smooth_gam(model_list_greenspace$fits_city, y_limits = c(0, 2), rug = T)

png(paste0(output.folder, "models_result_", "greenspace_sensitivity_adjusted_gamma.png"), 900, 460)
patchwork::wrap_plots(plots_city)
dev.off()

plots_city_no_outl <- plot_smooth_gam(model_list_greenspace$fits_outl_city, y_limits = c(0, 2), rug = T)

png(paste0(output.folder, "models_result_", "greenspace_sensitivity_no_outliers_gamma.png"), 900, 460)
patchwork::wrap_plots(plots_city_no_outl)
dev.off()




# update
plots_ice_quint <- plot_smooth_gam(model_list_greenspace$fits_ice_quint, y_limits = c(0, 2500))
png(paste0(output.folder, "models_result_", "greenspace_close_effect_modif_ice_linear.png"), 900, 460)
patchwork::wrap_plots(plots_ice_quint[c(1,5,10,9)])
dev.off()

# Continuous ICE variable (tensor interaction)
plot_3d_green_dist_ice_inc <- plot_tensor3D_gam(
  gam_model = model_list_greenspace$fits_ice_cont$ICE_inc$fit_all,
  smooth_name = "te(community_severance_index,ICE_inc)",
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted closest greenspace (m)",
  title = "3D Tensor Smooth: Greenspace vs Severance & ICE_inc"
)

htmlwidgets::saveWidget(plot_3d_green_dist_ice_inc, paste0(output.folder, "plot_3d_ice_inc_csi_green_dist_linear.html")) 

# Continuous ICE variable (tensor interaction)
plot_3d_green_dist_ice_rewb <- plot_tensor3D_gam(
  gam_model = model_list_greenspace$fits_ice_cont$ICE_rewb$fit_all,
  smooth_name = "te(community_severance_index,ICE_rewb)",
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted closest greenspace (m)",
  title = "3D Tensor Smooth: Greenspace vs Severance & ICE_rewb"
)

htmlwidgets::saveWidget(plot_3d_green_dist_ice_rewb, paste0(output.folder, "plot_3d_ice_rewb_csi_green_dist_linear.html")) 


# Continuous ICE variable (tensor interaction)
plot_3d_green_dist_ice_inc_no_outl <- plot_tensor3D_gam(
  gam_model = model_list_greenspace$fits_ice_cont_no_outl$ICE_inc$fit_all,
  smooth_name = "te(community_severance_index,ICE_inc)",
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted closest greenspace (m)",
  title = "3D Tensor Smooth: Greenspace vs Severance & ICE_inc"
)

htmlwidgets::saveWidget(plot_3d_green_dist_ice_inc_no_outl, paste0(output.folder, "plot_3d_ice_inc_csi_green_dist_no_outl_linear.html")) 

# Continuous ICE variable (tensor interaction)
plot_3d_green_dist_ice_rewb_no_outl <- plot_tensor3D_gam(
  gam_model = model_list_greenspace$fits_ice_cont_no_outl$ICE_rewb$fit_all,
  smooth_name = "te(community_severance_index,ICE_rewb)",
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted closest greenspace (m)",
  title = "3D Tensor Smooth: Greenspace vs Severance & ICE_rewb"
)

htmlwidgets::saveWidget(plot_3d_green_dist_ice_rewb_no_outl, paste0(output.folder, "plot_3d_ice_rewb_csi_green_dist_no_outl_linear.html")) 


png(paste0(output.folder, "models_result_", "q1_q5_ICE_inc_green_dist_linear.png"), 900, 460)
plot_q1_q5_categorical(model_list_greenspace, ice_var = "ICE_inc_quintile", group = "all")
dev.off()
png(paste0(output.folder, "models_result_", "q1_q5_ICE_rewb_green_dist_linear.png"), 900, 460)
plot_q1_q5_categorical(model_list_greenspace, ice_var = "ICE_rewb_quintile", group = "all")
dev.off()

png(paste0(output.folder, "models_result_", "q1_q5_ICE_inc_green_dist_linear_nyc.png"), 900, 460)
plot_q1_q5_categorical(model_list_greenspace, ice_var = "ICE_inc_quintile", group = "nyc")
dev.off()
png(paste0(output.folder, "models_result_", "q1_q5_ICE_rewb_green_dist_linear_nyc.png"), 900, 460)
plot_q1_q5_categorical(model_list_greenspace, ice_var = "ICE_rewb_quintile", group = "nyc")
dev.off()

png(paste0(output.folder, "models_result_", "q1_q5_ICE_inc_green_dist_linear_la.png"), 900, 460)
plot_q1_q5_categorical(model_list_greenspace, ice_var = "ICE_inc_quintile", group = "la")
dev.off()
png(paste0(output.folder, "models_result_", "q1_q5_ICE_rewb_green_dist_linear_la.png"), 900, 460)
plot_q1_q5_categorical(model_list_greenspace, ice_var = "ICE_rewb_quintile", group = "la")
dev.off()


mdl <- model_list_greenspace$fit_all
dt_in <- dt[,c("GEOID")]
dt_in$orig_row_id <- seq_len(nrow(dt_in))
dt_res <- res_gen(dt_res = dt_in, mdl = mdl)
data_with_residuals_greenspace_all <- dplyr::left_join(dt_in, dt_res, by = "orig_row_id")%>%
  dplyr::select(-orig_row_id)

# nyc
mdl <- model_list_greenspace$fits_city$fit_city_nyc
dt_in <- dt[which(dt$city == "NYC"),c("GEOID")]
dt_in$orig_row_id <- seq_len(nrow(dt_in))
dt_res <- res_gen(dt_res = dt_in, mdl = mdl)
data_with_residuals_greenspace_nyc <- dplyr::left_join(dt_in, dt_res, by = "orig_row_id")%>%
  dplyr::select(-orig_row_id)

# la
mdl <- model_list_greenspace$fits_city$fit_city_la
dt_in <- dt[which(dt$city == "LA"),c("GEOID")]
dt_in$orig_row_id <- seq_len(nrow(dt_in))
dt_res <- res_gen(dt_res = dt_in, mdl = mdl)
data_with_residuals_greenspace_la <- dplyr::left_join(dt_in, dt_res, by = "orig_row_id") %>%
  dplyr::select(-orig_row_id)



sim <- "both cities"
dt_residuals <- data_with_residuals_greenspace_all

dt_residuals_sf_nyc_all <- dplyr::left_join(nyc_ses[,"GEOID"], dt_residuals[,c("GEOID","fitted", "residual")])
dt_residuals_sf_la_all <- dplyr::left_join(la_ses[,"GEOID"], dt_residuals[,c("GEOID", "fitted", "residual")])

png(paste0(output.folder, "models_result_", "residuals_main_both_cities_nyc_greenspace.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_nyc_all,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "NYC GAM Residual Diagnostics - Both cities"
)
dev.off()
png(paste0(output.folder, "models_result_", "residuals_main_both_cities_la_greenspace.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_la_all,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "LA GAM Residual Diagnostics - Both cities"
)
dev.off()

# nyc
mdl <- model_list_greenspace$fits_city$fit_city_nyc
dt_in <- dt[which(dt$city == "NYC"),c("GEOID")]
dt_in$orig_row_id <- seq_len(nrow(dt_in))
dt_res <- res_gen(dt_res = dt_in, mdl = mdl)
data_with_residuals_greenspace_nyc <- dplyr::left_join(dt_in, dt_res, by = "orig_row_id")%>%
  dplyr::select(-orig_row_id)

# la
mdl <- model_list_greenspace$fits_city$fit_city_la
dt_in <- dt[which(dt$city == "LA"),c("GEOID")]
dt_in$orig_row_id <- seq_len(nrow(dt_in))
dt_res <- res_gen(dt_res = dt_in, mdl = mdl)
data_with_residuals_greenspace_la <- dplyr::left_join(dt_in, dt_res, by = "orig_row_id") %>%
  dplyr::select(-orig_row_id)



sim <- "both cities"
dt_residuals <- data_with_residuals_greenspace_all

dt_residuals_sf_nyc_all <- dplyr::left_join(nyc_ses[,"GEOID"], dt_residuals[,c("GEOID","fitted", "residual")])
dt_residuals_sf_la_all <- dplyr::left_join(la_ses[,"GEOID"], dt_residuals[,c("GEOID", "fitted", "residual")])

png(paste0(output.folder, "models_result_", "residuals_greenspace_both_cities_nyc.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_nyc_all,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "NYC GAM Residual Diagnostics - Both cities"
)
dev.off()
png(paste0(output.folder, "models_result_", "residuals_greenspace_both_cities_la.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_la_all,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "LA GAM Residual Diagnostics - Both cities"
)
dev.off()
sim <- "nyc"
dt_residuals <- data_with_residuals_greenspace_nyc

dt_residuals_sf_nyc <- dplyr::left_join(nyc_ses[,"GEOID"], dt_residuals[,c("GEOID","fitted", "residual")])
png(paste0(output.folder, "models_result_", "greenspace_residuals_stratified_nyc.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_nyc,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "NYC GAM Residual Diagnostics"
)
dev.off()
sim <- "la"
dt_residuals <- data_with_residuals_ndvi_la

dt_residuals_sf_la <- dplyr::left_join(la_ses[,"GEOID"], dt_residuals[,c("GEOID","fitted", "residual")])

png(paste0(output.folder, "models_result_", "greenspace_residuals_stratified_la.png"), 900, 460)
plot_residual_diagnostics(
  dt_sf = dt_residuals_sf_la,
  resid_var = "residual",
  fitted_var = "fitted",
  k_neighbors = 5,
  title = "Los Angeles GAM Residual Diagnostics"
)
dev.off()


