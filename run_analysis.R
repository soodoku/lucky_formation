#!/usr/bin/env Rscript
# run_analysis.R - Master pipeline for lucky_formation analysis

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option("--panchang", type = "character", default = NULL,
              help = "Path to panchang data (CSV or parquet)"),
  make_option("--companies", type = "character", default = NULL,
              help = "Path to companies data (CSV zip)"),
  make_option("--start-year", type = "integer", default = 2010,
              help = "Start year for analysis [default: %default]"),
  make_option("--end-year", type = "integer", default = 2023,
              help = "End year for analysis [default: %default]"),
  make_option("--skip-completed", action = "store_true", default = FALSE,
              help = "Skip steps that have already produced output"),
  make_option("--step", type = "character", default = NULL,
              help = "Run only a specific step (e.g., '01' or '01_load_and_clean_data.R')"),
  make_option("--from-step", type = "character", default = NULL,
              help = "Start from a specific step (e.g., '03')"),
  make_option("--dry-run", action = "store_true", default = FALSE,
              help = "Show what would be run without executing")
)

parser <- OptionParser(
  usage = "usage: %prog [options]",
  option_list = option_list,
  description = "Run the lucky_formation analysis pipeline"
)

args <- parse_args(parser)

CONFIG <- list(
  panchang_path = if (!is.null(args$panchang)) args$panchang else "data/real_panchang_2000_2024.csv",
  companies_path = if (!is.null(args$companies)) args$companies else "data/registered_companies.csv.zip",
  output_dir = "output",
  start_year = args$`start-year`,
  end_year = args$`end-year`,
  skip_completed = args$`skip-completed`
)

Sys.setenv(
  LUCKY_PANCHANG_PATH = CONFIG$panchang_path,
  LUCKY_COMPANIES_PATH = CONFIG$companies_path,
  LUCKY_START_YEAR = as.character(CONFIG$start_year),
  LUCKY_END_YEAR = as.character(CONFIG$end_year)
)

steps <- c(
  "01_load_and_clean_data.R",
  "02_create_daily_panel.R",
  "03_summary_statistics.R",
  "04_design1_panchang_dimensions.R",
  "05_design2_composite_scores.R",
  "06_design4_balance_tests.R",
  "07_design5_heterogeneity.R",
  "08_design3_temporal_placebos.R",
  "09_design3_randomization_inference.R",
  "10_design3_specification_curve.R",
  "11_generate_figures.R",
  "12_generate_tables.R"
)

check_outputs <- list(
  "01_load_and_clean_data.R" = c("data/panchang_clean.parquet", "data/companies_clean.parquet"),
  "02_create_daily_panel.R" = "data/daily_panel.parquet",
  "03_summary_statistics.R" = "tabs/summary_stats.tex",
  "04_design1_panchang_dimensions.R" = "tabs/design1_individual_dimensions.tex",
  "05_design2_composite_scores.R" = "tabs/design2_composite_scores.tex",
  "06_design4_balance_tests.R" = "tabs/design4_balance.tex",
  "07_design5_heterogeneity.R" = "tabs/design5_heterogeneity.tex",
  "08_design3_temporal_placebos.R" = "tabs/design3_placebo_lags.tex",
  "09_design3_randomization_inference.R" = "data/ri_results.rds",
  "10_design3_specification_curve.R" = "data/spec_curve_results.parquet",
  "11_generate_figures.R" = "figs/fig1_daily_registrations.pdf",
  "12_generate_tables.R" = "tabs/main_results.tex"
)

step_completed <- function(step_name) {
  outputs <- check_outputs[[step_name]]
  if (is.null(outputs)) return(FALSE)
  all(file.exists(outputs))
}

run_step <- function(step_name, config) {
  script_path <- file.path("scripts", step_name)

  if (!file.exists(script_path)) {
    message("  [SKIP] Script not found: ", script_path)
    return(FALSE)
  }

  if (config$skip_completed && step_completed(step_name)) {
    message("  [SKIP] Already completed: ", step_name)
    return(TRUE)
  }

  message("  [RUN] ", step_name)
  start_time <- Sys.time()

  tryCatch({
    source(script_path, local = new.env())
    elapsed <- round(difftime(Sys.time(), start_time, units = "secs"), 1)
    message("  [DONE] ", step_name, " (", elapsed, "s)")
    return(TRUE)
  }, error = function(e) {
    message("  [ERROR] ", step_name, ": ", conditionMessage(e))
    return(FALSE)
  })
}

filter_steps <- function(steps, only_step, from_step) {
  if (!is.null(only_step)) {
    pattern <- paste0("^", gsub("^0+", "0*", only_step))
    matches <- grep(pattern, steps, value = TRUE)
    if (length(matches) == 0) {
      stop("No step matching '", only_step, "' found")
    }
    return(matches[1])
  }

  if (!is.null(from_step)) {
    pattern <- paste0("^", gsub("^0+", "0*", from_step))
    idx <- grep(pattern, steps)[1]
    if (is.na(idx)) {
      stop("No step matching '", from_step, "' found")
    }
    return(steps[idx:length(steps)])
  }

  return(steps)
}

main <- function() {
  message("=" |> rep(60) |> paste(collapse = ""))
  message("Lucky Formation Analysis Pipeline")
  message("=" |> rep(60) |> paste(collapse = ""))
  message("")
  message("Configuration:")
  message("  Panchang: ", CONFIG$panchang_path)
  message("  Companies: ", CONFIG$companies_path)
  message("  Years: ", CONFIG$start_year, "-", CONFIG$end_year)
  message("")

  steps_to_run <- filter_steps(steps, args$step, args$`from-step`)

  if (args$`dry-run`) {
    message("Dry run - would execute:")
    for (step in steps_to_run) {
      status <- if (step_completed(step)) "[completed]" else "[pending]"
      message("  ", status, " ", step)
    }
    return(invisible())
  }

  message("Running ", length(steps_to_run), " step(s)...")
  message("")

  results <- list()
  for (step in steps_to_run) {
    success <- run_step(step, CONFIG)
    results[[step]] <- success
    if (!success && !CONFIG$skip_completed) {
      message("")
      message("Pipeline stopped due to error in: ", step)
      break
    }
  }

  message("")
  message("=" |> rep(60) |> paste(collapse = ""))
  message("Pipeline Summary")
  message("=" |> rep(60) |> paste(collapse = ""))

  for (step in names(results)) {
    status <- if (results[[step]]) "OK" else "FAILED"
    message("  [", status, "] ", step)
  }

  n_success <- sum(unlist(results))
  n_total <- length(results)
  message("")
  message("Completed: ", n_success, "/", n_total, " steps")
}

main()
