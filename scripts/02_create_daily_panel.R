# 02_create_daily_panel.R
# Aggregate to daily counts, merge with panchang

source("scripts/00_setup.R")

message("Loading cleaned data...")
panchang <- read_parquet(file.path(PATH_DATA, "panchang_clean.parquet"))
companies <- read_parquet(file.path(PATH_DATA, "companies_clean.parquet"))

# Daily counts: total
daily_total <- companies %>%
  count(date, name = "n_inc")

# Daily counts: by company type
daily_by_type <- companies %>%
  count(date, company_type) %>%
  pivot_wider(names_from = company_type, values_from = n, values_fill = 0, names_prefix = "n_")

# Daily counts: by size
daily_by_size <- companies %>%
  count(date, size_cat) %>%
  pivot_wider(names_from = size_cat, values_from = n, values_fill = 0, names_prefix = "n_")

# Daily counts: by geography (Hindu belt vs cosmopolitan)
daily_by_geo <- companies %>%
  mutate(
    geo_group = case_when(
      state %in% HINDU_BELT_STATES ~ "hindu_belt",
      state %in% COSMOPOLITAN_STATES ~ "cosmopolitan",
      TRUE ~ "other"
    )
  ) %>%
  count(date, geo_group) %>%
  pivot_wider(names_from = geo_group, values_from = n, values_fill = 0, names_prefix = "n_")

# Merge all daily counts
daily <- daily_total %>%
  left_join(daily_by_type, by = "date") %>%
  left_join(daily_by_size, by = "date") %>%
  left_join(daily_by_geo, by = "date")

# Merge with panchang
daily <- daily %>%
  inner_join(panchang, by = "date")

message("Daily panel rows: ", nrow(daily))

# Create time variables
daily <- daily %>%
  mutate(
    year = year(date),
    month = month(date),
    day = day(date),
    quarter = quarter(date)
  )

# Create lead/lag placebo variables for shubh_strict
daily <- daily %>%
  arrange(date) %>%
  mutate(
    shubh_strict_lead1 = lead(shubh_strict, 1),
    shubh_strict_lead2 = lead(shubh_strict, 2),
    shubh_strict_lead3 = lead(shubh_strict, 3),
    shubh_strict_lag1 = lag(shubh_strict, 1),
    shubh_strict_lag2 = lag(shubh_strict, 2),
    shubh_strict_lag3 = lag(shubh_strict, 3)
  )

# Create control variables
daily <- daily %>%
  mutate(
    # Fiscal year timing
    is_fiscal_yearend = (month == 3 & day >= 25) | (month == 4 & day <= 7),
    is_fiscal_yearstart = month == 4 & day <= 15,

    # Macro shocks
    is_demonetization = date >= as.Date("2016-11-08") & date <= as.Date("2016-12-31"),
    is_gst_rollout = date >= as.Date("2017-07-01") & date <= as.Date("2017-07-31"),
    is_covid = date >= as.Date("2020-03-25") & date <= as.Date("2020-05-31"),
    is_covid_era = date >= as.Date("2020-03-01") & date <= as.Date("2021-06-30"),

    # Gregorian holidays (major ones)
    is_new_year = month == 1 & day == 1,
    is_republic_day = month == 1 & day == 26,
    is_independence_day = month == 8 & day == 15,
    is_gandhi_jayanti = month == 10 & day == 2,
    is_christmas = month == 12 & day == 25,
    is_gregorian_holiday = is_new_year | is_republic_day | is_independence_day |
                           is_gandhi_jayanti | is_christmas,

    # Diwali season (approximate: Oct 15 - Nov 15)
    is_diwali_season = (month == 10 & day >= 15) | (month == 11 & day <= 15),

    # Pre-COVID sample
    is_pre_covid = date < as.Date("2020-03-01"),

    # Post-demonetization sample
    is_post_demonetization = date >= as.Date("2017-01-01")
  )

# Convert weekday to factor
daily <- daily %>%
  mutate(weekday = factor(weekday, levels = 1:5, labels = c("Mon", "Tue", "Wed", "Thu", "Fri")))

message("Panel date range: ", min(daily$date), " to ", max(daily$date))
message("Observations per year:")
print(daily %>% count(year))

# Save daily panel
write_parquet(daily, file.path(PATH_DATA, "daily_panel.parquet"))
message("Saved: ", file.path(PATH_DATA, "daily_panel.parquet"))

message("Script 02 complete")
