rm(list = ls())

# 02_prep_csi.R
# Purpose: Population-weighted Community Severance Index (CSI) aggregation
#          from block group to census tract.
project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

# ---------------------------
# Libraries
# ---------------------------
library(ndi)
library(tidycensus)
library(dplyr)
library(sf)
library(tigris)
library(tmap)
library(GGally)
library(purrr)
library(readr)
library(tmap)

# ---------------------------
# Setup
# ---------------------------
set.seed(36)
year <- 2019
geo <- "tract"   # krieger() supports 'tract' and 'county' (not 'block group')

# CDC 500 Cities city boundaries — see README.md "Data" > "demography" for download link
city_boundaries_path <- paste0(raw.data.folder, "demography/500Cities_City_11082016/")
city_boundaries <- sf::read_sf(paste0(city_boundaries_path, "CityBoundaries.shp")) %>%
  sf::st_transform(crs)

spatial_context <- city_boundaries[which(city_boundaries$NAME == "Los Angeles"   |  city_boundaries$NAME == "New York"),]

dta_csi_la_cbg <- readRDS(paste0(raw.data.folder, "csi/csi_scores_la.rds"))
colnames(dta_csi_la_cbg)[which(colnames(dta_csi_la_cbg) == "MR1")] <- "community_severance_index"
file_name_nyc <- "csi_scores_nyc.rds"
dta_csi_nyc_cbg <- readRDS(paste0(raw.data.folder, "csi/csi_scores_nyc.rds"))
colnames(dta_csi_nyc_cbg)[which(colnames(dta_csi_nyc_cbg) == "MR1")] <- "community_severance_index"
# EPA Smart Location Database — see README.md "Data" > "demography" for download link
sld_us <- sf::read_sf(paste0(raw.data.folder, "demography/SmartLocationDatabaseV3/SmartLocationDatabase.gdb"))
sld_us_loc <- sld_us
sf::st_geometry(sld_us_loc) <- NULL
sld_us_loc_nyc <- sld_us_loc[which(sld_us_loc$GEOID20 %in% unique(dta_csi_nyc_cbg$GEOID20)),]
sld_us_loc_la <- sld_us_loc[which(sld_us_loc$GEOID20 %in% unique(dta_csi_la_cbg$GEOID20)),]

sld_us_sf_nyc <- sld_us[which(sld_us$GEOID20 %in% unique(dta_csi_nyc_cbg$GEOID20)),]
sld_us_sf_la <- sld_us[which(sld_us$GEOID20 %in% unique(dta_csi_la_cbg$GEOID20)),]


png(
  filename = paste0(output.folder, "la", "_","distrib_scores.png"),
  width = 8, height = 7, units = "in", res = 300
)
ggplot(data = dta_csi_la_cbg) +
  geom_histogram(mapping = aes(x = community_severance_index), binwidth = 0.5)
dev.off()
png(
  filename = paste0(output.folder, "nyc", "_","distrib_scores.png"),
  width = 8, height = 7, units = "in", res = 300
)
ggplot(data = dta_csi_nyc_cbg) +
  geom_histogram(mapping = aes(x = community_severance_index), binwidth = 0.5)
dev.off()

dta_csi_nyc_cbg$city <- "nyc"
dta_csi_la_cbg$city <- "la"
scores <- rbind(dta_csi_nyc_cbg, dta_csi_la_cbg)


png(
  filename = paste0(output.folder, "nyc_la_", "_","distrib_scores_raw.png"),
  width = 8, height = 7, units = "in", res = 300
)
ggplot(data = scores, mapping = aes(x = city, y = community_severance_index)) +
  geom_boxplot()
dev.off()



# combine population and community severance index
dta_csi_nyc_cbg <- dplyr::left_join(sld_us_sf_nyc[,c("GEOID20", "TotPop")], dta_csi_nyc_cbg[,c("GEOID20","community_severance_index")])
dta_csi_la_cbg <- dplyr::left_join(sld_us_sf_la[,c("GEOID20", "TotPop")], dta_csi_la_cbg[,c("GEOID20","community_severance_index")])


dta_csi_la_cbg <- dta_csi_la_cbg[-which(dta_csi_la_cbg$TotPop ==0),]
dta_csi_nyc_cbg <- dta_csi_nyc_cbg[-which(dta_csi_nyc_cbg$TotPop ==0),]

# get census tracts from ice data
nyc_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds"))
la_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))

dta_csi_nyc_cbg <- sf::st_transform(dta_csi_nyc_cbg, 2163)
nyc_ice <- sf::st_transform(nyc_ice, 2163)

# interpolate from census block group to zip codes using population weights
dta_nyc <- tidycensus::interpolate_pw(from = dta_csi_nyc_cbg,
                                       to = nyc_ice,
                                       to_id = "GEOID",
                                       extensive = FALSE,
                                       weights = dta_csi_nyc_cbg,
                                       weight_column = "TotPop",
                                       weight_placement = "surface",
                                       crs = 2163)
dta_nyc_df <- dta_nyc
sf::st_geometry(dta_nyc_df) <- NULL

dta_csi_la_cbg <- sf::st_transform(dta_csi_la_cbg, 2163)
la_ice <- sf::st_transform(la_ice, 2163)

dta_la <- tidycensus::interpolate_pw(from = dta_csi_la_cbg,
                                      to = la_ice,
                                      to_id = "GEOID",
                                      extensive = FALSE,
                                      weights = dta_csi_la_cbg,
                                      weight_column = "TotPop",
                                      weight_placement = "surface",
                                      crs = 2163)
dta_la_df <- dta_la
sf::st_geometry(dta_la_df) <- NULL


dta_nyc <- dplyr::left_join(nyc_ice, dta_nyc_df)
dta_la <- dplyr::left_join(la_ice, dta_la_df)

saveRDS(dta_nyc_df, paste0(generated.data.folder, "community_severance_nyc_census_tract.rds"))
saveRDS(dta_la_df, paste0(generated.data.folder, "community_severance_la_census_tract.rds"))
nyc_csi <- readRDS(paste0(generated.data.folder, "community_severance_nyc_census_tract.rds"))
la_csi <- readRDS(paste0(generated.data.folder, "community_severance_la_census_tract.rds"))
la_csi$GEOID <- sub('.', '', la_csi$GEOID)

tmap_mode("plot")
vars <- "community_severance_index"

cities <- c("NYC", "LA")
for (city in cities) {
  if(city == "NYC"){
    dta_sf <- dta_nyc
  } else if (city == "LA") {
    dta_sf <- dta_la
  } else {
    print("city not available")
  }
  for (v in vars) {
    if (!v %in% names(dta_sf)) next
    tm <- tm_shape(dta_sf) +
      tm_polygons(
        fill = v,
        fill.scale = tm_scale_continuous(
          values = "Spectral",
          midpoint = 0
        ),
        fill.legend = tm_legend(title = v)
      ) +
      tm_title(paste0(city, " – ", v)) +
      tm_layout(legend.outside = TRUE)
    #save map
    png(
      filename = paste0(output.folder, city, "_", v, "_map.png"),
      width = 8, height = 7, units = "in", res = 300
    )
    print(tm)
    dev.off()
  }
}

# where are the potential outliers of csi
la_csi$city <- "LA"
nyc_csi$city <- "NYC"
dt <- rbind(la_csi, nyc_csi)
# Assuming dt has columns: city, community_severance_index, lon, lat
city_csi_stats <- dt %>%
  group_by(city) %>%
  summarise(
    mean_csi = mean(community_severance_index, na.rm = TRUE),
    sd_csi   = sd(community_severance_index, na.rm = TRUE),
    .groups = "drop"
  )

# Join back to original data to compute z-scores and flag outliers
dt_filtered <- dt %>%
  left_join(city_csi_stats, by = "city") %>%
  mutate(
    z_csi = (community_severance_index - mean_csi) / sd_csi,
    outlier_flag = ifelse(abs(z_csi) > 2, "Outlier (|z|>2)", "Within ±2 SD")
  )

nyc_csi_outl <- dt_filtered %>% filter(city == "NYC")
la_csi_outl   <- dt_filtered %>% filter(city == "LA")


library(ggplot2)

# Color-blind–friendly palette for map points
outlier_palette <- c("Within ±2 SD" = "#0072B2", "Outlier (|z|>2)" = "#D55E00")

sld_us_sf_nyc <- nyc_ice[which(nyc_ice$GEOID %in% unique(nyc_csi$GEOID)),]
sld_us_sf_la <- sld_us[which(la_ice$GEOID %in% unique(la_csi$GEOID)),]

nyc_dt <- dplyr::left_join(nyc_ice[,"GEOID"], nyc_csi_outl[,c("GEOID", "community_severance_index", "outlier_flag")])
la_ice$GEOID <- sub('.', '', la_ice$GEOID)
la_dt <- dplyr::left_join(la_ice[,"GEOID"], la_csi_outl[,c("GEOID", "community_severance_index", "outlier_flag")])


# lets add roads

# ORNL Freight Analysis Framework (FAF5) road network — see README.md "Data" > "geometry" for download link
faf5_network <- sf::read_sf(paste0(raw.data.folder, "geometry/FAF5Network.gdb"))
faf5_highways <- faf5_network[which(faf5_network$F_Class %in% c(1,2,3)),]
faf5_highways <- faf5_highways %>%
  sf::st_transform(crs)



# intersect with spatial context
roads_contxt_id_fhwa <- sapply(sf::st_intersects(faf5_highways, spatial_context),function(x){length(x)>0})
roads_contxt_fhwa <- faf5_highways[roads_contxt_id_fhwa, ]
roads_contxt_fhwa <- sf::st_make_valid(roads_contxt_fhwa)

tmap_mode("view")
road_color <- "#595959"

nyc_dt$city <- "NYC"
la_dt$city <- "LA"

dt <- rbind(nyc_dt, la_dt)

tmap_mode("plot")  # or "view" for interactive mode

png(paste0(output.folder, "csi_outliers_nyc.png"), 900, 460)
nyc_map_outl <- tm_shape(nyc_dt) +
  tm_basemap("CartoDB.Positron") +  # clean, minimal base map
  
  # polygons go first
  tm_polygons(
    col = "outlier_flag",
    palette = outlier_palette,
    alpha = 0.6,
    border.col = NA,
    title = "CSI Status"
  ) +
  
  # roads on top
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col = road_color, lwd = 0.8, alpha = 1.0) +
  
  tm_layout(
    title = "Community Severance Index (±2 SD) — NYC",
    legend.position = c("right", "bottom"),
    frame = FALSE,
    bg.color = "white",
    title.size = 1.2
  )
dev.off()


png(paste0(output.folder, "csi_outliers_la.png"), 900, 460)
la_map_outl <- tm_shape(la_dt) +
  tm_basemap("CartoDB.Positron") +  # clean, minimal base map
  
  # polygons go first
  tm_polygons(
    col = "outlier_flag",
    palette = outlier_palette,
    alpha = 0.6,
    border.col = NA,
    title = "CSI Status"
  ) +
  
  # roads on top
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col = road_color, lwd = 0.8, alpha = 1.0) +
  
  tm_layout(
    title = "Community Severance Index (±2 SD) — la",
    legend.position = c("right", "bottom"),
    frame = FALSE,
    bg.color = "white",
    title.size = 1.2
  )
la_map_outl
dev.off()
tmap_mode("view")

tmap_save(
  tm = la_map_outl,
  filename = paste0(output.folder, "la_csi_outliers.html"),
  width = 1200,  # optional, in pixels
  height = 900   # optional
)

tmap_save(
  tm = nyc_map_outl,
  filename = paste0(output.folder, "nyc_csi_outliers.html"),
  width = 1200,  # optional, in pixels
  height = 900   # optional
)
