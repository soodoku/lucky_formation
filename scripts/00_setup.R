# 00_setup.R
# Common setup sourced by all scripts

library(tidyverse)
library(arrow)
library(fixest)
library(modelsummary)
library(lubridate)

# Paths
PATH_DATA <- "data"
PATH_TABS <- "tabs"
PATH_FIGS <- "figs"

# Configurable paths (from environment or defaults)
CONFIG <- list(
  panchang_path = Sys.getenv("LUCKY_PANCHANG_PATH", "data/real_panchang_2000_2024.csv"),
  companies_path = Sys.getenv("LUCKY_COMPANIES_PATH", "data/registered_companies.csv.zip"),
  start_year = as.integer(Sys.getenv("LUCKY_START_YEAR", "2010")),
  end_year = as.integer(Sys.getenv("LUCKY_END_YEAR", "2023"))
)

# Ensure output directories exist
dir.create(PATH_TABS, showWarnings = FALSE)
dir.create(PATH_FIGS, showWarnings = FALSE)

# Color scheme
COL_AUSP <- "#FF9933"
COL_INAUSP <- "#8B0000"
COL_NEUTRAL <- "gray50"

# Theme for plots
theme_lucky <- theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(face = "bold"),
    axis.title = element_text(face = "bold")
  )
theme_set(theme_lucky)

# Control formulas
CONTROLS_MINIMAL <- "| weekday + month"
CONTROLS_STANDARD <- "| weekday + month + year"
CONTROLS_FULL <- "| weekday + month + year + is_fiscal_yearend + is_demonetization + is_gst_rollout + is_covid"

# Hindu belt states
HINDU_BELT_STATES <- c(

  "Uttar Pradesh", "Madhya Pradesh", "Gujarat", "Rajasthan", "Bihar",
  "Jharkhand", "Chhattisgarh", "Uttarakhand", "Haryana", "Himachal Pradesh"
)

COSMOPOLITAN_STATES <- c("Maharashtra", "Karnataka", "Delhi", "Tamil Nadu", "Telangana")

# Modelsummary settings
gm <- list(
  list("raw" = "nobs", "clean" = "Observations", "fmt" = function(x) format(x, big.mark = ",")),
  list("raw" = "r.squared", "clean" = "R²", "fmt" = 3),
  list("raw" = "adj.r.squared", "clean" = "Adj. R²", "fmt" = 3)
)

# Function to save tables
save_tex_table <- function(tab, filename) {
  if (inherits(tab, "tinytable")) {
    tinytable::save_tt(tab, file.path(PATH_TABS, filename), overwrite = TRUE)
  } else if (is.character(tab)) {
    writeLines(tab, file.path(PATH_TABS, filename))
  } else {
    writeLines(as.character(tab), file.path(PATH_TABS, filename))
  }
  message("Saved: ", file.path(PATH_TABS, filename))
}

# Function to save figures
save_fig <- function(p, filename, width = 8, height = 6) {
  ggsave(file.path(PATH_FIGS, filename), p, width = width, height = height, dpi = 300)
  message("Saved: ", file.path(PATH_FIGS, filename))
}

# Helper function to extract coefficients from fixest models
tidy_fixest <- function(model, conf.int = TRUE) {
  coefs <- coef(model)
  se <- sqrt(diag(vcov(model)))
  pvals <- 2 * pnorm(-abs(coefs / se))
  tibble(
    term = names(coefs),
    estimate = as.numeric(coefs),
    std.error = se,
    p.value = pvals,
    conf.low = estimate - 1.96 * std.error,
    conf.high = estimate + 1.96 * std.error
  )
}

message("Setup loaded successfully")
