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

# ---------------------------
# Setup
# ---------------------------
set.seed(36)
year <- 2019
geo <- "tract"   # krieger() supports 'tract' and 'county' (not 'block group')

# 🔑 Your Census API key (must be set once)
# census_api_key("YOUR_API_KEY", install = TRUE)

# set coordinate reference system
crs <- 2163

### load data
city_boundaries_path <- "/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/demography/us/urban/500Cities_City_11082016/"
city_boundaries <- sf::read_sf(paste0(city_boundaries_path, "CityBoundaries.shp")) %>%
  sf::st_transform(crs)

la_num <- which(city_boundaries$NAME == "Los Angeles")
nyc_num <- which(city_boundaries$NAME == "New York")

la_shape <- city_boundaries[la_num,]
nyc_shape <- city_boundaries[nyc_num,]
# ---------------------------
# Function to compute Krieger ICE
# ---------------------------
compute_krieger_ice <- function(state, county, year, geo = "tract") {
  message("Computing Krieger ICE metrics for ", county, ", ", state, " ...")
  
  ice_results <- ndi::krieger(
    geo = geo,
    year = year,
    state = state,
    county = county,
    quiet = FALSE
  )
  
  # Extract ICE table
  ice_tbl <- ice_results$ice
  ice_sf <- tigris::tracts(state = state, county = county, year = year, cb = TRUE) %>%
    left_join(ice_tbl, by = "GEOID")
  
  return(ice_sf)
}

# ---------------------------
# Run for NYC and LA
# ---------------------------
nyc_ice <- compute_krieger_ice(state = "NY", county = c("New York", "Kings", "Richmond", "Queens", "Bronx"), year = year, geo = geo)
la_ice  <- compute_krieger_ice(state = "CA", county = "Los Angeles", year = year, geo = geo)

# add ses covariates

# read ses data from 2010-2014 5-year ACS
acs.dt <- tidycensus::get_acs(geography = "tract", state = c("NY", "CA"), variables = c("B01003_001", "B02001_003", "B03003_003", "B17001_002"), 
                              geometry = TRUE, year = 2019) 

saveRDS(acs.dt, paste0(generated.data.folder, "acs_ses.rds"))
acs.wide <- spread(acs.dt[,1:4], variable, estimate)  
names(acs.wide)[4:7] <- c("popn", "black", "hisp", "pov") 
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
acs.wide_df <- acs.wide
sf::st_geometry(acs.wide_df) <- NULL


# restrict to la and nyc
sf_cntxt <- sapply(sf::st_intersects(sf::st_transform(la_ice, sf::st_crs(la_shape)), la_shape),function(x){length(x)>0})
la_ice <- la_ice[sf_cntxt, ]
sf_cntxt <- sapply(sf::st_intersects(sf::st_transform(nyc_ice, sf::st_crs(nyc_shape)), nyc_shape),function(x){length(x)>0})
nyc_ice <- nyc_ice[sf_cntxt, ]

# link ice to ses from acs
la_ice <- dplyr::left_join(la_ice, acs.wide_df[,c("GEOID", "perc.black", "perc.hisp", "perc.pov", "pop_dens")])
nyc_ice <- dplyr::left_join(nyc_ice, acs.wide_df[,c("GEOID", "perc.black", "perc.hisp", "perc.pov", "pop_dens")])

# ---------------------------
# Save results
# ---------------------------
saveRDS(nyc_ice, paste0(generated.data.folder, "ses_ice_nyc.rds"))
saveRDS(la_ice,  paste0(generated.data.folder, "ses_ice_la.rds"))
# write.csv(nyc_ice, paste0(output_dir, "krieger_ice_nyc.csv"), row.names = FALSE)
# write.csv(la_ice,  paste0(output_dir, "krieger_ice_la.csv"), row.names = FALSE)

# ---------------------------
# Quick summaries
# ---------------------------
summarize_ice <- function(df, city, output_dir) {
  vars <- c("ICE_inc", "ICE_edu", "ICE_wbinc", "ICE_wpcinc")
  vars <- vars[vars %in% names(df)]
  
  summary_tbl <- df %>%
    summarise(across(all_of(vars), list(mean = mean, sd = sd), na.rm = TRUE))
  
  write.csv(summary_tbl, paste0(output_dir, city, "_krieger_summary.csv"), row.names = FALSE)
  
  cor_tbl <- cor(df[, vars], use = "pairwise.complete.obs")
  write.csv(cor_tbl, paste0(output_dir, city, "_krieger_correlations.csv"))
}
nyc_ice_df <- nyc_ice
sf::st_geometry(nyc_ice_df) <- NULL

la_ice_df <- la_ice
sf::st_geometry(la_ice_df) <- NULL

summarize_ice(nyc_ice_df, "NYC", output.folder)
summarize_ice(la_ice_df, "LA", output.folder)

# ---------------------------
# Plot and Map results
# ---------------------------
nyc_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds"))
la_ice <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds"))

# Income: 80th income percentile vs. 20th income percentile
# Education: less than high school vs. four-year college degree or more
# Race or Ethnicity: white non-Hispanic vs. black non-Hispanic
# Income and race or ethnicity combined: white non-Hispanic in 80th income percentile vs.
# black alone (including Hispanic) in 20th income percentile
# Income and race or ethnicity combined: white non-Hispanic in 80th income percentile vs.
# white non-Hispanic in 20th income percentile
vars <- c("ICE_inc", "ICE_edu", "ICE_wbinc", "ICE_wpcinc")
var_names <- c("ice_income", "ice_education", "ice_race_or_ethnicity", "ice_income_and_race_or_ethnicity_white")
vars <- vars[vars %in% names(nyc_ice)]
df <- nyc_ice_df
city <- "NYC"

png(paste0(output.folder, city, "_krieger_pairs.png"), width = 1000, height = 900)
GGally::ggpairs(df[, vars], columnLabels = var_names,
                title = paste(city, "– Krieger ICE Indices"))
dev.off()

df <- la_ice_df
city <- "LA"

png(paste0(output.folder, city, "_krieger_pairs.png"), width = 1000, height = 900)
GGally::ggpairs(df[, vars], columnLabels = var_names,
                title = paste(city, "– Krieger ICE Indices"))
dev.off()

tmap_mode("plot")


cities <- c("NYC", "LA")
for (city in cities) {
  if(city == "NYC"){
    ice_sf <- nyc_ice
  } else if (city == "LA") {
    ice_sf <- la_ice
  } else {
    print("city not available")
  }
  for (v in vars) {
    if (!v %in% names(ice_sf)) next
    tm <- tm_shape(ice_sf) +
      tm_polygons(
        fill = v,
        fill.scale = tm_scale_continuous(
          values = "-RdYlBu",
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

