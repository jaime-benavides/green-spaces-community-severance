# green_spaces_community_severance
Code repository for the project Community Severance and Green Space Accessibility in New York City and Los Angeles

note: please run init_directory_structure.R first to create folders. Also run this script before doing anything else, currently done via source(paste0(project.folder,'init_directory_structure.R'), to ensure that the folder locations are known in each script

## Code and data generated (file name - short description)

Scripts are labeled with their pipeline step, in run order. Steps with a letter suffix
(5b, 7b-7e, 8a-8k) run in parallel branches off the numbered step they extend, not strictly
sequentially, but always after the step whose number they share and before the next integer step.

### Data preparation list:

Step 1. prep_ses.R - ACS tract-level socioeconomic indicators and Index of Concentration at the Extremes (ICE)

- ses_ice_nyc.rds, ses_ice_la.rds - SES variables with sf geometry
- krieger_ice_nyc.rds, krieger_ice_la.rds - ICE indices
- acs_ses.rds - ACS summary object

Step 2. prep_csi.R - population-weighted Community Severance Index (CSI) aggregation to census tract

- community_severance_nyc_census_tract.rds
- community_severance_la_census_tract.rds

Step 3. prep_greenspace.R - NDVI and Euclidean distance to nearest public green space

- ndvi_nyc_census_tract.rds, ndvi_la_census_tract.rds
- cs_access_euclidean_nyc.rds, cs_access_euclidean_la.rds

Step 4. prep_building_density.R - tract-level building density

- building_dens_nyc.rds, building_dens_la.rds

Step 5b. prep_cbg_nh_combined.R - merges primary and supplementary Advan CBG-level neighboring-home (NH) files

- 2019_full_year_neighbor_home_nyc_la_cbg_combined.csv - single canonical CBG-level NH input for all downstream processing

Step 6. prep_neighbor_visits_annual_average.R - aggregates NH visits to tract-level annual averages; restricts to green-space CBGs

- data_models_neighbor_visits_annual_average_2019_full_year.rds - full modeling dataset joined with NH metrics
- neighbor_visit_annual_average_2019_full_year_tract.rds / .csv - tract-level NH metrics (green-space CBGs only)

### Statistical models list:

Step 5. models_linear.R - NDVI (Gaussian GAM) and proximity (Gamma GAM) models

- data_models.rds - base modeling dataset (N=3,312 tracts; NYC=2,164, LA=1,148)
- ndvi_model_objects_city_adjusted_linear.rds, ndvi_model_objects_city_crude_linear.rds
- greenspace_model_objects_city_adjusted_linear.rds, greenspace_model_objects_city_crude_linear.rds

Step 7. models_neighbor_visits_annual_average.R - neighboring-home visits GAMs (negative binomial)

- neighbor_visit_annual_average_model_objects_2019_full_year.rds - all model objects
- neighbor_visit_primary_fit_city_{nyc,la}_2019_full_year.rds - adjusted models
- neighbor_visit_primary_crude_fit_city_{nyc,la}_2019_full_year.rds - crude models
- neighbor_visit_ice_q1_q5_fit_2019_full_year.rds - ICE Q1/Q5 model objects

run_neighbor_visits_workflow.R - orchestrates prep_neighbor_visits_annual_average.R + models_neighbor_visits_annual_average.R (Steps 6-7)

### Figures and tables list:

Step 7b. generate_nh_ice_q1_q5_figure.R - NH ICE Q1/Q5 stratified figure

- models_result_neighbor_visit_q1_q5_ICE_inc_2019_full_year.png - NH ICE model object source (combined into Fig 4)

Step 7c. generate_linear_ice_outl_figures.R - NDVI/proximity ICE Q1/Q5 and outlier-excluded figures (primary manuscript figures)

- ndvi_ice_q1_q5_fit.rds, greenspace_ice_q1_q5_fit.rds - ICE Q1/Q5 model objects (used for Fig 4)
- models_result_ndvi_proximity_primary.png - Figure 3
- models_result_neighbor_visit_annual_avg_no_outliers_2019_full_year.png - Figure 2

Step 7e. regenerate_manuscript_figures.R - regenerates all manuscript smooth figures from saved model objects (no re-fitting), including Figure 4 and sensitivity Figures S3/S4

Step 7d. generate_figure1_maps.R - Figure 1 and supplementary spatial maps

- figure1_nh_csi_maps.png - Figure 1
- supp_map_ice_inc.png - Figure S1, panel (a)
- supp_map_ice_q1_q5.png - Figure S1, panel (b)

Step 8a. table1_outcome_descriptives_neighbor_visits.R - Table 1 (outcomes, exposure & covariates)

- table1_descriptives_2019_full_year.tex

Step 8b2. generate_supp_table_nh_missingness.R - Supplementary Table S1 (missing vs. analytic sample); reads `nh_exclusion_reason_diagnosis.csv` from `diagnose_nh_exclusion_reason.R` (Step 8b1, listed under Diagnostics below)

- supp_table_nh_missingness.tex

Step 8c. extract_numeric_results.R - Q25-to-Q75 quartile contrasts, the source of Table S2 and Results-text numbers

- numeric_results_quartile_contrasts.csv

Step 8c2. generate_supp_table_s2_per_iqr.R - Supplementary Table S2, generated from numeric_results_quartile_contrasts.csv

Step 8d. extract_outlier_exclusion_counts.R - "excluded tracts" numbers cited in-text

Step 8e. extract_tract_area_by_city.R - tract area by city, context for the LA-vs-NYC distance comparison

Step 8f. generate_supp_table_outlier_geography.R - Supplementary Table S3 (outlier-tract geography and built environment)

Step 8g. generate_nh_distribution_figure.R - NH visits distribution figure (Fig S2a)

Step 8h. extract_ice_nh_quartile_contrasts.R, extract_ice_ndvi_quartile_contrasts.R, extract_ice_distance_quartile_contrasts.R - ICE-stratified (Q1/Q5) quartile contrasts cited in §3.5

Step 8i. extract_ice_effect_modification_contrasts.R - ICE effect-modification statistics cited in §3.5

Step 8j. extract_ice_effect_modification_difference_contrasts.R - reads the three Step 8h CSVs to compute Q5-vs-Q1 difference contrasts, cited in §3.5

Step 8k. extract_manuscript_misc_counts.R - missingness/sample-size counts cited in-text; reads Step 8d's output

Step 9. run_manuscript_audit.R (local-only, not in this repo) - reruns every extraction/diagnostic script feeding a manifest of manuscript numeric claims and checks each against its computed source value

- output/manuscript_audit_results.csv

### Diagnostics list (not part of the manuscript pipeline, except as noted):

Step 8b1. diagnose_nh_exclusion_reason.R - diagnoses NH exclusion reasons; **its output is a required input to Step 8b2** (`generate_supp_table_nh_missingness.R`, Supplementary Table S1), so despite being framed as a diagnostic script it is part of the manuscript pipeline

Step 8l. inspect_table2_missingness.R - reproduces the check behind the Table 2 missingness footnote; **its output (`table2_missingness_diagnosis.csv`) is checked by Step 9's audit**, so despite being framed as a diagnostic script it is part of the manuscript pipeline

## Data (data) list:

### Self-generated (copied into data/raw/, description - file name - provenance):

CSI factor scores (LA) - data/raw/csi/csi_scores_la.rds - author's own community_severance_us PCP + factor-analysis pipeline

CSI factor scores (NYC) - data/raw/csi/csi_scores_nyc.rds - author's own community_severance_nyc PCP + factor-analysis pipeline

Pre-processed ACS estimates table - data/raw/acs/acs_dt.rds - author's own community_severance_nys_climate_change_mh pipeline

### Raw (description - file name - link to source)

#### demography

500 Cities city boundaries - CityBoundaries.shp - https://data.cdc.gov/500-Cities-Places/500-Cities-City-Boundaries/n44h-hy2j/about_data

EPA Smart Location Database - SmartLocationDatabase.gdb - https://www.epa.gov/smartgrowth/smart-location-mapping#SLD

NYC UHF42 neighborhood boundaries - UHF_42_DOHMH_2009.shp - https://www1.nyc.gov/site/doh/data/data-sets/maps-gis-data-files-for-download.page

LA Community Plan Area boundaries - Community_Plan_Areas.shp - https://geohub.lacity.org/datasets/85f6c625014a40ad9dfcfdaf9f751aae_0/explore

U.S. Census 2015-2019 ACS 5-year estimates - via tidycensus - https://walker-data.com/tidycensus/

U.S. Census 2020 Population Centers, tract-level mean centers (CA, NY) - CenPop2020_Mean_TR06.txt, CenPop2020_Mean_TR36.txt - https://www2.census.gov/geo/docs/reference/cenpop2020/tract/

#### green infrastructure

PAD-US Areas of Recreation (curated) - padus_ar.shp - Browning et al. 2022, https://www.nature.com/articles/s41597-022-01857-7 (obtained directly from the original authors)

Landsat-derived tract-level NDVI - NDVI_US_MajorCities_Tracts_2000_2010_2019.csv - Brochu et al. 2022, https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2022.841936/full (obtained directly from the original authors)

#### geometry

Freight Analysis Framework road network (FAF5), CSI input - FAF5Network.gdb - https://faf.ornl.gov/faf5/

NYC water body geometry (Planimetric Database) - NYC_Planimetrics_2022.gdb, layer Hydrography - https://data.cityofnewyork.us/City-Government/NYC-Planimetric-Database-Open-Space-Parks-/y6ja-fw4f/about_data

##### buildings

Building footprint density rasters - NewYork_sum.tif, California_sum.tif - direct outputs of Heris et al. 2020, https://www.nature.com/articles/s41597-020-0542-3

#### mobility

Advan Research Neighboring Home visits - 2019 full-year CBG files (NYC + LA) - accessed via Dewey Data platform; restricted, cannot be publicly shared due to data use restrictions

## Software

R (≥ 4.2). Package dependencies are loaded via `code/packages/packages_to_load.R`. Key packages: `mgcv`, `sf`, `tigris`, `tidycensus`, `tmap`, `data.table`.

## Reference

Benavides J, Zigler C, Usmani S, Kioumourtzoglou M-A. Community Severance and Green Space Accessibility in New York City and Los Angeles. Submitted.
