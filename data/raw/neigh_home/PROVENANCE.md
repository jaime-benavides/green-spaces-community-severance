# Neighbor-Home Metric — Provenance

Files in this folder are outputs of the `dewey_dta_walking` project and
should not be edited here. To regenerate, rerun the pipeline in that project.

**Source project:** `dewey_dta_walking` (external to this repo)  
**Date copied:** 2026-05-13 (CBG-level annual-average CSV); 2026-06-08 (tract-average CSV);
2026-08-20 (supplementary CBG-level annual-average CSV)  
**Audit report last updated:** 2026-05-13  

---

## Files

| File | Description | Role |
|------|-------------|------|
| `2019_full_year_neighbor_home_nyc_la_tract_average.csv` | Pre-merged tract-level NH estimates: all 2019 TIGER CBGs within the 500 Cities boundaries for NYC and LA, aggregated to census tract, full year (12 months), primary + supplementary sources combined | **Workflow input — Step 6** |
| `2019_full_year_neighbor_home_nyc_la_annual_average.csv` | Annual-average NH estimates at the CBG level, NYC and LA, 2019 — primary Advan Neighborhood Patterns Plus data only | Archival / raw source |
| `2019_full_year_neighbor_home_supplementary_tract_average.csv` | Tract-level NH estimates for 258 tracts whose CBGs were absent from the primary Advan output; processed via a supplementary pipeline run | Archival / raw source |
| `2019_full_year_neighbor_home_supplementary_annual_average.csv` | CBG-level NH estimates for the 949 CBGs from the supplementary pipeline run (pre-tract-aggregation) | `code/prep_cbg_nh_combined.R` (Step 5b) input |
| `2019_neighbor_home_robustness_audit.html` | Full robustness and coverage audit — read before using the metric in any model | Reference |
| `neigh_home.tex` | Methods manuscript (in prep, Discover Cities) — cite for methods description | Reference |

The tract-average CSV was derived by processing all 2019 TIGER CBGs that intersect the
500 Cities boundaries for NYC and LA through the Advan Neighborhood Patterns Plus pipeline,
aggregating from CBG to tract, and merging primary and supplementary outputs into a single
file. The canonical upstream CBG list is 2019 TIGER CBGs intersected with the 500 Cities
boundaries — not the Advan barrier-factor reference, which was an implementation detail
of the upstream processing.

---

## NH coverage

Of 3,312 study-area tracts (krieger_ice), 3,307 have NH data in the tract-average CSV.
Five tracts have NH = NA in the analytic dataset:

- **4 LA tracts** (06037543604, 06037603001, 06037650902, 06037670602): restricted
  industrial or port areas with no civilian device footfall recorded in the Advan data.
- **1 NYC Bronx tract** (36005001900): present in the Advan supplementary output but
  with only 9 of 12 months of data; excluded upstream per the 12-month completeness
  requirement.

All five are reflected correctly in `data/generated/data_models_neighbor_visits_annual_average_2019_full_year.rds`.

---

## How to use the covariate

**Join key:** `TRACT_GEOID` (11-digit tract GEOID, left-padded with zero)  
**Primary variable:** `neighbor_visit_count_annual_avg` (annual-average NH visit count per tract)  
**City column:** `city` (`"NYC"` or `"LA"`)  
**Source flag:** `nh_source` (`"primary"` or `"supplementary_barrier_ref"`)

```r
library(readr)
library(dplyr)
library(stringr)

nh <- read_csv(
  "data/raw/neigh_home/2019_full_year_neighbor_home_nyc_la_tract_average.csv"
) |>
  mutate(TRACT_GEOID = str_pad(as.character(TRACT_GEOID), 11, "left", "0"))
```

The green space project joins this to `data/generated/data_models.rds` via
`GEOID` × `city` in `code/prep_neighbor_visits_annual_average.R` (Step 6).

---

## Three things to know before using this metric

1. **Missing tracts are not zeros.** Five tracts (0.2%) have no 2019 NH data — they
   are absent from the file, not present with zero. All five are predominantly
   non-residential (industrial/port or insufficient temporal coverage).

2. **Missingness is non-random but negligible.** The 5 missing tracts have near-zero
   building density (median 0.000 vs. 0.267 in the analytic sample) and are unlikely to
   represent meaningful residential destinations for local mobility measurement.

3. **The metric is behaviorally stable.** Median within-year standard deviation across
   CBGs is less than 1 percentage point. The annual average is a reliable summary of the
   year, not a noisy monthly snapshot.

See `2019_neighbor_home_robustness_audit.html` for full details on coverage,
panel representativeness, internal consistency checks, and recommended sensitivity analyses.

---

## Citation

Benavides, J. (in prep). Walking-Scale Accessibility from Mobile Location Data:
A Census Block Group-Level Neighbor-Home Metric for New York City and Los Angeles.
*Discover Cities.*
