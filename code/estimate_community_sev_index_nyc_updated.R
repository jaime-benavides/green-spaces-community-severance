# script aim: put together inputs to run community severance index over NYC
# First step to load packages etc.
rm(list=ls())
# 1a Declare root directory, folder locations and load essential stuff
project.folder = paste0(print(here::here()),'/')
source(paste0(project.folder,'init_directory_structure.R'))
source(paste0(functions.folder,'script_initiate.R'))

crs <- 2163
city_name <- "nyc"
# set coordinate reference system
#nyc_inputs <-  readRDS(paste0(generated.data.folder, "community_severance_nyc_input_data_city.rds")) # todo: transform to cbsa
#la_inputs <-   readRDS(paste0(generated.data.folder, "community_severance_la_input_data_city.rds"))
#seattle_inputs <- readRDS(paste0(generated.data.folder, "community_severance_seattle_input_data_city.rds"))
dta_inputs <- readRDS(paste0(generated.data.folder, "community_severance_nyc_input_data.rds"))

dta_cs_in <- dta_inputs
dta_cs_in <- dta_cs_in[,c("autom_netw_dens", "autom_inters_dens", "barrier_factor_osm","barrier_factor_fhwa", "motorway_prox", "primary_prox",
  "secondary_prox", "trunk_prox", "interstate_highway_prox", "freeways_expressways_prox", "other_princ_arter_prox", "tertiary_prox", "residential_prox", 
  "aadt_esri_point", "aadt_fhwa_segm", "traffic_co2_emis", "pedest_netw_dens", "street_no_autom_inters_dens", "NatWalkInd")]
family_vars <- c("Road infrastructure", "Road infrastructure", "Road infrastructure", 
                 "Road infrastructure", "Road infrastructure", "Road infrastructure", "Road infrastructure",
                 "Road infrastructure", "Road infrastructure", "Road infrastructure", "Road infrastructure", "Road infrastructure", "Road infrastructure", "Road traffic activity", "Road traffic activity", 
                 "Road traffic activity", "Pedestrian infrastructure", "Pedestrian infrastructure", "Pedestrian infrastructure" )
# smart location database (you can download it here https://www.epa.gov/smartgrowth/smart-location-mapping#SLD)
# set coordinate reference system

name_sim <- city_name

### load community severance input data
data_desc <- readRDS(paste0(generated.data.folder, "smart_location_data_subset_desc.rds"))

built_social_block_comm_sev_m <-  as.matrix(dta_cs_in) # geoid20 and shape out

### estimate community severance index
#c("barrier_factor_osm","traffic_co2_emis", "street_no_autom_inters_dens")

cng <- data.frame(vars = colnames(built_social_block_comm_sev_m), family_vars = family_vars)
cng_comm_sev_vars <- cng
## run pcp grid search  ------------------------------------------------------

# Prepare inputs for pcpr
geoids <- dta_inputs[,"GEOID20"]
dat <- built_social_block_comm_sev_m
mat_cs <- dat

# Define grid and parameters (similar to Script M)
int_rank <- 5L
df_rrmc_grid <- data.frame(
  eta =seq(0.01,0.07, length.out=11)    # log-spaced grid from 0.1 to 100
)
int_runs <- 22L
num_perc_test <- 0.15
num_lod <- rep(0, ncol(mat_cs))

library(parallel)
num_cores <- 4

# Run PCP grid search using pcpr
with_progress(
  expr = {
    list_rrmc_grid_result <- pcpr::grid_search_cv(
      D = mat_cs,
      pcp_fn = pcpr::rrmc,
      grid = df_rrmc_grid,
      r = int_rank,
      perc_test = num_perc_test,
      num_runs = int_runs,
      parallel_strategy = "sequential"  # can set to "multisession" if needed
    )
  }
)

# Inspect results summary
summary_stats <- list_rrmc_grid_result$summary_stats
summary_stats %>% dplyr::slice_min(rel_err)

# Visualize the grid search (keeping your original style)
plot_ly(
  data = summary_stats,
  x = ~eta, y = ~r, z = ~rel_err,
  type = "heatmap"
) %>% layout(title = "RRMC grid search - Relative error")

if ("S_sparsity" %in% colnames(summary_stats)) {
  plot_ly(
    data = summary_stats,
    x = ~eta, y = ~r, z = ~S_sparsity,
    type = "heatmap"
  ) %>% layout(title = "RRMC grid search - Sparsity")
}

# Manual selection rule:
# Choose a solution with low relative error AND sparsity near 0.99
summary_stats <- summary_stats %>%
  dplyr::mutate(
    sparsity_dist = abs(S_sparsity - 0.99)
  )

# Rank candidates: prioritize high sparsity proximity, then low error
summary_stats <- summary_stats %>%
  dplyr::arrange(sparsity_dist, rel_err)

# View top few options
head(summary_stats[, c("eta", "r", "rel_err", "S_sparsity")])

# best combination: r 2 eta 
num_eta_opt <- 0.028
num_r_opt <- 2

cat("Chosen eta:", num_eta_opt, " | rank:", num_r_opt, "\n")

# Run PCP with chosen parameters
pcp_outs <- pcpr::rrmc(
  D   = mat_cs,
  r   = num_r_opt,
  eta = num_eta_opt,
  LOD = num_lod
)

# Diagnostics for L-matrix sparsity
cat("Share of L < 0:", sum(pcp_outs$L < 0) / prod(dim(pcp_outs$L)), "\n")
cat("Share of L < -0.5:", sum(pcp_outs$L < (-0.5)) / prod(dim(pcp_outs$L)), "\n")

# Save result for later use
saveRDS(pcp_outs, file = paste0(generated.data.folder, "pcp_rrmc_", name_sim, "_updated.rds"))


# run factor analysis on low rank matrix
cn <- colnames(pcp_outs$S)
data_desc <- data_desc[which(data_desc$var_name %in% cn),]

#re-order columns in low-rank matrix
cng <- data_desc[,c("var_name", "source")]
cng <- cng[which(cng$var_name %in% cn),]
colnames(pcp_outs$L) <- colnames(pcp_outs$S)

# manuscript Figure 3b
# L matrix correlations:
graph_title <- paste0("pcp_rrmc", ": L Pearson correlation")
png(paste0(output.folder, "pcp_rrmc", "_l_matrix_correlations_", name_sim, "_updated.png"), 900, 460)
pcp_outs$L %>% GGally::ggcorr(., method = c("pairwise.complete.obs", "pearson"),
                              label = T, label_size = 3, label_alpha = T,
                              hjust = 1, nbreaks = 10, limits = TRUE,
                              size = 4, layout.exp = 5) + ggtitle(graph_title)
dev.off()


# manuscript Figure 3a
graph_title <- paste0("raw_data", ": Pearson correlation")
png(paste0(output.folder, "raw_mat_corr_", name_sim, "_updated.png"), 900, 460)
mat_cs %>% GGally::ggcorr(., method = c("pairwise.complete.obs", "pearson"),
                          label = T, label_size = 3, label_alpha = T,
                          hjust = 1, nbreaks = 10, limits = TRUE,
                          size = 4, layout.exp = 5) + ggtitle(graph_title)
dev.off()

# factor analysis
ranktol <- 1e-04
L.rank <- Matrix::rankMatrix(pcp_outs$L, tol = ranktol)
scale_flag <- FALSE
pcs <- paste0("PC", 1:L.rank)
factors <- 1:L.rank
n <- nrow(pcp_outs$L)
colgroups_l <- data.frame(column_names = colnames(pcp_outs$L), 
                          family = data_desc[match(colnames(pcp_outs$L), data_desc$var_name), "source"])
colgroups_l$family <- family_vars
colgroups_m <- data.frame(column_names = colnames(mat_cs), 
                          family = data_desc[match(colnames(mat_cs), data_desc$var_name), "source"])
colgroups_m$family <- family_vars

# run factor analysis
orthos <- factors %>% purrr::map(~fa(pcp_outs$L, nfactors = ., n.obs = n, rotate = "varimax", scores = "regression"))
# explore results
orthos %>% walk(print, digits = 2, sort = T)
ortho_ebics <- orthos %>% map_dbl(~.$EBIC)
best_fit <- which.min(ortho_ebics)
# visualize in table
data.frame("Factors" = factors, "EBIC" = ortho_ebics) %>% kbl(caption = "Orthogonal Models: Fit Indices") %>%
  kable_classic(full_width = F, html_font = "Cambria", position = "center") %>%
  kable_styling(bootstrap_options = c("hover", "condensed"), fixed_thead = T) %>%
  row_spec(best_fit, bold = T, color = "white", background = "#D7261E")

fa_model <- orthos[[best_fit]]

print(fa_model, digits = 2)

# organize loadings
loadings <- as_tibble(cbind(rownames(fa_model$loadings[]), fa_model$loadings[]))
colnames(loadings)[1] <- "Variable"
loadings <- loadings %>% mutate_at(colnames(loadings)[str_starts(colnames(loadings), "MR")], as.numeric)
loadings$Max <- colnames(loadings[, -1])[max.col(loadings[, -1], ties.method = "first")] # should be 2:5
# loadings table
# manuscript Table S1
loadings %>% kbl(caption = "Loadings") %>% kable_classic(full_width = F, html_font = "Cambria", position = "center") %>% 
  kable_styling(bootstrap_options = c("hover", "condensed"), fixed_thead = T) %>% scroll_box(width = "100%", height = "400px") 
# organize scores
scores <- as.tibble(cbind(rownames(fa_model$scores[]), fa_model$scores[])) %>% mutate_all(as.numeric)
scores$Max <- colnames(scores)[max.col(scores, ties.method = "first")]
# scores table
scores %>% kbl(caption = "Scores") %>% kable_classic(full_width = F, html_font = "Cambria", position = "center") %>% 
  kable_styling(bootstrap_options = c("hover", "condensed"), fixed_thead = T) %>% scroll_box(width = "100%", height = "400px")

# prepare loadings for plotting
fa_pats <- loadings %>% 
  dplyr::select(-Max, -Variable) %>% 
  mutate_all(as.numeric)
fa_pats <- fa_pats %>% dplyr::select(sort(colnames(.))) %>% as.matrix()
# build dataframe for plotting
dat <- cbind(colgroups_l, fa_pats)
# plot loadings
p <- 1 # 1 is for community severance index (manuscript Figure 4) and 2 for the other pattern (manuscript Figure S1)
png(paste0(output.folder, "_l_fa_", p, "_patterns_", name_sim, "_updated.png"), 1250, 460)
print_patterns_loc(dat[,c("MR1", "MR2")], colgroups = dat[,c("column_names", "family")], pat_type = "factor", n = p, title = "FA factors", size_line = 2, size_point = 3.5)
dev.off()
# variability explained 59 and 41

# save normalized scores
dat_scores <- cbind(built_social_block_comm_sev_m, scores)
dat_scores$GEOID20 <- geoids
saveRDS(dat_scores, paste0(generated.data.folder, "csi_scores_nyc.rds"))
normalize <- function(x) {
  return ((x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE)))
}
dat_scores$MR1_norm <- normalize(dat_scores$MR1)
saveRDS(dat_scores, paste0(generated.data.folder, "comm_sev_fa_scores", name_sim, "_dta_us_updated.rds"))



