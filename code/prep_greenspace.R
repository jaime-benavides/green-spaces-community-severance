################################################################################
# ICE Index (Krieger et al., Feldman et al.) – NYC & LA Block Groups
# Using ndi::krieger() from the NDI package
################################################################################

rm(list = ls())
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
library(units)

# ---------------------------
# Setup
# ---------------------------
set.seed(36)
year <- 2019
geo <- "tract"   # krieger() supports 'tract' and 'county' (not 'block group')
crs <- 2163
# 🔑 Your Census API key (must be set once)
# census_api_key("YOUR_API_KEY", install = TRUE)
dta_path <- "/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/green_infrastructure/"
dta_demographic_path <- "/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/demography/"
file_name <- "NDVI_US_MajorCities_Tracts_2000_2010_2019.csv"
dta_green_spaces <- readr::read_csv(paste0(dta_path, file_name))
dta_green_spaces <- dta_green_spaces[,c("CBSA_GEOID","GEOID19", "POP2019", "NDVI2019")]
colnames(dta_green_spaces)[2:4] <- c("GEOID", "population", "NDVI")
dta_green_spaces$GEOID <- as.character(dta_green_spaces$GEOID)
# limit to LA and NYC

nyc_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds"))
la_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))
la_ice$GEOID <- sub('.', '', la_ice$GEOID)
dta_ice <- rbind(nyc_ice, la_ice)
dta <- dplyr::left_join(dta_ice, dta_green_spaces)
dta_nyc <- dplyr::left_join(nyc_ice, dta_green_spaces)
dta_la <- dplyr::left_join(la_ice, dta_green_spaces)

dta_nyc_green_spaces <- dta_nyc[,c("GEOID", "population", "NDVI")]
dta_la_green_spaces <- dta_la[,c("GEOID", "population", "NDVI")]

sf::st_geometry(dta_nyc_green_spaces) <- NULL
sf::st_geometry(dta_la_green_spaces) <- NULL

saveRDS(dta_nyc_green_spaces, paste0(generated.data.folder, "ndvi_nyc_census_tract.rds"))
saveRDS(dta_la_green_spaces, paste0(generated.data.folder, "ndvi_la_census_tract.rds"))

# pad-us ar
padus_ar <- sf::read_sf(paste0(dta_path, "padus_ar.shp")) %>%
  sf::st_transform(crs)
city_boundaries_path <- "/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/demography/us/urban/500Cities_City_11082016/"
city_boundaries <- sf::read_sf(paste0(city_boundaries_path, "CityBoundaries.shp")) %>%
  sf::st_transform(crs)
city_boundary_nyc_raw <- city_boundaries[which(city_boundaries$NAME == "New York"),] %>%
  sf::st_transform(crs)
city_boundary_nyc <- city_boundary_nyc_raw %>%
  sf::st_buffer(dist = 10000)
nyc_ids <- sapply(sf::st_intersects(padus_ar, city_boundary_nyc),function(x){length(x)>0})
padus_ar_nyc <- padus_ar[nyc_ids, ]

nyc_only_ids <- sapply(sf::st_intersects(padus_ar, city_boundary_nyc_raw),function(x){length(x)>0})
padus_ar_nyc_only <- padus_ar[nyc_only_ids, ]

# check for nyc how much of the green space is water body
water_bodies_nyc <- sf::st_read('/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/geom/NYC_Planimetrics_2022.gdb', layer = "Hydrography") %>%
sf::st_transform(crs)

water_within_padus <- sf::st_intersection(
  padus_ar_nyc_only,
  water_bodies_nyc
)

# in the case of nyc mental health community severance, only important in zip codes
acs.dt <- readRDS('/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/workspace/community_severance_nys_climate_change_mh/data/generated/acs_dt.rds')
acs.wide <- spread(acs.dt[,1:4], variable, estimate)  
names(acs.wide)[3:6] <- c("popn", "black", "hisp", "pov") 
# estimate percentages
acs.wide$perc.black <- acs.wide$black/acs.wide$popn    
acs.wide$perc.hisp  <- acs.wide$hisp/acs.wide$popn    
acs.wide$perc.pov   <- acs.wide$pov/acs.wide$popn    
# transform coordinate reference system
acs.wide <- acs.wide %>%
  sf::st_transform(crs)

# estimate population density
area_km2 <- as.numeric(sf::st_area(acs.wide) / (1000*1000))
acs.wide$pop_dens <- acs.wide$popn/area_km2


# filter ZIP codes located within NYC only
acs.nyc <- acs.wide[as.numeric(sf::st_intersects(city_boundary_nyc_raw, sf::st_centroid(acs.wide))[[1]]),]
acs.nyc <- sf::st_make_valid(acs.nyc)
acs.nyc <- acs.nyc[-which(acs.nyc$popn ==0),]
acs.nyc <- acs.nyc[-which(acs.nyc$popn ==1),]
# get rid of airport zip code at JFK airport
acs.nyc <- acs.nyc[-which(acs.nyc$GEOID == 11430),]

acs_union <- sf::st_union(acs.nyc)

padus_in_zip <- sf::st_intersection(
  padus_ar_nyc_only,
  acs_union
)

# ============================================================
# Restrict water bodies to PADUS within those ZIP code areas
# ============================================================
water_in_padus_zip <- sf::st_intersection(
  water_bodies_nyc,
  padus_in_zip
)

# ============================================================
# Compute areas
# ============================================================
padus_zip_area <- sum(sf::st_area(padus_in_zip))
water_padus_zip_area <- sum(sf::st_area(water_in_padus_zip))

# ============================================================
# Fraction and percent of PADUS area that is water,
# within the relevant ZIP code areas
# ============================================================
water_fraction <- water_padus_zip_area / padus_zip_area
water_percent <- as.numeric(water_fraction) * 100


city_boundary_la_raw <- city_boundaries[which(city_boundaries$NAME == "Los Angeles"),] %>%
  sf::st_transform(crs)
city_boundary_la <- city_boundary_la_raw %>%
  sf::st_buffer(dist = 10000)
la_ids <- sapply(sf::st_intersects(padus_ar, city_boundary_la),function(x){length(x)>0})
padus_ar_la <- padus_ar[la_ids, ]


# Income: 80th income percentile vs. 20th income percentile
# Education: less than high school vs. four-year college degree or more
# Race or Ethnicity: white non-Hispanic vs. black non-Hispanic
# Income and race or ethnicity combined: white non-Hispanic in 80th income percentile vs.
# black alone (including Hispanic) in 20th income percentile
# Income and race or ethnicity combined: white non-Hispanic in 80th income percentile vs.
# white non-Hispanic in 20th income percentile
vars <- c("ICE_inc", "ICE_edu", "ICE_wbinc", "ICE_wpcinc", "NDVI")
var_names <- c("ice_income", "ice_education", "ice_race_or_ethnicity", "ice_income_and_race_or_ethnicity_white", "NDVI")
vars <- vars[vars %in% names(dta)]
df <- dta
sf::st_geometry(df) <- NULL
city <- "NYC and LA"

png(paste0(output.folder, city, "_krieger_pairs_and_green_space.png"), width = 1000, height = 900)
GGally::ggpairs(df[, vars], columnLabels = var_names,
                title = paste(city, "– Krieger ICE Indices & green space"))
dev.off()

# todo: check for each city


tmap_mode("plot")
vars <- "NDVI"

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

dta_nyc_green_spaces <- readRDS(paste0(generated.data.folder, "ndvi_nyc_census_tract.rds"))
dta_la_green_spaces <- readRDS(paste0(generated.data.folder, "ndvi_la_census_tract.rds"))


# Choose a local projected CRS in meters (for NYC)
crs_nyc <- 2263  # NAD83 / New York Long Island (meters)

# Transform everything consistently
dta_nyc_green_spaces <- sf::st_transform(dta_nyc_green_spaces, crs)
padus_ar_nyc <- sf::st_transform(padus_ar_nyc, crs)

sf::st_crs(dta_nyc_green_spaces)
sf::st_crs(padus_ar_nyc)
sf::st_crs(edges_nyc_sf)


faf5_network <- sf::read_sf(paste0("/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/workspace/community_severance_us/data/raw/", "geometry/FAF5Network.gdb"))
faf5_highways <- faf5_network[which(faf5_network$F_Class %in% c(1,2,3)),]
faf5_highways <- faf5_highways %>%
  sf::st_transform(crs)

city_boundaries_path <- "/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/demography/us/urban/500Cities_City_11082016/"
city_boundaries <- sf::read_sf(paste0(city_boundaries_path, "CityBoundaries.shp")) %>%
  sf::st_transform(crs)

spatial_context <- city_boundaries[which(city_boundaries$NAME == "Los Angeles"   |  city_boundaries$NAME == "New York"),]


# intersect with spatial context
roads_contxt_id_fhwa <- sapply(sf::st_intersects(faf5_highways, spatial_context),function(x){length(x)>0})
roads_contxt_fhwa <- faf5_highways[roads_contxt_id_fhwa, ]
roads_contxt_fhwa <- sf::st_make_valid(roads_contxt_fhwa)

map <- mapview::mapview(padus_ar_la) + padus_ar_nyc + roads_contxt_fhwa

# read census tracts population weighted centroids
california_pop_centers_df <- readr::read_delim(paste0(dta_demographic_path, "us/census_tracts/CenPop2020_Mean_TR06.txt"
                        ))
new_york_pop_centers_df <- readr::read_delim(paste0(dta_demographic_path, "us/census_tracts/CenPop2020_Mean_TR36.txt"
))
california_pop_centers_sf = sf::st_as_sf(california_pop_centers_df, coords = c("LONGITUDE", "LATITUDE"), 
                 crs = 4326) %>%
  sf::st_transform(crs)
new_york_pop_centers_sf = sf::st_as_sf(new_york_pop_centers_df, coords = c("LONGITUDE", "LATITUDE"), 
                                         crs = 4326) %>%
  sf::st_transform(crs)
# join with geoids
california_pop_centers_sf$GEOID <- tidyr::unite(california_pop_centers_df[,c("STATEFP", "COUNTYFP", "TRACTCE")], col = "GEOID", sep='')
new_york_pop_centers_sf$GEOID <- tidyr::unite(new_york_pop_centers_df[,c("STATEFP", "COUNTYFP", "TRACTCE")], col = "GEOID", sep='')

dta_nyc_green_spaces_df <- dta_nyc_green_spaces
sf::st_geometry(dta_nyc_green_spaces_df) <- NULL

#geoids <- as.data.frame(new_york_pop_centers_sf$GEOID)

#nyc_pop_centers_sf <- new_york_pop_centers_sf[which(geoids$GEOID %in% dta_nyc_green_spaces_df$GEOID),]

cs_access_euclidean_nyc <- euclidean_to_edge(areal_units = dta_nyc_green_spaces,
  address_location = new_york_pop_centers_sf,
  greenspace = padus_ar_nyc,
  buffer_distance = 804.672, 
  projected_crs = crs,
  minimum_greenspace_size = 400
)

# todo california and la

# checks visual ok
saveRDS(cs_access_euclidean_nyc, paste0(generated.data.folder, "cs_access_euclidean_nyc.rds"))


dta_la_green_spaces_df <- dta_la_green_spaces
sf::st_geometry(dta_la_green_spaces_df) <- NULL

geoids <- as.data.frame(california_pop_centers_sf$GEOID)
geoids$GEOID <- sub('.', '', geoids$GEOID)


cs_access_euclidean_la <- euclidean_to_edge(areal_units = dta_la_green_spaces,
  address_location = california_pop_centers_sf,
  greenspace = padus_ar_la,
  buffer_distance = 804.672, 
  projected_crs = crs,
  minimum_greenspace_size = 400
)


saveRDS(cs_access_euclidean_la, paste0(generated.data.folder, "cs_access_euclidean_la.rds"))


cs_access_euclidean_la$city <- "Los Angeles"
cs_access_euclidean_nyc$city <- "New York City"


dt_sf_nyc <- dplyr::left_join(dta_nyc_green_spaces, cs_access_euclidean_nyc) %>%
  sf::st_transform(crs)
dt_sf_la <- dplyr::left_join(dta_la_green_spaces, cs_access_euclidean_la)%>%
  sf::st_transform(crs)

dt_sf <- rbind(dt_sf_nyc, dt_sf_la)
dt <- dt_sf
sf::st_geometry(dt) <- NULL
library(ggplot2)
library(dplyr)

theme_green <- theme_bw(base_size = 13) +
  theme(
    plot.title = element_text(size = 15, face = "bold"),
    axis.title = element_text(size = 13),
    axis.text  = element_text(size = 11),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey85"),
    plot.subtitle = element_text(size = 12, color = "grey30")
  )

green_palette <- c(
  "Los Angeles"  = "#009E73",  # bluish-green
  "New York City" = "#0072B2"   # blue
)

png(paste0(output.folder, "green_space_scatter_plots.png"), 900, 460)
ggplot(dt, aes(x = closest_greenspace, y = NDVI, color = city)) +
  geom_point(alpha = 0.4, size = 2) +
  geom_smooth(aes(color = city), method = "loess", se = TRUE, linewidth = 1.2) +
  scale_color_manual(values = green_palette) +
  coord_cartesian(xlim = c(0, 3000)) +
  labs(
    title = "Greenness vs Proximity to Greenspace",
    subtitle = "NDVI vs Closest Greenspace Distance by City",
    x = "Closest greenspace (m)",
    y = "NDVI (0–1)",
    color = "City"
  ) +
  theme_bw(base_size = 13) +
  theme(
    plot.title = element_text(size = 15, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.title = element_text(size = 13),
    axis.text = element_text(size = 11),
    legend.position = "top"
  )
dev.off()

png(paste0(output.folder, "green_space_ndvi_distribution.png"), 900, 460)
ggplot(dt, aes(x = NDVI, fill = city)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = green_palette) +
  labs(
    title = "NDVI Distribution",
    x = "NDVI (0–1)", y = "Density", fill = "City"
  ) +
  theme_bw(base_size = 13)
dev.off()

png(paste0(output.folder, "green_space_distance_distribution.png"), 900, 460)
ggplot(dt, aes(x =closest_greenspace, fill = city)) +
  geom_density(alpha = 0.5) +
  scale_fill_manual(values = green_palette) +
  labs(
    title = "Distance to Nearest Green Space Distribution",
    x = "Distance to closest greenspace (m)", y = "Density", fill = "City"
  ) +
  coord_cartesian(xlim = c(0, 5000)) +
  theme_bw(base_size = 13)
dev.off()

# Greenspace distance boxplot
cb_palette <- c("TRUE" = "#E69F00",  # orange
                "FALSE" = "#0072B2") # blue

png(paste0(output.folder, "green_space_distance_categories_ndvi.png"), 900, 460)
ggplot(dt, aes(x = city, y = NDVI, fill = greenspace_in_buffer)) +
  geom_boxplot(
    alpha = 0.6,
    outlier.alpha = 0.4,
    color = "black",             # outline of boxes
    position = position_dodge(width = 0.8)
  ) +
  scale_fill_manual(
    values = cb_palette,
    labels = c("Outside Walking Distance", "Within Walking Distance")
  ) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(
    fill = "Greenspace Access",
    x = "",
    y = "NDVI (Normalized Difference Vegetation Index)"
  ) +
  theme_bw(base_size = 14) +
  theme(
    legend.position = "top",
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 13),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )
dev.off()

# plot maps, todo: need to improve, not looking really good, check 
nyc_close_green_space <- dplyr::left_join(nyc_ice[,c("GEOID", "tract")], cs_access_euclidean_nyc)
la_close_green_space <- dplyr::left_join(la_ice[,c("GEOID", "tract")], cs_access_euclidean_la)
mapview::mapview(la_close_green_space, zcol = "closest_greenspace")
mapview::mapview(nyc_close_green_space, zcol = "closest_greenspace")
