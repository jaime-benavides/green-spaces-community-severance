# Green Spaces and Community Severance

This repository is an R analysis project studying how community severance relates to green space exposure and access in New York City and Los Angeles. The code builds a community severance index from transportation and road-environment variables, prepares socioeconomic and green-space measures at the census-tract level, and fits downstream models linking severance to NDVI, distance to green space, and a Dewey-derived neighboring-home mobility metric.

For review and reproducibility auditing, see:

- [CODE_REVIEW_GUIDE.md](/Users/jaimebenavides/claude_cowork/green_spaces_community_severance/CODE_REVIEW_GUIDE.md)
- [CODE_REVIEW_GUIDE.html](/Users/jaimebenavides/claude_cowork/green_spaces_community_severance/CODE_REVIEW_GUIDE.html)

## What this project is doing

At a high level, the workflow is:

1. Build folder paths and load packages/functions.
2. Estimate tract-level socioeconomic indicators and ICE variables for NYC and LA.
3. Estimate or load a city-specific community severance index (CSI).
4. Aggregate CSI to census tracts and join it to socioeconomic context.
5. Prepare green-space metrics:
   - NDVI by tract
   - Euclidean distance to green space
   - Building density
6. Prepare the Dewey neighboring-home mobility metric from destination `CBG x month` exports and aggregate it to tract-level annual-average summaries.
7. Combine all tract-level measures into modeling datasets.
8. Fit generalized additive models and sensitivity analyses.
9. Export figures, HTML widgets, maps, and summary tables to `output/` and `data/generated/`.

## Repository structure

- `code/`
  Main analysis scripts.
- `code/functions/functions.R`
  Shared helper functions for spatial processing, descriptive tables, GAM fitting, Q1/Q5 comparisons, effect-modification plots, residual diagnostics, and distance calculations.
- `code/functions/script_initiate.R`
  Bootstrap file that loads packages and shared functions.
- `code/packages/packages_to_load.R`
  Installs and loads the project package set.
- `data/generated/`
  Intermediate and final `.rds` objects already produced by the pipeline.
- `output/`
  Maps, plots, HTML widgets, and exported tables.
- `manuscript/`
  Draft manuscript files plus neighboring-home decision memos and rendered HTML discussion notes.
- `init_directory_structure.R`
  Defines project folders and creates them if missing.

## Core scripts and their roles

### Setup and shared utilities

- `init_directory_structure.R`
  Creates standard project folders like `code/`, `data/raw/`, `data/generated/`, and `output/`.
- `code/functions/script_initiate.R`
  Sources package-loading and helper-function scripts.
- `code/functions/functions.R`
  Contains most reusable logic. Important function families include:
  - network and spatial helpers such as `generate_osm_network()`, `context_sp()`, and `euclidean_to_edge()`
  - descriptive helpers such as `table_desc()`
  - model builders such as `model_gam_mixed_ndvi()` and `model_gam_mixed_greenspace()`
  - wrappers for grouped analyses such as `fit_by()`, `fit_q1_q5_models()`, and `fit_city_ice()`
  - plotting helpers for smooths, tensor surfaces, residual maps, and effect modification

### Community severance index construction

- `code/estimate_community_sev_index_nyc_updated.R`
  Builds the NYC community severance index from transportation variables stored in `community_severance_nyc_input_data.rds`. It:
  - selects the severance input variables
  - runs robust rank-reduced matrix completion with `pcpr`
  - inspects grid-search error and sparsity
  - performs factor analysis on the low-rank matrix
  - saves factor scores to `data/generated/csi_scores_nyc.rds`

- `code/estimate_community_sev_index_la_updated.R`
  Same overall process for LA using `community_severance_la_input_data_city.rds`, saving to `data/generated/csi_scores_la.rds`.

- `code/estimate_community_sev_index_nyc_updated_check.R`
  Alternate NYC validation/check version of the same pipeline. It saves check-specific artifacts such as:
  - `pcp_rrmc_nyc_updated_check.rds`
  - `csi_scores_nyc_check.rds`

- `code/fa_diagnostics_gpt.R`
  A diagnostic script for checking factor-analysis suitability and score behavior after PCP decomposition. This looks more like a validation/teaching script than a main production step.

### Socioeconomic and tract-level preparation

- `code/prep_ses.R`
  Pulls ACS and ICE measures for NYC and LA, computes tract-level percentages for race/ethnicity and poverty, estimates population density, and saves:
  - `data/generated/acs_ses.rds`
  - `data/generated/ses_ice_nyc.rds`
  - `data/generated/ses_ice_la.rds`
  It also exports summary CSVs and pairwise plots/maps to `output/`.

- `code/prep_csi.R`
  Converts block-group/community-severance outputs into tract-level CSI by population-weighted interpolation using `tidycensus::interpolate_pw()`. It saves:
  - `data/generated/community_severance_nyc_census_tract.rds`
  - `data/generated/community_severance_la_census_tract.rds`
  It also produces CSI distribution plots, maps, and outlier visualizations.

### Green-space and built-environment preparation

- `code/prep_greenspace.R`
  Joins tract-level NDVI data to NYC and LA, creates tract-level NDVI files, and computes green-space access measures. Key outputs include:
  - `data/generated/ndvi_nyc_census_tract.rds`
  - `data/generated/ndvi_la_census_tract.rds`
  - `data/generated/cs_access_euclidean_nyc.rds`
  - `data/generated/cs_access_euclidean_la.rds`
  The script also contains exploratory work around PAD-US parks, water bodies, road networks, and tract centroids.

- `code/prep_building_density.R`
  Crops statewide building-area rasters to NYC and LA, extracts tract-level totals with `terra::extract()`, computes building density, and saves:
  - `data/generated/building_dens_nyc.rds`
  - `data/generated/building_dens_la.rds`

### Main modeling

- `code/models.R`
  Main nonlinear GAM analysis. It:
  - loads tract-level CSI, SES, NDVI, green-space access, and building-density data
  - assigns neighborhood labels by spatial intersection
  - builds a combined NYC/LA modeling dataset
  - creates ICE quintiles
  - fits GAMs for NDVI and distance-to-green-space outcomes
  - runs city-stratified, SES-stratified, no-outlier, and effect-modification analyses
  - exports many publication-style figures and interactive 3D surfaces

- `code/models_linear.R`
  Linear-model variant of the main analysis. It follows the same data assembly pattern but uses linear specifications for some analyses and writes:
  - `data/generated/data_models.rds`
  plus a parallel set of figures and HTML widgets.

- `code/models_sens_anal_functions.R`
  A sensitivity-analysis variant of the modeling workflow. It appears to rerun the main structure with alternate outcome families and settings, saving additional 3D widgets and figures.

### Neighboring-home annual-average workflow

- `code/prep_neighbor_visits_annual_average.R`
  Reads a prebuilt Dewey neighboring-home export, derives tract GEOIDs from destination CBGs, aggregates `CBG x month` rows to `tract x month`, then builds tract-level annual-average and annual-total mobility summaries. It joins those summaries onto the existing tract-level modeling dataset and saves both a tract summary file and a model-ready merged file.

- `code/models_neighbor_visits_annual_average.R`
  Fits neighboring-home GAMs using the tract-level annual-average dataset. It includes:
  - primary negative binomial count models with `HOME_DEVICE_COUNTS_TOTAL_PARSED` as the offset
  - fallback negative binomial count models with `DEVICE_COUNTS_ROW_TOTAL` as the offset
  - beta-regression share sensitivity models
  - pooled and city-specific fits for NYC and LA
  - saved model objects and smooth plots

- `code/plot_neighbor_visits_interactive_maps.R`
  Builds neighboring-home maps without any API dependency. It saves interactive `tmap` HTML maps and static `ggplot` PNG maps for NYC and LA for:
  - weighted neighboring-home share
  - total neighboring-home visits
  - total Dewey row-level visit counts
  Note: `tm_view(use_WebGL = FALSE)` is set explicitly. tmap 4 auto-enables WebGL via `leafgl` for datasets ≥ 500 rows, but `leafgl` does not encode per-polygon fill colors in saved HTML, causing all polygons to render grey. Disabling WebGL forces standard `leaflet::addPolygons` rendering which correctly embeds fill colors.

- `code/run_neighbor_visits_workflow.R`
  Driver script that runs the neighboring-home prep, modeling, and mapping steps in sequence from one command.

### Outcome model covariates

The current outcome models follow a common structure across outcomes. In all cases, the exposure is modeled as a smooth term:

- `s(community_severance_index, fx = FALSE)`

and local clustering is handled with:

- `s(neighborhood, bs = 're')`

Crude models use:

- `pop_dens`

Adjusted models use:

- `perc.black`
- `perc.hisp`
- `perc.pov`
- `pop_dens`
- `building_density`

Outcome-specific details:

- `NDVI`
  Uses the covariate sets above, plus the CSI smooth and neighborhood random effect.

- `closest_greenspace`
  Uses the same crude and adjusted covariate sets as `NDVI`.

- `neighbor_visit_count_annual_avg`
  Uses the same crude and adjusted covariate sets as the other outcomes, but also includes an exposure offset:
  - primary offset: `log(home_device_counts_total_parsed_annual_avg)`
  - fallback offset: `log(device_counts_row_total_annual_avg)`

- `neighbor_visit_share_annual_avg`
  Uses the same crude and adjusted covariate sets, but no offset because the share already contains the parsed denominator by construction.

City handling:

- pooled crude models can include `city`
- city-specific models are stratified to NYC or LA and therefore do not include `city` as a predictor

### Descriptive table workflow

- `code/table1_outcome_descriptives_neighbor_visits.R`
  Builds a manuscript-ready Table 1 for outcome variables only. The current outcome table includes:
  - `NDVI`
  - `closest_greenspace`
  - `neighbor_visit_count_annual_avg`
  - `neighbor_visit_share_annual_avg`

- `code/table_distribution_missingness_neighbor_visits.R`
  Builds a broader descriptive table for the exposure, selected tract-level covariates, and neighboring-home denominator variables used in offset-based models.

- `code/descriptive_tables.R`
  Wrapper script that runs both descriptive table generators in one command and writes CSV and LaTeX outputs.

### Mapping and descriptive outputs

- `code/plot_maps.R`
  Builds quantile maps for CSI and contextual variables such as poverty, population density, building density, race/ethnicity, NDVI, green-space distance, and ICE.

- `code/explore_ses.R`
  Creates descriptive summaries and ICE quintile maps/tables from the prepared SES/modeling dataset.

- `code/explore.R`
  Ad hoc exploratory analysis for correlations, missingness, and map production.

### Troubleshooting and prototype work

- `code/rgee_troubleshooting.R`
  Standalone experimentation with `rgee`, `GreenExp`, canopy cover, NDVI, land cover, and OSM tree data. This does not look like part of the main reproducible pipeline.

## Important generated datasets

The project already contains many intermediate artifacts in `data/generated/`. The most central ones appear to be:

- `ses_ice_nyc.rds`, `ses_ice_la.rds`
  Tract-level socioeconomic context and ICE variables.
- `csi_scores_nyc.rds`, `csi_scores_la.rds`
  Raw factor-analysis outputs used to represent community severance.
- `community_severance_nyc_census_tract.rds`, `community_severance_la_census_tract.rds`
  Tract-level community severance measures used in the downstream models.
- `ndvi_nyc_census_tract.rds`, `ndvi_la_census_tract.rds`
  Tract-level NDVI values.
- `cs_access_euclidean_nyc.rds`, `cs_access_euclidean_la.rds`
  Tract-level distance-to-green-space measures.
- `building_dens_nyc.rds`, `building_dens_la.rds`
  Tract-level building density.
- `dt_nyc_and_la_quintiles_ses.rds` and `data_models.rds`
  Combined analysis datasets used by the modeling and plotting scripts.
- `neighbor_visit_annual_average_2019_full_year_tract.rds`
  Tract-level neighboring-home annual-average and annual-total summary built from the full-year 2019 Dewey monthly export.
- `data_models_neighbor_visits_annual_average_2019_full_year.rds`
  Main tract-level model input for neighboring-home analyses after joining the Dewey summaries to the existing tract-level study dataset.
- `neighbor_visit_annual_average_model_objects_2019_full_year.rds`
  Bundle of pooled and by-city neighboring-home model fits.

## Suggested execution order

There is no single driver script, so the intended order is roughly:

1. `init_directory_structure.R`
2. `code/prep_ses.R`
3. `code/estimate_community_sev_index_nyc_updated.R`
4. `code/estimate_community_sev_index_la_updated.R`
5. `code/prep_csi.R`
6. `code/prep_greenspace.R`
7. `code/prep_building_density.R`
8. `code/models.R` or `code/models_linear.R`
9. `code/plot_maps.R` and `code/explore_ses.R`

To run the neighboring-home extension after `data_models.rds` already exists:

1. `code/prep_neighbor_visits_annual_average.R`
2. `code/models_neighbor_visits_annual_average.R`
3. `code/plot_neighbor_visits_interactive_maps.R`

Or run the full neighboring-home extension in one step:

1. `code/run_neighbor_visits_workflow.R <INPUT_PATH> [TARGET_YEAR] [START_MONTH] [END_MONTH] [OUTPUT_LABEL]`

Example:

```bash
Rscript code/run_neighbor_visits_workflow.R \
  /Users/jaimebenavides/claude_cowork/dewey_dta_walking/data/outputs/2019_neighbor_home/2019_full_year_neighbor_home_nyc_la_values.csv \
  2019 1 12 2019_full_year
```

To regenerate the manuscript descriptive tables from the neighboring-home model dataset:

```bash
Rscript code/descriptive_tables.R \
  data/generated/data_models_neighbor_visits_annual_average_2019_full_year.rds \
  2019_full_year
```

## Neighboring-home implementation status

The neighboring-home metric has now been integrated into this repo as a tract-level annual-average workflow.

What is implemented:

- direct use of a prebuilt Dewey export rather than rebuilding the metric
- derivation of tract GEOID from the first 11 digits of destination `AREA`
- aggregation from destination `CBG x month` to tract-level full-year annual summaries
- pooled and city-specific model runs for NYC and LA
- local `tmap` and `ggplot` maps with no Google Maps dependency
- manuscript-side documentation in `manuscript/neighbor_visit_modeling_decision_memo.md` and `manuscript/neighbor_visit_modeling_scenarios.md`
- manuscript methods updated in `manuscript/sn-article.tex` to describe:
  - the neighboring-home metric
  - the translation from destination `CBG x month` to tract-level annual summaries
  - the tract-level negative binomial modeling strategy
  - crude versus fully adjusted neighboring-home covariate sets
  - the offset-based rate interpretation for neighboring-home counts
- manuscript tables now use generated `.tex` files from `output/` via `\input{}`

Preferred 2019 neighboring-home inputs:

- monthly full-year file used by the main workflow:
  `/Users/jaimebenavides/claude_cowork/dewey_dta_walking/data/outputs/2019_neighbor_home/2019_full_year_neighbor_home_nyc_la_values.csv`
- precomputed annual-average file available but not used by the main workflow:
  `/Users/jaimebenavides/claude_cowork/dewey_dta_walking/data/outputs/2019_neighbor_home/2019_full_year_neighbor_home_nyc_la_annual_average.csv`

Why the monthly file is used:

- the repo’s existing annual-average workflow already expects `CBG x month` input
- it aggregates internally to tract-month and then tract-level annual summaries
- downstream outputs depend on monthly structure to compute:
  - tract-level annual averages
  - tract-level annual totals
  - weighted neighboring-home shares
  - `n_months_neighbor_visit`
- the precomputed annual-average file is suitable as a check, but it would replace the within-repo averaging step and remove some downstream totals

2019 full-year outputs currently present:

- `data/generated/neighbor_visit_annual_average_2019_full_year_tract.rds`
- `data/generated/neighbor_visit_annual_average_2019_full_year_tract.csv`
- `data/generated/data_models_neighbor_visits_annual_average_2019_full_year.rds`
- `data/generated/neighbor_visit_annual_average_model_objects_2019_full_year.rds`
- city-specific model objects for NYC and LA in `data/generated/neighbor_visit_*_2019_full_year.rds`
- map and model figure outputs in `output/`
- descriptive table outputs in `output/`:
  - `table1_outcome_descriptives_2019_full_year.csv`
  - `table1_outcome_descriptives_2019_full_year.tex`
  - `table_distribution_missingness_2019_full_year.csv`
  - `table_distribution_missingness_2019_full_year.tex`

Observed integration issues that were fixed:

- LA tract GEOIDs in the existing `data_models.rds` table were stored as 10-digit strings without a leading zero, while the Dewey-derived tract GEOIDs were proper 11-digit FIPS tract codes. The neighboring-home prep script now pads tract GEOIDs before joining, so both LA and NYC merge correctly.

- Interactive HTML maps rendered as all-grey polygons. Root cause: tmap 4 automatically switches to WebGL rendering via `leafgl` when a layer has ≥ 500 features. The `leafgl` backend does not embed per-polygon `fillColor` values in the saved HTML, so the continuous color scale is not applied. Fixed in `code/plot_neighbor_visits_interactive_maps.R` by adding `tm_view(use_WebGL = FALSE)` to each map object, forcing standard `leaflet::addPolygons` rendering. Two related tmap 4 API corrections were made at the same time: `values.repeat = TRUE` (not a valid `tm_scale_continuous` argument) was removed, and the polygon transparency argument was corrected from `alpha` to `fill_alpha`.

Current manuscript table structure:

- Table 1: outcomes only, including neighboring-home outcomes
- Table 2: exposure, selected covariates, and neighboring-home denominator variables

Next-session caveat:

- the manuscript compiles from generated LaTeX table files in `output/`, so if the source dataset changes, rerun `code/descriptive_tables.R` before updating the manuscript text or results tables

## Reproducibility notes

This project is only partially self-contained.

Several scripts reference data outside this repository with hard-coded paths like:

- `/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/data/...`
- `/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/workspace/...`

That means a fresh run will fail unless those external files are available or the scripts are edited to point to local equivalents.

Other practical notes:

- `code/packages/packages_to_load.R` tries to install missing packages automatically, but now skips that step with a warning if the active R library is not writable.
- Some scripts use Census APIs through `tidycensus`, so an API key may be required.
- Some objects already exist in `data/generated/`, which makes the repository usable for downstream analysis even if the raw external data are unavailable.
- A few scripts mix production code with exploratory sections; for a clean rerun, treat `models.R`, `models_linear.R`, `prep_ses.R`, `prep_csi.R`, `prep_greenspace.R`, and `prep_building_density.R` as the main pipeline.
- The neighboring-home extension depends on a Dewey export from the `dewey_dta_walking` repo or an equivalent local file with the expected schema.

## In plain language

This repository is analyzing whether neighborhoods with higher transportation-related community severance also have worse green-space conditions and potentially weaker realized local-access patterns. It does that by:

- deriving a latent community severance score from road and mobility features
- harmonizing that score with tract-level socioeconomic indicators
- measuring green-space quantity and access
- incorporating a Dewey neighboring-home mobility measure as a realized accessibility outcome
- testing whether the severance-green-space relationship differs across levels of socioeconomic disadvantage in NYC and LA

## Current state of the repo

The repository already contains many finished outputs in `output/`, including:

- CSI maps for NYC and LA
- ICE maps and quintile maps
- NDVI and green-space figures
- GAM effect plots
- interactive 3D HTML surfaces
- neighboring-home annual-average maps and city-specific model plots
- descriptive tables and correlation plots

So this folder is best understood as a working research analysis project with both code and already-generated study artifacts.
