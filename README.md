# Green Spaces and Community Severance

Analysis code for the study: **"Community Severance and Green Space Accessibility in New York City and Los Angeles"**

This repository contains the R scripts used to estimate associations between the Community Severance Index (CSI) and three complementary measures of green space accessibility — neighboring-home visits to publicly accessible green spaces, NDVI, and distance to the nearest public green space — across census tracts in New York City and Los Angeles in 2019.

## Data availability

Raw input data are not included in this repository. The analysis requires:

- Advan Research Neighborhood Patterns Plus data (accessed via Dewey Data platform)
- PAD-US Areas of Recreation (U.S. Geological Survey)
- Landsat-derived tract-level NDVI (Brochu et al. 2022)
- U.S. Census 2015–2019 ACS 5-year estimates (via `tidycensus`)
- Road infrastructure and traffic inputs for CSI construction (stored on external drive)
- 500 Cities project city boundary shapefile (CDC)

Several intermediate `.rds` files are present in `data/generated/` (not tracked in this repository), allowing downstream scripts (Steps 5b onwards) to be run without the external data sources.

## Repository structure

```
code/                        Analysis scripts (see execution order below)
code/functions/functions.R   Shared helper and model-fitting functions
code/packages/               Package loading
```

## Execution order

Steps 1–6 require external data. Steps 7 onwards can be run using pre-generated files in `data/generated/`.

| Step | Script | Description |
|------|--------|-------------|
| 1 | `code/prep_ses.R` | ACS tract-level socioeconomic indicators and ICE |
| 2 | `code/prep_csi.R` | Population-weighted CSI aggregation to census tract |
| 3 | `code/prep_greenspace.R` | NDVI and Euclidean distance to nearest green space |
| 4 | `code/prep_building_density.R` | Tract-level building density |
| 5a | `code/models_linear.R` | NDVI (Gaussian GAM) and proximity (Gamma GAM) models |
| 5b | `code/prep_cbg_nh_combined.R` | Merges primary and supplementary Advan CBG-level NH files |
| 6 | `code/prep_neighbor_visits_annual_average.R` | Aggregates NH visits to tract-level annual averages; restricts to green-space CBGs |
| 7 | `code/models_neighbor_visits_annual_average.R` | Neighboring-home visits GAMs (negative binomial) |
| 7b | `code/generate_nh_ice_q1_q5_figure.R` | NH ICE Q1/Q5 stratified figure |
| 7c | `code/generate_linear_ice_outl_figures.R` | NDVI/proximity ICE Q1/Q5 and outlier-excluded figures |
| 7d | `code/generate_figure1_maps.R` | Figure 1 and supplementary spatial maps |
| 7e | `code/regenerate_manuscript_figures.R` | Regenerates all manuscript smooth figures from saved model objects (no re-fitting) |
| 8a | `code/table1_outcome_descriptives_neighbor_visits.R` | Descriptive tables |
| 8b2 | `code/generate_supp_table_nh_missingness.R` | Supplementary Table S1 |
| 8c | `code/extract_numeric_results.R` | Q25-to-Q75 quartile contrasts — source of Table S2 and Results-text numbers |
| 8d | `code/generate_nh_distribution_figure.R` | NH visits distribution figure |

See `CODE_REVIEW.md` for the full reproduction guide, including diagnostic-only scripts not part of the manuscript pipeline (`inspect_nh_missingness.R`, `map_uncovered_cbgs_nh.R`, `diagnose_nh_exclusion_reason.R`, `diagnose_ndvi_missing_reason.R`, `inspect_table2_missingness.R`).

Steps 6 and 7 can be run together:

```bash
Rscript code/run_neighbor_visits_workflow.R
```

## Software

R (≥ 4.2). Package dependencies are loaded via `code/packages/packages_to_load.R`. Key packages: `mgcv`, `sf`, `tigris`, `tidycensus`, `tmap`, `data.table`.

## Reference

Benavides J, Zigler C, Kioumourtzoglou M-A. Community Severance and Green Space Accessibility in New York City and Los Angeles. *Discover Cities* (under review).
