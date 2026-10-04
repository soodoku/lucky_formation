# 04_describe.R
# Descriptive exhibits: the registration series, closures, and the panchang's variation.

source("scripts/00_setup.R")

panel <- read_parquet(file.path(PATH_DATA, "roc_panel.parquet"))
panchang <- read_csv(CONFIG$panchang_path, show_col_types = FALSE) %>%
  mutate(date = as.Date(date))

# --- Figure 1: weekly registrations, with Pitru Paksha marked ------------------------
weekly <- panel %>%
  group_by(week) %>%
  summarise(n = sum(n_dom), pitru = any(pitru_paksha == 1 & weekday <= 5), .groups = "drop")
pp_spans <- panchang %>%
  filter(pitru_paksha == 1, date >= SAMPLE_START, date <= SAMPLE_END) %>%
  group_by(year = year(date)) %>%
  summarise(start = min(date), end = max(date))

fig1 <- ggplot(weekly, aes(week, n)) +
  geom_rect(data = pp_spans, aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
            inherit.aes = FALSE, fill = COL_MAIN, alpha = 0.25) +
  geom_line(linewidth = 0.3, colour = "gray20") +
  scale_y_continuous(labels = scales::comma) +
  labs(x = NULL, y = "Companies registered per week",
       caption = "Shaded: Pitru Paksha. Domestic non-government companies, all registrars.")
save_fig(fig1, "fig_weekly_series.pdf", width = 7, height = 3.2)

# --- Figure 2: what a closure looks like --------------------------------------------
# Each registrar-weekday's count relative to its weekly median, for registrars large
# enough that a closure is distinguishable from a slow day.
rel <- panel %>%
  filter(weekday <= 5, post_crc | roc_med >= 10) %>%
  mutate(
    ratio = if_else(post_crc, nat_rel, n_all / pmax(roc_med, 1)),
    source = case_when(
      holiday_listed & closure_detected ~ "Listed holiday, closed",
      holiday_listed ~ "Listed holiday, open",
      closure_detected ~ "Unlisted closure",
      TRUE ~ "Ordinary day"
    )
  ) %>%
  distinct(date, roc = if_else(post_crc, "CRC", roc), .keep_all = TRUE)

fig2 <- ggplot(rel, aes(pmin(ratio, 2), fill = source)) +
  geom_histogram(binwidth = 0.05, boundary = 0) +
  geom_vline(xintercept = 0.1, linetype = "dashed") +
  scale_fill_manual(values = c("Ordinary day" = "gray75", "Listed holiday, closed" = COL_MAIN,
                               "Listed holiday, open" = "#E3A87E", "Unlisted closure" = "gray25")) +
  scale_y_sqrt() +
  labs(x = "Registrations relative to the registrar's weekly median (capped at 2)",
       y = "Registrar-days (square-root scale)", fill = NULL)
save_fig(fig2, "fig_closures.pdf", width = 7, height = 3.5)

# --- Table: sample description --------------------------------------------------------
prim <- filter(panel, weekday <= 5)
summ <- tibble(
  Quantity = c(
    "Companies registered (Mon--Sat)",
    "\\quad domestic non-government",
    "\\quad subsidiaries of foreign companies",
    "\\quad government companies",
    "Registrars",
    "Business days (Mon--Fri)",
    "Registrar-days, Mon--Fri",
    "\\quad of which closed",
    "Mean registrations per open registrar-day",
    "Days in Pitru Paksha per year (mean)",
    "Share of business days with auspicious tithi",
    "Share of business days with inauspicious tithi"
  ),
  Value = c(
    fmt_int(sum(panel$n_all)),
    fmt_int(sum(panel$n_dom)),
    fmt_int(sum(panel$n_foreign)),
    fmt_int(sum(panel$n_govt)),
    n_distinct(panel$roc),
    fmt_int(n_distinct(prim$date)),
    fmt_int(nrow(prim)),
    fmt_int(sum(prim$closed)),
    sprintf("%.1f", mean(prim$n_dom[!prim$closed])),
    sprintf("%.1f", mean(table(year(panchang$date[panchang$pitru_paksha == 1])))),
    fmt_pct(mean(distinct(prim, date, tithi_ausp)$tithi_ausp), 0),
    fmt_pct(mean(distinct(prim, date, tithi_inausp)$tithi_inausp), 0)
  )
)
tab <- c(
  "\\begin{tabular}{lr}", "\\toprule",
  paste0(summ$Quantity, " & ", summ$Value, " \\\\"),
  "\\bottomrule", "\\end{tabular}"
)
save_tex_table(tab, "tab_sample.tex")

# --- Validation table ---------------------------------------------------------------
# Drik Panchang for the sample years (rules tuned there); the holidays package, never used
# for tuning, for the sample years and 2020-2025.
labels <- c(
  gudi_padwa = "Gudi Padwa / Ugadi", akshaya_tritiya = "Akshaya Tritiya",
  vijayadashami = "Vijayadashami", dhanteras = "Dhanteras", diwali = "Lakshmi Puja (Diwali)",
  pitru_paksha_first = "Pitru Paksha, first day", pitru_paksha_last = "Pitru Paksha, last day"
)
fest <- read_csv(file.path(PATH_DATA, "validation_festivals.csv"), show_col_types = FALSE)
days <- read_csv(file.path(PATH_DATA, "validation_days.csv"), show_col_types = FALSE)
pkg <- read_csv(file.path(PATH_DATA, "validation_holidays_pkg.csv"), show_col_types = FALSE) %>%
  mutate(late = year(as.Date(package)) >= 2020)
cell <- function(m, n) if (n == 0) "" else sprintf("%d / %d", m, n)
v_drik <- fest %>%
  group_by(event) %>%
  summarise(drik = cell(sum(drik_offset_days %in% 0), n()))
v_pkg <- pkg %>%
  group_by(event) %>%
  summarise(pkg_in = cell(sum(match[!late]), sum(!late)),
            pkg_out = cell(sum(match[late]), sum(late)))
val <- full_join(v_drik, v_pkg, by = "event") %>%
  mutate(across(everything(), ~ replace_na(.x, "")), event = labels[event]) %>%
  bind_rows(tibble(event = c("Sunrise tithi, random days", "Sunrise nakshatra, random days"),
                   drik = c(cell(sum(days$tithi_ok), nrow(days)),
                            cell(sum(days$nak_ok), nrow(days))),
                   pkg_in = "", pkg_out = ""))
tab_val <- c(
  "\\begin{tabular}{lccc}", "\\toprule",
  " & Drik Panchang & \\multicolumn{2}{c}{\\texttt{holidays} package} \\\\",
  " & 2006--2019 & 2006--2019 & 2020--2025 \\\\", "\\midrule",
  sprintf("%s & %s & %s & %s \\\\", val$event, val$drik, val$pkg_in, val$pkg_out),
  "\\bottomrule", "\\end{tabular}"
)
save_tex_table(tab_val, "tab_validation.tex")
pkg_miss <- filter(pkg, !match)

write_numbers(c(
  NRegistered = fmt_int(sum(panel$n_all)),
  NDomestic = fmt_int(sum(panel$n_dom)),
  NForeign = fmt_int(sum(panel$n_foreign)),
  NGovt = fmt_int(sum(panel$n_govt)),
  NRocDays = fmt_int(nrow(prim)),
  NRocDaysClosed = fmt_int(sum(prim$closed)),
  MeanPerRocDay = sprintf("%.1f", mean(prim$n_dom[!prim$closed])),
  ValFestIn = sum(fest$drik_offset_days %in% 0), ValFestInN = nrow(fest),
  ValPkgOut = sum(pkg$match[pkg$late]), ValPkgOutN = sum(pkg$late),
  ValPkgIn = sum(pkg$match[!pkg$late]), ValPkgInN = sum(!pkg$late)
), "numbers_describe.tex")
