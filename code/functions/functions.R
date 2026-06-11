#' get spatial context
#'
#' @export context_sp
#'
#########################################################################
generate_osm_network <- function( #99% inspired by https://github.com/Spatial-Data-Science-and-GEO-AI-Lab/GreenExp_R/blob/main/R/accessibility.R but needed to have network prebuilt 
    boundary,
    city = NULL,
    crs = 3395,
    save_path = NULL,
    max_file_size = 5e+09,
    highway_types = NULL  # optional filter (e.g. c("residential", "footway", "path"))
) {
  # Ensure boundary has projected CRS
  if (sf::st_is_longlat(boundary)) {
    boundary <- sf::st_transform(boundary, crs)
  } else {
    crs <- sf::st_crs(boundary)
  }
  
  # --- 1. Download OSM lines ---
  message("🔹 Downloading OSM network data...")
  if (!is.null(city)) {
    lines <- osmextract::oe_get(
      city,
      boundary = boundary,
      boundary_type = "spat",
      max_file_size = max_file_size,
      stringsAsFactors = FALSE
    )
  } else {
    lines <- osmextract::oe_get(
      boundary,
      boundary = boundary,
      boundary_type = "spat",
      max_file_size = max_file_size,
      stringsAsFactors = FALSE
    )
  }
  
  # --- 2. Filter by highway type (optional) ---
  if (!is.null(highway_types)) {
    message(paste0("🔹 Filtering network for highway types: ",
                   paste(highway_types, collapse = ", ")))
    if ("highway" %in% names(lines)) {
      lines <- dplyr::filter(lines, highway %in% highway_types)
    } else {
      warning("No 'highway' field found in OSM data; skipping filter.")
    }
  } else {
    message("✅ Using all available OSM edges (no highway filtering).")
  }
  
  # --- 3. Transform and clip to boundary ---
  lines <- sf::st_transform(lines, crs)
  if (all(c("osm_id", "name") %in% names(lines))) {
    lines <- dplyr::select(lines, "osm_id", "name")
  } else {
    lines <- lines
  }
  
  lines <- lines[boundary, , op = sf::st_intersects]
  
  # --- 4. Convert to sfnetwork ---
  message("🔹 Building sfnetwork object...")
  net <- sfnetworks::as_sfnetwork(lines, directed = FALSE)
  net <- tidygraph::convert(net, sfnetworks::to_spatial_subdivision)
  
  # --- 5. Keep the largest connected component ---
  message("🔹 Extracting largest connected component...")
  edges_sf <- tidygraph::activate(net, "edges") |> sf::st_as_sf()
  touching <- sf::st_touches(edges_sf)
  graph <- igraph::graph.adjlist(touching)
  comps <- igraph::components(graph)
  biggest <- names(which.max(table(comps$membership)))
  edges_connected <- edges_sf[comps$membership == biggest, ]
  net <- net |> tidygraph::activate("nodes") |> sf::st_filter(edges_connected, .pred = sf::st_intersects)
  
  # --- 6. Compute edge weights (lengths) ---
  net <- tidygraph::mutate(
    tidygraph::activate(net, "edges"),
    weight = sfnetworks::edge_length()
  )
  
  # --- 7. Optional save to file ---
  if (!is.null(save_path)) {
    if (!dir.exists(save_path)) dir.create(save_path, recursive = TRUE)
    edges_sf <- tidygraph::activate(net, "edges") |> sf::st_as_sf()
    sf::st_write(edges_sf, paste0(save_path, "/network.gpkg"), quiet = TRUE)
    message(paste0("💾 Network edges saved to: ", save_path, "/network.gpkg"))
  }
  
  message("✅ Network successfully created.")
  return(net)
}



context_sp <- function(area_type = "municipality", area_name = "Barcelona", use_address = FALSE, address = "Carrer de Valencia 445, 08013 Barcelona, Spain",
                       lon = 2.155278, lat = 41.38611, coords = NULL, geom_path = geom_path, buffer = NULL, area_shape = "circle", crs = 2163) {
  if ((use_address == FALSE) && (is.numeric(lat) == TRUE)) {
    if(length(lon) == 1){
      coords_sp <- sf::st_sf(a=1, geom = sf::st_sfc(sf::st_point(c(lon,lat))), crs = "+proj=longlat +datum=WGS84")
      coords_sp <- sf::st_transform(coords_sp, crs)
    } else {
      coords_sp <- sf::st_sf(a=1, geom = sf::st_sfc(sf::st_multipoint(matrix(c(lon,lat), ncol = 2), dim = "XY")), crs = "+proj=longlat +datum=WGS84")
      coords_sp <- sf::st_transform(coords_sp, crs)
    }
  } else if (use_address == TRUE){
    coords_sp <- get_loc_coord(address = address, spatial_df = TRUE, projection = "UTM")
  } else if (!is.null(coords) == TRUE){
    coords_sp <- coords
  }
  # grid_model <-  sf::read_sf(paste0(geom_path, "Malla_CAT_1km.shp"))
  # grid_model_ij <- grid_model %>%
  #   dplyr::select(I,J, geometry) %>%
  #   sf::st_transform("+proj=utm +zone=31 +ellps=intl +units=m +no_defs")
  if (area_type == "cell") {
    # ref <- sf::st_intersection(grid_model_ij, coords_sp)
    # if(length(unique(ref$I)) > 1){
    #   sp_context <- grid_model_ij[unique(sapply(sf::st_intersects(coords_sp,grid_model_ij), function(z) if (length(z)==0) NA_integer_ else z[1])),]
    # } else {
    #   sp_context <- grid_model_ij[grid_model_ij$I == ref$I & grid_model_ij$J == ref$J,]
    # }
  } else if ((area_type == "municipality") && (!is.null(area_name))) {
    # cat_munic <- sf::st_read(paste0(geom_path, "Catalunya_munic.shp"))
    # sp_context <- cat_munic %>%
    #   sf::st_transform("+proj=utm +zone=31 +ellps=intl +units=m +no_defs") %>%
    #   dplyr::filter(NAME == area_name) %>%
    #   sf:: st_as_sf( ) #%>%
    # #sf::st_intersection(grid_model_ij)
  } else if ((area_type == "address") && (!is.null(address))) {
    # ref <- sf::st_intersection(coords_sp,grid_model_ij)
    # sp_context <- grid_model_ij[grid_model_ij$I == ref$I & grid_model_ij$J == ref$J,]
  } else if ((area_type == "district") && (!is.null(area_name))){
    # districts <- sf::read_sf(paste0(geom_path, "BCN_Districte_ED50_SHP.shp"))
    # sp_context <- districts %>%
    #   sf::st_transform(23031) %>%
    #   dplyr::filter(N_Distri == area_name) %>%
    #   sf::st_as_sf() %>%
    #   sf::st_transform("+proj=utm +zone=31 +ellps=intl +units=m +no_defs")
  } else if ((area_type == "district") && (is.null(area_name)) && (!is.null(lon) & !is.null(lat))){
    # districts <- sf::read_sf(paste0(geom_path, "BCN_Districte_ED50_SHP.shp"))
    # districts_sf <- districts %>%
    #   sf::st_transform(23031) %>%
    #   sf::st_as_sf() %>%
    #   sf::st_transform("+proj=utm +zone=31 +ellps=intl +units=m +no_defs")
    # contains <- districts_sf %>%
    #   sf::st_contains(coords_sp) %>%
    #   as.numeric()
    # sp_context <- districts_sf[which(contains == 1),]
  } else if (area_type == "buffer" && area_shape == "square"){
    sp_context <- sf::st_buffer(coords_sp, buffer, nQuadSegs = 1)
  } else if (area_type == "buffer" && area_shape == "circle"){
    sp_context <- sf::st_buffer(coords_sp, buffer)
  }else {
    print("we are not working yet in that spatial context. Do you think we should?")
  }
  # sp_context <- methods::as(sp_context, "Spatial")
  if(!is.null(buffer) && is.numeric(buffer) && area_type != "buffer"){
    #sp_context <- rgeos::gBuffer(sp_context,width=buffer,capStyle="FLAT")
    sp_context <- sf::st_buffer(sp_context, buffer, nQuadSegs = 30)
  }
  return(sp_context)
}

# kriging from mid point 
# adapted from Criado et al. (2022) https://earth.bsc.es/gitlab/es/universalkriging/-/blob/production/general/UK_mean.R
regrid_ok <- function(non_uniform_data, target_grid,crs_sim = "+proj=utm +zone=31 +ellps=intl +units=m +no_defs"){
  if(isTRUE(class(non_uniform_data) != "SpatialPointsDataFrame")){
    non_uniform_data <- sp::SpatialPointsDataFrame(non_uniform_data[,c("X", "Y")],non_uniform_data)
    sp::proj4string(non_uniform_data) <- crs_sim
  }
  vf_ok      <- automap::autofitVariogram(aadt ~ 1, non_uniform_data)
  ok_regular <- gstat(formula = aadt ~ 1, data = non_uniform_data, model = vf_ok$var_model, nmax = 20) 
  regular <- predict(ok_regular, target_grid)
  regular_sf <- sf::st_as_sf(regular)
  # regular <- sp::spTransform(regular, sp::CRS("+proj=longlat"))
  # pixels <- sp::SpatialPixelsDataFrame(regular,tolerance = 0.99, as.data.frame(regular[,"var1.pred"]))
  # mean_raster <- raster::raster(pixels[,'var1.pred'])
  # return(mean_raster)}
  return(regular_sf)}



print_patterns_loc <- function (pats, colgroups = NULL, n = 1:6, pat_type = "pat", 
                                title = "", size_line = 1, size_point = 1) 
{
  if (!is.null(colgroups)) {
    colgroups <- colgroups %>% dplyr::rename(chem = !!names(colgroups)[1])
  }
  else {
    colgroups <- data.frame(chem = rownames(pats), group = "1")
  }
  if (n > ncol(pats)) 
    n <- ncol(pats)
  grouping <- names(colgroups)[2]
  colnames(pats) <- paste0(pat_type, stringr::str_pad(1:ncol(pats), 
                                                      width = 2, pad = "0", side = "left"))
  pats.df <- pats %>% tibble::as_tibble() %>% dplyr::mutate(chem = colgroups[[1]]) %>% 
    tidyr::pivot_longer(-chem, names_to = "pattern", values_to = "loading") %>% 
    dplyr::right_join(., colgroups, by = "chem")
  pats.df$chem <- factor(as.character(pats.df$chem), levels = unique(as.character(pats.df$chem)))
  loadings <- pats.df %>% dplyr::filter(pattern %in% paste0(pat_type, 
                                                            stringr::str_pad(n, width = 2, pad = "0", side = "left"))) %>% 
    ggplot(aes(x = chem, y = loading, color = !!sym(grouping))) + 
    geom_point(size = size_point) + geom_segment(aes(yend = 0, xend = chem), size = size_line) + 
    facet_wrap(~pattern) + theme_bw() + theme(legend.position = "bottom", legend.text = element_text(size=12), legend.title = element_text(size=14),
                                              axis.text.x = element_text(angle = 45, hjust = 1, size = 14), strip.background = element_rect(fill = "white"), 
                                              axis.title.x = element_blank(), axis.title.y = element_blank()) + 
    geom_hline(yintercept = 0, size = 0.2) #+ ggtitle(title)
  loadings
}

 
estimate_barrier_spatial_units  <- function(sp_unit_pos) { 
  sp_unit <- grid_contxt[sp_unit_pos[1],]
  influence_area <- sf::st_buffer(sp_unit, dist = 804.672)
  roads_buffer_id <- sapply(sf::st_intersects(roads_contxt, influence_area),function(x){length(x)>0})
  roads_local <- roads_contxt[roads_buffer_id, ]
  sp_unit_buffer_id <- sapply(sf::st_intersects(grid_contxt, influence_area),function(x){length(x)>0})
  sp_unit_buffer_cents <- grid_contxt[sp_unit_buffer_id, ]
  sp_unit_buffer_cents <- sp_unit_buffer_cents[-which(sp_unit_buffer_cents$id_local == sp_unit$id_local),]
  rm(roads_buffer_id, influence_area, sp_unit_buffer_id)
  if(nrow(sp_unit_buffer_cents) > 0) {
    # find visible centroids from the sp_unit segment
    # obtain blocked centroids from sp_unit segment and their view factor
    barrier_factor <- sapply(seq_along(1:length(sp_unit_buffer_cents$id_local)), function(r) { 
      ray <- sf::st_cast(sf::st_union(sp_unit,sp_unit_buffer_cents[r,]),"LINESTRING")
      inters_loc <- lengths(sf::st_intersects(ray, roads_local, sparse = TRUE)) > 0
      if(any(inters_loc == TRUE)){
        barrier_factor <- 1
      } else {
        barrier_factor <- 0
      }
      return(barrier_factor)
    })
    severed_sp_units  <- sp_unit_buffer_cents$id_local[which(barrier_factor != 0)]
    if(length(severed_sp_units) > 0){
      n_contxt_barr_sp_units <- length(sp_unit_buffer_cents$id_local[which(barrier_factor != 0)])
      barrier_sp_units <- paste(severed_sp_units, collapse = " ")
      barrier_factor <- 100 * length(severed_sp_units) / length(sp_unit_buffer_cents$id_local)
    } else {
      n_contxt_barr_sp_units <- 0
      barrier_factor <- 0
    }
  } else {
    n_contxt_barr_sp_units <- 0
    barrier_factor <- 0
  }
  barr <- c(sp_unit_pos[2], n_contxt_barr_sp_units, barrier_factor) #barrier_sp_units,
  return(barr)
}


table_desc <- function(dta = data_uns, vars = vars, groups = groups, 
                       table_df = table_df, round = 2){
  for (group in groups){
    dt <- dta  %>%
      filter(city == group) 
      for (var in vars){
        v <- dt[[var]]
        med <- median(v, na.rm = T)
        q_25 <- quantile(v, 0.25,  na.rm = T)
        q_75 <- quantile(v, 0.75,  na.rm = T)
        table_df[which(table_df$group == group), var] <- paste0(round(med,round), "(", round(q_25,round), "-", round(q_75,round), ")")
    }
    
  }
  return(table_df)
}


subset_q1_q5 <- function(data, ice_quintile_var) {
  subset(
    data,
    data[[ice_quintile_var]] %in% c("Q1 (Most Disadvantaged)", "Q5 (Most Advantaged)")
  )
}

fit_q1_q5_models <- function(data,
                             ice_quint_var,
                             model_fun,
                             ice_cont_vars = NULL,
                             family_type = NULL) {
  
  out <- list()
  
  # --- (A) Categorical models: Q1 vs Q5 only ----------------
  dt_q1_q5 <- subset_q1_q5(data, ice_quint_var)
  
  out$cat_model <- model_fun(
    dt_q1_q5,
    by = ice_quint_var,
    include_city = TRUE,
    family_type = family_type
  )
  
  # --- (B) Continuous ICE models with tensor interaction ----
  if (!is.null(ice_cont_vars)) {
    for (ice_cont in ice_cont_vars) {
      out[[paste0("cont_model_", ice_cont)]] <- model_fun(
        dt_q1_q5,
        by = "none",
        include_city = TRUE,
        ice_cont = ice_cont,
        family_type = family_type
      )
    }
  }
  
  out
}


fit_q1_q5_models_old <- function(data,
                             ice_quint_var,
                             model_fun,
                             ice_cont_vars = NULL) {
  
  out <- list()
  
  # --- (A) Categorical models: Q1 vs Q5 only ----------------
  dt_q1_q5 <- subset_q1_q5(data, ice_quint_var)
  
  out$cat_model <- model_fun(
    dt_q1_q5,
    by = ice_quint_var,
    include_city = TRUE
  )
  
  # --- (B) Continuous ICE models with tensor interaction ----
  if (!is.null(ice_cont_vars)) {
    for (ice_cont in ice_cont_vars) {
      out[[paste0("cont_model_", ice_cont)]] <-
        model_fun(
          dt_q1_q5,
          by = "none",
          include_city = TRUE,
          ice_cont = ice_cont
        )
    }
  }
  
  out
}



model_gam_mixed_ndvi <- function(
    data,
    by = "none",
    include_city = FALSE,
    ice_cont = NULL,
    family_type = c("beta", "linear"),
    crude = FALSE
) {
  

  family_type <- match.arg(family_type)
  
  # Ensure neighborhood is a factor
  if (!is.factor(data$neighborhood)) {
    data$neighborhood <- as.factor(data$neighborhood)
  }
  
  # Ensure city is factor if included
  if (include_city && "city" %in% names(data)) {
    if (!is.factor(data$city)) {
      data$city <- as.factor(data$city)
    }
    if (length(unique(stats::na.omit(data$city))) < 2) {
      include_city <- FALSE
    }
  }
  
  # ----- Build formula -----
  if (crude) {
    base_formula <- "NDVI ~ s(community_severance_index, fx = FALSE)  + pop_dens + s(neighborhood, bs = 're')"
    if (include_city && "city" %in% names(data)) {
      base_formula <- paste(base_formula, "+ city")
    }
  } else {
    base_formula <- "NDVI ~ s(community_severance_index, fx = FALSE) + s(neighborhood, bs = 're') +
                   perc.black + perc.hisp + perc.pov + pop_dens + building_density"
    
    if (include_city && "city" %in% names(data)) {
      base_formula <- paste(base_formula, "+ city")
    }
    
    # Add ICE tensor if specified
    if (!is.null(ice_cont) && ice_cont %in% names(data)) {
      base_formula <- paste0(base_formula, " + te(community_severance_index, ", ice_cont, ")")
    }
  }
  
  formula <- as.formula(base_formula)
  
  # ----- Choose family -----
  fam <- switch(
    family_type,
    beta   = mgcv::betar(link = "logit"),
    linear = gaussian(link = "identity")
  )
  
  # ----- Fit model -----
  tryCatch(
    mgcv::gam(
      formula = formula,
      family  = fam,
      data    = data,
      method  = "REML"
    ),
    error = function(e) {
      message("NDVI model failed: ", e$message)
      NULL
    }
  )
}



# ============================================================
# --- Helper Functions ---
# ============================================================

# Fit GAMs by subgroup safely -------------------------------
fit_by_old <- function(data, by, model_fun, include_city = FALSE, ice_cont = NULL) {
  # No grouping
  if (by == "none") {
    fit <- model_fun(data, by = "none", include_city = TRUE, ice_cont = ice_cont)
    if (is.null(fit)) return(NULL)
    return(list(fit_all = fit))
  }
  
  # Check variable exists and has data
  if (!by %in% names(data) || all(is.na(data[[by]]))) {
    message("Skipping '", by, "' — variable missing or all NA.")
    return(NULL)
  }
  
  groups <- unique(na.omit(data[[by]]))
  if (length(groups) == 0) return(NULL)
  
  fits <- lapply(groups, function(g) {
    subset_data <- subset(data, data[[by]] == g)
    model_fun(subset_data, by = by, include_city = include_city, ice_cont = ice_cont)
  })
  
  valid <- !sapply(fits, is.null)
  fits <- fits[valid]
  
  if (length(fits) > 0) {
    names(fits) <- paste0("fit_", by, "_", tolower(groups[valid]))
  }
  
  fits
}

library(dlnm)
library(mgcv)
library(dplyr)
library(tibble)

# ----------------------------
# Safe crossbasis
# ----------------------------
safe_crossbasis <- function(var, lag, argvar, df_var = 3) {
  try_ns <- tryCatch({
    crossbasis(
      var,
      lag = lag,
      argvar = argvar,
      arglag = list(fun = "lin")
    )
  }, error = function(e) {
    message("Error with ns: Switching to bs due to error: ", e$message)
    crossbasis(
      var,
      lag = lag,
      argvar = list(fun = "bs", df = df_var),
      arglag = list(fun = "lin")
    )
  })
  
  return(try_ns)
}

# ----------------------------
# Main function
# ----------------------------
estimate_75_vs_median <- function(data,
                                  city_name,
                                  predictor = "community_severance_index",
                                  outcome = "NDVI",
                                  lag = 0,
                                  df_var = 3,
                                  family_type = c("gaussian", "gamma")) {
  
  family_type <- match.arg(family_type)
  
  # 1️⃣ Filter city
  dta_city <- data %>%
    dplyr::filter(city == city_name)
  
  if (nrow(dta_city) == 0) {
    message("No data for city: ", city_name)
    return(NULL)
  }
  
  # 2️⃣ Build crossbasis
  cb <- safe_crossbasis(
    var = dta_city[[predictor]],
    lag = lag,
    argvar = list(fun = "ns", df = df_var),
    df_var = df_var
  )
  
  # 3️⃣ Choose family
  fam <- switch(
    family_type,
    gaussian = gaussian(link = "identity"),
    gamma    = Gamma(link = "log")
  )
  
  # 4️⃣ Fit GAM
  formula_gam <- as.formula(
    paste0(outcome,
           " ~ cb + s(neighborhood, bs = 're') + pop_dens")
  )
  
  gam_fit <- mgcv::gam(
    formula_gam,
    data = dta_city,
    family = fam,
    method = "REML"
  )
  
  # 5️⃣ Compute percentiles
  q50 <- quantile(dta_city[[predictor]], 0.50, na.rm = TRUE)
  q75 <- quantile(dta_city[[predictor]], 0.75, na.rm = TRUE)
  
  # 6️⃣ crosspred
  quartile_pred <- crosspred(
    basis = cb,
    model = gam_fit,
    at = c(q50, q75),
    cen = q50
  )
  
  if (family_type == "gaussian") {
    
    fit_75     <- quartile_pred$matfit[2]
    ci_low_75  <- quartile_pred$matlow[2]
    ci_high_75 <- quartile_pred$mathigh[2]
    
  } else if (family_type == "gamma") {
    
    fit_75     <- quartile_pred$allRRfit[2]   # already exponentiated
    ci_low_75  <- quartile_pred$allRRlow[2]
    ci_high_75 <- quartile_pred$allRRhigh[2]
  }
  
  # 8️⃣ Transform depending on family
  if (family_type == "gaussian") {
    
    result <- tibble(
      city = city_name,
      predictor = predictor,
      family = "gaussian",
      beta_75_50 = fit_75,           # absolute difference
      ci_low = ci_low_75,
      ci_high = ci_high_75
    )
    
  } else if (family_type == "gamma") {
    
    result <- tibble(
      city = city_name,
      predictor = predictor,
      family = "gamma",
      ratio_75_50 = fit_75,
      percent_change_75_50 = (fit_75 - 1) * 100,
      ci_low_ratio = quartile_pred$allRRlow[2],
      ci_high_ratio = quartile_pred$allRRhigh[2]
    )
  }
  
  return(result)
}

# Fit GAMs by subgroup safely -------------------------------
fit_by <- function(data, by, model_fun, include_city = FALSE, ice_cont = NULL, crude = FALSE,
                   family_type = "beta") {
  
  # No grouping
  if (by == "none") {
    fit <- model_fun(
      data,
      by = "none",
      include_city = TRUE,
      ice_cont = ice_cont,
      crude = crude,
      family_type = family_type
    )
    
    if (is.null(fit)) return(NULL)
    return(list(fit_all = fit))
  }
  
  # Check variable exists and has data
  if (!by %in% names(data) || all(is.na(data[[by]]))) {
    message("Skipping '", by, "' — variable missing or all NA.")
    return(NULL)
  }
  
  groups <- unique(na.omit(data[[by]]))
  if (length(groups) == 0) return(NULL)
  
  fits <- lapply(groups, function(g) {
    subset_data <- subset(data, data[[by]] == g)
    model_fun(
      subset_data,
      by = by,
      include_city = include_city,
      ice_cont = ice_cont,
      crude = crude,
      family_type = family_type
    )
  })
  
  valid <- !sapply(fits, is.null)
  fits <- fits[valid]
  
  if (length(fits) > 0) {
    names(fits) <- paste0("fit_", by, "_", tolower(groups[valid]))
  }
  
  fits
}



# Fit GAMs by city and ICE group safely ----------------------
# Fit GAMs by city and ICE group safely ----------------------
fit_city_ice <- function(data, model_fun, city_var = "city",
                         ice_vars = NULL, ice_cont_vars = NULL,
                         family_type = NULL) {
  
  cities <- unique(na.omit(data[[city_var]]))
  out <- list()
  
  for (c in cities) {
    dt_city <- subset(data, data[[city_var]] == c)
    
    # City-level model
    out[[paste0("fit_", tolower(c), "_city")]] <- model_fun(
      dt_city, by = "city", family_type = family_type
    )
    
    # ICE-level categorical models
    if (!is.null(ice_vars)) {
      for (ice in ice_vars) {
        fits <- fit_by(
          dt_city, by = ice, model_fun = model_fun,
          include_city = TRUE, family_type = family_type
        )
        if (!is.null(fits) && length(fits) > 0) {
          names(fits) <- paste0("fit_", tolower(c), "_", names(fits))
          out <- c(out, fits)
        }
      }
    }
    
    # ICE-level continuous models with tensor interaction
    if (!is.null(ice_cont_vars)) {
      for (ice_cont in ice_cont_vars) {
        fits <- fit_by(
          dt_city, by = "none", model_fun = model_fun,
          include_city = TRUE, ice_cont = ice_cont,
          family_type = family_type
        )
        if (!is.null(fits) && length(fits) > 0) {
          names(fits) <- paste0("fit_", tolower(c), "_", ice_cont)
          out <- c(out, fits)
        }
      }
    }
  }
  
  out
}

fit_city_ice_old <- function(data, model_fun, city_var = "city", ice_vars = NULL, ice_cont_vars = NULL) {
  cities <- unique(na.omit(data[[city_var]]))
  out <- list()
  
  for (c in cities) {
    dt_city <- subset(data, data[[city_var]] == c)
    
    # City-level model
    out[[paste0("fit_", tolower(c), "_city")]] <- model_fun(dt_city, by = "city")
    
    # ICE-level categorical models
    if (!is.null(ice_vars)) {
      for (ice in ice_vars) {
        fits <- fit_by(dt_city, by = ice, model_fun = model_fun, include_city = TRUE)
        if (!is.null(fits) && length(fits) > 0) {
          names(fits) <- paste0("fit_", tolower(c), "_", names(fits))
          out <- c(out, fits)
        }
      }
    }
    
    # ICE-level continuous models with tensor interaction
    if (!is.null(ice_cont_vars)) {
      for (ice_cont in ice_cont_vars) {
        fits <- fit_by(dt_city, by = "none", model_fun = model_fun, include_city = TRUE, ice_cont = ice_cont)
        if (!is.null(fits) && length(fits) > 0) {
          names(fits) <- paste0("fit_", tolower(c), "_", ice_cont)
          out <- c(out, fits)
        }
      }
    }
  }
  
  out
}


# ================================================
# Extract Q1 vs Q5 Categorical Models (generic)
# ================================================
get_q1_q5_categorical <- function(model_list) {
  if (!"fits_q1_q5" %in% names(model_list)) {
    stop("Model list does not contain $fits_q1_q5.")
  }
  
  qmods <- model_list$fits_q1_q5
  out <- list()
  
  for (branch in names(qmods)) {
    cat_mod <- qmods[[branch]]$cat_model
    if (!is.null(cat_mod)) {
      out[[paste0(branch, "_categorical")]] <- cat_mod
    }
  }
  
  purrr::compact(out)
}

# ================================================
# Extract Q1 vs Q5 Continuous ICE Models (generic)
# ================================================
get_q1_q5_continuous <- function(model_list) {
  if (!"fits_q1_q5" %in% names(model_list)) {
    stop("Model list does not contain $fits_q1_q5.")
  }
  
  qmods <- model_list$fits_q1_q5
  out <- list()
  
  for (branch in names(qmods)) {
    m_inc  <- qmods[[branch]]$cont_model_ICE_inc
    m_rewb <- qmods[[branch]]$cont_model_ICE_rewb
    
    if (!is.null(m_inc))
      out[[paste0(branch, "_cont_ICE_inc")]] <- m_inc
    
    if (!is.null(m_rewb))
      out[[paste0(branch, "_cont_ICE_rewb")]] <- m_rewb
  }
  
  purrr::compact(out)
}

plot_q1_q5_categorical <- function(model_list, group = "all",
                                   ice_var = "ICE_inc_quintile",
                                   smooth_term = "s(community_severance_index)",
                                   rug = TRUE) {
  
  # --- locate Q1 and Q5 models --- #
  if(group == "all"){
  quint_models <- model_list$fits_ice_quint[[ice_var]]
  } else if (group == "nyc"){
    quint_models <- model_list$fits_ice_quint_nyc[[ice_var]]  
  } else if (group == "la"){
    quint_models <- model_list$fits_ice_quint_la[[ice_var]]  
  }
  if (is.null(quint_models)) stop("No ICE quintile models found in model_list.")
  
  mod_q1 <- quint_models[[grep("q1", names(quint_models), ignore.case = TRUE)]]
  mod_q5 <- quint_models[[grep("q5", names(quint_models), ignore.case = TRUE)]]
  
  if (is.null(mod_q1) | is.null(mod_q5)) stop("Q1 or Q5 model not found.")
  
  # --- extract smooths --- #
  sm_q1 <- gratia::smooth_estimates(mod_q1, smooth = smooth_term) |> gratia::add_confint()
  sm_q5 <- gratia::smooth_estimates(mod_q5, smooth = smooth_term) |> gratia::add_confint()
  
  # --- detect family --- #
  fam <- mod_q1$family$family
  linkinv <- mod_q1$family$linkinv
  
  intercept_q1 <- coef(mod_q1)[1]
  intercept_q5 <- coef(mod_q5)[1]
  
  # beta: NDVI → clipped 0–1
  if (grepl("Beta", fam, ignore.case = TRUE)) {
    transform_fun <- function(x) pmin(pmax(linkinv(x), 0), 1)
    y_lab <- "Predicted NDVI (0–1)"
    title_lab <- "NDVI vs Community Severance"
  }
  # gamma: greenspace distance → no clipping
  else if (grepl("Gamma", fam, ignore.case = TRUE)) {
    transform_fun <- function(x) linkinv(x)
    y_lab <- "Predicted Distance to Closest Greenspace (m)"
    title_lab <- "Distance to Greenspace vs Community Severance"
  }
  # fallback
  else {
    transform_fun <- function(x) linkinv(x)
    y_lab <- "Predicted Response"
    title_lab <- "Response vs Community Severance"
  }
  
  # --- transform estimates --- #
  sm_q1 <- sm_q1 |> dplyr::mutate(
    est   = transform_fun(intercept_q1 + .estimate),
    lower = transform_fun(intercept_q1 + .lower_ci),
    upper = transform_fun(intercept_q1 + .upper_ci),
    group = "Q1 (Most Disadvantaged)"
  )
  
  sm_q5 <- sm_q5 |> dplyr::mutate(
    est   = transform_fun(intercept_q5 + .estimate),
    lower = transform_fun(intercept_q5 + .lower_ci),
    upper = transform_fun(intercept_q5 + .upper_ci),
    group = "Q5 (Most Advantaged)"
  )
  
  sm <- rbind(sm_q1, sm_q5)
  
  # ---- compute mean predicted value per quartile ----
  mean_q1 <- mean(sm_q1$est, na.rm = TRUE)
  mean_q5 <- mean(sm_q5$est, na.rm = TRUE)
  
  # ---- plot ----
  p <- ggplot(sm, aes(x = community_severance_index, y = est,
                      color = group, fill = group)) +
    geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.15, color = NA) +
    geom_line(size = 1.2) +
    
    # 🟢 NEW: dashed mean-lines using each group's color
    geom_hline(aes(yintercept = mean_q1, color = "Q1 (Most Disadvantaged)"),
               linetype = "dashed", linewidth = 1) +
    geom_hline(aes(yintercept = mean_q5, color = "Q5 (Most Advantaged)"),
               linetype = "dashed", linewidth = 1) +
    
    labs(
      title = paste(title_lab, "–", ice_var),
      x = "Community Severance Index",
      y = y_lab,
      color = "Group",
      fill = "Group"
    ) +
    theme_bw(base_size = 14) +
    theme(
      legend.position = "top",
      plot.title = element_text(face = "bold")
    )
  
  # --- rug for Q1 --- #
  if (rug) {
    p <- p + geom_rug(
      data = mod_q1$model,
      aes(x = community_severance_index),
      inherit.aes = FALSE,
      sides = "b",
      alpha = 0.3
    )
  }
  
  p
}

res_gen <- function(dt_res = dt_res, mdl = mdl){
  residuals_df <- data.frame(
    orig_row_id = as.numeric(rownames(mdl$model)),
    fitted = fitted(mdl),
    residual = residuals(mdl, type = "response")
  )
  residuals_df
}

plot_residual_diagnostics <- function(dt_sf,
                                      resid_var = "residual",
                                      fitted_var = "fitted",
                                      k_neighbors = 5,
                                      title = "Residual Diagnostics") {
  suppressPackageStartupMessages({
    library(ggplot2)
    library(sf)
    library(spdep)
    library(dplyr)
    library(patchwork)
  })
  
  # ---------------------------
  # 1. Extract residuals + fitted
  # ---------------------------
  dt <- dt_sf |> st_drop_geometry()
  
  if (!(resid_var %in% names(dt_sf))) stop("Residual variable not found.")
  if (!(fitted_var %in% names(dt_sf))) stop("Fitted variable not found.")
  
  # ---------------------------
  # 2. Moran's I (polygon safe: uses centroids)
  # ---------------------------
  message("Computing spatial weights and Moran's I...")
  
  coords <- sf::st_coordinates(sf::st_centroid(dt_sf))
  
  nb <- spdep::knn2nb(spdep::knearneigh(coords, k = k_neighbors))
  lw <- spdep::nb2listw(nb, style = "W")
  
  moran_res <- spdep::moran.test(dt_sf[[resid_var]], lw, na.action = na.omit)
  
  print(moran_res)
  
  # ---------------------------
  # 3. Plots
  # ---------------------------
  
  # Histogram
  p1 <- ggplot(dt, aes(x = .data[[resid_var]])) +
    geom_histogram(bins = 30, fill = "skyblue", color = "black") +
    labs(title = "Residual Distribution", x = "Residuals", y = "Count") +
    theme_bw()
  
  # Q-Q plot
  p2 <- ggplot(dt, aes(sample = .data[[resid_var]])) +
    stat_qq() + stat_qq_line() +
    labs(title = "Q-Q Plot of Residuals") +
    theme_bw()
  
  # Residuals vs Fitted
  p3 <- ggplot(dt, aes(x = .data[[fitted_var]], y = .data[[resid_var]])) +
    geom_point(alpha = 0.5) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
    labs(title = "Residuals vs Fitted",
         x = "Fitted Values", y = "Residuals") +
    theme_bw()
  
  # Spatial plot — larger, without grid or lat/lon
  p4 <- ggplot(dt_sf) +
    geom_sf(aes(fill = .data[[resid_var]]), color = NA) +
    scale_fill_gradient2(
      low = "blue", mid = "white", high = "red",
      midpoint = 0, name = "Residual"
    ) +
    labs(
      title = "Spatial Distribution of Residuals",
      subtitle = paste0("Moran's I = ",
                        round(moran_res$estimate[1], 3),
                        " (p < ", signif(moran_res$p.value, 3), ")")
    ) +
    theme_void() +                      # removes axes + grid
    theme(
      legend.position = "right",
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 11)
    )
  
  # ---------------------------
  # 4. Combine with patchwork
  # ---------------------------
combined_plot <-
    (p1 | p2) /
    (p3 | p4) +
    plot_layout(heights = c(1, 2)) +   # << BIGGER MAP
    plot_annotation(
      title = title,
      theme = theme(plot.title = element_text(size = 18, face = "bold"))
    )
  
  combined_plot
}

# Greenspace Model -------------------------------------------
model_gam_mixed_greenspace <- function(
    data, 
    by = "none", 
    include_city = FALSE, 
    ice_cont = NULL,
    family_type = c("gamma", "linear"),
    crude = FALSE   # <-- NEW
) {
  
  family_type <- match.arg(family_type)
  
  # Ensure neighborhood is a factor
  if (!is.factor(data$neighborhood)) {
    data$neighborhood <- as.factor(data$neighborhood)
  }
  
  # Ensure city is factor if included
  if (include_city && "city" %in% names(data) && !is.factor(data$city)) {
    data$city <- as.factor(data$city)
  }
  
  # ----- Build formula -----
  if (crude) {
    base_formula <- "closest_greenspace ~ s(community_severance_index, fx = FALSE) + pop_dens + s(neighborhood, bs = 're')"
    if (include_city && "city" %in% names(data)) {
      base_formula <- paste(base_formula, "+ city")
    }
  } else {
    base_formula <- "closest_greenspace ~ s(community_severance_index, fx = FALSE) + 
                     s(neighborhood, bs = 're') + perc.black + perc.hisp + perc.pov + 
                     pop_dens + building_density"
    
    if (include_city && "city" %in% names(data)) {
      base_formula <- paste(base_formula, "+ city")
    }
    
    if (!is.null(ice_cont) && ice_cont %in% names(data)) {
      base_formula <- paste0(base_formula, " + te(community_severance_index, ", ice_cont, ")")
    }
  }
  
  formula <- as.formula(base_formula)
  
  # ----- Choose family -----
  fam <- switch(
    family_type,
    gamma  = Gamma(link = "log"),
    linear = gaussian(link = "identity")
  )
  
  # ----- Fit model safely -----
  tryCatch(
    mgcv::gam(
      formula = formula,
      family  = fam,  
      data    = data,
      method  = "REML"
    ),
    error = function(e) {
      message("Greenspace model failed: ", e$message)
      NULL
    }
  )
}


# Neighbor-visit count model --------------------------------
model_gam_mixed_neighbor_visits <- function(
    data,
    outcome_var = "neighbor_visit_count",
    by = "none",
    include_city = FALSE,
    ice_cont = NULL,
    family_type = c("nb", "poisson"),
    crude = FALSE,
    offset_var = NULL
) {
  
  family_type <- match.arg(family_type)
  
  if (!outcome_var %in% names(data)) {
    stop("Outcome variable not found in data: ", outcome_var)
  }
  
  # Keep rows with observed non-negative counts.
  data <- data[!is.na(data[[outcome_var]]) & data[[outcome_var]] >= 0, , drop = FALSE]
  if (nrow(data) == 0) {
    stop("No non-missing non-negative rows available for ", outcome_var)
  }
  
  if (!is.factor(data$neighborhood)) {
    data$neighborhood <- as.factor(data$neighborhood)
  }
  
  if (include_city && "city" %in% names(data) && !is.factor(data$city)) {
    data$city <- as.factor(data$city)
  }
  
  offset_term <- NULL
  if (!is.null(offset_var) && offset_var %in% names(data)) {
    valid_offset <- !is.na(data[[offset_var]]) & data[[offset_var]] > 0
    data <- data[valid_offset, , drop = FALSE]
    if (nrow(data) == 0) {
      stop("No rows with positive non-missing offset available for ", offset_var)
    }
    offset_term <- paste0("offset(log(", offset_var, "))")
  }
  
  if (crude) {
    rhs_terms <- c(
      "s(community_severance_index, fx = FALSE)",
      "pop_dens",
      "s(neighborhood, bs = 're')"
    )
  } else {
    rhs_terms <- c(
      "s(community_severance_index, fx = FALSE)",
      "s(neighborhood, bs = 're')",
      "perc.black",
      "perc.hisp",
      "perc.pov",
      "pop_dens",
      "building_density"
    )
  }
  
  if (include_city && "city" %in% names(data)) {
    rhs_terms <- c(rhs_terms, "city")
  }
  
  if (!is.null(ice_cont) && ice_cont %in% names(data)) {
    rhs_terms <- c(rhs_terms, paste0("te(community_severance_index, ", ice_cont, ")"))
  }
  
  if (!is.null(offset_term)) {
    rhs_terms <- c(rhs_terms, offset_term)
  }
  
  formula <- as.formula(
    paste(outcome_var, "~", paste(rhs_terms, collapse = " + "))
  )
  
  fam <- switch(
    family_type,
    nb = mgcv::nb(link = "log"),
    poisson = poisson(link = "log")
  )
  
  tryCatch(
    mgcv::gam(
      formula = formula,
      family = fam,
      data = data,
      method = "REML"
    ),
    error = function(e) {
      message("Neighbor-visit model failed: ", e$message)
      NULL
    }
  )
}


# Neighbor-visit share model --------------------------------
model_gam_mixed_neighbor_share <- function(
    data,
    outcome_var = "neighbor_visit_share",
    by = "none",
    include_city = FALSE,
    ice_cont = NULL,
    crude = FALSE
) {
  
  if (!outcome_var %in% names(data)) {
    stop("Outcome variable not found in data: ", outcome_var)
  }
  
  data <- data[!is.na(data[[outcome_var]]), , drop = FALSE]
  if (nrow(data) == 0) {
    stop("No non-missing rows available for ", outcome_var)
  }
  
  # Beta regression requires values in (0, 1), so shrink boundary values
  # slightly toward the interior using the observed sample size.
  y <- data[[outcome_var]]
  n_obs <- length(y)
  y <- pmin(pmax(y, 0), 1)
  y_adj <- (y * (n_obs - 1) + 0.5) / n_obs
  data[[outcome_var]] <- y_adj
  
  if (!is.factor(data$neighborhood)) {
    data$neighborhood <- as.factor(data$neighborhood)
  }
  
  if (include_city && "city" %in% names(data)) {
    if (!is.factor(data$city)) {
      data$city <- as.factor(data$city)
    }
    if (length(unique(stats::na.omit(data$city))) < 2) {
      include_city <- FALSE
    }
  }
  
  if (crude) {
    rhs_terms <- c(
      "s(community_severance_index, fx = FALSE)",
      "pop_dens",
      "s(neighborhood, bs = 're')"
    )
  } else {
    rhs_terms <- c(
      "s(community_severance_index, fx = FALSE)",
      "s(neighborhood, bs = 're')",
      "perc.black",
      "perc.hisp",
      "perc.pov",
      "pop_dens",
      "building_density"
    )
  }
  
  if (include_city && "city" %in% names(data)) {
    rhs_terms <- c(rhs_terms, "city")
  }
  
  if (!is.null(ice_cont) && ice_cont %in% names(data)) {
    rhs_terms <- c(rhs_terms, paste0("te(community_severance_index, ", ice_cont, ")"))
  }
  
  formula <- as.formula(
    paste(outcome_var, "~", paste(rhs_terms, collapse = " + "))
  )
  
  tryCatch(
    mgcv::gam(
      formula = formula,
      family = mgcv::betar(link = "logit"),
      data = data,
      method = "REML"
    ),
    error = function(e) {
      message("Neighbor-share model failed: ", e$message)
      NULL
    }
  )
}



model_gam_mixed_greenspace_old <- function(data, by = "none", include_city = FALSE, ice_cont = NULL) {
  # Base formula
  base_formula <- "closest_greenspace ~ s(community_severance_index, fx = FALSE) + 
                   s(neighborhood, bs = 're') + perc.black + perc.hisp + perc.pov + 
                   pop_dens + building_density"
  
  # Add city if requested or if by == "none"
  if (include_city || by == "none") {
    base_formula <- paste(base_formula, "+ city")
  }
  
  # Add tensor product interaction if continuous ICE variable is specified
  if (!is.null(ice_cont) && ice_cont %in% names(data)) {
    base_formula <- paste0(base_formula, " + te(community_severance_index, ", ice_cont, ")")
  }
  
  formula <- as.formula(base_formula)
  
  # Fit GAM safely
  tryCatch(
    mgcv::gam(
      formula = formula,
      family  = Gamma(link = "log"),  
      data    = data,
      method  = "REML"
    ),
    error = function(e) {
      message("Greenspace model failed: ", e$message)
      NULL
    }
  )
}


coeffs_lme_iqr_exp <- function(mod_name =NULL, mod = mod, dta = dta, var = "community_severance_index"){  
  q25 <- quantile(dta[,var], na.rm = T, probs = 0.25)
  q75 <- quantile(dta[,var], na.rm = T, probs = 0.75)
  iqr <- q75 - q25
  fixed_effects <- as.data.frame(mixedup::extract_fixed_effects(mod))
  #intercept <- fixed_effects[which(fixed_effects$term == "XIntercept"),"value"]
  Beta.fit <- fixed_effects[which(fixed_effects$term == paste0("X",var)),"value"]
  Beta.se <- fixed_effects[which(fixed_effects$term == paste0("X",var)),"se"]
  p_value <- fixed_effects[which(fixed_effects$term == paste0("X",var)),"p_value"]
  Beta.lci <- Beta.fit - 1.96 * Beta.se
  Beta.uci <- Beta.fit + 1.96 * Beta.se
  beta <- as.numeric(exp(iqr * Beta.fit))
  # It means that for each 1 IQR increase in CSI, the average mental health hospitalization increases by 1.32 hospitalizations. 
  lci <- as.numeric(exp(iqr * Beta.lci))
  uci <- as.numeric(exp(iqr * Beta.uci))
  df <- data.frame(mod_name = mod_name, beta = beta, lci = lci, uci = uci, p_value = p_value)
  return(df)
}

plot_linear_models <- function(res = res){
  res %>%
    dplyr::mutate(model_name = fct_relevel(mh_disorder_nm, 
                                           rev(c("Adjustment", "Anxiety", "Mood",
                                                 "Schizophrenia")))) %>%
    ggplot(aes(x = model_name, y = beta, #color = mh_disorder_nm, shape=mh_disorder_nm,
               ymin = lci,
               ymax = uci)) +
    geom_pointrange(size = 1.25) + theme_bw() +
    geom_linerange(size = 1.25) + 
    scale_shape_manual(values=c(1))+
    scale_color_manual(values=c('#3b7036'))+
    scale_y_log10(
      breaks = c(0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5),
      labels = scales::number_format(accuracy = 0.1)
    ) +
    coord_cartesian(ylim = c(0.8, 1.5)) +   # zooms without dropping data
    geom_hline(yintercept = 1, color = "black", linetype = "dashed") +
    theme(legend.text = element_text(size=12), legend.title = element_text(size=14),
          axis.text.y = element_text(hjust = 1, size = 17),
          axis.text.x = element_text(size = 17), strip.background = element_rect(fill = "white"), 
          axis.title.x = element_blank(), axis.title.y = element_blank()) + coord_flip() +
    labs(y = "Estimate", x = "---Mental Health Disorder")
}

# functions to plot non linear results
format_pred_mod <- function(pred.csi) {
  fit.table.csi <- as.data.frame(pred.csi$matRRfit)
  colnames(fit.table.csi) <- paste0("rr_", colnames(fit.table.csi))
  fit.table.csi <-fit.table.csi %>% mutate(csi = as.numeric(row.names(fit.table.csi)))
  # 3d.ii Extract 95% CI
  lci.table.csi <- as.data.frame(pred.csi$matRRlow)
  colnames(lci.table.csi) <- paste0("lci_", colnames(lci.table.csi))
  uci.table.csi <- as.data.frame(pred.csi$matRRhigh)
  colnames(uci.table.csi) <- paste0("uci_", colnames(uci.table.csi))
  ## plot
  plot.csi_mod <- data.frame(fit.table.csi, lci.table.csi, uci.table.csi)
  names(plot.csi_mod) <- c("pe", "csi", "lci", "uci")
  return(plot.csi_mod)
}

# --- Function: plot tensor product smooth in 3D for any GAM ---
plot_tensor3D_gam <- function(gam_model, smooth_name = NULL, n = 50,
                              xlab = NULL, ylab = NULL, zlab = "Estimated response",
                              title = NULL, color_palette = "Viridis") {
  
  # --- Step 1: Identify tensor product smooth ---
  if (is.null(smooth_name)) {
    t_smooths <- gam_model$smooth %>% purrr::keep(~ inherits(.x, "tensor.smooth"))
    if (length(t_smooths) == 0) stop("No tensor product smooths found in the model.")
    smooth_name <- t_smooths[[1]]$label
  }
  
  # --- Step 2: Get smooth estimates ---
  sm <- smooth_estimates(
    gam_model,
    smooth = smooth_name,
    n = n,
    partial_match = TRUE
  )
  
  # --- Step 3: Identify the two variables in the tensor ---
  vars <- names(sm)[!grepl("^\\.", names(sm))]
  if (length(vars) != 2) stop("Tensor product smooth must have exactly 2 variables.")
  
  x_var <- vars[1]
  y_var <- vars[2]
  
  # Ensure variables are numeric
  sm[[x_var]] <- as.numeric(sm[[x_var]])
  sm[[y_var]] <- as.numeric(sm[[y_var]])
  
  # Pivot to matrix
  sm_mat <- sm %>%
    select(all_of(c(x_var, y_var, ".estimate"))) %>%
    pivot_wider(names_from = all_of(y_var), values_from = ".estimate") %>%
    arrange(!!sym(x_var))
  
  x_vals <- sm_mat[[x_var]]
  y_vals <- as.numeric(colnames(sm_mat)[-1])
  z_mat <- as.matrix(sm_mat[,-1])
  storage.mode(z_mat) <- "double"
  
  # --- Step 4: Interactive 3D plot ---
  plot_ly(x = ~x_vals, y = ~y_vals, z = ~z_mat) %>%
    add_surface(colorscale = color_palette) %>%
    layout(
      scene = list(
        xaxis = list(title = ifelse(is.null(xlab), x_var, xlab)),
        yaxis = list(title = ifelse(is.null(ylab), y_var, ylab)),
        zaxis = list(title = zlab)
      ),
      title = ifelse(is.null(title), paste("Tensor product smooth:", smooth_name), title)
    )
}

plot_smooth_gam <- function(model_list,
                            smooth_term = "s(community_severance_index)",
                            line_color = "#3b7036",
                            ci_alpha = 0.2,
                            fill_color = "forestgreen",
                            rug = TRUE,
                            y_limits = NULL) {

  # --- City name lookup (from model list name → display label) ---
  city_label_map <- c(
    nyc = "New York City",
    la  = "Los Angeles"
  )

  # --- Response variable → y-axis label ---
  response_label_map <- c(
    neighbor_visit_count_annual_avg = "Neighboring-home visit rate (annual average)",
    neighbor_visit_share_annual_avg = "Neighboring-home visit share (annual average)",
    NDVI                            = "NDVI",
    closest_greenspace              = "Distance to nearest green space (m)"
  )

  # --- Helper: flatten nested lists of GAMs ---
  flatten_gams <- function(x, parent_name = NULL) {
    if (inherits(x, "gam")) {
      nm <- if (is.null(parent_name)) deparse(substitute(x)) else parent_name
      return(setNames(list(x), nm))
    } else if (is.list(x)) {
      out <- purrr::map2(x, names(x),
                         ~ flatten_gams(.x, if (is.null(.y)) parent_name else .y))
      return(purrr::flatten(out))
    } else list()
  }

  flat_models <- flatten_gams(model_list)
  if (length(flat_models) == 0) {
    warning("No valid GAMs found.")
    return(list())
  }

  # --- Function to plot one model’s smooth ---
  plot_one <- function(m, name) {
    tryCatch({

      # City title: detect nyc/la in model name
      name_lower <- tolower(name)
      if (grepl("nyc", name_lower)) {
        city_title <- "New York City"
      } else if (grepl("\\bla\\b|_la$|_la_", name_lower)) {
        city_title <- "Los Angeles"
      } else {
        city_title <- stringr::str_remove_all(name, "^fit_(city_)?")
      }

      # Extract smooth estimates
      sm <- gratia::smooth_estimates(m, smooth = smooth_term) |>
        gratia::add_confint()

      # Identify family and link
      fam_name <- m$family$family
      linkfun  <- m$family$linkinv
      response_var <- as.character(formula(m))[2]

      # Transform to response scale
      if (grepl("Beta|Gamma|gaussian|Negative Binomial|poisson", fam_name,
                ignore.case = TRUE)) {
        sm <- sm |>
          dplyr::mutate(
            est   = linkfun(.estimate),
            lower = linkfun(.lower_ci),
            upper = linkfun(.upper_ci)
          )
      }

      # Y-axis label: clean name or mapped label
      y_label <- if (response_var %in% names(response_label_map)) {
        response_label_map[[response_var]]
      } else {
        response_var
      }

      # Null/baseline line
      baseline <- if (grepl("Gamma|Negative Binomial|poisson", fam_name,
                            ignore.case = TRUE)) 1 else 0

      # Build plot
      p <- ggplot(sm, aes(x = community_severance_index, y = est)) +
        geom_ribbon(aes(ymin = lower, ymax = upper),
                    alpha = ci_alpha, fill = fill_color) +
        geom_line(color = line_color, linewidth = 1.5) +
        geom_hline(yintercept = baseline,
                   linetype = "dashed", color = "grey40", linewidth = 0.9) +
        labs(
          y     = y_label,
          x     = "Community Severance Index",
          title = city_title
        ) +
        theme_bw(base_size = 20) +
        theme(
          plot.title   = element_text(size = 24, face = "bold", hjust = 0.5),
          axis.title   = element_text(size = 20),
          axis.text    = element_text(size = 18),
          plot.margin  = margin(8, 12, 8, 8)
        )

      if (!is.null(y_limits)) p <- p + coord_cartesian(ylim = y_limits)

      if (rug && !is.null(m$model$community_severance_index)) {
        p <- p +
          geom_rug(
            data = m$model,
            aes(x = community_severance_index),
            sides = "b",
            alpha = 0.35,
            length = grid::unit(0.04, "npc"),
            inherit.aes = FALSE
          )
      }

      return(p)
    },
    error = function(e) {
      message("Could not plot model ‘", name, "’: ", e$message)
      NULL
    })
  }

  purrr::compact(purrr::imap(flat_models, plot_one))
}

# Plot Q1 vs Q5 ICE overlay: one panel per city, Q1=red, Q5=blue
# fits_q1, fits_q5: named lists keyed by "fit_city_nyc" / "fit_city_la"
plot_ice_overlay <- function(fits_q1, fits_q5,
                             smooth_term = "s(community_severance_index)",
                             rug = TRUE) {

  city_label_map <- c(nyc = "New York City", la = "Los Angeles")
  response_label_map <- c(
    neighbor_visit_count_annual_avg = "Neighboring-home visit rate (annual average)",
    neighbor_visit_share_annual_avg = "Neighboring-home visit share (annual average)",
    NDVI                            = "NDVI",
    closest_greenspace              = "Distance to nearest green space (m)"
  )

  cities <- intersect(names(fits_q1), names(fits_q5))

  plots <- lapply(cities, function(city_key) {
    mod_q1 <- fits_q1[[city_key]]
    mod_q5 <- fits_q5[[city_key]]

    tryCatch({
      sm_q1 <- gratia::smooth_estimates(mod_q1, smooth = smooth_term) |>
        gratia::add_confint()
      sm_q5 <- gratia::smooth_estimates(mod_q5, smooth = smooth_term) |>
        gratia::add_confint()

      fam_name <- mod_q1$family$family
      linkinv  <- mod_q1$family$linkinv
      response_var <- as.character(formula(mod_q1))[2]

      intercept_q1 <- coef(mod_q1)[1]
      intercept_q5 <- coef(mod_q5)[1]

      transform <- function(x, intercept) {
        if (grepl("gaussian", fam_name, ignore.case = TRUE)) {
          x + intercept
        } else {
          linkinv(x + intercept)
        }
      }

      sm_q1 <- sm_q1 |> dplyr::mutate(
        est   = transform(.estimate, intercept_q1),
        lower = transform(.lower_ci, intercept_q1),
        upper = transform(.upper_ci, intercept_q1),
        group = "Q1 (Most Disadvantaged)"
      )
      sm_q5 <- sm_q5 |> dplyr::mutate(
        est   = transform(.estimate, intercept_q5),
        lower = transform(.lower_ci, intercept_q5),
        upper = transform(.upper_ci, intercept_q5),
        group = "Q5 (Most Advantaged)"
      )
      sm <- dplyr::bind_rows(sm_q1, sm_q5)

      city_short <- sub("fit_city_", "", city_key)
      city_title <- if (city_short %in% names(city_label_map)) {
        city_label_map[[city_short]]
      } else city_short

      y_label <- if (response_var %in% names(response_label_map)) {
        response_label_map[[response_var]]
      } else response_var

      palette <- c("Q1 (Most Disadvantaged)" = "#c0392b",
                   "Q5 (Most Advantaged)"    = "#2980b9")

      p <- ggplot(sm, aes(x = community_severance_index, y = est,
                          color = group, fill = group)) +
        geom_ribbon(aes(ymin = lower, ymax = upper),
                    alpha = 0.15, color = NA) +
        geom_line(linewidth = 1.5) +
        scale_color_manual(values = palette, name = NULL) +
        scale_fill_manual(values  = palette, name = NULL) +
        labs(
          x     = "Community Severance Index",
          y     = y_label,
          title = city_title
        ) +
        theme_bw(base_size = 20) +
        theme(
          plot.title    = element_text(size = 24, face = "bold", hjust = 0.5),
          axis.title    = element_text(size = 20),
          axis.text     = element_text(size = 18),
          legend.position = "top",
          legend.text   = element_text(size = 16),
          plot.margin   = margin(8, 12, 8, 8)
        )

      if (rug) {
        rug_data <- dplyr::bind_rows(
          dplyr::mutate(mod_q1$model, group = "Q1 (Most Disadvantaged)"),
          dplyr::mutate(mod_q5$model, group = "Q5 (Most Advantaged)")
        )
        p <- p + geom_rug(
          data = rug_data,
          aes(x = community_severance_index, color = group),
          sides = "b", alpha = 0.3,
          length = grid::unit(0.04, "npc"),
          inherit.aes = FALSE
        )
      }
      p
    }, error = function(e) {
      message("Could not plot city '", city_key, "': ", e$message)
      NULL
    })
  })

  names(plots) <- cities
  purrr::compact(plots)
}




plot_pred_mod <- function(mod_dta, ylim_low = 0, ylim_high = 3) {
  mynamestheme <- theme(
    plot.title = element_text(family = "Helvetica", hjust = 0.5, size = (18)),
    axis.title = element_text(family = "Helvetica", size = (22)),
    axis.text = element_text(family = "Helvetica", size = (18))
  )
  
  p <- ggplot() +
    geom_rug(aes(x = csi),
             data = mod_dta,
             sides = "b", length = grid::unit(0.02, "npc")) +
    geom_ribbon(aes(ymin = lci, ymax = uci, x = csi), fill = "blue",
                alpha = 0.2, data = mod_dta) +
    geom_line(aes(x = csi, y = pe), lwd = 1, data = mod_dta) +
    geom_hline(yintercept=1, linetype="dashed", color = "grey", size = 1.5) +
    labs(y = "Schizophrenia Hospitalization RR", x = "Community severance index") +
    theme_bw() +
    ylim(ylim_low, ylim_high) +
    mynamestheme
  return(p)
}

get_df <- function(model = NULL){
  model_gamm <- model[["gam"]]
  gamm_summary <- summary(model_gamm)
  s_table <- gamm_summary[["s.table"]]
  s_table <- as.data.frame(s_table)
  edf <- s_table$edf[1] 
  return(edf)
}

euclidean_to_edge <- function(areal_units = census_tracts,
                                  address_location,
                                  greenspace,
                                  buffer_distance,
                                  projected_crs = NULL,
                                  minimum_greenspace_size = 0) {
  
  # 1. Transform CRS if needed
  if (!is.null(projected_crs)) {
    areal_units      <- sf::st_transform(areal_units, projected_crs)
    address_location <- sf::st_transform(address_location, projected_crs)
    greenspace       <- sf::st_transform(greenspace, projected_crs)
  }
  
  # 2. Ensure address locations are points
  if (!"POINT" %in% sf::st_geometry_type(address_location)) {
    stop("address_location must be POINT geometries")
  }
  
  # 3. Assign each address point to an areal unit → attach GEOID
  address_location <- sf::st_join(address_location[,"POPULATION"], 
                                  areal_units["GEOID"], 
                                  left = TRUE)
  
  address_location <- address_location[!is.na(address_location$GEOID), ]
  address_location$centroid_flag <- "population_weighted"
  
  # 3b. Add geometric centroids if any GEOIDs are missing
  missing_geoids <- setdiff(areal_units$GEOID, address_location$GEOID)
  
  if (length(missing_geoids) > 0) {
    centroids <- areal_units[areal_units$GEOID %in% missing_geoids, ]
    centroids <- sf::st_centroid(centroids)
    centroids$POPULATION <- NA
    centroids$centroid_flag <- "geometric"
    centroids <- centroids[, c("POPULATION","GEOID","centroid_flag","geometry")]
    
    address_location <- rbind(address_location, centroids)
  }
  
  # 4. Filter greenspace polygons by minimum area
  if (minimum_greenspace_size > 0) {
    threshold_units <- set_units(minimum_greenspace_size, "m^2")
    greenspace <- greenspace[sf::st_area(greenspace) > threshold_units, ]
  }
  
  # 5. Convert greenspace polygons to boundary lines
  greenspace_edges <- sf::st_cast(greenspace, "MULTILINESTRING") 
  # 6. Distance matrix point → greenspace edge
  dist_matrix <- sf::st_distance(address_location, greenspace_edges)
  closest_greenspace <- apply(dist_matrix, 1, min)
  
  # -------------------------------------------------------------------
  # ⭐ NEW STEP YOU REQUESTED  
  # If any address point falls inside ANY greenspace → force distance = 0
  # -------------------------------------------------------------------
  inside <- sf::st_intersects(address_location, greenspace, sparse = TRUE)
  inside_flag <- lengths(inside) > 0
  closest_greenspace[inside_flag] <- 0
  # -------------------------------------------------------------------
  
  # 7. Determine if within buffer
  greenspace_in_buffer <- closest_greenspace < buffer_distance
  
  # Create point-level results
  address_results <- data.frame(
    GEOID = address_location$GEOID,
    closest_greenspace = as.numeric(closest_greenspace),
    greenspace_in_buffer = greenspace_in_buffer,
    centroid_flag = address_location$centroid_flag
  )
  
  # 8. Aggregate to areal-unit level
  aggregated <- address_results |>
    dplyr::group_by(GEOID) |>
    dplyr::summarise(
      closest_greenspace = mean(closest_greenspace, na.rm = TRUE),
      greenspace_in_buffer = any(greenspace_in_buffer),
      n_points = n(),
      centroid_type = ifelse(any(centroid_flag == "geometric"),
                             "geometric",
                             "population_weighted"),
      .groups = "drop"
    )
  
  # 9. Ensure all GEOIDs exist
  full_output <- areal_units |>
    dplyr::select(GEOID) |>
    dplyr::left_join(aggregated, by = "GEOID") |>
    sf::st_drop_geometry()
  
  return(full_output)
}
