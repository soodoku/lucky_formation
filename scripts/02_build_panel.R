# 02_build_panel.R
# Registrar (ROC) x business-day panel of registration counts, with closures and panchang.

source("scripts/00_setup.R")

companies <- read_parquet(file.path(PATH_DATA, "companies_clean.parquet"))
panchang <- read_csv(CONFIG$panchang_path, show_col_types = FALSE)
holidays <- read_csv(file.path(PATH_DATA, "holidays.csv"), show_col_types = FALSE)

n_no_roc <- sum(is.na(companies$roc))
message("Companies without a registrar, dropped: ", n_no_roc)
companies <- filter(companies, !is.na(roc))

days <- tibble(date = seq(SAMPLE_START, SAMPLE_END, by = "day")) %>%
  mutate(weekday = wday(date, week_start = 1)) %>%
  filter(weekday <= 6)

counts <- companies %>%
  mutate(
    n_all = 1L,
    n_dom = population == "domestic_private",
    n_foreign = population == "foreign_subsidiary",
    n_govt = population == "government",
    n_relig = n_dom & religious_name,
    n_secular = n_dom & !religious_name,
    n_large = n_dom & large %in% TRUE,
    n_small = n_dom & large %in% FALSE
  ) %>%
  group_by(roc, date) %>%
  summarise(across(starts_with("n_"), sum), .groups = "drop")

panel <- expand_grid(roc = sort(unique(companies$roc)), days) %>%
  left_join(counts, by = c("roc", "date")) %>%
  mutate(across(starts_with("n_"), ~ replace_na(as.integer(.x), 0L)))

stopifnot(sum(panel$n_all) == sum(wday(companies$date, week_start = 1) <= 6))
message("Weekday+Saturday registrations kept: ", sum(panel$n_all),
        "; Sunday registrations outside the spine: ",
        sum(wday(companies$date, week_start = 1) == 7))

# --- Closures -----------------------------------------------------------------
# Two independent sources. Listed: the jurisdiction's public holidays (state calendar before
# the CRC, central after). Detected: a registrar that normally approves at least ten a day
# approving fewer than a tenth of its weekly median, or the whole country doing so.
panel <- panel %>%
  mutate(
    week = floor_date(date, "week", week_start = 1),
    post_crc = date >= CRC_DATE,
    cal = if_else(post_crc, "NATIONAL", roc)
  ) %>%
  left_join(holidays %>% distinct(roc, date, .keep_all = TRUE) %>%
              rename(cal = roc), by = c("cal", "date")) %>%
  mutate(holiday_listed = !is.na(holiday))

weekdays_only <- filter(panel, weekday <= 5)
national <- weekdays_only %>%
  group_by(date, week) %>%
  summarise(n_nat = sum(n_all), .groups = "drop") %>%
  group_by(week) %>%
  mutate(nat_rel = n_nat / median(n_nat)) %>%
  ungroup()

panel <- panel %>%
  group_by(roc, week) %>%
  mutate(roc_med = median(n_all[weekday <= 5])) %>%
  ungroup() %>%
  left_join(select(national, date, nat_rel), by = "date") %>%
  mutate(
    closed_national = weekday <= 5 & nat_rel < 0.1,
    closed_roc = weekday <= 5 & !post_crc & roc_med >= 10 & n_all < 0.1 * roc_med,
    closure_detected = closed_national | closed_roc,
    closed = holiday_listed | closure_detected
  )

# Disrupted weeks: whole weeks far below trend, from regime changes (Companies Act 2013 forms
# in April 2014, the CRC take-over in March 2016) and portal outages. A within-week median
# cannot see these, so compare each week with the 17-week rolling median around it.
disrupted <- national %>%
  group_by(week) %>%
  summarise(n = sum(n_nat), .groups = "drop") %>%
  arrange(week) %>%
  mutate(
    trend = zoo::rollapply(n, 17, median, fill = NA, align = "center", partial = TRUE),
    disrupted_week = n < 0.5 * trend
  )
message("Disrupted weeks: ", paste(disrupted$week[disrupted$disrupted_week], collapse = ", "))
panel <- panel %>%
  left_join(select(disrupted, week, disrupted_week), by = "week") %>%
  mutate(disrupted_week = replace_na(disrupted_week, FALSE))

# Backlog: a closure pushes approvals onto the neighbouring open days.
panel <- panel %>%
  arrange(roc, date) %>%
  group_by(roc) %>%
  mutate(
    after_closure = lag(closed, default = FALSE) & !closed,
    before_closure = lead(closed, default = FALSE) & !closed
  ) %>%
  ungroup()

# --- Panchang and calendar -------------------------------------------------------
panel <- panel %>%
  left_join(panchang %>% mutate(date = as.Date(date)) %>% select(-weekday), by = "date") %>%
  mutate(
    year = year(date),
    week_of_year = isoweek(date),
    month = month(date),
    tithi_index = tithi_ausp - tithi_inausp,
    month_end = days_in_month(date) - day(date) < 3,
    quarter_end = month %in% c(3, 6, 9, 12) & month_end
  )
stopifnot(!anyNA(panel$tithi_num), !anyNA(panel$weekday))

write_parquet(panel, file.path(PATH_DATA, "roc_panel.parquet"))
message("Saved roc_panel.parquet: ", nrow(panel), " ROC-days, ",
        n_distinct(panel$roc), " registrars")

# --- Agreement between the two closure sources --------------------------------
# Only where a closure is detectable: weekdays at registrars averaging ten or more a day,
# or any weekday for national closures.
detectable <- panel %>%
  filter(weekday <= 5, post_crc | roc_med >= 10)
agree <- detectable %>%
  count(holiday_listed, closure_detected) %>%
  mutate(share = n / sum(n))
print(agree)
detected_unlisted <- detectable %>%
  filter(closure_detected, !holiday_listed) %>%
  distinct(date, .keep_all = TRUE)
listed_open <- detectable %>%
  filter(holiday_listed, !closure_detected) %>%
  count(holiday, sort = TRUE)
write_csv(detected_unlisted %>% select(roc, date, n_all, roc_med, nat_rel),
          file.path(PATH_DATA, "closures_detected_unlisted.csv"))
write_csv(listed_open, file.path(PATH_DATA, "holidays_listed_but_open.csv"))

closure_tab <- agree %>%
  mutate(
    holiday_listed = if_else(holiday_listed, "Listed holiday", "Not listed"),
    closure_detected = if_else(closure_detected, "Closed", "Open")
  )
write_numbers(c(
  NCompanies = fmt_int(nrow(companies) + n_no_roc),
  NNoRoc = fmt_int(n_no_roc),
  NRocs = n_distinct(panel$roc),
  NBusinessDays = fmt_int(n_distinct(panel$date[panel$weekday <= 5])),
  NDisruptedWeeks = sum(disrupted$disrupted_week),
  ShareClosedListedAgree = fmt_pct(
    with(detectable, mean(holiday_listed[closure_detected])), 0),
  ShareListedClosed = fmt_pct(
    with(detectable, mean(closure_detected[holiday_listed])), 0)
), "numbers_panel.tex")
