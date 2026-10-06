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
# Each registrar-weekday's count relative to its weekly median (national after the CRC), for
# registrars large enough that a shut-down is distinguishable from a slow day.
type_cols <- c("ordinary day" = "gray75", "holiday, closed" = COL_MAIN,
               "holiday, open" = "#E3A87E", "national shut-down" = "gray40",
               "unexplained shut-down" = "black")
rel <- panel %>%
  filter(weekday <= 5, detectable) %>%
  mutate(ratio = if_else(post_crc, nat_rel, n_all / pmax(roc_med, 1)),
         closure_type = factor(closure_type, names(type_cols))) %>%
  distinct(date, roc = if_else(post_crc, "CRC", roc), .keep_all = TRUE)

fig2 <- ggplot(rel, aes(pmin(ratio, 2), fill = closure_type)) +
  geom_histogram(binwidth = 0.05, boundary = 0) +
  geom_vline(xintercept = 0.1, linetype = "dashed") +
  scale_fill_manual(values = type_cols, drop = FALSE) +
  scale_y_sqrt() +
  labs(x = "Registrations relative to the weekly median (capped at 2)",
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
# Festival dates in the data are the almanac's; the table shows how often the classical rules
# in 00_generate_panchang.py reproduce them, and how the computed daily values compare.
labels <- c(
  gudi_padwa = "Gudi Padwa / Ugadi", akshaya_tritiya = "Akshaya Tritiya",
  vijayadashami = "Vijayadashami", dhanteras = "Dhanteras", diwali = "Lakshmi Puja (Diwali)",
  pitru_paksha_first = "Pitru Paksha, first day", pitru_paksha_last = "Pitru Paksha, last day",
  navratri_first = "Navratri, first day", navratri_last = "Navratri, last day"
)
fest <- read_csv(file.path(PATH_DATA, "festivals_drik.csv"), show_col_types = FALSE) %>%
  mutate(in_sample = year >= year(OFFICIAL_CALENDAR_START) & year <= year(SAMPLE_END))
days <- read_csv(file.path(PATH_DATA, "validation_days.csv"), show_col_types = FALSE)
cell <- function(m, n) sprintf("%d / %d", m, n)
v_fest <- fest %>%
  group_by(event) %>%
  summarise(
    sample = cell(sum((rule_date == drik_date)[in_sample]), sum(in_sample)),
    all = cell(sum(rule_date == drik_date), n())
  ) %>%
  mutate(event = factor(labels[event], labels)) %>%
  arrange(event)
tab_val <- c(
  "\\begin{tabular}{lcc}", "\\toprule",
  " & 2007--2020 & 2005--2021 \\\\", "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Festival dates: classical rules reproduce the almanac}} \\\\",
  sprintf("\\quad %s & %s & %s \\\\", v_fest$event, v_fest$sample, v_fest$all),
  "\\multicolumn{3}{l}{\\textit{Daily values at sunrise, random days}} \\\\",
  sprintf("\\quad Tithi & %s & %s \\\\",
          with(filter(days, between(year(date), 2007, 2020)), cell(sum(tithi_ok), length(tithi_ok))),
          cell(sum(days$tithi_ok), nrow(days))),
  sprintf("\\quad Nakshatra & %s & %s \\\\",
          with(filter(days, between(year(date), 2007, 2020)), cell(sum(nak_ok), length(nak_ok))),
          cell(sum(days$nak_ok), nrow(days))),
  "\\bottomrule", "\\end{tabular}"
)
save_tex_table(tab_val, "tab_validation.tex")

write_numbers(c(
  NRegistered = fmt_int(sum(panel$n_all)),
  NDomestic = fmt_int(sum(panel$n_dom)),
  NForeign = fmt_int(sum(panel$n_foreign)),
  NGovt = fmt_int(sum(panel$n_govt)),
  NRocDays = fmt_int(nrow(prim)),
  NRocDaysClosed = fmt_int(sum(prim$closed)),
  MeanPerRocDay = sprintf("%.1f", mean(prim$n_dom[!prim$closed])),
  RuleAgree = sum(fest$rule_date == fest$drik_date), RuleAgreeN = nrow(fest),
  NValDays = nrow(days), ValTithi = sum(days$tithi_ok), ValNak = sum(days$nak_ok)
), "numbers_describe.tex")
