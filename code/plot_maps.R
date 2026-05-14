# script aim: get data from census and get percentage of people per race/ethnicity
rm(list = ls())
project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(dplyr)
library(tmap)
library(tidyverse)

crs <- 2163
dta_path <- "/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/green_infrastructure/"
dt <- readRDS(paste0(generated.data.folder, "data_models.rds"))

nyc_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds"))
la_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))
la_ice$GEOID <- sub('.', '', la_ice$GEOID)
dta_ice <- rbind(nyc_ice, la_ice)
dt_sf <- dplyr::left_join(dta_ice[,"GEOID"],dt) %>%
  sf::st_transform(crs)


# plot correlations
data_corr <- dt[,c("NDVI","closest_greenspace", "pop_dens", "ICE_inc", "ICE_rewb", "perc.pov", "perc.black", "perc.hisp","community_severance_index")]


graph_title <- "correlations"
png(paste0(output.folder, "corrs.png"), 900, 460)
data_corr %>% GGally::ggcorr(., method = c("pairwise.complete.obs", "spearman"),
                             label = T, label_size = 3, label_alpha = T,
                             hjust = 1, nbreaks = 10, limits = TRUE,
                             size = 4, layout.exp = 5) + ggtitle(graph_title)
dev.off()

# dataset for models

nas_perc <- (colMeans(is.na(data)))*100
nas_perc <- nas_perc[-c(1)]
x <- nas_perc
x <- x[order(x, decreasing = TRUE)]
miss <- as.data.frame(x )
colnames(miss) <- "percent_miss"

# read road infrastructure for plotting (todo: move to plotting script)
faf5_network <- sf::read_sf(paste0("/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/mobility/us/FAF5_Model_Highway_Network/Networks/geodatabase_format/", "FAF5Network.gdb"))
faf5_highways <- faf5_network[which(faf5_network$F_Class %in% c(1,2,3)),]
faf5_highways <- faf5_highways %>%
  sf::st_transform(crs)

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
city_boundary_la_raw <- city_boundaries[which(city_boundaries$NAME == "Los Angeles"),] %>%
  sf::st_transform(crs)
city_boundary_la <- city_boundary_la_raw %>%
  sf::st_buffer(dist = 10000)
la_ids <- sapply(sf::st_intersects(padus_ar, city_boundary_la),function(x){length(x)>0})
padus_ar_la <- padus_ar[la_ids, ]

sp_context <- rbind(city_boundary_nyc_raw, city_boundary_la_raw)
# intersect with spatial context
roads_contxt_id_fhwa <- sapply(sf::st_intersects(faf5_highways, sp_context),function(x){length(x)>0})
roads_contxt_fhwa <- faf5_highways[roads_contxt_id_fhwa, ]


data <- dt_sf[which(!is.na(dt_sf$population)),]
tmap::tmap_mode(mode = "view")

# plot boroughs maps


tmap::tm_shape(sf::st_make_valid(sp_context)) +
  tmap::tm_borders(alpha = 0.4, col = "black") 

# make quantile maps for the paper fig1


map_community_severance_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "community_severance_index",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 9  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "Community Severance Index",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_community_severance_ctxt_q, paste0(output.folder, "map_community_severance_index_nyc_q.html"))


map_perc_pov_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "perc.pov",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 10  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "Percentage Poverty",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_perc_pov_ctxt_q, paste0(output.folder, "map_perc_pov_ctxt_q.html"))


# pop_dens


map_pop_dens_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "pop_dens",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 10  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "Population density (people/km²)",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_pop_dens_ctxt_q, paste0(output.folder, "map_pop_dens_ctxt_q.html"))


map_building_density_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "building_density",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 10  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "Building density",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_building_density_ctxt_q, paste0(output.folder, "map_building_density_ctxt_q.html"))


# percentage black


map_perc_black_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "perc.black",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 10  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "Percentage Black",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_perc_black_ctxt_q, paste0(output.folder, "map_perc_black_ctxt_q.html"))


# percentage hispanic


map_perc_hisp_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "perc.hisp",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 10  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "Percentage Hispanic",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_perc_hisp_ctxt_q, paste0(output.folder, "map_perc_hisp_ctxt_q.html"))


# percentage hispanic


map_ndvi_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "NDVI",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 10  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "NDVI",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_ndvi_ctxt_q, paste0(output.folder, "map_pc_parks_ctxt_q.html"))

# black carbon

map_distance_greenspace_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "closest_greenspace",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 10  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "Greenspace distance",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_distance_greenspace_ctxt_q, paste0(output.folder, "map_distance_greenspace_ctxt_q.html"))

map_ICE_inc_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "ICE_inc",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 9  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "ICE Income",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_ICE_inc_ctxt_q, paste0(output.folder, "map_ICE_inc_ctxt_q.html"))

map_ICE_rewb_ctxt_q <- 
  tm_shape(sf::st_make_valid(sp_context)) +
  tm_borders(fill_alpha = 0.1, col = "black") +
  tm_shape(data) +
  tm_polygons(
    fill = "ICE_rewb",
    fill.scale = tm_scale(
      values = "brewer.purples", 
      style = "quantile", 
      n = 10  # force 4 bins
    ),
    fill.legend = tm_legend(
      title = "ICE Race",
      labels = c("0%–10%", "10%–20%", "20%–30%", "30%–40%", "40%–50%", "50%–60%", "60%–70%", "70%–80%", "80%–90%", "90%–100%")
    ),
    col = NA
  ) +
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col_alpha = 0.5) +
  
  tm_layout(
    legend.position = c("right", "top"),
    legend.frame = TRUE,
    legend.bg.color = "white",
    legend.bg.alpha = 0.8,
    legend.title.size = 1,
    legend.text.size = 0.8,
    outer.margins = c(0.05, 0.2, 0.05, 0.05)  # bottom, left, top, right margins to avoid overlap
  )
tmap::tmap_save(map_ICE_rewb_ctxt_q, paste0(output.folder, "map_ICE_rewb_ctxt_q.html"))

