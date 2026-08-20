# CSI factor scores (LA + NYC) — Provenance

`csi_scores_la.rds` and `csi_scores_nyc.rds` are self-generated outputs of the
author's own Principal Component Pursuit + factor analysis pipeline for the
Community Severance Index (see `sn-article.tex` §2.3 and
\citep{Benavides2024Development}), not third-party datasets. Neither is
publicly downloadable — both are copied here so the code package is
self-contained.

**Source projects:** `community_severance_us` (LA) and `community_severance_nyc`
(NYC) (both external to this repo)
**Date copied:** 2026-08-20
**Used by:** `code/prep_csi.R` (Step 2), as `dta_csi_la_cbg` / `dta_csi_nyc_cbg`
