library(rgee)
ee_check() # Check non-R dependencies
library(GreenExp) # If not loaded yet
library(magrittr) # If not loaded yet (used for piping %>%)
library (sf) #Need for most spatial operation
library (sfheaders) #for additional functions to work with sf package
library(tmaptools) 
addresspoint <- sf::st_sf(sfheaders::sf_point(c(4.881076, 52.358416)), crs = st_crs(4326))
#mean NDVI at single address point, here no NDVI file given so the start and end date inidicate the range within which satellite images will be search on Planetary Computer
address_ndvi <- GreenExp::calc_ndvi(addresspoint,  buffer_distance = 300, start_date = "2020-08-01", end_date = "2020-09-30")
#print the result
address_ndvi
#create random points within in a city to test
# can try: "Centrum, Amsterdam" or "Washington, DC" or "Kampala, Uganda" or "Bogura, Bangladesh" and more...!
#first get the OSM city geocoded bounding box
getcityboudingbox <- tmaptools::geocode_OSM("Centrum, Amsterdam", as.sf = T) 

#generate random points within the bounding box
RandomPoints <- sf::st_sample(getcityboudingbox$bbox, size = 1000) %>% st_as_sf()

#Calculate mean NDVI at many address points
Randomaddresses_ndvi <- GreenExp::calc_ndvi(RandomPoints,  buffer_distance = 300, start_date = "2020-08-01", end_date = "2020-09-30")

#map the result using the amazing mapview 
mapview::mapview(Randomaddresses_ndvi, zcol = "mean_NDVI")

#Attch the data file
?Ams_Neighborhoods #explore the data if needed
AMS_NH <- Ams_Neighborhoods #load the file

#Calculate mean NDVI for Neighborhood polygons, here we need to metion the given address file is Neighborhood zone, so no buffer distance will be needed. 
AMS_NH_ndvi <- GreenExp::calc_ndvi(AMS_NH,  address_location_neighborhood = TRUE, start_date = "2020-08-01", end_date = "2020-09-30")

#map the result using mapview 
mapview::mapview(AMS_NH_ndvi, zcol = "mean_NDVI")

#We can use the OSM to extract building footprint data
#fist determind the bounding box to get OSM buildings within Central Amsterdam
getcityboudingbox <- tmaptools::geocode_OSM("Centrum, Amsterdam", as.sf = T) 

#download building data, get buildings within Bounding Box
buildings <- osmdata::opq(sf::st_bbox(getcityboudingbox$bbox)) %>%
  osmdata::add_osm_feature(key = "building") %>%
  osmdata::osmdata_sf()

#get the building footprint 
buildings <- buildings$osm_polygons

#estimate the land cover from ESA's land cover data
# Note: for given polygon file, this funtion autometically convert polygon to centroid point
build_land_cover <- GreenExp::land_cover(buildings,  buffer_distance = 300)

#print the result
build_land_cover

#for mapping to the building footprint we joined the land cover data to downloaded building file
#firt convert the projection to downloaded building files (as both need to be in same projection)
build_land_cover <-  sf::st_transform(build_land_cover, sf::st_crs(buildings))

#spatially join them
buildings_landcover <- sf::st_join (buildings, build_land_cover, join= st_intersects)

#Now mapping the tree cover only, while we can explore different land cover types by clicking on each building! 
mapview::mapview(buildings_landcover, zcol = "tree_cover")

# load neighborhoods data (given with the package)
AMS_NH <- Ams_Neighborhoods

#If we want to save the OSM tree data we have to provide a path info
path <- getwd () #for now, let us use the working directory, user can give other paths

#run the function
AMS_NH_canopy_cover <- GreenExp::canopy_pct(AMS_NH, address_location_neighborhood = TRUE, avgcanopyRedii = 3.5, folder_path_osmtrees = path)

#the file will save as "OSMtrees.gpkg"
#let us bring the saved tree file for visualization 
AMS_trees <- sf::st_read ("OSMtrees.gpkg")

#let us map both the canopy cover and OSM trees used to estimate the coverage
mapview::mapview (AMS_trees) + mapview::mapview (AMS_NH_canopy_cover, zcol = "canopy_pct")
