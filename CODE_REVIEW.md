# Code Review and Reproduction Guide  
# Community Severance & Green Space Accessibility

**Project:** `green_spaces_community_severance`  
**Purpose:** Maps every manuscript figure, table, and in-text number to the script that produces it, so a reviewer can check the code against `manuscript/sn-article.tex` without re-deriving the pipeline from scratch.  
**Audience:** A collaborator or external reviewer who has not worked on this project and wants to understand, verify, or reproduce the analysis from scratch.

---

## Raw data sources

Every input under `data/raw/` and on the external SSD falls into one of four categories:

**Self-generated — copied into `data/raw/` in this package**

| File | Description | Provenance |
|---|---|---|
| `data/raw/csi/csi_scores_la.rds` | LA CBG-level CSI factor scores | Author's own `community_severance_us` PCP + factor-analysis pipeline (§2.3). See `data/raw/csi/PROVENANCE.md`. |
| `data/raw/csi/csi_scores_nyc.rds` | NYC CBG-level CSI factor scores | Author's own `community_severance_nyc` PCP + factor-analysis pipeline (§2.3). See `data/raw/csi/PROVENANCE.md`. |
| `data/raw/acs/acs_dt.rds` | Pre-processed ACS estimates table (used by `prep_greenspace.R` for NYC water-body processing) | Author's own `community_severance_nys_climate_change_mh` pipeline. See `data/raw/acs/PROVENANCE.md`. |

**Publicly available — not copied (download from source if reproducing Steps 1–5 from raw data)**

| File | Description | Source |
|---|---|---|
| `data/raw/demography/500Cities_City_11082016/CityBoundaries.shp` | City boundary polygons (§2.1) | [CDC 500 Cities: City Boundaries](https://data.cdc.gov/500-Cities-Places/500-Cities-City-Boundaries/n44h-hy2j/about_data) |
| `data/raw/demography/SmartLocationDatabaseV3/SmartLocationDatabase.gdb` | EPA Smart Location Database (built-environment covariates) | [EPA Smart Location Mapping](https://www.epa.gov/smartgrowth/smart-location-mapping#SLD) |
| `data/raw/geometry/FAF5Network.gdb` | Freight Analysis Framework road network (CSI input) | [ORNL Freight Analysis Framework (FAF5)](https://faf.ornl.gov/faf5/) |
| `data/raw/demography/Community_Plan_Areas_la/Community_Plan_Areas.shp` | LA Community Plan Area boundaries (neighborhood random-effect unit, §2.4) | [LA GeoHub: Community Plan Areas](https://geohub.lacity.org/datasets/85f6c625014a40ad9dfcfdaf9f751aae_0/explore) |
| `data/raw/demography/uhf42_dohmh_2009/UHF_42_DOHMH_2009.shp` | NYC UHF42 neighborhood boundaries (neighborhood random-effect unit, §2.4) | [NYC DOHMH: Maps and GIS Data Files for Download](https://www1.nyc.gov/site/doh/data/data-sets/maps-gis-data-files-for-download.page) |
| `data/raw/geometry/NYC_Planimetrics_2022.gdb` (layer `Hydrography`) | NYC water body geometry | [NYC Open Data: NYC Planimetric Database — Open Space (Parks)](https://data.cityofnewyork.us/City-Government/NYC-Planimetric-Database-Open-Space-Parks-/y6ja-fw4f/about_data) |
| `data/raw/geometry/buildings/{NewYork,California}_sum.tif` | Building footprint density rasters (§2.4) | Direct outputs of \citet{Heris2020ARasterized}, [Nature Sci Data paper](https://www.nature.com/articles/s41597-020-0542-3) — download the New York and California state rasters from the dataset linked in that paper |
| `data/raw/demography/us/census_tracts/CenPop2020_Mean_TR06.txt`, `CenPop2020_Mean_TR36.txt` | 2020 Census population-weighted tract mean centers (CA, NY) — used for Euclidean distance to green space (§2.2) | [Census Bureau: 2020 Population Centers, tract level](https://www2.census.gov/geo/docs/reference/cenpop2020/tract/) |

**Third-party research data — access via original publication, no direct file download link**

| File | Description | Notes |
|---|---|---|
| `data/raw/green_infrastructure/padus_ar.shp` | PAD-US AR (accessible/recreational green space polygons, §2.2) | Curated by \citet{Browning2022ThePAD}, [Nature Sci Data paper](https://www.nature.com/articles/s41597-022-01857-7); the AR-curated version has no separate direct-download link distinct from the paper's own data-availability statement — obtained directly from the original authors. Contact the corresponding author for access if reproducing Steps 3/6 from raw data. |
| `data/raw/green_infrastructure/NDVI_US_MajorCities_Tracts_2000_2010_2019.csv` | Pre-computed tract-level NDVI, 2000/2010/2019 | From \citet{Brochu2022Benefits}, [Frontiers in Public Health paper](https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2022.841936/full); no separate direct-download link for the tract-level file — obtained directly from the original authors. |

**Restricted / licensed — cannot be redistributed**

| File | Description | Notes |
|---|---|---|
| `data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv` (and its two source CBG-level CSVs) | Advan Research neighboring-home visit counts (§2.2) | Accessed via the Dewey Data platform; data use restrictions prohibit public redistribution. See "Data: the Advan Research input files" below. |

---

## What this study does

This study asks: do neighborhoods with more road infrastructure and traffic have less access to green space? It uses census tracts across New York City (NYC) and Los Angeles (LA) in 2019.

**The exposure** is the Community Severance Index (CSI) — a composite score derived from road lanes, traffic volume, and pedestrian infrastructure. Higher values mean more severance. It is measured at census block group (CBG) level and aggregated to census tracts.

**The three outcomes** measure green space accessibility in complementary ways:

| Outcome | What it measures | Source |
|---------|-----------------|--------|
| Neighboring-home visits count | How often devices from nearby home CBGs visit a destination tract (restricted to green-space CBGs intersecting PAD-US AR) — a behavioral measure of realized local green space accessibility | Advan Research / Dewey Data (mobile location data) |
| NDVI | Normalized Difference Vegetation Index — how much vegetation is present in a tract | Landsat satellite imagery |
| Distance to nearest green space | Euclidean distance from the population-weighted centroid of a tract to the edge of the nearest public green space (PAD-US AR) | PAD-US AR shapefile |

**The models** are Generalized Additive Models (GAMs) with a flexible spline on CSI, estimated separately for NYC and LA. The main analysis uses fully adjusted models for all three outcomes. Two sensitivity analyses and one secondary analysis are conducted for all three outcomes:

| Analysis | Description | Figures |
|----------|-------------|---------|
| **Main** (adjusted, outlier-excluded) | Full covariate adjustment; tracts with \|z_CSI\| > 2 (city-specific) excluded | Figs 2, 3 |
| **Sensitivity 1** (crude) | Only population density + neighborhood RE; same outlier exclusion | Figs S3a, S3b |
| **Sensitivity 2** (full sample) | Adjusted; all tracts including extreme-CSI | Figs S4a, S4b |
| **Secondary** (ICE stratification) | Outlier-excluded within each stratum; separate models for ICE Q1 and Q5 | Fig 4 |

---

## Manuscript section → code

Use this table to jump straight from a paragraph in `manuscript/sn-article.tex` to the script(s) that produced it, without reading the full step-by-step guide below.

| Manuscript section | What it covers | Script(s) |
|---|---|---|
| §2.1 Study area | City boundaries, census tracts as unit of analysis | `prep_ses.R` (Step 1), `generate_figure1_maps.R` (Step 7d, city boundary clipping) |
| §2.2 Green spaces and accessibility metrics | NH visits definition; NDVI; distance to nearest green space | `prep_greenspace.R` (Step 3, NDVI + distance); `prep_cbg_nh_combined.R` (Step 5b) + `prep_neighbor_visits_annual_average.R` (Step 6, NH metric) |
| §2.3 Community Severance Index | CSI aggregation to tract | `prep_csi.R` (Step 2) |
| §2.4 Covariates | %Black, %Hispanic, %poverty, pop. density, building density, ICE, neighborhood random-effect units | `prep_ses.R` (Step 1, ACS covariates + ICE); `prep_building_density.R` (Step 4); `models_linear.R` (Step 5, neighborhood spatial join) |
| §2.5 Statistical analysis | GAMM specifications, offset, outlier exclusion, quartile-segment contrasts | `models_linear.R` (Step 5, NDVI/proximity); `models_neighbor_visits_annual_average.R` (Step 7, NH); `generate_linear_ice_outl_figures.R` (Step 7c, outlier-excluded primary models); `extract_numeric_results.R` (Step 8c, quartile contrasts); `extract_outlier_exclusion_counts.R` (Step 8d, exclusion counts cited in-text) |
| §2.6 Sensitivity analyses | Crude (reduced-covariate) models; full-sample (outlier-included) models | `models_linear.R` / `models_neighbor_visits_annual_average.R` (crude and full-sample fits); `regenerate_manuscript_figures.R` (Step 7e, Figs S3/S4) |
| §2.7 Secondary analyses (ICE stratification) | Q1/Q5 economic-polarization stratified models and contrasts | `generate_nh_ice_q1_q5_figure.R` (Step 7b, NH); `generate_linear_ice_outl_figures.R` (Step 7c, NDVI/proximity); `extract_ice_nh_quartile_contrasts.R`, `extract_ice_ndvi_quartile_contrasts.R`, `extract_ice_distance_quartile_contrasts.R`, `extract_ice_effect_modification_difference_contrasts.R` (see ICE-stratified sections below) |
| §3.1 Descriptive statistics | Table 1; Figure 1 maps; missingness counts | `table1_outcome_descriptives_neighbor_visits.R` (Step 8a); `generate_figure1_maps.R` (Step 7d, Figs 1 and S1); `extract_manuscript_misc_counts.R` (missingness/sample-size counts) |
| §3.2 Main analysis (neighboring-home visits) | Fig 2; primary NH quartile contrasts and exclusion counts | `generate_linear_ice_outl_figures.R` (Step 7c, Fig 2); `extract_numeric_results.R` (Step 8c); `extract_outlier_exclusion_counts.R` (Step 8d) |
| §3.3 Complementary analyses (NDVI and proximity) | Fig 3; NDVI/proximity quartile contrasts | `generate_linear_ice_outl_figures.R` (Step 7c, Fig 3); `extract_numeric_results.R` (Step 8c) |
| §3.4 Sensitivity analyses | Figs S3, S4; outlier-tract geography table | `regenerate_manuscript_figures.R` (Step 7e); `generate_supp_table_outlier_geography.R` (Step 8f) |
| §3.5 Secondary analysis | Fig 4; ICE Q1/Q5 within-stratum and Q5-vs-Q1 contrasts | `regenerate_manuscript_figures.R` (Step 7e, Fig 4); ICE-stratified extraction scripts (see "ICE-stratified" sections below) |

---

## Prerequisites

### Software

- **R** (≥ 4.2 recommended) with the packages listed in §7 below.
- **LaTeX** with the `sn-jnl` class (the class file `sn-jnl.cls` is already in `manuscript/`). Compile from within the `manuscript/` directory.

### Data: what requires the external SSD

Most raw inputs live on an external SSD (`/Volumes/Extreme SSD/`). **If the SSD is not mounted, Steps 1–5 cannot be run.** However, all outputs from those steps already exist in `data/generated/`, so the analysis from Step 6 onward can be reproduced without the SSD.

| Needs SSD | Scripts |
|-----------|---------|
| ✅ Yes | `prep_ses.R`, `prep_csi.R`, `prep_greenspace.R`, `prep_building_density.R`, `models_linear.R`, `prep_neighbor_visits_annual_average.R` (PAD-US AR shapefile) |
| ❌ No | `prep_cbg_nh_combined.R`, `models_neighbor_visits_annual_average.R`, `generate_nh_ice_q1_q5_figure.R`, `generate_linear_ice_outl_figures.R`, `regenerate_manuscript_figures.R`, `generate_figure1_maps.R`, `generate_nh_distribution_figure.R`, `table1_outcome_descriptives_neighbor_visits.R`, `generate_supp_table_nh_missingness.R`, `extract_numeric_results.R`, `inspect_table2_missingness.R` |
| ✅ Yes | `diagnose_nh_exclusion_reason.R` (PAD-US AR shapefile) — its output feeds Step 8b2 (Supplementary Table S1), part of the manuscript pipeline |

> **Note:** `generate_linear_ice_outl_figures.R` reads `data_models.rds`, which was produced by `models_linear.R` (SSD-dependent). The file already exists in `data/generated/`, so the script itself does not need the SSD to run.

> **Note:** `prep_csi.R` and `prep_greenspace.R` are marked "✅ Yes" above because they still read city boundaries, the Smart Location Database, the FAF5 network, NYC water body geometry, and PAD-US AR from the SSD — see "Raw data sources" at the top of this document. Their CSI-factor-score and ACS-table inputs, however, are self-generated files bundled in `data/raw/csi/` and `data/raw/acs/` and do not require the SSD.

### Data: the Advan Research input files

The neighboring-home visits workflow uses CBG-level data from two archival files produced by the `dewey_dta_walking` project. Step 5b merges them into a single canonical file:

```
data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv
```

This combined file contains one row per CBG (primary + supplementary sources, all 12-month complete CBGs). It is the input to Step 6. The file cannot be publicly shared due to data use restrictions; it must be present locally to run Steps 5b–7.

Alternatively, the pre-processed modeling dataset already exists at:
```
data/generated/data_models_neighbor_visits_annual_average_2019_full_year.rds
```
If this file exists, you can skip directly to Step 7.

---

## How the code is organized

```
code/
  prep_ses.R                                      # Step 1 — SES & ICE indices
  prep_csi.R                                      # Step 2 — CSI aggregated to tract
  prep_greenspace.R                               # Step 3 — NDVI and proximity
  prep_building_density.R                         # Step 4 — building density
  models_linear.R                                 # Step 5 — NDVI and proximity GAMs
  prep_cbg_nh_combined.R                          # Step 5b — merge primary + supplementary CBG NH files
  prep_neighbor_visits_annual_average.R           # Step 6 — NH metric preparation (reads Step 5b output)
  run_neighbor_visits_workflow.R                  # Step 6 (orchestrator)
  models_neighbor_visits_annual_average.R         # Step 7 — NH GAMs
  generate_nh_ice_q1_q5_figure.R                 # Step 7b — NH ICE Q1/Q5 model fitting (saves .rds for Fig 4)
  generate_linear_ice_outl_figures.R              # Step 7c — primary figures (Figs 2, 3) and NDVI/proximity ICE .rds (used in Fig 4)
  regenerate_manuscript_figures.R                 # Step 7e — quick regeneration of all 9 smooth figures from saved .rds; no model re-fitting
  generate_figure1_maps.R                         # Step 7d — Figure 1 (2-row × 4-col: LA/NYC rows, NH/NDVI/proximity/CSI columns) and supplementary maps (Fig S1)
  table1_outcome_descriptives_neighbor_visits.R   # Step 8a — Table 1 (outcomes, exposure & covariates)
  generate_supp_table_nh_missingness.R             # Step 8b2 — Supplementary Table S1 (missing vs. analytic sample)
  extract_numeric_results.R                       # Step 8c — writes numeric_results_quartile_contrasts.csv, the source of Table S2 and Results-text numbers
  generate_supp_table_s2_per_iqr.R                 # Step 8c2 — Supplementary Table S2, generated from numeric_results_quartile_contrasts.csv
  generate_nh_distribution_figure.R               # Step 8g — NH visits distribution figure (Fig S2a)
  diagnose_nh_exclusion_reason.R                   # Step 8b1 — classifies each excluded tract's reason (structural: no green-space CBG; data gap: incomplete months; no CBG data at all); output feeds Step 8b2
  inspect_table2_missingness.R                     # Step 8l — reproduces the Table 2 missingness footnote check; output is checked by Step 9's audit
  functions/functions.R                           # Shared GAM helper functions

data/
  raw/neigh_home/          # Advan Research input files (restricted)
  generated/               # All intermediate .rds files (already computed)

output/                    # Figures (.png) and tables (.tex, .csv)

manuscript/
  sn-article.tex           # Main manuscript
  sn-bibliography.bib      # Reference list
  sn-jnl.cls               # Springer Nature LaTeX class (already here)
```

---

## Step-by-step reproduction

### Before you start: verify generated files exist

If you only want to reproduce the outputs that do not require the SSD (Steps 6–9), first confirm these files are present:

```bash
ls data/generated/data_models.rds
ls data/generated/data_models_neighbor_visits_annual_average_2019_full_year.rds
ls data/generated/ndvi_model_objects_city_adjusted_linear.rds
ls data/generated/ndvi_model_objects_city_crude_linear.rds
ls data/generated/greenspace_model_objects_city_adjusted_linear.rds
ls data/generated/greenspace_model_objects_city_crude_linear.rds
ls data/generated/neighbor_visit_primary_fit_city_la_2019_full_year.rds
ls data/generated/neighbor_visit_primary_fit_city_nyc_2019_full_year.rds
ls data/generated/city_boundary_nyc.rds
ls data/generated/city_boundary_la.rds
```

All of these should exist. If they do, go directly to Step 8c to regenerate the numeric results, or Step 7 to re-fit the NH models.

> **Note on city boundary files:** `city_boundary_nyc.rds` and `city_boundary_la.rds` were extracted once from the 500 Cities project shapefile (SSD-dependent) and saved to `data/generated/`. They are used by Step 7d to clip tract geometries to city land area. If they are missing and the SSD is not available, run the extraction block in `prep_ses.R` (lines 38–46) with the SSD mounted, or adapt `generate_figure1_maps.R` to skip clipping.

---

### Step 1 — Prepare SES and ICE indices

**Script:** `code/prep_ses.R`  
**Requires:** External SSD mounted; Census API key set via `tidycensus::census_api_key()`.  
**What it does:** Downloads 2015–2019 ACS 5-year estimates at tract level for NYC and LA. Computes ICE (income), % Black, % Hispanic, % poverty, and population density at the census tract level.

**Outputs written to `data/generated/`:**
- `ses_ice_nyc.rds`, `ses_ice_la.rds` — SES variables with sf geometry
- `krieger_ice_nyc.rds`, `krieger_ice_la.rds` — ICE indices
- `acs_ses.rds` — ACS summary object

**Run:**
```r
source("code/prep_ses.R")
```

---

### Step 2 — Aggregate CSI to census tract

**Script:** `code/prep_csi.R`  
**Requires:** External SSD (for the 500 Cities city boundaries, Smart Location Database, and FAF5 network); `krieger_ice_nyc.rds` and `krieger_ice_la.rds` from Step 1; pre-computed CBG-level CSI scores (`data/raw/csi/csi_scores_nyc.rds`, `data/raw/csi/csi_scores_la.rds` — the author's own `community_severance_nyc`/`community_severance_us` PCP + factor-analysis pipeline; see `data/raw/csi/PROVENANCE.md`).  
**What it does:** Takes CSI factor scores at the CBG level and uses population-weighted spatial interpolation (`tidycensus::interpolate_pw()`) to aggregate them to census tracts. The CSI measures the degree to which road infrastructure and traffic sever local community connectivity.

**Key note:** Outlier z-scores computed here are **city-specific** (separate mean/SD for NYC and LA). Step 5 (`models_linear.R`) also uses city-specific z-scores — these are consistent.

**Outputs written to `data/generated/`:**
- `community_severance_nyc_census_tract.rds`
- `community_severance_la_census_tract.rds`

**Run:**
```r
source("code/prep_csi.R")
```

---

### Step 3 — Prepare green space measures

**Script:** `code/prep_greenspace.R`  
**Requires:** External SSD; NDVI CSV (`NDVI_US_MajorCities_Tracts_2000_2010_2019.csv`); PAD-US AR shapefile; population-weighted centroid text files (Census Bureau).  
**What it does:**
- Joins pre-computed tract-level NDVI values (from Landsat 2019) to census tract geometries.
- Computes the Euclidean distance from each tract's population-weighted centroid to the **edge** of the nearest PAD-US AR public green space polygon. Only green spaces ≥ 400 m² are included. A 10 km buffer extends beyond city boundaries to capture nearby parks.
- 94 tracts (LA = 28, NYC = 66) whose centroid falls **inside** a green space polygon receive distance = 0 (flagged as `inside_flag`). These are later recoded to 1 m before Gamma model fitting.

**Outputs written to `data/generated/`:**
- `ndvi_nyc_census_tract.rds`, `ndvi_la_census_tract.rds`
- `cs_access_euclidean_nyc.rds`, `cs_access_euclidean_la.rds`

**Run:**
```r
source("code/prep_greenspace.R")
```

---

### Step 4 — Prepare building density

**Script:** `code/prep_building_density.R`  
**Requires:** Building footprint data (on SSD).  
**What it does:** Computes building footprint area per census tract, used as a covariate in adjusted models.

**Outputs written to `data/generated/`:**
- `building_dens_nyc.rds`, `building_dens_la.rds`

**Run:**
```r
source("code/prep_building_density.R")
```

---

### Step 5 — Fit NDVI and proximity GAMs

**Script:** `code/models_linear.R`  
**Requires:** External SSD (for neighborhood boundary shapefiles); outputs from Steps 1–4.  
**What it does:**
1. Loads all datasets and spatially joins tracts to neighborhood boundaries (NYC: UHF42 neighborhoods; LA: Community Plan Areas) using the largest-intersection-area rule. Neighborhood is used as a random intercept in all GAMs.
2. Strips the leading `0` from raw 11-digit LA GEOIDs using `substring(la_csi$GEOID, 2)` to produce 10-character GEOIDs used consistently throughout the join chain. The NH workflow restores these to 11 digits via `pad_geoid(..., 11)` before joining.
3. Assigns ICE quintiles using `ntile()` within each city (`group_by(city)`) so that Q1/Q5 boundaries are city-specific and consistent with the city-stratified analysis throughout.
4. Identifies outlier tracts where `|z_csi| > 2` using **city-specific** z-scores (separate mean/SD per city). These are excluded in the crude sensitivity models (Figs S3a and S3b), matching the outlier exclusion used by the primary/adjusted models (Figs 2, 3). The full-sample sensitivity models (Figs S4a and S4b) are the ones that include outlier tracts by design.
5. Saves the combined modeling dataset as `data_models.rds` **before** any recoding.
6. Recodes `closest_greenspace == 0` to 1 metre (for 94 tracts, LA = 28 / NYC = 66, whose centroid is inside a green space polygon) before fitting Gamma models.
7. Fits all NDVI (Gaussian, identity link) and proximity (Gamma, log link) GAMs, including crude, adjusted, outlier-excluded, by-city, and ICE-stratified specifications.
8. Saves city-specific model objects for use by `extract_numeric_results.R`.

**Model specifications:**

| Model | Family | Link | Covariates | Purpose |
|-------|--------|------|-----------|---------|
| Adjusted, outlier-excluded | Gaussian or Gamma | identity or log | `s(CSI)` + `pop_density` + `s(nbhd, bs='re')` + `%Black` + `%Hispanic` + `%poverty` + `building_density`; excludes \|z_CSI\| > 2 | **Main result** (Fig 3 combined: top NDVI, bottom proximity) |
| Crude, outlier-excluded | Gaussian or Gamma | identity or log | `s(CSI)` + `pop_density` + `s(nbhd, bs='re')`; same outlier exclusion | **Sensitivity 1** (Fig S3b combined: top NDVI, bottom proximity) |
| Adjusted, full sample | Gaussian or Gamma | same | Same as adjusted; includes all tracts | **Sensitivity 2** (Fig S4b combined: top NDVI, bottom proximity) |
| ICE Q1/Q5, outlier-excluded | Adjusted | same | Same as adjusted; outlier exclusion applied within each stratum; run separately on Q1 and Q5 | **Secondary** (Fig 4, middle and bottom rows) |

**Outputs written to `data/generated/`:**
- `data_models.rds` — base modeling dataset (N=3,312 tracts; NYC=2,164, LA=1,148)
- `ndvi_model_objects_city_adjusted_linear.rds` — list of city-specific adjusted NDVI GAMs
- `ndvi_model_objects_city_crude_linear.rds` — list of city-specific crude NDVI GAMs
- `greenspace_model_objects_city_adjusted_linear.rds` — list of city-specific adjusted proximity GAMs
- `greenspace_model_objects_city_crude_linear.rds` — list of city-specific crude proximity GAMs

**Figures written to `output/` (via `regenerate_manuscript_figures.R`):**

| File | Manuscript reference |
|------|---------------------|
| `models_result_ndvi_proximity_full_sample.png` | Fig S4b (combined: top NDVI, bottom proximity) |
| `models_result_ndvi_proximity_crude.png` | Fig S3b (combined: top NDVI, bottom proximity) |

> **Note:** The model objects from this step are loaded by `regenerate_manuscript_figures.R` (Step 7e) to regenerate the actual manuscript figures with correct styling. The primary outlier-excluded figure (Fig 3) is produced by `generate_linear_ice_outl_figures.R` (Step 7c); the NDVI and proximity ICE Q1/Q5 .rds files from Step 7c are also used by Step 7e to compose Fig 4.

**Run:**
```r
source("code/models_linear.R")
```

---

### Step 5b — Merge primary and supplementary CBG NH files

**Script:** `code/prep_cbg_nh_combined.R`  
**Requires:** Two archival CBG-level CSV files from the `dewey_dta_walking` project, copied into `data/raw/neigh_home/` (see PROVENANCE.md there).  
**What it does:**

The Advan Research neighboring-home data was produced in two separate pipeline runs stored in the `dewey_dta_walking` project:

| Source | File | CBGs | Tracts | Notes |
|--------|------|------|--------|-------|
| Primary | `2019_full_year_neighbor_home_nyc_la_annual_average.csv` | 15,483 | 5,434 | Main Advan Neighborhood Patterns Plus run; has `city` column |
| Supplementary | `2019_full_year_neighbor_home_supplementary_annual_average.csv` | 949 | 258 | Second run covering tracts absent from primary; `city` column is NA (inferred from state FIPS) |

The two sources have zero CBG overlap by design. The script harmonises column names, infers `city` for the supplementary source from state FIPS (06xxx → LA, 36xxx → NYC), includes `months_present` for downstream filtering, and writes the merged file to:

```
data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv
```

Key columns retained: `GEOID_CBG` (12-digit), `TRACT_GEOID` (11-digit), `city`, `nh_source`, `months_present`, `avg_neighbor_home_device_counts`, `avg_home_device_counts_total_parsed`, `avg_device_counts_row_total`.

This combined file is the single canonical CBG-level input for all downstream NH processing. Step 6 always reads from it.

**Run:**
```r
source("code/prep_cbg_nh_combined.R")
```

---

### Step 6 — Prepare the neighboring-home visits metric

**Script:** `code/prep_neighbor_visits_annual_average.R`  
**Requires:** `data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv` from Step 5b; `data_models.rds` from Step 5; PAD-US AR shapefile (SSD); `krieger_ice_{nyc,la}.rds` (already in `data/generated/`).  
**What it does:**

The neighboring-home (NH) metric measures, for each destination census tract, how many device visits came from devices whose home CBG is within 0.5 miles (804 m) of the destination, restricted to destination CBGs that contain publicly accessible green space (PAD-US AR). This restriction aligns the behavioral metric with green space use rather than general local mobility.

**CBG inclusion criteria (both must hold):**
1. `months_present == 12` — full-year temporal coverage
2. CBG geometry intersects at least one PAD-US AR polygon — destination contains accessible green space

**Aggregation to tract level** (summing from qualifying CBGs):
- `neighbor_visit_count_annual_avg` = Σ `avg_neighbor_home_device_counts`
- `home_device_counts_total_parsed_annual_avg` = Σ `avg_home_device_counts_total_parsed`
- `device_counts_row_total_annual_avg` = Σ `avg_device_counts_row_total`

Both the outcome and the model offset (`log(home_device_counts_total_parsed_annual_avg)`) are computed from the same set of green-space CBGs, so the models run unchanged.

**Tract inclusion criterion:** A tract is included in the NH analytic sample only if at least one of its constituent CBGs meets both criteria above (`has_greenspace_tract == TRUE`). Tracts with no qualifying CBGs receive `NA` on the outcome and are excluded by the complete-case filter in Step 7.

The script downloads 2019 TIGER CBG geometries via `tigris` (cached), intersects them with the PAD-US AR shapefile, and joins the green-space flag to the NH data before aggregating.

**Outputs written to `data/generated/`:**
- `data_models_neighbor_visits_annual_average_2019_full_year.rds` — full modeling dataset joined with NH metrics and `has_greenspace_tract` flag
- `neighbor_visit_annual_average_2019_full_year_tract.rds` / `.csv` — tract-level NH metrics (green-space CBGs only)

**Run:**
```r
source("code/prep_neighbor_visits_annual_average.R")
```

---

### Step 7 — Fit the neighboring-home GAMs

**Script:** `code/models_neighbor_visits_annual_average.R`  
**Requires:** `data_models_neighbor_visits_annual_average_2019_full_year.rds` from Step 6.  
**What it does:** Fits GAMs for the NH outcome separately by city. Three model variants plus ICE-stratified models are fit:

| Model | Outcome | Family | Offset | Purpose |
|-------|---------|--------|--------|---------|
| Primary adjusted | `neighbor_visit_count_annual_avg` | Negative Binomial | `log(home_device_counts_total_parsed_annual_avg)` | **Main result** (Figs 2) |
| Primary crude | same | Negative Binomial | same | **Sensitivity 1** (crude; Fig S3a) |
| Outlier-excluded | same | Negative Binomial | same | **Main result** (Fig 2) — **fit in Step 7c**, not here |
| Fallback | same | Negative Binomial | `log(device_counts_row_total_annual_avg)` | Alternative offset robustness check |
| Share | `neighbor_visit_share_annual_avg` | Beta regression | — | Additional robustness check — not in manuscript (`other_analysis/`) |
| ICE Q1 by city | `neighbor_visit_count_annual_avg` | Negative Binomial | same as primary | **Secondary** — most disadvantaged tracts (Fig 4, top row) |
| ICE Q5 by city | same | same | same | **Secondary** — most advantaged tracts (Fig 4, top row) |

The offset `log(home_device_counts_total_parsed_annual_avg)` is the log of the mean monthly total parsed home-origin device count. This makes the model estimate the rate of neighboring-home visits relative to total nearby device activity.

The ICE Q1/Q5 models cannot use `fit_by()` because it does not forward the `offset_var` argument. They are fit via `split(data, city)` + `lapply` to run city-specific models on each income stratum directly.

**Outputs written to `output/` (via `regenerate_manuscript_figures.R`):**

| File | Manuscript reference |
|------|---------------------|
| `models_result_neighbor_visit_annual_avg_primary_crude_2019_full_year.png` | Fig S3a (crude sensitivity) |
| `models_result_neighbor_visit_annual_avg_primary_adjusted_2019_full_year.png` | Fig S4a (full-sample sensitivity) |
| `models_result_neighbor_visit_annual_avg_share_adjusted_2019_full_year.png` | Not in manuscript |

> **Note:** The PRIMARY NH figure (Fig 2) uses the **outlier-excluded** model from Step 7c, not the full-sample model from this step. Fig S4a is the full-sample (Sensitivity 2) NH figure; Fig S3a is the crude (Sensitivity 1) NH figure.
>
> **GAM spline edf:** Primary outlier-excluded models (Fig 2) have spline edf ≈ 1.0 (LA: 1.024; NYC: 1.016), indicating effectively linear CSI–NH associations after covariate adjustment. Crude outlier-excluded models (Fig S3a) have substantially higher edf (LA: 1.23; NYC: 1.26). The full-sample adjusted models (Fig S4a) also show elevated edf (LA: 2.40; NYC: 3.70), consistent with influential high-leverage tracts pulling the spline.

**Outputs written to `data/generated/`:**
- `neighbor_visit_annual_average_model_objects_2019_full_year.rds` — all model objects
- `neighbor_visit_primary_fit_city_nyc_2019_full_year.rds` — adjusted NYC model
- `neighbor_visit_primary_fit_city_la_2019_full_year.rds` — adjusted LA model
- `neighbor_visit_primary_crude_fit_city_nyc_2019_full_year.rds` — crude NYC model
- `neighbor_visit_primary_crude_fit_city_la_2019_full_year.rds` — crude LA model
- `neighbor_visit_ice_q1_q5_fit_2019_full_year.rds` — ICE Q1/Q5 model objects

**Run:**
```r
source("code/models_neighbor_visits_annual_average.R")
```

---

### Step 7b — Generate NH ICE Q1/Q5 figure

**Script:** `code/generate_nh_ice_q1_q5_figure.R`  
**Requires:** `data_models_neighbor_visits_annual_average_2019_full_year.rds` from Step 6. **No SSD required.**  
**What it does:** Fits city-specific negative binomial GAMs for the NH outcome separately for Q1 (most disadvantaged) and Q5 (most advantaged) ICE income quintile tracts, using `split(data, city)` + `lapply` (not `fit_by()`, which does not forward the offset). Saves model objects and generates the combined figure.

**Outputs:**
- `data/generated/neighbor_visit_ice_q1_q5_fit_2019_full_year.rds` — model objects
- `output/models_result_neighbor_visit_q1_q5_ICE_inc_2019_full_year.png` — NH ICE model object source (combined into Fig 4 by Step 7e)

**Run:**
```r
source("code/generate_nh_ice_q1_q5_figure.R")
```

---

### Step 7c — Generate primary figures and ICE Q1/Q5 (outlier-excluded)

**Script:** `code/generate_linear_ice_outl_figures.R`  
**Requires:** `data_models.rds` from Step 5. **No SSD required** (the file already exists).  
**What it does:** Re-fits five groups of models from saved datasets, all applying city-specific outlier exclusion (|z_CSI| > 2):
1. NDVI GAMs for ICE Q1 and Q5 tracts by city (outlier-excluded within each stratum) → saves .rds for **Fig 4** (middle row, via Step 7e)
2. Proximity Gamma GAMs for ICE Q1 and Q5 tracts by city (outlier-excluded within each stratum) → saves .rds for **Fig 4** (bottom row, via Step 7e)
3. NDVI + proximity GAMs excluding CSI outliers → saves .rds for **Fig 3** (combined primary figure: top row NDVI, bottom row proximity, via Step 7e)
4. NH negative binomial GAMs excluding CSI outliers → **Fig 2** (primary NH figure)

Fig 2 uses `plot_city_comparison()` directly. ICE .rds files (items 1–2) are consumed by Step 7e's `plot_ice_overlay()`. NDVI/proximity .rds files (item 3) are consumed by Step 7e's `plot_city_comparison()`.

**Outputs:**
- `data/generated/ndvi_ice_q1_q5_fit.rds`, `data/generated/greenspace_ice_q1_q5_fit.rds`
- `data/generated/ndvi_outl_city_adjusted_linear.rds`, `data/generated/greenspace_outl_city_adjusted_linear.rds`
- `data/generated/neighbor_visit_outl_city_adjusted_2019_full_year.rds`
- `data/generated/ndvi_ice_q1_q5_fit.rds`, `data/generated/greenspace_ice_q1_q5_fit.rds` — ICE Q1/Q5 model objects (used by Step 7e for Fig 4)
- `output/models_result_ndvi_proximity_primary.png` — **Fig 3** (primary, combined: top NDVI, bottom proximity; generated by Step 7e from these .rds files)
- `output/models_result_neighbor_visit_annual_avg_no_outliers_2019_full_year.png` — **Fig 2** (primary)

> **Filename note:** `models_result_q1_q5_ICE_inc_green_dist_linear.png` has `_linear` in its name from development history; the proximity model uses Gamma regression (log link).

---

### Step 7e — Regenerate all manuscript smooth figures (quick, no model re-fitting)

**Script:** `code/regenerate_manuscript_figures.R`  
**Requires:** All `data/generated/*.rds` model objects from Steps 5, 7, 7c. **No SSD required.**  
**What it does:** Loads saved model objects and regenerates all 7 main and supplementary smooth figures. Figs 2, 3, S4, S5 use `plot_city_comparison()` (shared y-axis, log scale where appropriate, city-name titles atop each panel, no right y-label). Fig 4 uses `plot_ice_overlay()`, which overlays Q1 (red) and Q5 (blue) on the same panel; each stratum's curve is the model's centered CSI smooth on the same conditional-association scale as `plot_smooth_gam()`/`plot_city_comparison()` — no stratum intercept is added back — via `make_ice_row()`'s `log_y` argument (`TRUE` for NH and proximity, `FALSE` for NDVI, matching each outcome's Fig 2/3 setting) and a shared y-axis per row computed by `compute_shared_ylim()` (the same helper Figs 2/3 use). Fig 4 uses the same centered/ratio-scale convention as Figs 2/3 (no stratum intercept added back), matching the established convention in this author's prior GAM-curve papers (`gratia::draw(mod, fun = exp)`, no intercept) — see `manuscript/writing_style_guide.md` §5. `plot_ice_overlay()` suppresses the per-panel legend (`legend.position = "none"`); this script extracts a single shared legend via `cowplot::get_legend()` from one reference panel (that source panel's `legend.position` must be `"right"`, not `"top"` — `"top"` silently returns an empty guide-box in this cowplot/ggplot2 combination) and places it once above the three stacked rows via `patchwork::wrap_elements()`. NDVI+proximity figures are 2-row patchwork (1400×1200 px); Fig 4 is 4-row patchwork including the legend row (1400×1800 px). Copies all regenerated figures to `manuscript/figs/`. Use this script whenever figure styling changes — it avoids re-fitting models.

**Figures regenerated:**

| Figure | File | Rows | Plotting function |
|--------|------|------|-------------------|
| Fig 2 — NH primary (outlier-excl) | `models_result_neighbor_visit_annual_avg_no_outliers_2019_full_year.png` | 1 (log) | `plot_city_comparison` |
| Fig 3 — NDVI + proximity primary (outlier-excl) | `models_result_ndvi_proximity_primary.png` | 2 (linear / log) | `plot_city_comparison` |
| Fig 4 — ICE Q1/Q5 all outcomes | `models_result_ice_q1_q5_combined.png` | 3 (log / linear / log) | `plot_ice_overlay` (centered scale, same as Figs 2/3) |
| Fig S3a — NH crude | `models_result_neighbor_visit_annual_avg_primary_crude_2019_full_year.png` | 1 (log) | `plot_city_comparison` |
| Fig S3b — NDVI + proximity crude | `models_result_ndvi_proximity_crude.png` | 2 (linear / log) | `plot_city_comparison` |
| Fig S4a — NH full sample | `models_result_neighbor_visit_annual_avg_primary_adjusted_2019_full_year.png` | 1 (log) | `plot_city_comparison` |
| Fig S4b — NDVI + proximity full sample | `models_result_ndvi_proximity_full_sample.png` | 2 (linear / log) | `plot_city_comparison` |

**Run:**
```r
source("code/regenerate_manuscript_figures.R")
```

---

### Step 7d — Generate Figure 1 and supplementary descriptive maps

**Script:** `code/generate_figure1_maps.R`  
**Requires:** `krieger_ice_nyc.rds`, `krieger_ice_la.rds`, `city_boundary_nyc.rds`, `city_boundary_la.rds`, `community_severance_nyc/la_census_tract.rds`, `data_models_neighbor_visits_annual_average_2019_full_year.rds`, `data_models.rds`. **No SSD required** (all files already in `data/generated/`). The city boundary files were saved from the 500 Cities shapefile on first run; they do not need to be regenerated unless the study area changes.  
**What it does:** Loads census tract sf geometry from the krieger ICE files (which have tract boundaries for both cities), clips tract geometries to the 500 Cities project city boundary polygons (`city_boundary_{nyc,la}.rds`) using `sf::st_intersection()` so that only the land portions of tracts within the city boundary are displayed, joins outcome, exposure, and covariate data, and produces:
- **Figure 1** (`ggplot2`/`patchwork`): a 2-row × 4-column grid — row 1: LA; row 2: NYC; columns left to right: NH visit rate (NH analytic sample only), NDVI, distance to nearest green space, CSI — with a single shared decile-percentage legend ("0%–10%"…"90%–100%", one common purple palette across all four variables) placed once above the grid, variable names as column headers printed once, and city names as row labels printed once. Decile ranks are computed within-city, separately per variable, via `dplyr::ntile()`. Because `coord_sf()` does not support `facet_grid(scales = "free")` (and a shared coordinate scale collapses LA and NYC — ~44° of longitude apart — to specks), each panel is built as its own `ggplot`+`geom_sf` object and the grid is assembled manually with `patchwork::wrap_plots()`; the shared legend is extracted once from a single reference panel via `cowplot::get_legend()`.
- **Supplementary Fig S1:** one figure with panel (a) continuous ICE and panel (b) ICE Q1/Q5 categorical (most deprived = red, Q2–Q4 = gray, most advantaged = blue), stacked under a single caption.

`save_supp_map()` and the ICE-map panel-b block build LA first, then NYC, matching every "Left: LA; right: NYC" caption in the manuscript.

NDVI and distance-to-green-space spatial maps are not generated by this script — Figure 1 already maps both variables (columns 2–3) for both cities via the same tract geometries, just decile-shaded instead of quantile-value-labeled.

Non-Figure-1 maps use within-city quantile (decile) breaks (`tm_scale_intervals(n=10, style="quantile")`) with actual value ranges displayed in legend (no D1–D10 labels). Tracts with NA values are rendered as transparent. Color scales: YlGn = NDVI, Blues = proximity, RdBu = ICE continuous, tricolor (red/gray/blue) = ICE Q1/Q5 categorical.

**GEOID notes:**
- `krieger_ice_la$GEOID`: 11-digit (leading `0` present, e.g., `"06037199800"`)
- `community_severance_la_census_tract.rds` GEOID: 11-digit — joins directly to krieger geometry
- `data_models.rds` LA GEOID: 10-digit (leading `0` stripped) — padded in script via `ifelse(nchar(GEOID)==10, paste0("0", GEOID), GEOID)` before join
- `data_models_neighbor_visits_annual_average_2019_full_year.rds` GEOID: 11-digit for both cities — joins directly

**Outputs written to `output/` and copied to `manuscript/figs/`:**
- `figure1_nh_csi_maps.png` — **Fig 1**
- `supp_map_ice_inc.png` — **Fig S1, panel (a)** (continuous ICE)
- `supp_map_ice_q1_q5.png` — **Fig S1, panel (b)** (ICE Q1/Q5 categorical)

`supp_map_ndvi.png` and `supp_map_proximity.png` are not generated (redundant with Figure 1; see above).

**Run:**
```r
source("code/generate_figure1_maps.R")
```

---

### Step 8a — Generate descriptive table (Table 1)

**Script:** `code/table1_outcome_descriptives_neighbor_visits.R`  
**Requires:** `data_models_neighbor_visits_annual_average_2019_full_year.rds`  
**What it does:** Produces a single formatted LaTeX table with descriptive statistics (median [P25, P75]) stratified by city (NYC and LA), combining the three study outcomes (NDVI, distance to nearest green space, NH visit count), CSI (Exposure section), and six covariates (Covariates section: % Black, % Hispanic, % poverty, population density, building density, ICE). Variables with missing data carry a lettered footnote (a–g) giving the missingness count and, for NH visits and NDVI, the substantive reason for exclusion.

Uses booktabs formatting (`\toprule`, `\midrule`, `\bottomrule`) and is included in the manuscript via `\input{}`.

**Outputs written to `output/`:**
- `table1_descriptives_2019_full_year.tex`

**Run:**
```r
source("code/table1_outcome_descriptives_neighbor_visits.R")
```

---

### Step 8b2 — Generate Supplementary Table S1 (missing vs. analytic sample)

**Script:** `code/generate_supp_table_nh_missingness.R`  
**Requires:** `data_models_neighbor_visits_annual_average_2019_full_year.rds`  
**What it does:** Produces Supplementary Table S1 comparing characteristics of tracts excluded from the NH analytic sample to the 2,018-tract analytic sample. Tracts are excluded if they contain no destination CBG intersecting a PAD-US AR polygon with 12 months of complete data (N = 1,294 tracts). Within the 2,018-tract analytic sample, the NH GAMs are actually fit on 1,963 tracts (LA = 542, NYC = 1,421) after `complete.cases()` on the modeling covariates — 55 tracts (2.7\%; LA = 22, NYC = 33) are further excluded for missing covariate data (most commonly missing CSI, 48 tracts, or missing race/ethnicity/poverty, 36 tracts each), predominantly non-residential areas with near-zero building density (median 0.009 vs. 0.245 among retained tracts). Reports median (IQR) for continuous variables and N (%) for categorical variables.

**Table path:** Written to `output/supp_table_nh_missingness.tex` and copied to `manuscript/tables/supp_table_nh_missingness.tex`. Included in `sn-article.tex` via `\input{tables/supp_table_nh_missingness.tex}`.

**Outputs written to `output/` and `manuscript/tables/`:**
- `supp_table_nh_missingness.tex`

**Run:**
```r
source("code/generate_supp_table_nh_missingness.R")
```

---

### Step 8c — Extract effect estimates (Q25-to-Q75 quartile contrasts are the numbers in the manuscript)

**Script:** `code/extract_numeric_results.R`  
**Requires:** Model objects from Steps 5 and 7; `data_models.rds`. **No SSD required.**  
**What it does:** Computes the Q25-to-Q75 quartile contrast, the quantity actually cited in the manuscript Results text, Abstract, and Supplementary Table S2, and writes it to `output/numeric_results_quartile_contrasts.csv`.

**Output (used by the manuscript): `output/numeric_results_quartile_contrasts.csv`**
Computed by `compute_quartile_contrasts()` (mirrors `main_anchored_quartile_contrasts.R` in `bne_uncertainty_ses_multiyear`). For each outcome × city, builds an `mgcv::predict.gam(..., type = "lpmatrix")` contrast between CSI at the city-specific Q25/Q50/Q75 (covariates fixed at city means, random effect cancels by construction) and propagates uncertainty via the delta method on the CSI smooth's vcov submatrix. Reports three contrasts per outcome × city: `Q50_vs_Q25`, `Q75_vs_Q25`, `Q75_vs_Q50`. This is the source of Supplementary Table S2 (`supp_table_s2_per_iqr.tex`) and every Q25-to-Q75 number quoted in Results §3.2–3.3 and Discussion. RR/ratio values are rounded to 2 decimal places in the manuscript text and Table S2 (CI bounds also 2 dp); NDVI absolute-difference values stay at 3 decimal places — see `manuscript/writing_style_guide.md` §4.

**Note on `supp_table_s2_per_iqr.tex`:** despite the filename echoing "per_iqr," this table's contents are the Q25-to-Q75 quartile contrasts from `numeric_results_quartile_contrasts.csv`. It is generated by `code/generate_supp_table_s2_per_iqr.R`, which reads `output/numeric_results_quartile_contrasts.csv` and writes `output/supp_table_s2_per_iqr.tex`, copied to `manuscript/tables/`. Run:
```r
source("code/generate_supp_table_s2_per_iqr.R")
```
Rounding uses a round-half-away-from-zero helper (`round_half_up()`) rather than raw `sprintf()`, to avoid silent off-by-one-digit errors at exact `.xx5` boundaries caused by binary floating-point representation (e.g. `sprintf("%.2f", -0.615)` gives `"-0.61"` because -0.615 is stored as -0.61499999999999999...). `extract_numeric_results.R` stores `csi_q25`/`csi_q50`/`csi_q75` at 5 decimal places (not 3) for the same reason — rounding a pre-rounded 3dp value to 2dp for display is a double-rounding hazard.

> **Note on proximity direction:** A ratio < 1 for proximity means higher CSI is associated with **shorter** Euclidean distance to the nearest green space. In NYC this reflects park placement along arterial corridors, not improved access. The manuscript Results §3.3 and Discussion ¶3 address this explicitly.

**Run:**
```r
source("code/extract_numeric_results.R")
```

---

### Step 8d — Extract outlier exclusion counts (the "excluded tracts" numbers in the manuscript)

**Script:** `code/extract_outlier_exclusion_counts.R`  
**Requires:** `data_models.rds`; `data_models_neighbor_visits_annual_average_2019_full_year.rds`. **No SSD required.**  
**What it does:** Reports, per city and per outcome, how many census tracts are excluded from the primary (adjusted, outlier-excluded) analytic samples by the `|z_CSI| > 2` (city-specific) rule stated in the Statistical analysis subsection of `sn-article.tex`. Replicates the same city-specific z-score exclusion logic used by `generate_linear_ice_outl_figures.R` (Figs 2, 3) and `models_linear.R`, applied separately to each outcome's own analytic sample so that differences in missingness across outcomes are reflected in the counts, rather than assuming a single shared exclusion count across all three outcomes.

**Output: `output/numeric_results_outlier_exclusion_counts.csv`**

| Outcome | LA excluded | NYC excluded |
|---|---|---|
| Neighboring-home visits | 33 | 84 |
| NDVI | 62 | 87 |
| Distance to green space | 62 | 98 |

(Consistency check: for neighboring-home visits, `Outlier + Within + NA` reproduces the primary NH analytic sample sizes already reported at `sn-article.tex` line 154 — LA 33 + 514 + 17 = 564; NYC 84 + 1,339 + 31 = 1,454 — confirming this script's exclusion counts are drawn from the same sample the manuscript already describes, not a divergent one.)

**Run:**
```r
source("code/extract_outlier_exclusion_counts.R")
```

---

### Step 8e — Extract tract area by city (context for the LA-vs-NYC distance comparison)

**Script:** `code/extract_tract_area_by_city.R`  
**Requires:** `data/generated/krieger_ice_la.rds`; `data/generated/krieger_ice_nyc.rds`. **No SSD required.**  
**What it does:** Computes median (IQR) census tract land area, by city, from `sf::st_area()` on the tract geometries already used to build the ICE indices. Provides context for interpreting the Results-section comparison of median distance to nearest green space (LA 435 m vs. NYC 182 m): LA tracts are markedly larger, so part of any absolute-distance gap between cities is mechanically related to tract geometry (a fixed point feature is, on average, farther from the population-weighted centroid of a larger tract) rather than to differential green space accessibility itself.

**Output: `output/numeric_results_tract_area_by_city.csv`**

| City | n tracts | Median area (km²) | IQR |
|---|---|---|---|
| LA | 1,148 | 0.80 | 0.48–1.34 |
| NYC | 2,164 | 0.19 | 0.16–0.33 |

(Consistency check: 1,148 + 2,164 = 3,312, matching the full analytic universe already cited at `sn-article.tex` line 154.)

**Run:**
```r
source("code/extract_tract_area_by_city.R")
```

---

### Step 8f — Generate Supplementary Table (outlier-tract geography and built environment)

**Script:** `code/generate_supp_table_outlier_geography.R`  
**Requires:** `data/generated/data_models.rds`; `data/generated/krieger_ice_la.rds`; `data/generated/krieger_ice_nyc.rds`. **No SSD required.**  
**What it does:** Compares tract area, population density, building density, and Community Severance Index (CSI) between tracts excluded by the primary `|z_CSI| > 2` outlier rule and tracts retained in the primary analysis, separately by city. Answers the Results-section question of whether outlier-excluded tracts (which drive the non-linearity seen in the full-sample sensitivity analysis, Supplementary Figure S4) have distinguishing geographic characteristics. Distance to the city boundary is deliberately excluded: it is sensitive to which tracts define the city union polygon and is not a stable number.

The `|z_CSI| > 2` rule flags both distribution tails. LA's outliers are all high-CSI (z > 2); NYC's split into a high-CSI group (z > 2, n = 57) and a low-CSI group (z < -2, n = 41) with materially different area and density profiles, so NYC is reported with separate high-CSI and low-CSI outlier columns rather than one pooled "outlier" column.

**Output: `output/supp_table_outlier_geography.tex`** (copied to `manuscript/tables/supp_table_outlier_geography.tex`)

| City | Group | n | Tract area (km²) | Pop. density (k/km²) | Building density | CSI |
|---|---|---|---|---|---|---|
| LA | Outlier (\|z\|>2) | 62 | 0.72 [0.49, 1.07] | 4.77 [3.13, 6.70] | 0.21 [0.17, 0.25] | 2.24 [1.98, 2.76] |
| LA | Within ±2 SD | 1,046 | 0.79 [0.47, 1.33] | 5.10 [3.03, 8.44] | 0.24 [0.18, 0.29] | -0.30 [-0.47, 0.05] |
| NYC | High-CSI outlier (z>2) | 57 | 0.25 [0.18, 0.65] | 11.85 [4.68, 24.49] | 0.15 [0.06, 0.29] | 2.08 [1.95, 2.35] |
| NYC | Low-CSI outlier (z<-2) | 41 | 0.69 [0.22, 1.09] | 5.65 [3.44, 9.70] | 0.16 [0.10, 0.23] | -2.18 [-2.47, -2.07] |
| NYC | Within ±2 SD | 2,025 | 0.18 [0.16, 0.29] | 16.69 [9.99, 25.98] | 0.31 [0.22, 0.38] | -0.11 [-0.72, 0.50] |

(Consistency check: outlier + within counts reproduce the same per-city totals as Step 8d/8e — LA 62 + 1,046 = 1,108 outlier-flagged tracts with non-missing CSI; NYC 57 + 41 + 2,025 = 2,123.)

**Run:**
```r
source("code/generate_supp_table_outlier_geography.R")
```

---

### Step 10 — Compile the manuscript

From within the `manuscript/` directory:
```bash
cd manuscript
pdflatex sn-article.tex
bibtex sn-article
pdflatex sn-article.tex
pdflatex sn-article.tex
```

The `sn-jnl.cls` file is already in `manuscript/`. Compile from within `manuscript/`. Figures are at `figs/` and tables at `tables/` (both subdirectories of `manuscript/`) — all paths in `sn-article.tex` are relative to the manuscript directory.

**Before compiling:** Confirm Funding, Author Contributions, Code Availability, and Acknowledgements placeholder text (see §Known Issues) are filled in.

---

## What you should have after running all steps

### Generated data files (all in `data/generated/`)

| File | Created by |
|------|-----------|
| `data_models.rds` | Step 5 |
| `data_models_neighbor_visits_annual_average_2019_full_year.rds` | Step 6 |
| `ndvi_model_objects_city_adjusted_linear.rds` | Step 5 |
| `ndvi_model_objects_city_crude_linear.rds` | Step 5 |
| `greenspace_model_objects_city_adjusted_linear.rds` | Step 5 |
| `greenspace_model_objects_city_crude_linear.rds` | Step 5 |
| `neighbor_visit_primary_fit_city_nyc_2019_full_year.rds` | Step 7 |
| `neighbor_visit_primary_fit_city_la_2019_full_year.rds` | Step 7 |
| `neighbor_visit_primary_crude_fit_city_nyc_2019_full_year.rds` | Step 7 |
| `neighbor_visit_primary_crude_fit_city_la_2019_full_year.rds` | Step 7 |
| `neighbor_visit_ice_q1_q5_fit_2019_full_year.rds` | Step 7 |
| `neighbor_visit_outl_city_adjusted_2019_full_year.rds` | Step 7c |
| `city_boundary_nyc.rds` | Extracted from 500 Cities shapefile (SSD); saved once |
| `city_boundary_la.rds` | Extracted from 500 Cities shapefile (SSD); saved once |

### Output files (all in `output/`)

| File | Manuscript reference | Created by |
|------|---------------------|-----------|
| `table1_descriptives_2019_full_year.tex` | Table 1 | Step 8a |
| `supp_table_nh_missingness.tex` | Supplementary Table S1 | Step 8b2 |
| `numeric_results_quartile_contrasts.csv` | In-text estimates, Table S2 | Step 8c |
| `figure1_nh_csi_maps.png` | Fig 1 | Step 7d |
| `models_result_neighbor_visit_annual_avg_no_outliers_2019_full_year.png` | Fig 2 (primary, outlier-excluded) | Step 7c / Step 7e |
| `models_result_ndvi_proximity_primary.png` | Fig 3 (primary, combined: top NDVI, bottom proximity) | Step 7e |
| `supp_map_ice_inc.png` | Fig S1, panel (a) (continuous ICE) | Step 7d |
| `supp_map_ice_q1_q5.png` | Fig S1, panel (b) (ICE Q1/Q5 categorical) | Step 7d |
| `nh_visits_distribution.png` | Fig S2a | Step 8d |
| `green_space_ndvi_distribution.png` | Fig S2b | existing |
| `green_space_distance_distribution.png` | Fig S2c | existing |
| `models_result_neighbor_visit_annual_avg_primary_crude_2019_full_year.png` | Fig S3a (crude, Sensitivity 1) | Step 7 / Step 7e |
| `models_result_ndvi_proximity_crude.png` | Fig S3b (crude, combined: top NDVI, bottom proximity) | Step 7e |
| `models_result_neighbor_visit_annual_avg_primary_adjusted_2019_full_year.png` | Fig S4a (full-sample, Sensitivity 2) | Step 7 / Step 7e |
| `models_result_ndvi_proximity_full_sample.png` | Fig S4b (full-sample, combined: top NDVI, bottom proximity) | Step 7e |
| `models_result_ice_q1_q5_combined.png` | Fig 4 (combined: top NH, middle NDVI, bottom proximity) | Step 7e |
| `models_result_neighbor_visit_annual_avg_share_adjusted_2019_full_year.png` | Not in manuscript — in `other_analysis/` | Step 7 |

> All figures are copied to `manuscript/figs/` for self-contained Overleaf compilation. Tables (including Supplementary Table S1) are in `manuscript/tables/`. The manuscript uses relative paths `figs/` and `tables/` (not `../output/`) — compile from within `manuscript/`.

---

## Table 2 covariate missingness

`code/inspect_table2_missingness.R` (Step 8l) reproduces the check behind the Table 2 missingness footnote in `sn-article.tex`. For each covariate with missing values (CSI, Percent Black, Percent Hispanic, Percent poverty, ICE), it reports the share of missing-value tracts that are non-residential (population density = 0) and maps their locations by city. Output: `output/table2_missingness_diagnosis.csv` and `output/table2_missingness_maps.png`. Its output is checked by Step 9's audit against the manuscript footnote numbers.

Percent Black/Hispanic/poverty missingness is 100% explained by non-residential (zero population-density) tracts in both cities (LA n=10, NYC n=40). CSI and ICE missingness is only partially explained this way (CSI: 40% LA / 93% NYC zero-density; ICE: 83%/83%), so the manuscript text is scoped to avoid overclaiming a single cause for all five covariates — see `sn-article.tex`, Table 2 paragraph. Missing tracts cluster spatially in large non-residential zones (e.g., airport/wetland areas in NYC, park/reservoir areas in LA).

---

## ICE-stratified (Q1/Q5) neighboring-home visits: quantified CSI decrease by stratum

`code/extract_ice_nh_quartile_contrasts.R` quantifies the stratum-specific CSI–neighboring-home-visits contrasts cited in the Secondary analysis paragraph of `sn-article.tex` (CSI x neighboring-home visits effect modification by ICE income quintile). It rebuilds the Q1 (most disadvantaged) / Q5 (most advantaged) stratum subsets exactly as in `models_neighbor_visits_annual_average.R` (primary, outlier-excluded sample), loads the corresponding stratified GAMs from `neighbor_visit_ice_q1_q5_fit_2019_full_year.rds`, and computes the CSI Q25-to-Q75 RR contrast within each city x stratum cell using the same lpmatrix/delta-method approach as `extract_numeric_results.R`. Output: `output/numeric_results_ice_nh_quartile_contrasts.csv`.

Results: LA — Q1 RR 0.92 (95% CI 0.84–0.99, n=93) vs. Q5 RR 0.91 (95% CI 0.82–1.02, n=153): nearly identical. NYC — Q1 RR 0.82 (95% CI 0.79–0.86, n=305) vs. Q5 RR 0.72 (95% CI 0.64–0.82, n=285): both strata show a decrease, but it is steeper in the most-advantaged stratum and the two CIs do not overlap, indicating a real (not noise-driven) difference in slope. The manuscript's Secondary analysis paragraph reports effect modification via the explicit Q5-vs-Q1 difference contrast (see below), not by comparing whether these per-stratum CIs overlap.

---

## ICE-stratified (Q1/Q5) NDVI: quantified within-stratum shape

`code/extract_ice_ndvi_quartile_contrasts.R` quantifies the CSI–NDVI slope within each ICE stratum (Q1 most disadvantaged, Q5 most advantaged) for each city, using the same lpmatrix/delta-method quartile-segment contrast approach as `extract_numeric_results.R` (Q25-to-Q50, Q50-to-Q75, Q25-to-Q75, smooth centered at Q50), applied separately to each of the four stratum-city NDVI models (`ndvi_ice_q1_q5_fit.rds`, outlier-excluded sample, as fit in `generate_linear_ice_outl_figures.R`).

`code/extract_ice_effect_modification_contrasts.R` computes a related but distinct quantity: the Q1-vs-Q5 baseline (level) gap between the two independently fit models, rather than the CSI slope within each. This baseline-gap comparison is not part of the study design — the study does not formally test the ICE–NDVI association (no regression of NDVI on ICE, no confounder adjustment for that specific comparison), and a difference in fitted intercepts across two independently fit stratum models is not a tested association. Its output (`numeric_results_ice_effect_modification.csv`) is not cited by any manuscript number and does not feed any manuscript figure; the script is retained only as a standalone diagnostic. Manuscript numbers for NDVI Q1-vs-Q5 effect modification instead come from `extract_ice_effect_modification_difference_contrasts.R` (see below).

Results (`output/numeric_results_ice_ndvi_quartile_contrasts.csv`): in LA, the Q25-to-Q75 contrasts overlapped (Q1: −0.010, 95% CI −0.017 to −0.003; Q5: −0.015, 95% CI −0.026 to −0.004) — consistent magnitude across strata, no evidence of effect modification. In NYC, the Q25-to-Q75 decrease was larger in the most advantaged stratum (Q5: −0.022, 95% CI −0.043 to −0.001) than the most disadvantaged stratum (Q1: −0.013, 95% CI −0.023 to −0.002), roughly 70% larger in magnitude; the CIs overlap, so this does not meet a strict non-overlapping-CI threshold for effect modification, but the pattern is at least suggestive of a steeper CSI–NDVI decrease among the most advantaged NYC tracts. A blanket "no effect modification" claim does not hold for NDVI in NYC. The manuscript reports this via the explicit Q5-minus-Q1 difference contrast with its own CI (see below), not via CI-overlap comparison.

The manuscript's Secondary analysis paragraph reports the NYC-vs-LA NDVI shape difference using the Q25-to-Q75 estimate and CI in each stratum/city (per the numbers above), consistent with the general rule for narrative stratified/subgroup comparisons in `manuscript/writing_style_guide.md` §4.

---

## ICE-stratified (Q1/Q5) distance to nearest green space: quantified CSI slope by stratum

`code/extract_ice_distance_quartile_contrasts.R` quantifies the CSI-distance-to-nearest-green-space slope within each ICE stratum (Q1 most disadvantaged, Q5 most advantaged) for each city, replacing a purely qualitative "Q5 decreased somewhat more steeply than Q1" claim in the Secondary analysis paragraph of `sn-article.tex`. Same lpmatrix/delta-method quartile-segment contrast approach as `extract_numeric_results.R` and `extract_ice_ndvi_quartile_contrasts.R`, applied to the four stratum-city Gamma/log-link proximity models (`greenspace_ice_q1_q5_fit.rds`, outlier-excluded sample, as fit in `generate_linear_ice_outl_figures.R`), back-transformed to a ratio scale.

Results (`output/numeric_results_ice_distance_quartile_contrasts.csv`): in LA, Q25-to-Q75 ratios were of comparable magnitude and both close to (Q1) or overlapping (Q5) the null (Q1: 1.12, 95% CI 1.01–1.24; Q5: 1.07, 95% CI 0.95–1.21) — no clear stratum difference. In NYC, the association was statistically significant only in the most economically advantaged stratum (Q5: 0.79, 95% CI 0.70–0.90) and not in the most economically deprived stratum (Q1: 0.93, 95% CI 0.83–1.03); the two CIs overlap, so this does not meet a strict non-overlapping-CI threshold for effect modification, but the pattern (significant, steep decrease in Q5; null in Q1) is directionally consistent with effect modification in NYC. The manuscript's Secondary analysis paragraph states this explicitly with numbers rather than asserting "no clear evidence of effect modification" without quantification.

The manuscript reports this via the explicit Q5-vs-Q1 ratio-of-ratios contrast with its own CI (see below), not via CI-overlap comparison.

---

## ICE-stratified (Q1/Q5) effect modification: explicit Q1-vs-Q5 difference contrast with CI

The Secondary analysis paragraphs (NH visits, NDVI, distance) report effect modification as an explicit contrast-of-contrasts with its own 95% CI, rather than by checking whether the Q1 and Q5 stratum-specific Q25-to-Q75 CSI-quartile-contrast CIs overlap — CI overlap is a known-conservative/imprecise heuristic (two overlapping CIs can still hide a real difference, and non-overlapping CIs can overstate one). The two stratum models are treated as independent, since they are fit on disjoint tract subsets: `Var(delta) = Var(est_1) + Var(est_2)`, with each stratum's SE recovered from its already-reported CI width. This mirrors the convention in the author's related paper on PM2.5 uncertainty and SES (`bne_uncertainty_ses_multiyear`, `03_explore_results/contrast_main_rev.R`, `compute_strata_delta()`).

`code/extract_ice_effect_modification_difference_contrasts.R` implements this by reading the three existing per-stratum quartile-contrast CSVs (`numeric_results_ice_nh_quartile_contrasts.csv`, `numeric_results_ice_ndvi_quartile_contrasts.csv`, `numeric_results_ice_distance_quartile_contrasts.csv` — no models are refit) and computing, per city and outcome: a ratio of the Q5 and Q1 stratum-specific quartile-contrast estimates (`ratio_q5_vs_q1`, for the two ratio/log-link outcomes — NH visits RR and distance ratio) or a Q5-minus-Q1 difference of the stratum-specific estimates (`diff_q5_minus_q1`, for the Gaussian NDVI estimate), each with a delta-method 95% CI. Output: `output/numeric_results_ice_effect_modification_difference_contrasts.csv`.

Results: NH visits — LA ratio 1.00 (95% CI 0.87–1.14); NYC ratio 0.88 (95% CI 0.77–1.00). NDVI — LA diff −0.005 (95% CI −0.018 to 0.008); NYC diff −0.009 (95% CI −0.033 to 0.014). Distance — LA ratio 0.96 (95% CI 0.82–1.12); NYC ratio 0.86 (95% CI 0.73–1.01). All six CIs include the null (1 for ratios, 0 for the NDVI difference), so the manuscript's overall "no clear evidence of effect modification" conclusion is unchanged and, if anything, put on firmer statistical footing than the CI-overlap heuristic it replaces — the NYC NH-visits and NYC distance contrasts are the closest to the null boundary (upper CI 1.00 and 1.01 respectively), consistent with the "directionally suggestive but not statistically robust" language used for those two cells in the manuscript text.

The manuscript's Secondary analysis paragraph (`sn-article.tex`, lines ~198, 200, 202) was rewritten for all three outcomes to state this explicit contrast and its CI inline, alongside the existing per-stratum estimates, rather than describing CI overlap qualitatively.

---

## ICE-stratified (Q1/Q5) overlay figure (Figure 4): axis scale and per-panel titles

Figure 4 (`plot_ice_overlay()`, `code/functions/functions.R`) plots each Q1/Q5 curve as the stratum's centered CSI smooth (`gratia::smooth_estimates()`, mean-zero by mgcv's sum-to-zero constraint), exponentiated to a ratio/RR scale for log-link families or left on the identity scale for Gaussian (NDVI) — the same centered transform, `log_y` convention, and axis-label convention as `plot_smooth_gam()`/`plot_city_comparison()` (Figs 2/3), with no stratum intercept added back. This keeps the y-axis meaning consistent across all four figures: a given outcome's axis means the same thing in Fig 4 as in Figs 2/3. The established convention in this author's prior GAM-curve figures (`open_streets_environ_noise`, `community_severance` repos) is this same centered/ratio scale (`gratia::draw(mod, select = sm, fun = exp)`, intercept never added back, dashed null line at 1). `regenerate_manuscript_figures.R`'s `make_ice_row()` computes the shared y-limit via `compute_shared_ylim()` (the same helper Figs 2/3 use), passing `log_y = TRUE` for the NH and proximity rows and `log_y = FALSE` for the NDVI row, matching each outcome's Fig 2/3 setting. Because no stratum intercept is added, Fig 4 does not visually imply a Q1-vs-Q5 baseline-level comparison for any outcome — consistent with that comparison not being part of this study's design (see the note above on `extract_ice_effect_modification_contrasts.R`).

`plot_ice_overlay()` also gained a `show_title` argument; `regenerate_manuscript_figures.R`'s `make_ice_row()` now passes `show_title = TRUE` only for the top (neighboring-home visits) row of Figure 4, so the city names ("Los Angeles" / "New York City") appear once above the combined figure instead of being repeated above every row.

---

## Population totals cited in the Discussion ("Strengths" paragraph)

`sn-article.tex` states the analysis spans "approximately 13 million residents across 3,312 census tracts, with the neighboring-home visits analysis covering 8.2 million residents across 2,018 tracts." These are computed from the `population` column of `data_models_neighbor_visits_annual_average_2019_full_year.rds` — **not** `TotPop`, a separate, smaller derived variable used only for `pop_dens` calculations, which sums to a much lower and non-matching total. Summing `population` across all 3,312 tracts gives 12,875,603 (≈13 million); restricting to the 2,018 NH-analytic tracts (`has_greenspace_tract == TRUE`) gives 8,188,889 (≈8.2 million) — both match the manuscript exactly.

## Reproducible manuscript numeric audit

`only_local/audit_manifest.csv` + `only_local/run_manuscript_audit.R` (local-only, gitignored, not part of this repo) form a permanent, mechanical, zero-tolerance checker for every numeric claim in `sn-article.tex`, replacing manual spot-checks. The manifest has one row per claim (`tex_ref`, `claim`, `source_csv`, `filter_expr` — a literal dplyr-filter string, `value_col` or `__count__`, `round_dp`, `manuscript_value` — read as a character column so trailing zeros like `-0.30`/`1.00` are preserved). `run_manuscript_audit.R` reruns every extraction/diagnostic script feeding the manifest fresh (no cached outputs), then checks each row's computed value (via `round_half_up()`, immune to the IEEE-754 boundary artifact — see Step 8c note above) against the manuscript string, writing `output/manuscript_audit_results.csv`.

`code/extract_manuscript_misc_counts.R` is the consolidated source for small claims that previously had no permanent script: ICE income quintile boundaries, primary NH spline edf, Gamma zero-distance reassignment counts, NH analytic/retained sample sizes and percentages, LA >300m share, and the population totals above.

Any new manuscript number must get both a manifest row and a permanent extraction script (existing convention, now enforced by a runnable checker rather than review alone). Run:
```r
source("only_local/run_manuscript_audit.R")
```

---

## R packages required

```r
# Core analysis
install.packages(c(
  "mgcv",        # GAMs — all model fitting
  "gratia",      # smooth extraction, model diagnostics
  "patchwork",   # composite multi-panel figures
  "tidycensus",  # ACS data download
  "ndi",         # krieger() ICE index computation
  "sf",          # spatial operations
  "tigris"       # TIGER CBG geometries (prep_neighbor_visits_annual_average.R)
))

# Data wrangling
install.packages(c("dplyr", "tidyr", "readr", "stringr", "data.table"))

# Visualization
install.packages(c("ggplot2", "GGally", "tmap", "mapview"))
```
