rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))
source(paste0(functions.folder, "script_initiate.R"))

library(ggplot2)

manuscript.folder <- paste0(project.folder, "manuscript/")

dt <- readRDS(paste0(generated.data.folder,
  "data_models_neighbor_visits_annual_average_2019_full_year.rds"))

city_palette <- c(
  "LA"  = "#009E73",
  "NYC" = "#0072B2"
)

out_path <- paste0(output.folder, "nh_visits_distribution.png")

png(out_path, width = 900, height = 460, type = "quartz")
print(
  ggplot(dt, aes(x = neighbor_visit_count_annual_avg, fill = city)) +
    geom_density(alpha = 0.5) +
    scale_fill_manual(values = city_palette) +
    labs(
      title = "Neighboring-Home Visits Distribution",
      x = "Annual-average neighboring-home visits count",
      y = "Density",
      fill = "City"
    ) +
    theme_bw(base_size = 13)
)
dev.off()
message("Saved: ", basename(out_path))

file.copy(out_path, paste0(manuscript.folder, "figs/nh_visits_distribution.png"),
          overwrite = TRUE)
message("Copied to manuscript/figs/")
