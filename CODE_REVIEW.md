# Code Review and Reproduction Guide  
# Community Severance & Green Space Accessibility

**Project:** `green_spaces_community_severance`  
Maps every manuscript figure, table, and in-text number to the script that produces it.

---

## Raw data sources

Every input under `data/raw/` falls into one of four categories:

**Self-generated — copied into `data/raw/` in this package**

| File | Description | Provenance |
|---|---|---|
| `data/raw/csi/csi_scores_la.rds` | LA CBG-level CSI factor scores | `community_severance_us` PCP + factor-analysis pipeline (§2.3). See `data/raw/csi/PROVENANCE.md`. |
| `data/raw/csi/csi_scores_nyc.rds` | NYC CBG-level CSI factor scores | `community_severance_nyc` PCP + factor-analysis pipeline (§2.3). See `data/raw/csi/PROVENANCE.md`. |
| `data/raw/acs/acs_dt.rds` | Pre-processed ACS estimates table (used by `03_prep_greenspace.R` for NYC water-body processing) | `community_severance_nys_climate_change_mh` pipeline. See `data/raw/acs/PROVENANCE.md`. |

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

**Three outcomes**, green space accessibility:

| Outcome | What it measures | Source |
|---------|-----------------|--------|
| Neighboring-home visits count | Device visits from nearby home CBGs to a destination tract (restricted to green-space CBGs intersecting PAD-US AR) — behavioral, realized access | Advan Research / Dewey Data (mobile location data) |
| NDVI | Normalized Difference Vegetation Index — vegetation present in a tract | Landsat satellite imagery |
| Distance to nearest green space | Euclidean distance, tract population-weighted centroid to nearest public green space edge (PAD-US AR) | PAD-US AR shapefile |

**Models:** GAMs with a flexible spline on CSI, fit separately per city. Main analysis: fully adjusted, all three outcomes. Plus two sensitivity analyses and one secondary analysis, all three outcomes:

| Analysis | Description | Figures |
|----------|-------------|---------|
| **Main** (adjusted, outlier-excluded) | Full covariate adjustment; tracts with \|z_CSI\| > 2 (city-specific) excluded | Figs 2, 3 |
| **Sensitivity 1** (crude) | Only population density + neighborhood RE; same outlier exclusion | Figs S3a, S3b |
| **Sensitivity 2** (full sample) | Adjusted; all tracts including extreme-CSI | Figs S4a, S4b |
| **Secondary** (ICE stratification) | Outlier-excluded within each stratum; separate models for ICE Q1 and Q5 | Fig 4 |

---

## Manuscript section → code

Jump from a manuscript paragraph to the script(s) that produced it.

| Manuscript section | What it covers | Script(s) |
|---|---|---|
| §2.1 Study area | City boundaries, census tracts as unit of analysis | `01_prep_ses.R` (Step 1), `07d_generate_figure1_maps.R` (Step 7d, city boundary clipping) |
| §2.2 Green spaces and accessibility metrics | NH visits definition; NDVI; distance to nearest green space | `03_prep_greenspace.R` (Step 3, NDVI + distance); `05b_prep_cbg_nh_combined.R` (Step 5b) + `06_prep_neighbor_visits_annual_average.R` (Step 6, NH metric) |
| §2.3 Community Severance Index | CSI aggregation to tract | `02_prep_csi.R` (Step 2) |
| §2.4 Covariates | %Black, %Hispanic, %poverty, pop. density, building density, ICE, neighborhood random-effect units | `01_prep_ses.R` (Step 1, ACS covariates + ICE); `04_prep_building_density.R` (Step 4); `05_models_linear.R` (Step 5, neighborhood spatial join) |
| §2.5 Statistical analysis | GAMM specifications, offset, outlier exclusion, quartile-segment contrasts | `05_models_linear.R` (Step 5, NDVI/proximity); `07_models_neighbor_visits_annual_average.R` (Step 7, NH); `07c_generate_linear_ice_outl_figures.R` (Step 7c, outlier-excluded primary models); `08c_extract_numeric_results.R` (Step 8c, quartile contrasts); `08d_extract_outlier_exclusion_counts.R` (Step 8d, exclusion counts cited in-text) |
| §2.6 Sensitivity analyses | Crude (reduced-covariate) models; full-sample (outlier-included) models | `05_models_linear.R` / `07_models_neighbor_visits_annual_average.R` (crude and full-sample fits); `07e_regenerate_manuscript_figures.R` (Step 7e, Figs S3/S4) |
| §2.7 Secondary analyses (ICE stratification) | Q1/Q5 economic-polarization stratified models and contrasts | `07b_generate_nh_ice_q1_q5_figure.R` (Step 7b, NH); `07c_generate_linear_ice_outl_figures.R` (Step 7c, NDVI/proximity); `08h_extract_ice_nh_quartile_contrasts.R`, `08h_extract_ice_ndvi_quartile_contrasts.R`, `08h_extract_ice_distance_quartile_contrasts.R`, `08j_extract_ice_effect_modification_difference_contrasts.R` (see ICE-stratified sections below) |
| §3.1 Descriptive statistics | Table 1; Figure 1 maps; missingness counts | `08a_table1_outcome_descriptives_neighbor_visits.R` (Step 8a); `07d_generate_figure1_maps.R` (Step 7d, Figs 1 and S1); `08k_extract_manuscript_misc_counts.R` (missingness/sample-size counts) |
| §3.2 Main analysis (neighboring-home visits) | Fig 2; primary NH quartile contrasts and exclusion counts | `07c_generate_linear_ice_outl_figures.R` (Step 7c, Fig 2); `08c_extract_numeric_results.R` (Step 8c); `08d_extract_outlier_exclusion_counts.R` (Step 8d) |
| §3.3 Complementary analyses (NDVI and proximity) | Fig 3; NDVI/proximity quartile contrasts | `07c_generate_linear_ice_outl_figures.R` (Step 7c, Fig 3); `08c_extract_numeric_results.R` (Step 8c) |
| §3.4 Sensitivity analyses | Figs S3, S4; outlier-tract geography table | `07e_regenerate_manuscript_figures.R` (Step 7e); `08f_generate_supp_table_outlier_geography.R` (Step 8f) |
| §3.5 Secondary analysis | Fig 4; ICE Q1/Q5 within-stratum and Q5-vs-Q1 contrasts | `07e_regenerate_manuscript_figures.R` (Step 7e, Fig 4); ICE-stratified extraction scripts (see "ICE-stratified" sections below) |

---

## Prerequisites

### Software

- **R** (≥ 4.2 recommended) with the packages listed in §7 below.

### Data: raw-input dependencies

Some scripts need raw inputs (see "Raw data sources" above); others only need files already in `data/generated/`. Steps 6 onward can run from `data/generated/` alone.

| Needs raw inputs | Scripts |
|-----------|---------|
| ✅ Yes | `01_prep_ses.R`, `02_prep_csi.R`, `03_prep_greenspace.R`, `04_prep_building_density.R`, `05_models_linear.R`, `06_prep_neighbor_visits_annual_average.R` (PAD-US AR shapefile) |
| ❌ No | `05b_prep_cbg_nh_combined.R`, `07_models_neighbor_visits_annual_average.R`, `07b_generate_nh_ice_q1_q5_figure.R`, `07c_generate_linear_ice_outl_figures.R`, `07e_regenerate_manuscript_figures.R`, `07d_generate_figure1_maps.R`, `08g_generate_nh_distribution_figure.R`, `08a_table1_outcome_descriptives_neighbor_visits.R`, `08b2_generate_supp_table_nh_missingness.R`, `08c_extract_numeric_results.R`, `08l_inspect_table2_missingness.R` |
| ✅ Yes | `08b1_diagnose_nh_exclusion_reason.R` (PAD-US AR shapefile) — output feeds Step 8b2 (Table S1), part of the manuscript pipeline |

> `07c_generate_linear_ice_outl_figures.R` reads `data_models.rds` (produced by `05_models_linear.R`). Already exists in `data/generated/` — no raw inputs needed to run this script itself.

> `02_prep_csi.R` and `03_prep_greenspace.R` still read city boundaries, the Smart Location Database, the FAF5 network, NYC water body geometry, and PAD-US AR from raw data — see "Raw data sources" above. Their CSI-factor-score and ACS-table inputs are self-generated files already bundled in `data/raw/csi/` and `data/raw/acs/`.

### Data: the Advan Research input files

Two archival CBG-level files. Step 5b merges them into one canonical file:

```
data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv
```

One row per CBG (primary + supplementary sources, all 12-month complete CBGs). Input to Step 6. Restricted — cannot be publicly shared; must be present locally to run Steps 5b–7.

Or use the pre-processed modeling dataset, already at:
```
data/generated/data_models_neighbor_visits_annual_average_2019_full_year.rds
```
If it exists, skip directly to Step 7.

---

## How the code is organized

```
code/
  01_prep_ses.R                                      # Step 1 — SES & ICE indices
  02_prep_csi.R                                      # Step 2 — CSI aggregated to tract
  03_prep_greenspace.R                               # Step 3 — NDVI and proximity
  04_prep_building_density.R                         # Step 4 — building density
  05_models_linear.R                                 # Step 5 — NDVI and proximity GAMs
  05b_prep_cbg_nh_combined.R                          # Step 5b — merge primary + supplementary CBG NH files
  06_prep_neighbor_visits_annual_average.R           # Step 6 — NH metric preparation (reads Step 5b output)
  06_07_run_neighbor_visits_workflow.R                  # Step 6 (orchestrator)
  07_models_neighbor_visits_annual_average.R         # Step 7 — NH GAMs
  07b_generate_nh_ice_q1_q5_figure.R                 # Step 7b — NH ICE Q1/Q5 model fitting (saves .rds for Fig 4)
  07c_generate_linear_ice_outl_figures.R              # Step 7c — primary figures (Figs 2, 3) and NDVI/proximity ICE .rds (used in Fig 4)
  07e_regenerate_manuscript_figures.R                 # Step 7e — quick regeneration of all 9 smooth figures from saved .rds; no model re-fitting
  07d_generate_figure1_maps.R                         # Step 7d — Figure 1 (2-row × 4-col: LA/NYC rows, NH/NDVI/proximity/CSI columns) and supplementary maps (Fig S1)
  08a_table1_outcome_descriptives_neighbor_visits.R   # Step 8a — Table 1 (outcomes, exposure & covariates)
  08b2_generate_supp_table_nh_missingness.R             # Step 8b2 — Supplementary Table S1 (missing vs. analytic sample)
  08c_extract_numeric_results.R                       # Step 8c — writes numeric_results_quartile_contrasts.csv, the source of Table S2 and Results-text numbers
  08c2_generate_supp_table_s2_per_iqr.R                 # Step 8c2 — Supplementary Table S2, generated from numeric_results_quartile_contrasts.csv
  08g_generate_nh_distribution_figure.R               # Step 8g — NH visits distribution figure (Fig S2a)
  08b1_diagnose_nh_exclusion_reason.R                   # Step 8b1 — classifies each excluded tract's reason (structural: no green-space CBG; data gap: incomplete months; no CBG data at all); output feeds Step 8b2
  08l_inspect_table2_missingness.R                     # Step 8l — reproduces the Table 2 missingness footnote check; output is checked by Step 9's audit
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

To reproduce Steps 6–9 only (no raw inputs needed), first confirm these files are present:

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

All should exist. If so, go directly to Step 8c to regenerate the numeric results, or Step 7 to re-fit the NH models.

> `city_boundary_nyc.rds` and `city_boundary_la.rds`: extracted once from the 500 Cities shapefile, saved to `data/generated/`. Used by Step 7d to clip tract geometries to city land area. If missing, run the extraction block in `01_prep_ses.R` (lines 38–46), or adapt `07d_generate_figure1_maps.R` to skip clipping.

---

### Step 1 — Prepare SES and ICE indices

**Script:** `code/01_prep_ses.R`  
**Requires:** Census API key set via `tidycensus::census_api_key()`.  
**What it does:** Downloads 2015–2019 ACS 5-year estimates, tract level, NYC and LA. Computes ICE (income), % Black, % Hispanic, % poverty, population density per tract.

**Outputs written to `data/generated/`:**
- `ses_ice_nyc.rds`, `ses_ice_la.rds` — SES variables with sf geometry
- `krieger_ice_nyc.rds`, `krieger_ice_la.rds` — ICE indices
- `acs_ses.rds` — ACS summary object

**Run:**
```r
source("code/01_prep_ses.R")
```

---

### Step 2 — Aggregate CSI to census tract

**Script:** `code/02_prep_csi.R`  
**Requires:** 500 Cities city boundaries, Smart Location Database, FAF5 network; `krieger_ice_nyc.rds` and `krieger_ice_la.rds` from Step 1; pre-computed CBG-level CSI scores (`data/raw/csi/csi_scores_nyc.rds`, `data/raw/csi/csi_scores_la.rds` — PCP + factor-analysis pipeline; see `data/raw/csi/PROVENANCE.md`).  
**What it does:** Aggregates CBG-level CSI factor scores to census tracts via population-weighted spatial interpolation (`tidycensus::interpolate_pw()`). CSI measures how much road infrastructure and traffic sever local community connectivity.

**Key note:** Outlier z-scores here are **city-specific** (separate mean/SD for NYC and LA). Step 5 (`05_models_linear.R`) uses the same convention.

**Outputs written to `data/generated/`:**
- `community_severance_nyc_census_tract.rds`
- `community_severance_la_census_tract.rds`

**Run:**
```r
source("code/02_prep_csi.R")
```

---

### Step 3 — Prepare green space measures

**Script:** `code/03_prep_greenspace.R`  
**Requires:** NDVI CSV (`NDVI_US_MajorCities_Tracts_2000_2010_2019.csv`); PAD-US AR shapefile; population-weighted centroid text files (Census Bureau).  
**What it does:**
- Joins pre-computed tract-level NDVI values (Landsat 2019) to census tract geometries.
- Computes Euclidean distance from each tract's population-weighted centroid to the **edge** of the nearest PAD-US AR public green space polygon. Only green spaces ≥ 400 m². 10 km buffer beyond city boundaries to catch nearby parks.
- 94 tracts (LA = 28, NYC = 66) with centroid **inside** a green space get distance = 0 (`inside_flag`). Recoded to 1 m before Gamma model fitting.

**Outputs written to `data/generated/`:**
- `ndvi_nyc_census_tract.rds`, `ndvi_la_census_tract.rds`
- `cs_access_euclidean_nyc.rds`, `cs_access_euclidean_la.rds`

**Run:**
```r
source("code/03_prep_greenspace.R")
```

---

### Step 4 — Prepare building density

**Script:** `code/04_prep_building_density.R`  
**Requires:** Building footprint data.  
**What it does:** Computes building footprint area per census tract. Covariate in adjusted models.

**Outputs written to `data/generated/`:**
- `building_dens_nyc.rds`, `building_dens_la.rds`

**Run:**
```r
source("code/04_prep_building_density.R")
```

---

### Step 5 — Fit NDVI and proximity GAMs

**Script:** `code/05_models_linear.R`  
**Requires:** Neighborhood boundary shapefiles; outputs from Steps 1–4.  
**What it does:**
1. Spatially joins tracts to neighborhood boundaries (NYC: UHF42; LA: Community Plan Areas) by largest-intersection-area. Neighborhood = random intercept in all GAMs.
2. Strips leading `0` from raw 11-digit LA GEOIDs (`substring(la_csi$GEOID, 2)`) → 10-character GEOIDs used through the join chain. NH workflow restores to 11 digits via `pad_geoid(..., 11)` before joining.
3. Assigns ICE quintiles via `ntile()` within each city (`group_by(city)`), so Q1/Q5 are city-specific.
4. Flags outlier tracts where `|z_csi| > 2`, city-specific z-scores. Excluded in crude sensitivity models (Figs S3a/S3b), matching primary/adjusted models (Figs 2, 3). Full-sample sensitivity models (Figs S4a/S4b) include outliers by design.
5. Saves combined modeling dataset as `data_models.rds` **before** any recoding.
6. Recodes `closest_greenspace == 0` to 1 metre (for 94 tracts, LA = 28 / NYC = 66, whose centroid is inside a green space polygon) before fitting Gamma models.
7. Fits all NDVI (Gaussian, identity link) and proximity (Gamma, log link) GAMs, including crude, adjusted, outlier-excluded, by-city, and ICE-stratified specifications.
8. Saves city-specific model objects for use by `08c_extract_numeric_results.R`.

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

**Figures written to `output/` (via `07e_regenerate_manuscript_figures.R`):**

| File | Manuscript reference |
|------|---------------------|
| `models_result_ndvi_proximity_full_sample.png` | Fig S4b (combined: top NDVI, bottom proximity) |
| `models_result_ndvi_proximity_crude.png` | Fig S3b (combined: top NDVI, bottom proximity) |

> **Note:** Model objects from this step are loaded by `07e_regenerate_manuscript_figures.R` (Step 7e) to regenerate manuscript figures with correct styling. Primary outlier-excluded figure (Fig 3) comes from `07c_generate_linear_ice_outl_figures.R` (Step 7c); its NDVI and proximity ICE Q1/Q5 .rds files are also used by Step 7e to compose Fig 4.

**Run:**
```r
source("code/05_models_linear.R")
```

---

### Step 5b — Merge primary and supplementary CBG NH files

**Script:** `code/05b_prep_cbg_nh_combined.R`  
**Requires:** Two archival CBG-level CSV files from the `dewey_dta_walking` project, copied into `data/raw/neigh_home/` (see PROVENANCE.md there).  
**What it does:**

Advan Research neighboring-home data came from two separate pipeline runs, both in `dewey_dta_walking`:

| Source | File | CBGs | Tracts | Notes |
|--------|------|------|--------|-------|
| Primary | `2019_full_year_neighbor_home_nyc_la_annual_average.csv` | 15,483 | 5,434 | Main Advan Neighborhood Patterns Plus run; has `city` column |
| Supplementary | `2019_full_year_neighbor_home_supplementary_annual_average.csv` | 949 | 258 | Second run, covers tracts absent from primary; `city` column NA (inferred from state FIPS) |

Zero CBG overlap between sources, by design. Script harmonizes column names, infers `city` for the supplementary source from state FIPS (06xxx → LA, 36xxx → NYC), keeps `months_present` for downstream filtering, writes merged file to:

```
data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv
```

Key columns kept: `GEOID_CBG` (12-digit), `TRACT_GEOID` (11-digit), `city`, `nh_source`, `months_present`, `avg_neighbor_home_device_counts`, `avg_home_device_counts_total_parsed`, `avg_device_counts_row_total`.

Single canonical CBG-level input for all downstream NH processing. Step 6 always reads from it.

**Run:**
```r
source("code/05b_prep_cbg_nh_combined.R")
```

---

### Step 6 — Prepare the neighboring-home visits metric

**Script:** `code/06_prep_neighbor_visits_annual_average.R`  
**Requires:** `data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_cbg_combined.csv` from Step 5b; `data_models.rds` from Step 5; PAD-US AR shapefile; `krieger_ice_{nyc,la}.rds` (already in `data/generated/`).  
**What it does:**

Neighboring-home (NH) metric: for each destination tract, device visits from homes within 0.5 miles (804 m), restricted to destination CBGs containing publicly accessible green space (PAD-US AR). Aligns the behavioral metric with green space use rather than general local mobility.

**CBG inclusion criteria (both must hold):**
1. `months_present == 12` — full-year coverage
2. CBG geometry intersects at least one PAD-US AR polygon — destination has accessible green space

**Aggregation to tract level** (sum from qualifying CBGs):
- `neighbor_visit_count_annual_avg` = Σ `avg_neighbor_home_device_counts`
- `home_device_counts_total_parsed_annual_avg` = Σ `avg_home_device_counts_total_parsed`
- `device_counts_row_total_annual_avg` = Σ `avg_device_counts_row_total`

Outcome and model offset (`log(home_device_counts_total_parsed_annual_avg)`) both computed from the same set of green-space CBGs, so models run unchanged.

**Tract inclusion:** tract enters the NH analytic sample only if ≥1 constituent CBG meets both criteria (`has_greenspace_tract == TRUE`). Tracts with no qualifying CBGs get `NA` on the outcome, excluded by the complete-case filter in Step 7.

Script downloads 2019 TIGER CBG geometries via `tigris` (cached), intersects with the PAD-US AR shapefile, joins the green-space flag to NH data before aggregating.

**Outputs written to `data/generated/`:**
- `data_models_neighbor_visits_annual_average_2019_full_year.rds` — full modeling dataset joined with NH metrics and `has_greenspace_tract` flag
- `neighbor_visit_annual_average_2019_full_year_tract.rds` / `.csv` — tract-level NH metrics (green-space CBGs only)

**Run:**
```r
source("code/06_prep_neighbor_visits_annual_average.R")
```

---

### Step 7 — Fit the neighboring-home GAMs

**Script:** `code/07_models_neighbor_visits_annual_average.R`  
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

Offset `log(home_device_counts_total_parsed_annual_avg)` = log of mean monthly total parsed home-origin device count. Model then estimates the rate of neighboring-home visits relative to total nearby device activity.

ICE Q1/Q5 models can't use `fit_by()` (doesn't forward `offset_var`). Fit via `split(data, city)` + `lapply` instead, running city-specific models per income stratum.

**Outputs written to `output/` (via `07e_regenerate_manuscript_figures.R`):**

| File | Manuscript reference |
|------|---------------------|
| `models_result_neighbor_visit_annual_avg_primary_crude_2019_full_year.png` | Fig S3a (crude sensitivity) |
| `models_result_neighbor_visit_annual_avg_primary_adjusted_2019_full_year.png` | Fig S4a (full-sample sensitivity) |
| `models_result_neighbor_visit_annual_avg_share_adjusted_2019_full_year.png` | Not in manuscript |

> **Note:** PRIMARY NH figure (Fig 2) uses the **outlier-excluded** model from Step 7c, not the full-sample model here. Fig S4a = full-sample (Sensitivity 2) NH figure; Fig S3a = crude (Sensitivity 1) NH figure.
>
> **GAM spline edf:** Primary outlier-excluded models (Fig 2): edf ≈ 1.0 (LA: 1.024; NYC: 1.016) — effectively linear CSI–NH after adjustment. Crude outlier-excluded (Fig S3a): higher edf (LA: 1.23; NYC: 1.26). Full-sample adjusted (Fig S4a): elevated edf (LA: 2.40; NYC: 3.70), consistent with influential high-leverage tracts pulling the spline.

**Outputs written to `data/generated/`:**
- `neighbor_visit_annual_average_model_objects_2019_full_year.rds` — all model objects
- `neighbor_visit_primary_fit_city_nyc_2019_full_year.rds` — adjusted NYC model
- `neighbor_visit_primary_fit_city_la_2019_full_year.rds` — adjusted LA model
- `neighbor_visit_primary_crude_fit_city_nyc_2019_full_year.rds` — crude NYC model
- `neighbor_visit_primary_crude_fit_city_la_2019_full_year.rds` — crude LA model
- `neighbor_visit_ice_q1_q5_fit_2019_full_year.rds` — ICE Q1/Q5 model objects

**Run:**
```r
source("code/07_models_neighbor_visits_annual_average.R")
```

---

### Step 7b — Generate NH ICE Q1/Q5 figure

**Script:** `code/07b_generate_nh_ice_q1_q5_figure.R`  
**Requires:** `data_models_neighbor_visits_annual_average_2019_full_year.rds` from Step 6.  
**What it does:** Fits city-specific negative binomial GAMs for NH outcome, separately for Q1 (most disadvantaged) and Q5 (most advantaged) ICE income quintiles, via `split(data, city)` + `lapply` (not `fit_by()`, doesn't forward offset). Saves model objects, generates combined figure.

**Outputs:**
- `data/generated/neighbor_visit_ice_q1_q5_fit_2019_full_year.rds` — model objects
- `output/models_result_neighbor_visit_q1_q5_ICE_inc_2019_full_year.png` — NH ICE model object source (combined into Fig 4 by Step 7e)

**Run:**
```r
source("code/07b_generate_nh_ice_q1_q5_figure.R")
```

---

### Step 7c — Generate primary figures and ICE Q1/Q5 (outlier-excluded)

**Script:** `code/07c_generate_linear_ice_outl_figures.R`  
**Requires:** `data_models.rds` from Step 5.  
**What it does:** Re-fits five groups of models from saved datasets, all with city-specific outlier exclusion (|z_CSI| > 2):
1. NDVI GAMs, ICE Q1/Q5 tracts by city (outlier-excluded within each stratum) → .rds for **Fig 4** (middle row, via Step 7e)
2. Proximity Gamma GAMs, ICE Q1/Q5 tracts by city (outlier-excluded) → .rds for **Fig 4** (bottom row, via Step 7e)
3. NDVI + proximity GAMs, outliers excluded → .rds for **Fig 3** (combined: top NDVI, bottom proximity, via Step 7e)
4. NH negative binomial GAMs, outliers excluded → **Fig 2** (primary NH figure)

Fig 2 uses `plot_city_comparison()` directly. ICE .rds (1–2) consumed by Step 7e's `plot_ice_overlay()`. NDVI/proximity .rds (3) consumed by Step 7e's `plot_city_comparison()`.

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

**Script:** `code/07e_regenerate_manuscript_figures.R`  
**Requires:** All `data/generated/*.rds` model objects from Steps 5, 7, 7c.  
**What it does:** Loads saved model objects, regenerates all 7 main + supplementary smooth figures.
- Figs 2, 3, S4, S5: `plot_city_comparison()` — shared y-axis, log scale where appropriate, city-name titles per panel, no right y-label.
- Fig 4: `plot_ice_overlay()` — overlays Q1 (red) and Q5 (blue) on one panel. Each stratum's curve is the model's centered CSI smooth, same conditional-association scale as `plot_smooth_gam()`/`plot_city_comparison()`, no stratum intercept added back. `make_ice_row()`'s `log_y` argument: `TRUE` for NH and proximity, `FALSE` for NDVI (matches each outcome's Fig 2/3 setting). Shared y-axis per row via `compute_shared_ylim()` (same helper as Figs 2/3). Centered/ratio-scale convention matches prior GAM-curve papers (`gratia::draw(mod, fun = exp)`, no intercept) — see `manuscript/writing_style_guide.md` §5.
- `plot_ice_overlay()` suppresses per-panel legend (`legend.position = "none"`); script extracts one shared legend via `cowplot::get_legend()` from a reference panel (source panel's `legend.position` must be `"right"`, not `"top"` — `"top"` silently returns an empty guide-box in this cowplot/ggplot2 combination), places it above the three stacked rows via `patchwork::wrap_elements()`.
- NDVI+proximity figures: 2-row patchwork (1400×1200 px). Fig 4: 4-row patchwork incl. legend row (1400×1800 px).
- Copies all regenerated figures to `manuscript/figs/`. Use whenever figure styling changes — avoids re-fitting models.

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
source("code/07e_regenerate_manuscript_figures.R")
```

---

### Step 7d — Generate Figure 1 and supplementary descriptive maps

**Script:** `code/07d_generate_figure1_maps.R`  
**Requires:** `krieger_ice_nyc.rds`, `krieger_ice_la.rds`, `city_boundary_nyc.rds`, `city_boundary_la.rds`, `community_severance_nyc/la_census_tract.rds`, `data_models_neighbor_visits_annual_average_2019_full_year.rds`, `data_models.rds` (all already in `data/generated/`). City boundary files saved from the 500 Cities shapefile on first run; regenerate only if study area changes.  
**What it does:** Loads tract sf geometry from krieger ICE files, clips to 500 Cities city boundary polygons (`city_boundary_{nyc,la}.rds`) via `sf::st_intersection()` — land portions only — joins outcome/exposure/covariate data, produces:
- **Figure 1** (`ggplot2`/`patchwork`): 2-row × 4-column grid — row 1 LA, row 2 NYC; columns: NH visit rate (NH analytic sample only), NDVI, distance to nearest green space, CSI. Single shared decile-percentage legend ("0%–10%"…"90%–100%", one purple palette across all four variables) above the grid; column headers and row labels each printed once. Decile ranks computed within-city, per variable, via `dplyr::ntile()`. `coord_sf()` doesn't support `facet_grid(scales = "free")` (shared coordinate scale would collapse LA/NYC — ~44° apart — to specks), so each panel is its own `ggplot`+`geom_sf`, assembled with `patchwork::wrap_plots()`; shared legend extracted once via `cowplot::get_legend()`.
- **Supplementary Fig S1:** panel (a) continuous ICE, panel (b) ICE Q1/Q5 categorical (most deprived = red, Q2–Q4 = gray, most advantaged = blue), stacked under one caption.

`save_supp_map()` and the ICE-map panel-b block build LA first, then NYC — matches every "Left: LA; right: NYC" caption.

NDVI and distance-to-green-space spatial maps aren't generated separately — Figure 1 already maps both (columns 2–3), decile-shaded rather than quantile-value-labeled.

Non-Figure-1 maps: within-city quantile (decile) breaks (`tm_scale_intervals(n=10, style="quantile")`), actual value ranges in legend (no D1–D10 labels). NA tracts rendered transparent. Color scales: YlGn = NDVI, Blues = proximity, RdBu = ICE continuous, tricolor (red/gray/blue) = ICE Q1/Q5 categorical.

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
source("code/07d_generate_figure1_maps.R")
```

---

### Step 8a — Generate descriptive table (Table 1)

**Script:** `code/08a_table1_outcome_descriptives_neighbor_visits.R`  
**Requires:** `data_models_neighbor_visits_annual_average_2019_full_year.rds`  
**What it does:** Formatted LaTeX table, descriptive statistics (median [P25, P75]) by city (NYC, LA): three outcomes (NDVI, distance to green space, NH visit count), CSI (Exposure), six covariates (% Black, % Hispanic, % poverty, population density, building density, ICE). Missing-data variables get a lettered footnote (a–g) with count and, for NH visits/NDVI, the reason for exclusion.

Booktabs formatting (`\toprule`, `\midrule`, `\bottomrule`); included in the manuscript via `\input{}`.

**Outputs written to `output/`:**
- `table1_descriptives_2019_full_year.tex`

**Run:**
```r
source("code/08a_table1_outcome_descriptives_neighbor_visits.R")
```

---

### Step 8b2 — Generate Supplementary Table S1 (missing vs. analytic sample)

**Script:** `code/08b2_generate_supp_table_nh_missingness.R`  
**Requires:** `data_models_neighbor_visits_annual_average_2019_full_year.rds`  
**What it does:** Supplementary Table S1: compares tracts excluded from the NH analytic sample vs. the 2,018-tract analytic sample. Excluded if no destination CBG intersects a PAD-US AR polygon with 12 months complete data (N = 1,294 tracts). Within the 2,018-tract sample, NH GAMs actually fit on 1,963 tracts (LA = 542, NYC = 1,421) after `complete.cases()` on modeling covariates — 55 tracts (2.7%; LA = 22, NYC = 33) further excluded for missing covariate data (most commonly missing CSI, 48 tracts, or race/ethnicity/poverty, 36 tracts each), predominantly non-residential areas with near-zero building density (median 0.009 vs. 0.245 among retained). Reports median (IQR) for continuous, N (%) for categorical.

**Table path:** `output/supp_table_nh_missingness.tex`, copied to `manuscript/tables/supp_table_nh_missingness.tex`. Included in the manuscript via `\input{tables/supp_table_nh_missingness.tex}`.

**Outputs written to `output/` and `manuscript/tables/`:**
- `supp_table_nh_missingness.tex`

**Run:**
```r
source("code/08b2_generate_supp_table_nh_missingness.R")
```

---

### Step 8c — Extract effect estimates (Q25-to-Q75 quartile contrasts are the numbers in the manuscript)

**Script:** `code/08c_extract_numeric_results.R`  
**Requires:** Model objects from Steps 5 and 7; `data_models.rds`.  
**What it does:** Computes the Q25-to-Q75 quartile contrast — the quantity cited in the manuscript Results, Abstract, and Table S2 — writes to `output/numeric_results_quartile_contrasts.csv`.

**Output (used by the manuscript): `output/numeric_results_quartile_contrasts.csv`**
Computed by `compute_quartile_contrasts()` (mirrors `main_anchored_quartile_contrasts.R` in `bne_uncertainty_ses_multiyear`). For each outcome × city: `mgcv::predict.gam(..., type = "lpmatrix")` contrast between CSI at city-specific Q25/Q50/Q75 (covariates fixed at city means, random effect cancels by construction), delta-method uncertainty on the CSI smooth's vcov submatrix. Three contrasts per outcome × city: `Q50_vs_Q25`, `Q75_vs_Q25`, `Q75_vs_Q50`. Source of Table S2 (`supp_table_s2_per_iqr.tex`) and every Q25-to-Q75 number in Results §3.2–3.3 and Discussion. RR/ratio values rounded to 2 dp in text and Table S2 (CI bounds too); NDVI absolute-difference stays at 3 dp — see `manuscript/writing_style_guide.md` §4.

**Note on `supp_table_s2_per_iqr.tex`:** despite the filename saying "per_iqr," contents are the Q25-to-Q75 quartile contrasts from `numeric_results_quartile_contrasts.csv`. Generated by `code/08c2_generate_supp_table_s2_per_iqr.R`, reads that CSV, writes `output/supp_table_s2_per_iqr.tex`, copied to `manuscript/tables/`. Run:
```r
source("code/08c2_generate_supp_table_s2_per_iqr.R")
```
Rounding uses a round-half-away-from-zero helper (`round_half_up()`), not raw `sprintf()` — avoids off-by-one-digit errors at `.xx5` boundaries from binary floating-point (e.g. `sprintf("%.2f", -0.615)` gives `"-0.61"` since -0.615 is stored as -0.61499999999999999...). `08c_extract_numeric_results.R` stores `csi_q25`/`csi_q50`/`csi_q75` at 5 dp (not 3) for the same reason — rounding a pre-rounded 3dp value to 2dp is a double-rounding hazard.

> **Note on proximity direction:** ratio < 1 for proximity = higher CSI associated with **shorter** distance to nearest green space. In NYC this reflects park placement along arterial corridors, not improved access. Manuscript Results §3.3 and Discussion ¶3 address this.

**Run:**
```r
source("code/08c_extract_numeric_results.R")
```

---

### Step 8d — Extract outlier exclusion counts (the "excluded tracts" numbers in the manuscript)

**Script:** `code/08d_extract_outlier_exclusion_counts.R`  
**Requires:** `data_models.rds`; `data_models_neighbor_visits_annual_average_2019_full_year.rds`.  
**What it does:** Per city and outcome, counts census tracts excluded from the primary (adjusted, outlier-excluded) analytic samples by the `|z_CSI| > 2` (city-specific) rule stated in the manuscript's Statistical analysis subsection. Replicates the same city-specific z-score exclusion logic as `07c_generate_linear_ice_outl_figures.R` (Figs 2, 3) and `05_models_linear.R`, applied separately per outcome so missingness differences across outcomes show up in the counts rather than assuming one shared exclusion count.

**Output: `output/numeric_results_outlier_exclusion_counts.csv`**

| Outcome | LA excluded | NYC excluded |
|---|---|---|
| Neighboring-home visits | 33 | 84 |
| NDVI | 62 | 87 |
| Distance to green space | 62 | 98 |

(Consistency check: for neighboring-home visits, `Outlier + Within + NA` reproduces the primary NH analytic sample sizes already in the manuscript (line 154) — LA 33 + 514 + 17 = 564; NYC 84 + 1,339 + 31 = 1,454 — confirms this script's counts come from the same sample the manuscript describes.)

**Run:**
```r
source("code/08d_extract_outlier_exclusion_counts.R")
```

---

### Step 8e — Extract tract area by city (context for the LA-vs-NYC distance comparison)

**Script:** `code/08e_extract_tract_area_by_city.R`  
**Requires:** `data/generated/krieger_ice_la.rds`; `data/generated/krieger_ice_nyc.rds`.  
**What it does:** Median (IQR) census tract land area, by city, from `sf::st_area()` on the tract geometries used to build the ICE indices. Context for the Results-section comparison of median distance to nearest green space (LA 435 m vs. NYC 182 m): LA tracts are markedly larger, so part of the absolute-distance gap is mechanical (a fixed point feature is, on average, farther from the population-weighted centroid of a larger tract), not purely differential accessibility.

**Output: `output/numeric_results_tract_area_by_city.csv`**

| City | n tracts | Median area (km²) | IQR |
|---|---|---|---|
| LA | 1,148 | 0.80 | 0.48–1.34 |
| NYC | 2,164 | 0.19 | 0.16–0.33 |

(Consistency check: 1,148 + 2,164 = 3,312, matching the full analytic universe cited in the manuscript, line 154.)

**Run:**
```r
source("code/08e_extract_tract_area_by_city.R")
```

---

### Step 8f — Generate Supplementary Table (outlier-tract geography and built environment)

**Script:** `code/08f_generate_supp_table_outlier_geography.R`  
**Requires:** `data/generated/data_models.rds`; `data/generated/krieger_ice_la.rds`; `data/generated/krieger_ice_nyc.rds`.  
**What it does:** Compares tract area, population density, building density, and CSI between tracts excluded by the primary `|z_CSI| > 2` outlier rule and tracts retained, by city. Answers whether outlier-excluded tracts (driving the non-linearity in the full-sample sensitivity analysis, Fig S4) have distinguishing geographic characteristics. Distance to city boundary deliberately excluded — sensitive to which tracts define the city union polygon, not a stable number.

`|z_CSI| > 2` flags both distribution tails. LA's outliers are all high-CSI (z > 2); NYC splits into high-CSI (z > 2, n = 57) and low-CSI (z < -2, n = 41) groups with materially different area/density profiles, so NYC gets separate columns rather than one pooled "outlier" column.

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
source("code/08f_generate_supp_table_outlier_geography.R")
```

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
| `city_boundary_nyc.rds` | Extracted from 500 Cities shapefile; saved once |
| `city_boundary_la.rds` | Extracted from 500 Cities shapefile; saved once |

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

> All figures copied to `manuscript/figs/` for self-contained Overleaf compilation. Tables (incl. Table S1) in `manuscript/tables/`. Manuscript uses relative paths `figs/` and `tables/` (not `../output/`) — compile from within `manuscript/`.

---

## Table 2 covariate missingness

`code/08l_inspect_table2_missingness.R` (Step 8l) reproduces the Table 2 missingness footnote check. Output: `output/table2_missingness_diagnosis.csv`, `output/table2_missingness_maps.png`. Checked by the manuscript audit below.

---

## ICE-stratified (Q1/Q5) extraction scripts

Quantify CSI slope/contrast within each ICE stratum (Q1 most disadvantaged, Q5 most advantaged), per city, feeding the manuscript's Secondary analysis paragraph and Fig 4.

| Script | Outcome | Output |
|---|---|---|
| `code/08h_extract_ice_nh_quartile_contrasts.R` | Neighboring-home visits | `output/numeric_results_ice_nh_quartile_contrasts.csv` |
| `code/08h_extract_ice_ndvi_quartile_contrasts.R` | NDVI | `output/numeric_results_ice_ndvi_quartile_contrasts.csv` |
| `code/08h_extract_ice_distance_quartile_contrasts.R` | Distance to green space | `output/numeric_results_ice_distance_quartile_contrasts.csv` |
| `code/08j_extract_ice_effect_modification_difference_contrasts.R` | Explicit Q5-vs-Q1 contrast-of-contrasts, all three outcomes | `output/numeric_results_ice_effect_modification_difference_contrasts.csv` |

`code/08i_extract_ice_effect_modification_contrasts.R` is a standalone diagnostic (Q1-vs-Q5 baseline gap, not part of the study design) — not cited by any manuscript number, doesn't feed a figure.

Figure 4 (`plot_ice_overlay()`, `code/functions/functions.R`) overlays each stratum's centered CSI smooth, same scale/axis convention as Figs 2/3, via `07e_regenerate_manuscript_figures.R`'s `make_ice_row()`.

---

## Population totals cited in the Discussion

`code/08k_extract_manuscript_misc_counts.R` computes the population totals cited in the Discussion "Strengths" paragraph, from the `population` column of `data_models_neighbor_visits_annual_average_2019_full_year.rds` (not `TotPop`, a separate derived variable used only for `pop_dens`).

## Reproducible manuscript numeric audit

`only_local/audit_manifest.csv` + `only_local/run_manuscript_audit.R` (local-only, gitignored, not part of this repo): mechanical checker for every numeric claim in the manuscript. Reruns every extraction/diagnostic script fresh, checks each computed value against the manuscript. Run:
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
  "tigris"       # TIGER CBG geometries (06_prep_neighbor_visits_annual_average.R)
))

# Data wrangling
install.packages(c("dplyr", "tidyr", "readr", "stringr", "data.table"))

# Visualization
install.packages(c("ggplot2", "GGally", "tmap", "mapview"))
```
