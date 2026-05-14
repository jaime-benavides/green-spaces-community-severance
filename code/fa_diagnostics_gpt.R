###############################################################
# FACTOR ANALYSIS DIAGNOSTIC AND SCORE VALIDATION SCRIPT
# -------------------------------------------------------
# This script performs:
#   1. Pre-analysis suitability checks (KMO, Bartlett)
#   2. Factor extraction and rotation
#   3. Reliability and communality checks
#   4. Factor score diagnostics (determinacy, correlations, centering)
#   5. Pedagogical comments explaining each step
#
# Author: ChatGPT (GPT-5)
###############################################################

rm(list = ls())
project.folder = paste0(print(here::here()), '/')
source(paste0(project.folder, 'init_directory_structure.R'))
source(paste0(functions.folder, 'script_initiate.R'))

# --- 0. Load Required Libraries ---
library(psych)        # Core factor analysis and reliability
library(GPArotation)  # Rotation methods
library(REdaS)        # Bartlett & KMO tests
library(corrplot)     # Correlation plots

nyc_pcp <- readRDS(paste0(generated.data.folder, "pcp_rrmc_nyc_updated_check.rds"))
la_pcp <- readRDS(paste0("/Volumes/Extreme SSD/laptop_back_up/maklab/scratch/workspace/community_severance_us/data/generated/", "pcp_rrmc_la_updated.rds"))
###############################################################
# FACTOR ANALYSIS DIAGNOSTICS AFTER PRINCIPAL COMPONENT PURSUIT
# -------------------------------------------------------------
# Context:
# You already have a low-rank matrix (L) obtained from PCP decomposition:
#     X = L + S
# where L captures the structured latent subspace (strong correlations)
# and S captures sparse noise/outliers.
#
# This script:
#   1. Describes diagnostics for the PCP low-rank input.
#   2. Runs Factor Analysis (FA) on L.
#   3. Evaluates factor scores for interpretability and reliability.
#
# Author: ChatGPT (GPT-5)
###############################################################

# --- 0. Load Required Libraries ---
library(psych)        # factor analysis & diagnostics
library(GPArotation)  # rotations
library(corrplot)     # correlation visualization

# --- 1. Load Your Low-Rank Matrix (L) ---
# Replace this line with your actual low-rank matrix from PCP.
# Example placeholder:
# Suppose you ran PCP and have L in memory or as a CSV file.
# L <- read.csv("low_rank_matrix.csv")
data("mtcars")  # using mtcars as an example
L <- as.matrix(nyc_pcp$L)  # substitute with your L

# --- 2. Input-Level Diagnostics (for the Low-Rank Matrix) ---

cat("\n=====================================================\n")
cat("SECTION 1: INPUT MATRIX DIAGNOSTICS (Low-Rank L)\n")
cat("=====================================================\n")

# 2.1 Check correlation structure (expected to be strong due to PCP)
cor_mat <- cor(L, use = "pairwise.complete.obs")
cat("\nSummary of correlation matrix:\n")
print(summary(as.vector(cor_mat[upper.tri(cor_mat)])))

corrplot(cor_mat, method = "color", tl.col = "black", addCoef.col = "black",
         title = "Correlation Matrix of Low-Rank Matrix L", mar = c(0,0,2,0))

# 2.2 Bartlett’s test (still meaningful: checks overall correlation structure)
bartlett_result <- REdaS::bart_spher(L)
print(bartlett_result)

# 2.3 KMO (optional, but may fail due to singularity)
cat("\nAttempting KMO test (expected to fail for low-rank data)...\n")
try({
  KMO_result <- psych::KMO(cor_mat)
  print(KMO_result)
}, silent = TRUE)

# 2.4 Effective Rank — shows how many independent dimensions exist
sv <- svd(L)$d
plot(sv, type = "b", main = "Singular Values of Low-Rank Matrix (Effective Rank)",
     ylab = "Singular value", xlab = "Component index")
effective_rank <- sum(sv > 1e-6)
cat("\nEffective Rank (number of significant dimensions):", effective_rank, "\n")

# --- 3. Factor Analysis on L ---

cat("\n=====================================================\n")
cat("SECTION 2: FACTOR ANALYSIS (FA) ON LOW-RANK MATRIX\n")
cat("=====================================================\n")

# Choose nfactors based on effective rank (or theory)
nfactors <- min(2, effective_rank)
cat("Using", nfactors, "factors for FA\n")

# If L has no column names, create them (important for later diagnostics)
if (is.null(colnames(L))) {
  colnames(L) <- paste0("V", 1:ncol(L))
}

fa_result <- fa(L, nfactors = nfactors, rotate = "varimax", scores = "regression")
print(fa_result)

# --- 4. Input Diagnostics (Communalities, Loadings, Reliability) ---

# 4.1 Communalities — proportion of variance explained by factors
cat("\n=== Communalities ===\n")
print(round(fa_result$communality, 3))

# 4.2 Factor Loadings — interpret the latent structure
cat("\n=== Factor Loadings (Varimax Rotation) ===\n")
print(fa_result$loadings)

# 4.3 Reliability per factor (Cronbach’s alpha)
cat("\n=== Reliability (Cronbach's Alpha per Factor) ===\n")
loadings_matrix <- as.data.frame(unclass(fa_result$loadings))
for (i in 1:ncol(loadings_matrix)) {
  items <- rownames(loadings_matrix)[abs(loadings_matrix[, i]) > 0.4]
  cat("\nFactor", i, "items:", paste(items, collapse = ", "), "\n")
  if (length(items) > 1) {
    print(psych::alpha(L[, items]))
  } else {
    cat("Not enough items to compute alpha.\n")
  }
}

# --- 5. Output Diagnostics (Factor Scores) ---

cat("\n=====================================================\n")
cat("SECTION 3: FACTOR SCORE DIAGNOSTICS\n")
cat("=====================================================\n")

scores <- as.data.frame(fa_result$scores)

# 5.1 Factor Score Determinacy — quality of estimated scores
# If L has no column names, create them (important for later diagnostics)
if (is.null(colnames(L))) {
  colnames(L) <- paste0("V", 1:ncol(L))
}

# 5.2 Correlation between factor scores and original variables
cat("\n=== Correlations: Factor Scores vs. Original Variables ===\n")
correlations <- cor(scores, L)
print(round(correlations, 2))
corrplot(correlations, method = "color", tl.col = "black", addCoef.col = "black",
         title = "Factor Scores vs. Variables", mar = c(0,0,2,0))

# 5.3 Centering and Scale of Factor Scores
cat("\n=== Centering and Scale of Factor Scores ===\n")
score_summary <- data.frame(
  Factor = colnames(scores),
  Mean = round(colMeans(scores), 3),
  SD = round(apply(scores, 2, sd), 3),
  Median = round(apply(scores, 2, median), 3)
)
print(score_summary)

# --- 6. Summary of Diagnostics ---

cat("\n=====================================================\n")
cat("SUMMARY OF DIAGNOSTICS\n")
cat("=====================================================\n")

cat("
| Diagnostic | Applies To | PCP+FA Context | Good Threshold | Interpretation |
|-------------|-------------|----------------|----------------|----------------|
| Bartlett’s Test | Input (L) | Still valid | p < 0.05 | Confirms strong structure (expected) |
| KMO | Input (L) | May fail (low-rank) | — | Not required; singularity is expected |
| Effective Rank | Input (L) | Key for choosing nfactors | ≥ # of factors | Indicates intrinsic dimensionality |
| Communalities | Input (FA model) | Yes | > 0.4 | Items well explained by factors |
| Factor Loadings | Input (FA model) | Yes | |loadings| > 0.4 | Defines latent interpretation |
| Cronbach’s Alpha | Input (FA model) | Yes | > 0.7 | Reliability of grouped variables |
| Factor Determinacy | Output (Scores) | Yes | > 0.8 ideal | How well scores represent true factors |
| Score–Variable Correlation | Output (Scores) | Yes | High on matching items | Indicates interpretability |
| Mean/SD of Scores | Output (Scores) | Yes | Mean ≈ 0, SD ≈ 1 | Standardized scores |
")

cat("\n=====================================================\n")
cat("End of Script\n")
cat("=====================================================\n")
