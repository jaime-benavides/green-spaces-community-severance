rm(list = ls())

project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))

args <- commandArgs(trailingOnly = TRUE)

default_label <- "2019_full_year"
input_path <- if (length(args) >= 1) {
  args[[1]]
} else {
  paste0(generated.data.folder, "data_models_neighbor_visits_annual_average_", default_label, ".rds")
}

output_label <- if (length(args) >= 2) args[[2]] else default_label

table1_csv <- paste0(output.folder, "table1_outcome_descriptives_", output_label, ".csv")
table1_tex <- paste0(output.folder, "table1_outcome_descriptives_", output_label, ".tex")
table2_csv <- paste0(output.folder, "table_distribution_missingness_", output_label, ".csv")
table2_tex <- paste0(output.folder, "table_distribution_missingness_", output_label, ".tex")

run_cmd <- function(script_name, input_path, output_csv, output_tex) {
  cmd <- paste(
    "Rscript",
    shQuote(paste0(code.folder, script_name)),
    shQuote(input_path),
    shQuote(output_csv),
    shQuote(output_tex)
  )
  status <- system(cmd)
  if (status != 0) {
    stop(script_name, " failed with status ", status, call. = FALSE)
  }
}

message("Generating Table 1 outcomes descriptives...")
run_cmd(
  "table1_outcome_descriptives_neighbor_visits.R",
  input_path,
  table1_csv,
  table1_tex
)

message("Generating Table 2 exposure/covariate descriptives...")
run_cmd(
  "table_distribution_missingness_neighbor_visits.R",
  input_path,
  table2_csv,
  table2_tex
)

message("Descriptive tables completed for label: ", output_label)
message("Table 1 CSV: ", table1_csv)
message("Table 1 TeX: ", table1_tex)
message("Table 2 CSV: ", table2_csv)
message("Table 2 TeX: ", table2_tex)
