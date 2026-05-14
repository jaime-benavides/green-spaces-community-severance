rm(list = ls())
project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(dplyr)
library(tidyr)
library(knitr)
library(kableExtra)
library(RColorBrewer)

crs <- 2163

nyc_ice <- readRDS(paste0(generated.data.folder, "ses_ice_nyc.rds"))
nyc_sf <-nyc_ice[,c("GEOID")]
la_ice <- readRDS(paste0(generated.data.folder, "ses_ice_la.rds"))
la_sf <-la_ice[,c("GEOID")]
la_sf$GEOID <- sub('.', '', la_sf$GEOID)
dt_sf <- rbind(nyc_sf, la_sf)
dt <- readRDS(paste0(generated.data.folder, "dt_nyc_and_la_quintiles_ses.rds"))
dt_sf_comp <- dplyr::left_join(dt_sf, dt)

summary_table <- dt %>%
  select(city, ICE_inc_quintile, ICE_rewb_quintile) %>%
  pivot_longer(
    cols = starts_with("ICE_"),
    names_to = "measure",
    values_to = "quintile"
  ) %>%
  group_by(city, measure, quintile) %>%
  summarise(n = n(), .groups = "drop") %>%
  pivot_wider(
    names_from = city,
    values_from = n,
    values_fill = 0
  ) %>%
  rowwise() %>%
  mutate(
    total = sum(c_across(where(is.numeric))),       # total count for this row
    pct_LA = ifelse(!is.na(LA), round(LA / total * 100,1), 0),
    pct_NYC = ifelse(!is.na(NYC), round(NYC / total * 100,1), 0)
  ) %>%
  ungroup() %>%
  select(-total) %>%
  arrange(measure, quintile)


latex_file <- paste0(generated.data.folder, "summary_table.tex")

summary_table %>%
  kable(format = "latex", booktabs = TRUE, digits = 1,
        caption = "Counts and percentages by city and quintile") %>%
  kable_styling(latex_options = c("hold_position")) %>%
  save_kable(latex_file)

# Save HTML table to file
html_file <- paste0(generated.data.folder, "summary_table.html")

summary_table %>%
  kable(format = "html", digits = 1,
        caption = "Counts and percentages by city and quintile") %>%
  kable_styling(full_width = FALSE, position = "left") %>%
  save_kable(html_file)

# plot maps of quintile categories
tmap_mode("view")

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
# Define levels
quintile_levels <- c(
  "Q1 (Most Disadvantaged)",
  "Q2",
  "Q3",
  "Q4",
  "Q5 (Most Advantaged)"
)

# Colorblind-friendly palette (5 colors)
palette_cb <- c(
  "#D55E00",  # reddish - most disadvantaged
  "#E69F00",  # orange
  "#F0E442",  # yellow
  "#009E73",  # green
  "#0072B2"   # blue - most advantaged
)
road_color <- "#595959"

# Optional: make it a named vector
names(palette_cb) <- quintile_levels

palette_cb

dt_sf_comp_la <- dt_sf_comp[which(dt_sf_comp$city == "LA"),]
dt_sf_comp_nyc <- dt_sf_comp[which(dt_sf_comp$city == "NYC"),]

la_map_ice_inc <- tm_shape(dt_sf_comp_la) +
  tm_basemap("CartoDB.Positron") +  # clean, minimal base map
  
  # polygons go first
  tm_polygons(
    col = "ICE_inc_quintile",
    palette = palette_cb,
    alpha = 0.6,
    border.col = NA,
    title = "ICE income levels"
  ) +
  
  # roads on top
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col = road_color, lwd = 0.8, alpha = 1.0) +
  
  tm_layout(
    title = "ICE income levels — LA",
    legend.position = c("right", "bottom"),
    frame = FALSE,
    bg.color = "white",
    title.size = 1.2
  )



tmap_save(
  tm = la_map_ice_inc,
  filename = paste0(output.folder, "la_ice_inc_map.html"),
  width = 1200,  # optional, in pixels
  height = 900   # optional
)

# nyc 

nyc_map_ice_inc <- tm_shape(dt_sf_comp_nyc) +
  tm_basemap("CartoDB.Positron") +  # clean, minimal base map
  
  # polygons go first
  tm_polygons(
    col = "ICE_inc_quintile",
    palette = palette_cb,
    alpha = 0.6,
    border.col = NA,
    title = "ICE income levels"
  ) +
  
  # roads on top
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col = road_color, lwd = 0.8, alpha = 1.0) +
  
  tm_layout(
    title = "ICE income levels — NYC",
    legend.position = c("right", "bottom"),
    frame = FALSE,
    bg.color = "white",
    title.size = 1.2
  )

tmap_save(
  tm = nyc_map_ice_inc,
  filename = paste0(output.folder, "nyc_ice_inc_map.html"),
  width = 1200,  # optional, in pixels
  height = 900   # optional
)


la_map_ice_rewb <- tm_shape(dt_sf_comp_la) +
  tm_basemap("CartoDB.Positron") +  # clean, minimal base map
  
  # polygons go first
  tm_polygons(
    col = "ICE_rewb_quintile",
    palette = palette_cb,
    alpha = 0.6,
    border.col = NA,
    title = "ICE White/Black levels"
  ) +
  
  # roads on top
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col = road_color, lwd = 0.8, alpha = 1.0) +
  
  tm_layout(
    title = "ICE white/black levels — LA",
    legend.position = c("right", "bottom"),
    frame = FALSE,
    bg.color = "white",
    title.size = 1.2
  )



tmap_save(
  tm = la_map_ice_rewb,
  filename = paste0(output.folder, "la_ice_rewb_map.html"),
  width = 1200,  # optional, in pixels
  height = 900   # optional
)

# nyc 

nyc_map_ice_rewb <- tm_shape(dt_sf_comp_nyc) +
  tm_basemap("CartoDB.Positron") +  # clean, minimal base map
  
  # polygons go first
  tm_polygons(
    col = "ICE_rewb_quintile",
    palette = palette_cb,
    alpha = 0.6,
    border.col = NA,
    title = "ICE White/Black levels"
  ) +
  
  # roads on top
  tm_shape(roads_contxt_fhwa) +
  tm_lines(col = road_color, lwd = 0.8, alpha = 1.0) +
  
  tm_layout(
    title = "ICE white/black levels — NYC",
    legend.position = c("right", "bottom"),
    frame = FALSE,
    bg.color = "white",
    title.size = 1.2
  )

tmap_save(
  tm = nyc_map_ice_rewb,
  filename = paste0(output.folder, "nyc_ice_rewb_map.html"),
  width = 1200,  # optional, in pixels
  height = 900   # optional
)