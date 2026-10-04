# 00_setup.R
# Shared configuration, sourced by every analysis script.

suppressPackageStartupMessages({
  library(tidyverse)
  library(arrow)
  library(fixest)
  library(lubridate)
})

PATH_DATA <- "data"
PATH_TABS <- "tabs"
PATH_FIGS <- "figs"
dir.create(PATH_TABS, showWarnings = FALSE)
dir.create(PATH_FIGS, showWarnings = FALSE)

CONFIG <- list(
  panchang_path = Sys.getenv("LUCKY_PANCHANG_PATH", "data/panchang.csv"),
  companies_path = Sys.getenv("LUCKY_COMPANIES_PATH", "data/registered_companies.csv.zip")
)

# Electronic filing became mandatory on 2006-09-16; the snapshot ends in January 2020.
SAMPLE_START <- as.Date("2006-10-01")
SAMPLE_END <- as.Date("2020-01-31")
# CRC Phase 2: incorporations nationwide approved centrally, typically within a day.
CRC_DATE <- as.Date("2016-03-23")

# Fixed in ms/pap.md before any estimate using it was run.
RELIGIOUS_WORDS <- c(
  "SHRI", "SHREE", "SRI", "SREE", "LAXMI", "LAKSHMI", "MAHALAXMI", "MAHALAKSHMI",
  "GANESH", "GANESHA", "GANAPATI", "GANAPATHY", "VINAYAK", "VINAYAKA", "BALAJI",
  "TIRUPATI", "VENKATESHWARA", "SAI", "DURGA", "AMBIKA", "BHAWANI", "BHAVANI",
  "JAGDAMBA", "SHIV", "SHIVA", "MAHADEV", "KRISHNA", "GOPAL", "GOVIND", "HANUMAN",
  "BAJRANG", "OM", "SHUBH", "SHUBHLABH", "SIDDHI", "RIDDHI", "SARASWATI", "PARVATI",
  "MAA", "ISHWAR", "MANGALAM", "TIRUMALA", "MURUGAN", "AYYAPPA"
)

COL_MAIN <- "#B5551D"
COL_REF <- "gray45"

theme_set(
  theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      plot.title.position = "plot"
    )
)

save_tex_table <- function(tab, filename) {
  path <- file.path(PATH_TABS, filename)
  writeLines(as.character(tab), path)
  message("Saved: ", path)
}

save_fig <- function(p, filename, width = 7, height = 4.5) {
  ggsave(file.path(PATH_FIGS, filename), p, width = width, height = height)
  message("Saved: ", file.path(PATH_FIGS, filename))
}

# Numbers quoted in the paper's prose are written here as LaTeX macros, one file per script,
# so the text cannot drift from the code that produced it.
write_numbers <- function(values, filename) {
  stopifnot(!is.null(names(values)), all(grepl("^[A-Za-z]+$", names(values))))
  lines <- sprintf("\\newcommand{\\%s}{%s}", names(values), unlist(values))
  path <- file.path(PATH_TABS, filename)
  writeLines(lines, path)
  message("Saved: ", path)
}

fmt_pct <- function(x, digits = 1) sprintf(paste0("%.", digits, "f"), 100 * x)
fmt_int <- function(x) format(round(x), big.mark = ",", scientific = FALSE)
