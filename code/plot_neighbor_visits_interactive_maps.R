rm(list = ls())

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

library(dplyr)
library(sf)
library(ggplot2)
library(tmap)

args <- commandArgs(trailingOnly = TRUE)
default_period_label <- "2019_full_year"
default_input_path <- paste0(generated.data.folder, "neighbor_visit_annual_average_", default_period_label, "_tract.rds")
input_path <- if (length(args) >= 1) args[[1]] else default_input_path
output_label <- if (length(args) >= 2) args[[2]] else default_period_label

normalize_geoid <- function(x) {
  gsub("[^0-9]", "", as.character(x))
}

neighbor_dt <- readRDS(input_path) |>
  mutate(
    GEOID = normalize_geoid(TRACT_GEOID),
    city = as.character(city)
  )

nyc_shape <- readRDS(paste0(generated.data.folder, "ses_ice_nyc.rds")) |>
  mutate(
    GEOID = normalize_geoid(GEOID),
    city = "NYC"
  ) |>
  select(GEOID, city, geometry)

la_shape <- readRDS(paste0(generated.data.folder, "ses_ice_la.rds")) |>
  mutate(
    GEOID = normalize_geoid(GEOID),
    city = "LA"
  ) |>
  select(GEOID, city, geometry)

shape_dt <- rbind(nyc_shape, la_shape)

map_dt <- shape_dt |>
  left_join(neighbor_dt, by = c("GEOID", "city"))

metric_specs <- list(
  neighbor_visit_share_annual_weighted = list(
    title = "Neighbor Visit Share",
    palette = "RdYlBu",
    direction = -1,
    legend = "Share of visits from neighboring home CBGs"
  ),
  neighbor_visit_count_annual_total = list(
    title = "Total Neighbor Visits",
    palette = "Blues",
    direction = 1,
    legend = "Total neighboring visits"
  ),
  device_counts_row_total_annual_total = list(
    title = "Total Visits",
    palette = "Greens",
    direction = 1,
    legend = "Total visits"
  )
)

build_tmap_interactive <- function(city_name, metric_name, spec, data) {
  dt_city <- data |>
    filter(city == city_name, !is.na(.data[[metric_name]]))
  
  if (nrow(dt_city) == 0) {
    return(NULL)
  }
  
  dt_city$tooltip_text <- paste0(
    "City: ", dt_city$city, "\n",
    "GEOID: ", dt_city$GEOID, "\n",
    "Period: ", dt_city$period_label, "\n",
    "Neighbor visit share: ", round(dt_city$neighbor_visit_share_annual_weighted, 4), "\n",
    "Neighbor visits total: ", round(dt_city$neighbor_visit_count_annual_total, 1), "\n",
    "Total visits: ", round(dt_city$device_counts_row_total_annual_total, 1), "\n",
    "Available months: ", dt_city$n_months_neighbor_visit
  )
  
  tm_shape(dt_city) +
    tm_polygons(
      fill = metric_name,
      fill.scale = tm_scale_continuous(values = spec$palette),
      fill.legend = tm_legend(title = spec$legend),
      col = "gray40",
      lwd = 0.5,
      fill_alpha = 0.85,
      popup.vars = c(
        "City" = "city",
        "GEOID" = "GEOID",
        "Period" = "period_label",
        "Neighbor visit share" = "neighbor_visit_share_annual_weighted",
        "Neighbor visits total" = "neighbor_visit_count_annual_total",
        "Total visits" = "device_counts_row_total_annual_total",
        "Available months" = "n_months_neighbor_visit"
      ),
      id = "tooltip_text"
    ) +
    tm_basemap("OpenStreetMap") +
    tm_view(
      use_WebGL = FALSE,
      set.view = c(
        mean(sf::st_bbox(dt_city)[c("xmin", "xmax")]),
        mean(sf::st_bbox(dt_city)[c("ymin", "ymax")]),
        10
      )
    ) +
    tm_title(paste(city_name, "-", spec$title, "-", output_label))
}

build_ggplot_static <- function(city_name, metric_name, spec, data) {
  dt_city <- data |>
    filter(city == city_name, !is.na(.data[[metric_name]]))
  
  if (nrow(dt_city) == 0) {
    return(NULL)
  }
  
  ggplot(dt_city) +
    geom_sf(aes(fill = .data[[metric_name]]), color = "gray35", linewidth = 0.1) +
    scale_fill_distiller(palette = spec$palette, direction = spec$direction) +
    labs(
      title = paste(city_name, "-", spec$title, "-", output_label),
      fill = spec$legend
    ) +
    theme_void() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      legend.position = "right"
    )
}

tmap_mode("view")

for (city_name in c("NYC", "LA")) {
  for (metric_name in names(metric_specs)) {
    spec <- metric_specs[[metric_name]]
    
    tm_obj <- build_tmap_interactive(
      city_name = city_name,
      metric_name = metric_name,
      spec = spec,
      data = map_dt
    )
    
    if (!is.null(tm_obj)) {
      tmap::tmap_save(
        tm = tm_obj,
        filename = paste0(
          output.folder,
          "map_neighbor_visits_",
          tolower(city_name),
          "_",
          metric_name,
          "_",
          output_label,
          ".html"
        ),
        width = 1200,
        height = 900
      )
    }
    
    gg_obj <- build_ggplot_static(
      city_name = city_name,
      metric_name = metric_name,
      spec = spec,
      data = map_dt
    )
    
    if (!is.null(gg_obj)) {
      ggsave(
        filename = paste0(
          output.folder,
          "map_neighbor_visits_",
          tolower(city_name),
          "_",
          metric_name,
          "_",
          output_label,
          ".png"
        ),
        plot = gg_obj,
        width = 9,
        height = 7,
        dpi = 300
      )
    }
  }
}

message("Interactive tmap HTML and static ggplot PNG files saved to: ", output.folder)
