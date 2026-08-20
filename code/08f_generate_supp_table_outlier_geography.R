rm(list = ls())

project.folder <- paste0(print(here::here()), "/")
source(paste0(project.folder, "init_directory_structure.R"))

library(dplyr)
library(sf)

# 08f_generate_supp_table_outlier_geography.R
# Purpose: Builds Supplementary Table S3 comparing tract area, density, and
#          CSI between outlier and within-range tracts, by city.

dt <- readRDS(paste0(generated.data.folder, "data_models.rds"))

la_geom  <- readRDS(paste0(generated.data.folder, "krieger_ice_la.rds")) |>
  dplyr::select(GEOID, geometry) |>
  mutate(GEOID = sub("^0", "", GEOID))
nyc_geom <- readRDS(paste0(generated.data.folder, "krieger_ice_nyc.rds")) |>
  dplyr::select(GEOID, geometry) |>
  mutate(GEOID = sub("^0", "", GEOID))

la <- dt |>
  filter(city == "LA") |>
  left_join(la_geom, by = "GEOID") |>
  st_as_sf() |>
  filter(!is.na(outlier_flag))
nyc <- dt |>
  filter(city == "NYC") |>
  left_join(nyc_geom, by = "GEOID") |>
  st_as_sf() |>
  filter(!is.na(outlier_flag))

la$area_km2  <- as.numeric(st_area(la))  / 1e6
nyc$area_km2 <- as.numeric(st_area(nyc)) / 1e6

fmt_med_iqr <- function(x, dp = 2) {
  med <- median(x, na.rm = TRUE)
  q1  <- quantile(x, 0.25, na.rm = TRUE)
  q3  <- quantile(x, 0.75, na.rm = TRUE)
  sprintf(paste0("%.", dp, "f [%.", dp, "f, %.", dp, "f]"), med, q1, q3)
}

summarise_group <- function(x) {
  x <- st_drop_geometry(x)
  x$pop_dens_thousands <- x$pop_dens / 1000
  list(
    n                = nrow(x),
    area_km2         = fmt_med_iqr(x$area_km2, 2),
    pop_dens         = fmt_med_iqr(x$pop_dens_thousands, 2),
    building_density = fmt_med_iqr(x$building_density, 2),
    csi              = fmt_med_iqr(x$community_severance_index, 2)
  )
}

fmt_row <- function(label, unit, groups) {
  vals <- vapply(groups, function(g) g[[label]], character(1))
  paste0(unit, " & ", paste(vals, collapse = " & "), " \\\\")
}

# ---- LA: single outlier column (all 62 outliers are high-CSI, z > 2) ----
la_outl  <- summarise_group(filter(la, outlier_flag == "Outlier (|z|>2)"))
la_withn <- summarise_group(filter(la, outlier_flag != "Outlier (|z|>2)"))

la_lines <- c(
  "\\begin{subtable}{\\textwidth}",
  "\\centering",
  "\\subcaption{Los Angeles}",
  "\\label{tab:outlier_geography_la}",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  "Characteristic & Outlier tracts (|z| > 2) & Within \\textpm 2 SD \\\\",
  paste0(" & ($n$ = ", la_outl$n, ") & ($n$ = ", la_withn$n, ") \\\\"),
  "\\midrule",
  fmt_row("area_km2", "Tract area (km\\textsuperscript{2})", list(la_outl, la_withn)),
  fmt_row("pop_dens", "Population density (thousands per km\\textsuperscript{2})", list(la_outl, la_withn)),
  fmt_row("building_density", "Building density", list(la_outl, la_withn)),
  fmt_row("csi", "Community Severance Index", list(la_outl, la_withn)),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{subtable}"
)

# ---- NYC: high-CSI and low-CSI outliers reported as separate columns ----
nyc <- nyc |> mutate(
  outlier_tail = case_when(
    outlier_flag != "Outlier (|z|>2)" ~ "Within",
    z_csi > 0                         ~ "High-CSI outlier",
    TRUE                              ~ "Low-CSI outlier"
  )
)

nyc_high  <- summarise_group(filter(nyc, outlier_tail == "High-CSI outlier"))
nyc_low   <- summarise_group(filter(nyc, outlier_tail == "Low-CSI outlier"))
nyc_withn <- summarise_group(filter(nyc, outlier_tail == "Within"))

nyc_lines <- c(
  "\\begin{subtable}{\\textwidth}",
  "\\centering",
  "\\subcaption{New York City}",
  "\\label{tab:outlier_geography_nyc}",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  "Characteristic & High-CSI outliers (z > 2) & Low-CSI outliers (z < -2) & Within \\textpm 2 SD \\\\",
  paste0(
    " & ($n$ = ", nyc_high$n, ") & ($n$ = ", nyc_low$n,
    ") & ($n$ = ", nyc_withn$n, ") \\\\"
  ),
  "\\midrule",
  fmt_row("area_km2", "Tract area (km\\textsuperscript{2})", list(nyc_high, nyc_low, nyc_withn)),
  fmt_row("pop_dens", "Population density (thousands per km\\textsuperscript{2})", list(nyc_high, nyc_low, nyc_withn)),
  fmt_row("building_density", "Building density", list(nyc_high, nyc_low, nyc_withn)),
  fmt_row("csi", "Community Severance Index", list(nyc_high, nyc_low, nyc_withn)),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{subtable}"
)

latex_lines <- c(
  "\\begin{table}[h]",
  "\\centering",
  "\\caption{Tract area, population density, building density, and Community Severance Index (CSI), for tracts excluded by the primary outlier rule (|z\\textsubscript{CSI}| > 2) versus tracts retained in the primary analysis, Los Angeles (LA) and New York City (NYC), 2019. NYC outliers are reported separately by CSI tail because the two subgroups differ materially in area and density. Values are median [P25, P75].}",
  "\\label{tab:outlier_geography}",
  la_lines,
  "",
  "\\vspace{1em}",
  "",
  nyc_lines,
  "\\par\\vspace{0.5em}",
  "{\\footnotesize SD = standard deviation. Tract area computed from tract polygon geometry (2015--2019 ACS 5-year TIGER boundaries). LA has no low-CSI (z < -2) outlier tracts.}",
  "\\end{table}"
)

out_path <- paste0(output.folder, "supp_table_outlier_geography.tex")
writeLines(latex_lines, out_path)
message("Supplementary outlier-geography table saved to: ", out_path)
