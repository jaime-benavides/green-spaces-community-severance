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
la_csi$GEOID <- sub('.', '', la_csi$GEOID)

path_demography <- "/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/demography/us/"
neigh_nyc <- sf::st_read(paste0(path_demography, "nyc/uhf42_dohmh_2009/UHF_42_DOHMH_2009.shp"))
neigh_nyc <- sf::st_transform(neigh_nyc, crs)
neigh_la <- sf::st_read(paste0(path_demography,"urban/Community_Plan_Areas_la/Community_Plan_Areas.shp")) 
neigh_la <- sf::st_transform(neigh_la, crs)

# building density
nyc_build_dens <- readRDS(paste0(generated.data.folder, "building_dens_nyc.rds"))
la_build_dens <- readRDS(paste0(generated.data.folder, "building_dens_la.rds"))
la_build_dens$GEOID <- sub('.', '', la_build_dens$GEOID)
# ses
nyc_ses <- readRDS(paste0(generated.data.folder, "ses_ice_nyc.rds"))
la_ses <- readRDS(paste0(generated.data.folder, "ses_ice_la.rds"))
nyc_ses_df <- nyc_ses
sf::st_geometry(nyc_ses_df) <- NULL
nyc_ses_df <- nyc_ses_df[,c("GEOID", "ICE_inc",  "ICE_rewb", 
                            "perc.black", "perc.hisp", "perc.pov", "pop_dens")]
la_ses_df <- la_ses
sf::st_geometry(la_ses_df) <- NULL
la_ses_df <- la_ses_df[,c("GEOID",  "ICE_inc",  "ICE_rewb", 
                          "perc.black", "perc.hisp", "perc.pov", "pop_dens")]
la_ses_df$GEOID <- sub('.', '', la_ses_df$GEOID)
# green spaces
nyc_ndvi <- readRDS(paste0(generated.data.folder, "ndvi_nyc_census_tract.rds"))
nyc_ndvi <- sf::st_transform(nyc_ndvi, crs)
la_ndvi <- readRDS(paste0(generated.data.folder, "ndvi_la_census_tract.rds"))
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

# Assuming dt has columns: city, community_severance_index, lon, lat
city_csi_stats <- dt %>%
  #group_by(city) %>%
  summarise(
    mean_csi = mean(community_severance_index, na.rm = TRUE),
    sd_csi   = sd(community_severance_index, na.rm = TRUE),
    .groups = "drop"
  )

# Join back to original data to compute z-scores and flag outliers
dt <- dt %>%
  mutate(
    z_csi = (community_severance_index - city_csi_stats$mean_csi) / city_csi_stats$sd_csi,
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier (|z|>2)", "Within ±2 SD")
  )


dt <- dt |>
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
  )

# Convert all *_group variables to ordered factors
group_vars <- grep("_quintile$", names(dt), value = TRUE)

dt <- dt |>
  dplyr::mutate(
    dplyr::across(
      dplyr::all_of(group_vars),
      ~ factor(.x, levels = c("Q1 (Most Disadvantaged)", "Q2", "Q3", "Q4", "Q5 (Most Advantaged)"))
    )
  )

saveRDS(dt, paste0(generated.data.folder, "dt_nyc_and_la_quintiles_ses.rds"))

# neighborhoods as factors
dt$neighborhood <- as.factor(dt$neighborhood)
dt$city <- as.factor(dt$city)



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
  fit_all       = model_gam_mixed_ndvi(dt, by = "none"),
  
  # City-level models
  fits_city     = fit_by(dt, by = "city", model_fun = model_gam_mixed_ndvi),
  
  # sens anal no outliers
  fits_outl     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "none", model_fun = model_gam_mixed_ndvi),
  fits_outl_city     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "city", model_fun = model_gam_mixed_ndvi),
  # ICE quintile (categorical) models
  fits_ice_quint = setNames(
    lapply(ice_quint_vars, function(v)
      fit_by(dt, by = v, model_fun = model_gam_mixed_ndvi, include_city = TRUE)
    ),
    ice_quint_vars
  ),
  
  # ICE continuous models with tensor interactions
  fits_ice_cont = setNames(
    lapply(ice_cont_vars, function(v)
      fit_by(dt, by = "none", model_fun = model_gam_mixed_ndvi, include_city = TRUE, ice_cont = v)
    ),
    ice_cont_vars
  ),
  
  # ICE continuous models with tensor interactions
  fits_ice_cont_no_outl = setNames(
    lapply(ice_cont_vars, function(v)
      fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "none", model_fun = model_gam_mixed_ndvi, include_city = TRUE, ice_cont = v)
    ),
    ice_cont_vars
  ),
  
  # Q1 vs Q5 comparisons ---------------------------------------
  fits_q1_q5 = setNames(
    lapply(ice_quint_vars, function(ice_var)
      fit_q1_q5_models(
        data          = dt,
        ice_quint_var = ice_var,
        model_fun     = model_gam_mixed_ndvi,
        ice_cont_vars = ice_cont_vars
      )
    ),
    paste0("q1_q5_", ice_quint_vars)
  ),

  
  # City × ICE models
  fits_city_ice = fit_city_ice(
    data          = dt,
    model_fun     = model_gam_mixed_ndvi,
    city_var      = "city",
    ice_vars      = ice_quint_vars,    # categorical ICE
    ice_cont_vars = ice_cont_vars       # continuous ICE
  )
)


# --- Example usage ---
summary(model_list_ndvi$fit_all)
plot(model_list_ndvi$fit_all, select = 1, shade = TRUE)
gam.check(model_list_ndvi$fit_all)



# generate plots
png(paste0(output.folder, "models_result_", "ndvi_main.png"), 900, 460)
plot_smooth_gam(model_list_ndvi$fit_all, y_limits = c(0, .6), rug = TRUE)
dev.off()

# generate plots
png(paste0(output.folder, "models_result_", "ndvi_ses_outl.png"), 900, 460)
plot_smooth_gam(model_list_ndvi$fits_outl, y_limits = c(0, .6), rug = TRUE)
dev.off()

appraise(model_list_ndvi$fit_all)
draw(model_list_ndvi$fit_all, residuals = TRUE)


plots_city <- plot_smooth_gam(model_list_ndvi$fits_city, y_limits = c(0, .6), rug = T)

png(paste0(output.folder, "models_result_", "ndvi_effect_modif_cities.png"), 900, 460)
patchwork::wrap_plots(plots_city)
dev.off()

plots_city_no_outl <- plot_smooth_gam(model_list_ndvi$fits_outl_city, y_limits = c(0, .6), rug = T)

png(paste0(output.folder, "models_result_", "ndvi_effect_modif_cities_no_outl.png"), 900, 460)
patchwork::wrap_plots(plots_city_no_outl)
dev.off()

plots_ice_quint <- plot_smooth_gam(model_list_ndvi$fits_ice_quint, y_limits = c(0, .6))
png(paste0(output.folder, "models_result_", "ndvi_effect_modif_ice.png"), 900, 460)
patchwork::wrap_plots(plots_ice_quint)
dev.off()



plot_3d_ice_inc <- plot_tensor3D_gam(
  gam_model = model_list_ndvi$fits_ice_cont$ICE_inc$fit_all,
  smooth_name = "te(community_severance_index,ICE_inc)",
  n = 50,
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted NDVI"
)

htmlwidgets::saveWidget(plot_3d_ice_inc, paste0(output.folder, "plot_3d_ice_inc_csi_ndvi.html")) 


plot_3d_ice_rewb <- plot_tensor3D_gam(
  gam_model = model_list_ndvi$fits_ice_cont$ICE_rewb$fit_all,
  smooth_name = "te(community_severance_index,ICE_rewb)",
  n = 50,
  xlab = "Community Severance Index",
  ylab = "ICE_rewb",
  zlab = "Predicted NDVI"
)

htmlwidgets::saveWidget(plot_3d_ice_rewb, paste0(output.folder, "plot_3d_ice_rewb_csi_ndvi.html")) 



plot_3d_ice_inc_no_outl <- plot_tensor3D_gam(
  gam_model = model_list_ndvi$fits_ice_cont_no_outl$ICE_inc$fit_all,
  smooth_name = "te(community_severance_index,ICE_inc)",
  n = 50,
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted NDVI"
)

htmlwidgets::saveWidget(plot_3d_ice_inc_no_outl, paste0(output.folder, "plot_3d_ice_inc_csi_ndvi_no_outl.html")) 


plot_3d_ice_rewb_no_outl <- plot_tensor3D_gam(
  gam_model = model_list_ndvi$fits_ice_cont_no_outl$ICE_rewb$fit_all,
  smooth_name = "te(community_severance_index,ICE_rewb)",
  n = 50,
  xlab = "Community Severance Index",
  ylab = "ICE_rewb",
  zlab = "Predicted NDVI"
)

htmlwidgets::saveWidget(plot_3d_ice_rewb_no_outl, paste0(output.folder, "plot_3d_ice_rewb_csi_ndvi_no_outl.html")) 



plots_city_ice <- plot_smooth_gam(model_list_ndvi$fits_city_ice, y_limits = c(0, .6))
png(paste0(output.folder, "models_result_", "ndvi_effect_modif_city_ice.png"), 900, 460)
patchwork::wrap_plots(plots_city_ice)
dev.off()


png(paste0(output.folder, "models_result_", "q1_q5_ICE_inc.png"), 900, 460)
plot_q1_q5_categorical(model_list_ndvi, ice_var = "ICE_inc_quintile")
dev.off()
png(paste0(output.folder, "models_result_", "q1_q5_ICE_rewb.png"), 900, 460)
plot_q1_q5_categorical(model_list_ndvi, ice_var = "ICE_rewb_quintile")
dev.off()

dt$closest_greenspace[which(dt$closest_greenspace ==0)] <- 1
# greenspace distance models ------------------------------------------------
model_list_greenspace <- list(
  # Global model
  fit_all       = model_gam_mixed_greenspace(dt, by = "none"),
  
  # City-level models
  fits_city     = fit_by(dt, by = "city", model_fun = model_gam_mixed_greenspace),
  
  # sens anal no outliers
  fits_outl     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "none", model_fun = model_gam_mixed_greenspace),
  fits_outl_city     = fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "city", model_fun = model_gam_mixed_greenspace),
  
  # ICE quintile (categorical) models
  fits_ice_quint = setNames(
    lapply(ice_quint_vars, function(v)
      fit_by(dt, by = v, model_fun = model_gam_mixed_greenspace, include_city = TRUE)
    ),
    ice_quint_vars
  ),
  
  # ICE continuous models with tensor interactions
  fits_ice_cont = setNames(
    lapply(ice_cont_vars, function(v)
      fit_by(dt, by = "none", model_fun = model_gam_mixed_greenspace, include_city = TRUE, ice_cont = v)
    ),
    ice_cont_vars
  ),
  
  # ICE continuous models with tensor interactions
  fits_ice_cont_no_outl = setNames(
    lapply(ice_cont_vars, function(v)
      fit_by(dt[which(dt$outlier_flag != "Outlier (|z|>2)"), ], by = "none", model_fun = model_gam_mixed_greenspace, include_city = TRUE, ice_cont = v)
    ),
    ice_cont_vars
  ),
  # Q1 vs Q5 comparisons ---------------------------------------
  fits_q1_q5 = setNames(
    lapply(ice_quint_vars, function(ice_var)
      fit_q1_q5_models(
        data          = dt,
        ice_quint_var = ice_var,
        model_fun     = model_gam_mixed_greenspace,
        ice_cont_vars = ice_cont_vars
      )
    ),
    paste0("q1_q5_", ice_quint_vars)
  ),
  
  # City × ICE models
  fits_city_ice = fit_city_ice(
    data          = dt,
    model_fun     = model_gam_mixed_greenspace,
    city_var      = "city",
    ice_vars      = ice_quint_vars,    # categorical ICE
    ice_cont_vars = ice_cont_vars       # continuous ICE
  )
)


# generate plots

summary(model_list_greenspace$fit_all)
plot(model_list_greenspace$fit_all, select = 1, shade = TRUE)
gam.check(model_list_greenspace$fit_all)


png(paste0(output.folder, "models_result_", "greenspace_close_main.png"), 900, 460)
plot_smooth_gam(model_list_greenspace$fit_all, y_limits = c(0, 2000), rug = TRUE)
dev.off()

png(paste0(output.folder, "models_result_", "greenspace_dist_ses_outl.png"), 900, 460)
plot_smooth_gam(model_list_greenspace$fits_outl, y_limits = c(0, 2000), rug = TRUE)
dev.off()

appraise(model_list_greenspace$fit_all)
draw(model_list_greenspace$fit_all, residuals = TRUE)


plots_city <- plot_smooth_gam(model_list_greenspace$fits_city, y_limits = c(0, 2500), rug = T)

png(paste0(output.folder, "models_result_", "greenspace_close_effect_modif_cities.png"), 900, 460)
patchwork::wrap_plots(plots_city)
dev.off()

plots_city_no_outl <- plot_smooth_gam(model_list_greenspace$fits_outl_city, y_limits = c(0, 2500), rug = T)

png(paste0(output.folder, "models_result_", "greenspace_close_effect_modif_cities_no_outl.png"), 900, 460)
patchwork::wrap_plots(plots_city_no_outl)
dev.off()

# update
plots_ice_quint <- plot_smooth_gam(model_list_greenspace$fits_ice_quint, y_limits = c(0, 2500))
png(paste0(output.folder, "models_result_", "greenspace_close_effect_modif_ice.png"), 900, 460)
patchwork::wrap_plots(plots_ice_quint)
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

htmlwidgets::saveWidget(plot_3d_green_dist_ice_inc, paste0(output.folder, "plot_3d_ice_inc_csi_green_dist.html")) 

# Continuous ICE variable (tensor interaction)
plot_3d_green_dist_ice_rewb <- plot_tensor3D_gam(
  gam_model = model_list_greenspace$fits_ice_cont$ICE_rewb$fit_all,
  smooth_name = "te(community_severance_index,ICE_rewb)",
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted closest greenspace (m)",
  title = "3D Tensor Smooth: Greenspace vs Severance & ICE_rewb"
)

htmlwidgets::saveWidget(plot_3d_green_dist_ice_rewb, paste0(output.folder, "plot_3d_ice_rewb_csi_green_dist.html")) 


# Continuous ICE variable (tensor interaction)
plot_3d_green_dist_ice_inc_no_outl <- plot_tensor3D_gam(
  gam_model = model_list_greenspace$fits_ice_cont_no_outl$ICE_inc$fit_all,
  smooth_name = "te(community_severance_index,ICE_inc)",
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted closest greenspace (m)",
  title = "3D Tensor Smooth: Greenspace vs Severance & ICE_inc"
)

htmlwidgets::saveWidget(plot_3d_green_dist_ice_inc_no_outl, paste0(output.folder, "plot_3d_ice_inc_csi_green_dist_no_outl.html")) 

# Continuous ICE variable (tensor interaction)
plot_3d_green_dist_ice_rewb_no_outl <- plot_tensor3D_gam(
  gam_model = model_list_greenspace$fits_ice_cont_no_outl$ICE_rewb$fit_all,
  smooth_name = "te(community_severance_index,ICE_rewb)",
  xlab = "Community Severance Index",
  ylab = "ICE_inc",
  zlab = "Predicted closest greenspace (m)",
  title = "3D Tensor Smooth: Greenspace vs Severance & ICE_rewb"
)

htmlwidgets::saveWidget(plot_3d_green_dist_ice_rewb_no_outl, paste0(output.folder, "plot_3d_ice_rewb_csi_green_dist_no_outl.html")) 




plots_city_ice <- plot_smooth_gam(model_list_greenspace$fits_city_ice, y_limits = c(0, 2500))
png(paste0(output.folder, "models_result_", "greenspace_close_effect_modif_city_ice.png"), 900, 460)
patchwork::wrap_plots(plots_city_ice)
dev.off()


png(paste0(output.folder, "models_result_", "q1_q5_ICE_inc_green_dist.png"), 900, 460)
plot_q1_q5_categorical(model_list_greenspace, ice_var = "ICE_inc_quintile")
dev.off()
png(paste0(output.folder, "models_result_", "q1_q5_ICE_rewb_green_dist.png"), 900, 460)
plot_q1_q5_categorical(model_list_greenspace, ice_var = "ICE_rewb_quintile")
dev.off()

