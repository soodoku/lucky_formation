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
val_table <- function(fest, days) {
  labels <- c(
    gudi_padwa = "Gudi Padwa / Ugadi", akshaya_tritiya = "Akshaya Tritiya",
    vijayadashami = "Vijayadashami", dhanteras = "Dhanteras", diwali = "Lakshmi Puja (Diwali)",
    pitru_paksha_first = "Pitru Paksha, first day", pitru_paksha_last = "Pitru Paksha, last day"
  )
  bind_rows(
    fest %>%
      group_by(event) %>%
      summarise(match = sum(drik_offset_days %in% 0), n = n()) %>%
      mutate(event = labels[event]),
    tibble(event = "Sunrise tithi, random days", match = sum(days$tithi_ok), n = nrow(days)),
    tibble(event = "Sunrise nakshatra, random days", match = sum(days$nak_ok), n = nrow(days))
  )
}
v_in <- val_table(read_csv(file.path(PATH_DATA, "validation_festivals.csv"),
                           show_col_types = FALSE),
                  read_csv(file.path(PATH_DATA, "validation_days.csv"), show_col_types = FALSE))
v_out <- val_table(read_csv(file.path(PATH_DATA, "validation_festivals_holdout.csv"),
                            show_col_types = FALSE),
                   read_csv(file.path(PATH_DATA, "validation_days_holdout.csv"),
                            show_col_types = FALSE))
val <- left_join(v_in, v_out, by = "event", suffix = c("_in", "_out"))
tab_val <- c(
  "\\begin{tabular}{lcc}", "\\toprule",
  " & 2006--2019 & 2020--2025 \\\\",
  " & (rules tuned) & (holdout) \\\\", "\\midrule",
  sprintf("%s & %d / %d & %d / %d \\\\", val$event, val$match_in, val$n_in,
          val$match_out, val$n_out),
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
  ValFestIn = sum(v_in$match[1:7]), ValFestInN = sum(v_in$n[1:7]),
  ValFestOut = sum(v_out$match[1:7]), ValFestOutN = sum(v_out$n[1:7])
), "numbers_describe.tex")
