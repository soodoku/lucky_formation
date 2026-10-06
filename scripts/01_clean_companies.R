# 01_clean_companies.R
# Registry snapshot -> one row per company registered in the sample window.

source("scripts/00_setup.R")

# Strings exactly as in the snapshot (scripts/00_slim_registry.R); the same missing-value codes
# the CSV reader used are applied here.
raw <- read_parquet(CONFIG$companies_path) %>%
  mutate(across(everything(), ~ if_else(.x %in% c("", "NA", "NULL"), NA_character_, .x)))
message("Raw rows: ", nrow(raw))

companies <- raw %>%
  transmute(
    cin = CORPORATE_IDENTIFICATION_NUMBER,
    name = str_squish(COMPANY_NAME),
    status = COMPANY_STATUS,
    class = COMPANY_CLASS,
    sub_category = COMPANY_SUB_CATEGORY,
    date = dmy(DATE_OF_REGISTRATION, quiet = TRUE),
    roc = str_squish(str_remove(REGISTRAR_OF_COMPANIES, "^ROC[[:space:]\\x{00A0}]+")),
    state = REGISTERED_STATE,
    auth_cap = as.numeric(AUTHORIZED_CAP)
  ) %>%
  filter(date >= SAMPLE_START, date <= SAMPLE_END)
message("In window ", SAMPLE_START, " to ", SAMPLE_END, ": ", nrow(companies))

# Whole-word matches only, so SAI does not hit SAINT and OM does not hit OMEGA.
religious_re <- regex(paste0("\\b(", paste(RELIGIOUS_WORDS, collapse = "|"), ")\\b"),
                      ignore_case = TRUE)

companies <- companies %>%
  mutate(
    year = year(date),
    population = case_when(
      sub_category == "Subsidiary of Foreign Company" ~ "foreign_subsidiary",
      sub_category %in% c("Union Govt company", "State Govt company") ~ "government",
      TRUE ~ "domestic_private"
    ),
    religious_name = str_detect(name, religious_re),
    # Minimum-capital rules changed in 2015, so size is relative to the registration year.
    large = auth_cap > ave(auth_cap, year, FUN = function(x) median(x, na.rm = TRUE))
  )

stopifnot(!anyNA(companies$date), !anyDuplicated(companies$cin))

write_parquet(companies, file.path(PATH_DATA, "companies_clean.parquet"))
message("Saved companies_clean.parquet: ", nrow(companies), " rows")
