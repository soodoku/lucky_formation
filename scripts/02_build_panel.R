# 02_build_panel.R
# Registrar (ROC) x business-day panel of registration counts, with closures and panchang.

source("scripts/00_setup.R")

companies <- read_parquet(file.path(PATH_DATA, "companies_clean.parquet"))
panchang <- read_csv(CONFIG$panchang_path, show_col_types = FALSE)
holidays <- read_csv(file.path(PATH_DATA, "holidays_official.csv"), show_col_types = FALSE)

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
# Which days were holidays comes from DoPT's annual memoranda (scripts/build_holidays.py):
# 14 compulsory holidays for every central office, Delhi's 3 further choices, and the 12
# optional occasions from which each state's coordination committee picked 3 (not published
# centrally). Whether a registrar actually stopped approving comes from the registry: under a
# tenth of its weekly median, for registrars averaging at least ten a day, or the whole
# country under a tenth of its weekly median. The central registry (from March 2016) often
# approved on gazetted holidays, so a holiday on the list is not by itself a closure.
#
# Excluded registrar-weekdays:
#   - holiday, closed: a listed holiday (or the day next to a movable one: Islamic holidays
#     by moon sighting, Deepavali on Naraka Chaturdasi) on which the registrar shut;
#   - holiday, undetectable: a listed holiday at a registrar too small to show a shut-down;
#   - national shut-down: the whole country shut on a day not on the list (portal outages);
#   - unexplained shut-down: one registrar shut on a day not on the list (listed in
#     data/closures_unexplained.csv).
# Listed holidays on which the registrar worked are kept, with an indicator.
panel <- panel %>%
  filter(date >= OFFICIAL_CALENDAR_START) %>%
  mutate(
    week = floor_date(date, "week", week_start = 1),
    post_crc = date >= CRC_DATE
  )

weekdays_only <- filter(panel, weekday <= 5)
national <- weekdays_only %>%
  group_by(date, week) %>%
  summarise(n_nat = sum(n_all), .groups = "drop") %>%
  group_by(week) %>%
  mutate(nat_rel = n_nat / median(n_nat)) %>%
  ungroup()

compulsory <- filter(holidays, kind == "compulsory")
navratri_first <- panchang %>%
  mutate(date = as.Date(date)) %>%
  filter(navratri == 1, lag(navratri, default = 0) == 0) %>%
  transmute(date, holiday = "1st Navratra", kind = "optional", group = "vishu group",
            movable = FALSE)
listed <- bind_rows(holidays, navratri_first)
movable <- compulsory %>% filter(movable) %>% pull(date)

panel <- panel %>%
  group_by(roc, week) %>%
  mutate(roc_med = median(n_all[weekday <= 5])) %>%
  ungroup() %>%
  left_join(select(national, date, nat_rel), by = "date") %>%
  mutate(
    detectable = weekday <= 5 & (post_crc | roc_med >= 10),
    shut_national = weekday <= 5 & nat_rel < 0.1,
    shut = shut_national | (weekday <= 5 & !post_crc & roc_med >= 10 & n_all < 0.1 * roc_med),
    holiday_listed = date %in% listed$date |
      ((date + 1) %in% movable | (date - 1) %in% movable),
    closure_type = case_when(
      weekday > 5 ~ "saturday",
      holiday_listed & shut ~ "holiday, closed",
      holiday_listed & !detectable ~ "holiday, undetectable",
      holiday_listed ~ "holiday, open",
      shut_national ~ "national shut-down",
      shut ~ "unexplained shut-down",
      TRUE ~ "ordinary day"
    ),
    closed = closure_type %in% c("holiday, closed", "holiday, undetectable",
                                 "national shut-down", "unexplained shut-down"),
    holiday_open = closure_type == "holiday, open",
    closure_detected = shut
  )
print(count(filter(panel, weekday <= 5), closure_type))

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

# --- How well the official calendar explains the shut-downs ------------------------
det <- filter(panel, detectable)
compulsory_days <- det$date %in% compulsory$date
pre <- !det$post_crc
compulsory_shut_pre <- mean(det$shut[compulsory_days & pre])
compulsory_shut_post <- mean(det$shut[compulsory_days & !pre])
shut_listed <- with(det, mean(holiday_listed[shut & !shut_national]))
unexplained <- panel %>%
  filter(closure_type == "unexplained shut-down") %>%
  select(roc, date, n_all, roc_med, nat_rel)
write_csv(unexplained, file.path(PATH_DATA, "closures_unexplained.csv"))
message("Compulsory holidays shut where detectable, before / after CRC: ",
        round(100 * compulsory_shut_pre, 1), "% / ", round(100 * compulsory_shut_post, 1), "%")
message("Registrar shut-downs (not national) on a listed holiday: ", round(100 * shut_listed, 1),
        "%")

types <- count(filter(panel, weekday <= 5), closure_type)
type_n <- function(x) fmt_int(sum(types$n[types$closure_type == x]))
write_numbers(c(
  NCompanies = fmt_int(nrow(companies) + n_no_roc),
  NNoRoc = fmt_int(n_no_roc),
  NRocs = n_distinct(panel$roc),
  NBusinessDays = fmt_int(n_distinct(panel$date[panel$weekday <= 5])),
  NDisruptedWeeks = sum(disrupted$disrupted_week),
  ShareCompulsoryShutPre = fmt_pct(compulsory_shut_pre, 0),
  ShareCompulsoryShutPost = fmt_pct(compulsory_shut_post, 0),
  ShareShutListed = fmt_pct(shut_listed, 0),
  NHolidayClosed = type_n("holiday, closed"),
  NHolidayUndetectable = type_n("holiday, undetectable"),
  NHolidayOpen = type_n("holiday, open"),
  NNationalShut = type_n("national shut-down"),
  NUnexplainedShut = type_n("unexplained shut-down")
), "numbers_panel.tex")
