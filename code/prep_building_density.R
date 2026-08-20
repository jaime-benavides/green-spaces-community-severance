# prep_building_density.R
# Purpose: Computes tract-level building density from footprint rasters.

library(dplyr)

library(osmdata)
library(sf)
library(tmaptools)
library(dplyr)
library(purrr)
crs <- 2163
# 1️⃣ Get the bounding box for Los Angeles
getcityboudingbox <- tmaptools::geocode_OSM("Los Angeles, California, USA", as.sf = TRUE)
# CDC 500 Cities city boundaries — see README.md "Data" > "demography" for download link
city_boundaries_path <- paste0(raw.data.folder, "demography/500Cities_City_11082016/")
city_boundaries <- sf::read_sf(paste0(city_boundaries_path, "CityBoundaries.shp")) %>%
  sf::st_transform(crs)

la_num <- which(city_boundaries$NAME == "Los Angeles")
la_city_boundary <- city_boundaries[la_num,]
nyc_num <- which(city_boundaries$NAME == "New York")
nyc_city_boundary <- city_boundaries[nyc_num,]
# buildings

# Heris et al. 2020 building footprint density rasters — see README.md "Data" > "geometry" > "buildings" for download link
buildings_path <- paste0(raw.data.folder, "geometry/buildings/")

ny_building_area <- terra::rast(paste0(buildings_path, "NewYork/", "NewYork_sum.tif"))
ca_building_area <- terra::rast(paste0(buildings_path, "California/", "California_sum.tif"))

# ny


# 2️⃣ Make sure CRS (coordinate reference systems) match
if (sf::st_crs(nyc_city_boundary)$epsg != terra::crs(ny_building_area, proj=TRUE)) {
  nyc_city_boundary <- sf::st_transform(nyc_city_boundary, terra::crs(ny_building_area))
}

# 3️⃣ Crop raster to bounding box of city (faster)
ny_building_crop <- terra::crop(ny_building_area, nyc_city_boundary)

# 4️⃣ Mask raster by city polygon (clip exactly)
nyc_building_city <- terra::mask(ny_building_crop, nyc_city_boundary)


nyc_ice <- readRDS(paste0(generated.data.folder, "ses_ice_nyc.rds"))
la_ice <- readRDS(paste0(generated.data.folder, "ses_ice_la.rds"))

# 1️⃣ Make sure CRS matches
nyc_ice <- sf::st_transform(nyc_ice, terra::crs(nyc_building_city))

# 2️⃣ Extract raster values by census tract
# terra::extract computes zonal statistics for polygons
building_area_by_tract <- terra::extract(
  x = nyc_building_city,
  y = nyc_ice,
  fun = sum,          # total building area (sum of cell values)
  na.rm = TRUE,
  bind = TRUE          # keeps polygon attributes attached
)



# 3️⃣ Compute census tract area (in m²)
nyc_ice$tract_area_m2 <- as.numeric(sf::st_area(nyc_ice))

# 4️⃣ Join results back (if not already bound)
if (!"NewYork_sum" %in% names(building_area_by_tract)) {
  names(building_area_by_tract)[names(building_area_by_tract) == "nyc_building_city.NewYork_sum"] <- "NewYork_sum"
}
building_area_by_tract_df <- as.data.frame(building_area_by_tract)
nyc_ice_building <- dplyr::left_join(nyc_ice, building_area_by_tract_df[,c("GEOID", "NewYork_sum")], by = "GEOID")  # replace GEOID with your tract ID column

# 5️⃣ Compute building density
nyc_ice_building$building_density <- nyc_ice_building$NewYork_sum / nyc_ice_building$tract_area_m2

# los angeles

# 2️⃣ Make sure CRS (coordinate reference systems) match
if (sf::st_crs(la_city_boundary)$epsg != terra::crs(ca_building_area, proj=TRUE)) {
  la_city_boundary <- sf::st_transform(la_city_boundary, terra::crs(ca_building_area))
}

# 3️⃣ Crop raster to bounding box of city (faster)
ca_building_crop <- terra::crop(ca_building_area, la_city_boundary)

# 4️⃣ Mask raster by city polygon (clip exactly)
la_building_city <- terra::mask(ca_building_crop, la_city_boundary)


# 1️⃣ Make sure CRS matches
la_ice <- sf::st_transform(la_ice, terra::crs(la_building_city))

# 2️⃣ Extract raster values by census tract
# terra::extract computes zonal statistics for polygons
building_area_by_tract <- terra::extract(
  x = la_building_city,
  y = la_ice,
  fun = sum,          # total building area (sum of cell values)
  na.rm = TRUE,
  bind = TRUE          # keeps polygon attributes attached
)



# 3️⃣ Compute census tract area (in m²)
la_ice$tract_area_m2 <- as.numeric(sf::st_area(la_ice))

# 4️⃣ Join results back (if not already bound)
if (!"LosAngeles_sum" %in% names(building_area_by_tract)) {
  names(building_area_by_tract)[names(building_area_by_tract) == "la_building_city.LosAngeles_sum"] <- "LosAngeles_sum"
}
building_area_by_tract_df <- as.data.frame(building_area_by_tract)
la_ice_building <- dplyr::left_join(la_ice, building_area_by_tract_df[,c("GEOID", "California_sum")], by = "GEOID")  # replace GEOID with your tract ID column

# 5️⃣ Compute building density
la_ice_building$building_density <- la_ice_building$California_sum / la_ice_building$tract_area_m2

la_building_dens <- la_ice_building[,c("GEOID", "building_density")]
la_building_dens$building_density[is.na(la_building_dens$building_density)] <- 0
la_building_dens_df <- la_building_dens
sf::st_geometry(la_building_dens_df) <- NULL

nyc_building_dens <- nyc_ice_building[,c("GEOID", "building_density")]
nyc_building_dens$building_density[is.na(nyc_building_dens$building_density)] <- 0
nyc_building_dens_df <- nyc_building_dens
sf::st_geometry(nyc_building_dens_df) <- NULL

saveRDS(la_building_dens_df, paste0(generated.data.folder, "building_dens_la.rds"))
saveRDS(nyc_building_dens_df, paste0(generated.data.folder, "building_dens_nyc.rds"))
