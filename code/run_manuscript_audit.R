rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(readr)
library(rlang)

# =============================================================================
# run_manuscript_audit.R
#
# Purpose: Reproducible, zero-tolerance numeric audit of sn-article.tex.
#          Reruns every extraction script that feeds a manuscript number,
#          then checks each row of code/audit_manifest.csv (one manuscript
#          claim per row) against the freshly regenerated output CSV.
#
#          This exists because prior audits were manual spot-checks of prose
#          against CSVs, and hand-assembled tables were never mechanically
#          diffed cell-by-cell against source data — which is how a stale
#          rounding error survived multiple "completed" audits. This script
#          is the fix: every number in the manifest is re-derived from
#          scratch and compared, not eyeballed.
#
# Usage:   Rscript code/run_manuscript_audit.R
#          Add a row to code/audit_manifest.csv for any new manuscript claim;
#          add its generating script to `extract_scripts` below if new.
#
# Rounding: uses round-half-away-from-zero with a tiny epsilon, immune to the
#          IEEE-754 boundary artifact that caused the original bug (see
#          generate_supp_table_s2_per_iqr.R for the canonical writeup).
# =============================================================================

round_half_up <- function(x, dp) {
  scale <- 10^dp
  sign(x) * floor(abs(x) * scale + 0.5 + 1e-9) / scale
}

fmt <- function(x, dp) {
  sprintf(paste0("%.", dp, "f"), round_half_up(x, dp))
}

# ---- Step 1: rerun every extraction script feeding the manifest -----------
# Order matters: extract_manuscript_misc_counts.R reads
# numeric_results_outlier_exclusion_counts.csv, so that one runs first.

extract_scripts <- c(
  "extract_outlier_exclusion_counts.R",
  "extract_tract_area_by_city.R",
  "extract_numeric_results.R",
  "extract_ice_nh_quartile_contrasts.R",
  "extract_ice_ndvi_quartile_contrasts.R",
  "extract_ice_distance_quartile_contrasts.R",
  "extract_ice_effect_modification_contrasts.R",
  "extract_manuscript_misc_counts.R",
  "diagnose_nh_exclusion_reason.R",
  "inspect_table2_missingness.R"
)

message("=== Rerunning ", length(extract_scripts), " extraction scripts ===")
for (s in extract_scripts) {
  message("--- ", s, " ---")
  out <- tryCatch(
    system2("Rscript", paste0(code.folder, s), stdout = TRUE, stderr = TRUE),
    error = function(e) paste("FAILED:", conditionMessage(e))
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    message("  FAILED (exit ", status, "):")
    message(paste("   ", tail(out, 15), collapse = "\n"))
  }
}

# ---- Step 2: load manifest, check each row ---------------------------------

manifest <- read_csv(
  paste0(code.folder, "audit_manifest.csv"),
  show_col_types = FALSE,
  col_types = cols(manuscript_value = col_character())
)

csv_cache <- new.env()
load_csv <- function(name) {
  if (!exists(name, envir = csv_cache)) {
    assign(name, read_csv(paste0(output.folder, name), show_col_types = FALSE),
           envir = csv_cache)
  }
  get(name, envir = csv_cache)
}

check_row <- function(row) {
  d <- load_csv(row$source_csv)
  sub <- dplyr::filter(d, !!rlang::parse_expr(row$filter_expr))

  if (row$value_col == "__count__") {
    actual <- nrow(sub)
    actual_fmt <- as.character(actual)
  } else {
    if (nrow(sub) != 1) {
      return(data.frame(
        row$tex_ref, row$claim, row$source_csv,
        status = paste0("ERROR: ", nrow(sub), " rows matched filter (expected 1)"),
        manuscript = row$manuscript_value, actual = NA
      ) |> setNames(c("tex_ref", "claim", "source_csv", "status", "manuscript", "actual")))
    }
    actual <- sub[[row$value_col]]
    actual_fmt <- fmt(actual, row$round_dp)
  }

  status <- if (actual_fmt == row$manuscript_value) "OK" else "MISMATCH"

  data.frame(
    tex_ref = row$tex_ref, claim = row$claim, source_csv = row$source_csv,
    status = status, manuscript = row$manuscript_value, actual = actual_fmt
  )
}

results <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
  check_row(manifest[i, ])
}))

message("\n=== Audit results (", nrow(results), " claims checked) ===")
print(results, row.names = FALSE)

mismatches <- results[results$status != "OK", ]
if (nrow(mismatches) > 0) {
  message("\n*** ", nrow(mismatches), " MISMATCH(ES) — see above. ***")
} else {
  message("\nAll ", nrow(results), " manifest claims match the manuscript.")
}

write_csv(results, paste0(output.folder, "manuscript_audit_results.csv"))
message("Saved: ", output.folder, "manuscript_audit_results.csv")
