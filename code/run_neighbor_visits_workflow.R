rm(list = ls())

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))

# run_neighbor_visits_workflow.R
# Purpose: Runs Steps 6-7 (NH metric preparation, then NH GAM fitting).
#          Input is fixed: data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_tract_average.csv

output_label    <- "2019_full_year"
model_input_out <- paste0(generated.data.folder,
                          "data_models_neighbor_visits_annual_average_", output_label, ".rds")

prep_cmd <- paste("Rscript", shQuote(paste0(code.folder, "prep_neighbor_visits_annual_average.R")))

model_cmd <- paste(
  "Rscript",
  shQuote(paste0(code.folder, "models_neighbor_visits_annual_average.R")),
  shQuote(model_input_out),
  shQuote(output_label)
)

message("Running prep step...")
prep_status <- system(prep_cmd)
if (prep_status != 0) stop("Prep step failed with status ", prep_status, call. = FALSE)

message("Running model step...")
model_status <- system(model_cmd)
if (model_status != 0) stop("Model step failed with status ", model_status, call. = FALSE)

message("Neighbor-visit workflow completed successfully for label: ", output_label)
