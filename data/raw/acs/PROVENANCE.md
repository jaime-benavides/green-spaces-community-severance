# ACS data.table — Provenance

`acs_dt.rds` is a self-generated output of the `community_severance_nys_climate_change_mh`
project: a pre-processed long-format table of ACS estimates (population,
percent Black, percent Hispanic, percent poverty) reused here for the NYC
water-body/greenspace processing step. It is derived from public ACS 5-year
estimates but is not itself a public download — copied here so the code
package is self-contained.

**Source project:** `community_severance_nys_climate_change_mh` (external to this repo)
**Date copied:** 2026-08-20
**Used by:** `code/03_prep_greenspace.R` (Step 3), as `acs.dt`
