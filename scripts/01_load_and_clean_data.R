# 01_load_and_clean_data.R
# Load raw data once, clean, save as parquet

source("scripts/00_setup.R")

message("Loading panchang data from: ", CONFIG$panchang_path)

if (grepl("\\.parquet$", CONFIG$panchang_path)) {
  panchang <- read_parquet(CONFIG$panchang_path) %>%
    mutate(date = as.Date(date))
} else {
  panchang <- read_csv(CONFIG$panchang_path, show_col_types = FALSE) %>%
    mutate(date = as.Date(date))
}

message("Panchang rows: ", nrow(panchang))
message("Date range: ", min(panchang$date), " to ", max(panchang$date))

message("Loading company data from: ", CONFIG$companies_path)

if (grepl("\\.zip$", CONFIG$companies_path)) {
  companies <- read_csv(
    pipe(paste0("unzip -p ", CONFIG$companies_path)),
    show_col_types = FALSE,
    na = c("", "NA", "NULL")
  )
} else {
  companies <- read_csv(CONFIG$companies_path, show_col_types = FALSE, na = c("", "NA", "NULL"))
}

message("Raw company rows: ", nrow(companies))

start_date <- as.Date(paste0(CONFIG$start_year, "-01-01"))
end_date <- as.Date(paste0(CONFIG$end_year, "-12-31"))

companies <- companies %>%
  mutate(date = dmy(DATE_OF_REGISTRATION)) %>%
  filter(!is.na(date)) %>%
  filter(date >= start_date, date <= end_date)

message("Companies after date filter (", CONFIG$start_year, "-", CONFIG$end_year, "): ", nrow(companies))

companies <- companies %>%
  mutate(
    weekday = wday(date, week_start = 1),
    is_weekend = weekday %in% c(6, 7)
  )

message("Weekend incorporations: ", sum(companies$is_weekend))
message("Weekday incorporations: ", sum(!companies$is_weekend))

# Drop weekends (MCA portal closed)
companies <- companies %>%
  filter(!is_weekend)

message("Companies after dropping weekends: ", nrow(companies))

# Clean company type
# Note: OPC is in COMPANY_CLASS as "Private(One Person Company)"
# LLP may be in different dataset or marked differently
companies <- companies %>%
  mutate(
    company_type = case_when(
      str_detect(COMPANY_CLASS, regex("One Person", ignore_case = TRUE)) ~ "OPC",
      str_detect(COMPANY_CLASS, regex("Public", ignore_case = TRUE)) ~ "Public",
      str_detect(COMPANY_CLASS, regex("Private", ignore_case = TRUE)) ~ "Private",
      TRUE ~ "Other"
    ),
    state = REGISTERED_STATE,
    auth_cap = as.numeric(AUTHORIZED_CAP),
    auth_cap = if_else(is.na(auth_cap), 0, auth_cap)
  )

message("Company type distribution:")
print(companies %>% count(company_type, sort = TRUE))

# Size classification (based on authorized capital median)
med_cap <- median(companies$auth_cap[companies$auth_cap > 0], na.rm = TRUE)
companies <- companies %>%
  mutate(size_cat = if_else(auth_cap >= med_cap, "large", "small"))

message("Median authorized capital: ", format(med_cap, big.mark = ","))

# Save cleaned data as parquet
message("Saving cleaned data as parquet...")
write_parquet(panchang, file.path(PATH_DATA, "panchang_clean.parquet"))
write_parquet(companies, file.path(PATH_DATA, "companies_clean.parquet"))

message("Saved: ", file.path(PATH_DATA, "panchang_clean.parquet"))
message("Saved: ", file.path(PATH_DATA, "companies_clean.parquet"))

message("Script 01 complete")
