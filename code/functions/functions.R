 
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

plot_smooth_gam <- function(model_list,
                            smooth_term = "s(community_severance_index)",
                            line_color = "#3b7036",
                            ci_alpha = 0.2,
                            fill_color = "forestgreen",
                            rug = TRUE,
                            y_limits = NULL,
                            show_title = TRUE,
                            log_y = FALSE) {

  # --- City name lookup (from model list name → display label) ---
  city_label_map <- c(
    nyc = "New York City",
    la  = "Los Angeles"
  )

  # --- Response variable → y-axis label ---
  response_label_map <- c(
    neighbor_visit_count_annual_avg = "Neighboring-home visit rate ratio (RR)",
    neighbor_visit_share_annual_avg = "Neighboring-home visit share (annual average)",
    NDVI                            = "NDVI",
    closest_greenspace              = "Distance to nearest green space (ratio of predicted mean distance)"
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
          title = if (show_title) city_title else NULL
        ) +
        theme_bw(base_size = 20) +
        theme(
          plot.title   = element_text(size = 24, face = "bold", hjust = 0.5),
          axis.title   = element_text(size = 20),
          axis.text    = element_text(size = 18),
          plot.margin  = margin(8, 12, 8, 8)
        )

      if (log_y) p <- p + scale_y_log10()
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

# Compute shared y-limits across all models in a list (response scale)
compute_shared_ylim <- function(model_list,
                                 smooth_term = "s(community_severance_index)",
                                 padding = 0.05) {
  flatten_local <- function(x, nm = NULL) {
    if (inherits(x, "gam")) return(setNames(list(x), if (is.null(nm)) "m" else nm))
    if (is.list(x)) return(purrr::flatten(purrr::imap(x, ~ flatten_local(.x, .y))))
    list()
  }
  flat <- flatten_local(model_list)
  vals <- unlist(lapply(flat, function(m) {
    sm <- tryCatch(
      gratia::smooth_estimates(m, smooth = smooth_term) |> gratia::add_confint(),
      error = function(e) NULL
    )
    if (is.null(sm)) return(NULL)
    inv <- m$family$linkinv
    c(inv(sm$.lower_ci), inv(sm$.upper_ci))
  }))
  if (length(vals) == 0) return(NULL)
  rng <- diff(range(vals, na.rm = TRUE))
  c(min(vals, na.rm = TRUE) - padding * rng,
    max(vals, na.rm = TRUE) + padding * rng)
}

# Assemble a two-city comparison figure: shared y-axis, no titles, right-panel y-label removed
plot_city_comparison <- function(model_list, log_y = FALSE, rug = TRUE,
                                  smooth_term = "s(community_severance_index)",
                                  line_color = "#3b7036", ci_alpha = 0.2,
                                  fill_color = "forestgreen") {
  ylim <- compute_shared_ylim(model_list, smooth_term = smooth_term)
  plots <- plot_smooth_gam(model_list,
    smooth_term = smooth_term, line_color = line_color,
    ci_alpha = ci_alpha, fill_color = fill_color,
    rug = rug, y_limits = ylim, show_title = TRUE, log_y = log_y)
  if (length(plots) > 1)
    plots[[length(plots)]] <- plots[[length(plots)]] +
      ggplot2::theme(axis.title.y = ggplot2::element_blank())
  patchwork::wrap_plots(plots)
}

# Reference level for a GAM(M): the linear predictor evaluated with the CSI
# smooth and the neighborhood random effect held at their average (zero)
# contribution, but the other adjustment covariates set to the fitted
# model's own mean values rather than zero. This is added back to the
# (zero-centered) CSI smooth in plot_ice_overlay() so the Q1/Q5 curves are
# expressed as absolute predicted values for a typical tract in that
# stratum, not an unrealistic tract with all covariates equal to zero.
# Renamed from ice_reference_level() since the underlying computation is
# not ICE-specific, only its current caller is.
# Reference level for a GAM(M): the linear predictor evaluated with the CSI
# smooth and the neighborhood random effect held at their average (zero)
# contribution, but the other adjustment covariates set to the fitted
# model's own mean values rather than zero, so the result is the fitted
# value for a typical tract with mean covariates rather than an
# unrealistic all-covariates-zero tract.
#
# Not currently called by any script or figure — plot_ice_overlay() (Figure 4)
# plots the centered/ratio-scale smooth directly, with no reference level
# added back, matching Figures 2/3. Kept as a standalone diagnostic helper.
gam_reference_level <- function(model) {
  dt <- model$model
  adj_cols <- intersect(
    c("pop_dens", "perc.black", "perc.hisp", "perc.pov", "building_density"),
    names(dt)
  )
  means <- setNames(lapply(adj_cols, function(v) mean(dt[[v]], na.rm = TRUE)), adj_cols)
  ref_neigh <- levels(dt$neighborhood)[1]

  template <- as.data.frame(means, stringsAsFactors = FALSE)
  template$community_severance_index <- 0
  template$neighborhood <- ref_neigh

  form_str <- paste(deparse(formula(model)), collapse = " ")
  offset_match <- regmatches(form_str, regexpr("offset\\(log\\(([^)]+)\\)\\)", form_str))
  if (length(offset_match) > 0 && nzchar(offset_match)) {
    offset_var <- sub("offset\\(log\\(([^)]+)\\)\\)", "\\1", offset_match)
    template[[offset_var]] <- 1
  }

  Xp <- mgcv::predict.gam(model, newdata = template, type = "lpmatrix")
  drop_cols <- grep("^s\\(community_severance_index\\)|^s\\(neighborhood\\)", colnames(Xp))
  if (length(drop_cols) > 0) Xp[, drop_cols] <- 0
  as.numeric(Xp %*% coef(model))
}

# Plot Q1 vs Q5 ICE overlay: one panel per city, Q1=red, Q5=blue
# fits_q1, fits_q5: named lists keyed by "fit_city_nyc" / "fit_city_la"
plot_ice_overlay <- function(fits_q1, fits_q5,
                             smooth_term = "s(community_severance_index)",
                             rug = TRUE,
                             y_limits = NULL,
                             show_title = TRUE,
                             log_y = FALSE) {

  city_label_map <- c(nyc = "New York City", la = "Los Angeles")
  # Same centered ratio/RR scale as plot_smooth_gam() (Figures 2/3), so a
  # coauthor comparing this ICE-stratified figure to the main-analysis
  # figures is reading the same axis quantity for a given outcome. No
  # stratum intercept is added back (that would plot absolute predicted
  # levels and reintroduce an implied Q1-vs-Q5 baseline-level comparison,
  # which is out of scope for this study — see CODE_REVIEW.md).
  response_label_map <- c(
    neighbor_visit_count_annual_avg = "Neighboring-home visit rate ratio (RR)",
    neighbor_visit_share_annual_avg = "Neighboring-home visit share (annual average)",
    NDVI                            = "NDVI",
    closest_greenspace              = "Distance to nearest green space (ratio of predicted mean distance)"
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

      transform <- function(x) {
        if (grepl("gaussian", fam_name, ignore.case = TRUE)) x else linkinv(x)
      }

      sm_q1 <- sm_q1 |> dplyr::mutate(
        est   = transform(.estimate),
        lower = transform(.lower_ci),
        upper = transform(.upper_ci),
        group = "Q1 (Most Disadvantaged)"
      )
      sm_q5 <- sm_q5 |> dplyr::mutate(
        est   = transform(.estimate),
        lower = transform(.lower_ci),
        upper = transform(.upper_ci),
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

      baseline <- if (grepl("gaussian", fam_name, ignore.case = TRUE)) 0 else 1

      palette <- c("Q1 (Most Disadvantaged)" = "#c0392b",
                   "Q5 (Most Advantaged)"    = "#2980b9")

      p <- ggplot(sm, aes(x = community_severance_index, y = est,
                          color = group, fill = group)) +
        geom_ribbon(aes(ymin = lower, ymax = upper),
                    alpha = 0.15, color = NA) +
        geom_line(linewidth = 1.5) +
        geom_hline(yintercept = baseline,
                   linetype = "dashed", color = "grey40", linewidth = 0.9) +
        scale_color_manual(values = palette, name = NULL) +
        scale_fill_manual(values  = palette, name = NULL) +
        labs(
          x     = "Community Severance Index",
          y     = y_label,
          title = if (show_title) city_title else NULL
        ) +
        theme_bw(base_size = 20) +
        theme(
          plot.title    = element_text(size = 24, face = "bold", hjust = 0.5),
          axis.title    = element_text(size = 20),
          axis.text     = element_text(size = 18),
          legend.position = "none",
          plot.margin   = margin(8, 12, 8, 8)
        )

      if (log_y) p <- p + scale_y_log10()
      if (!is.null(y_limits)) p <- p + coord_cartesian(ylim = y_limits)

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
