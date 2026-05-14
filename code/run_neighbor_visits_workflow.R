rm(list = ls())

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  stop(
    paste(
      "Usage: Rscript code/run_neighbor_visits_workflow.R",
      "<INPUT_PATH> [TARGET_YEAR] [START_MONTH] [END_MONTH] [OUTPUT_LABEL]"
    ),
    call. = FALSE
  )
}

input_path <- args[[1]]
target_year <- if (length(args) >= 2) suppressWarnings(as.integer(args[[2]])) else 2019L
start_month <- if (length(args) >= 3) suppressWarnings(as.integer(args[[3]])) else 1L
end_month <- if (length(args) >= 4) suppressWarnings(as.integer(args[[4]])) else 12L
output_label <- if (length(args) >= 5) args[[5]] else if (target_year == 2019L && start_month == 1L && end_month == 12L) "2019_full_year" else paste0(target_year, "_m", start_month, "_to_m", end_month)

summary_out <- paste0(generated.data.folder, "neighbor_visit_annual_average_", output_label, "_tract.rds")
model_input_out <- paste0(generated.data.folder, "data_models_neighbor_visits_annual_average_", output_label, ".rds")

prep_cmd <- paste(
  "Rscript",
  shQuote(paste0(code.folder, "prep_neighbor_visits_annual_average.R")),
  shQuote(input_path),
  shQuote(summary_out),
  shQuote(model_input_out),
  target_year,
  start_month,
  end_month,
  shQuote(output_label)
)

model_cmd <- paste(
  "Rscript",
  shQuote(paste0(code.folder, "models_neighbor_visits_annual_average.R")),
  shQuote(model_input_out),
  shQuote(output_label)
)

map_cmd <- paste(
  "Rscript",
  shQuote(paste0(code.folder, "plot_neighbor_visits_interactive_maps.R")),
  shQuote(summary_out),
  shQuote(output_label)
)

message("Running prep step...")
prep_status <- system(prep_cmd)
if (prep_status != 0) {
  stop("Prep step failed with status ", prep_status, call. = FALSE)
}

message("Running model step...")
model_status <- system(model_cmd)
if (model_status != 0) {
  stop("Model step failed with status ", model_status, call. = FALSE)
}

message("Running map step...")
map_status <- system(map_cmd)
if (map_status != 0) {
  stop("Map step failed with status ", map_status, call. = FALSE)
}

message("Neighbor-visit workflow completed successfully for label: ", output_label)
