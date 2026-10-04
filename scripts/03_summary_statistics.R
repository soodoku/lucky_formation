# 03_summary_statistics.R
# Generate summary tables and exploratory figures

source("scripts/00_setup.R")

message("Loading daily panel...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Table 1: Panchang variable summary
panchang_summary <- daily %>%
  summarise(
    `Auspicious Tithi (%)` = mean(tithi_ausp) * 100,
    `Inauspicious Tithi (%)` = mean(tithi_inausp) * 100,
    `Neutral Tithi (%)` = mean(1 - tithi_ausp - tithi_inausp) * 100,
    `Auspicious Nakshatra (%)` = mean(nak_ausp) * 100,
    `Inauspicious Nakshatra (%)` = mean(nak_inausp) * 100,
    `Auspicious Yoga (%)` = mean(yoga_ausp) * 100,
    `Inauspicious Yoga (%)` = mean(yoga_inausp) * 100,
    `Vishti Karana (%)` = mean(is_vishti) * 100,
    `Shubh Strict (%)` = mean(shubh_strict) * 100,
    `Shubh Loose (%)` = mean(shubh_loose) * 100,
    `Ashubh (%)` = mean(ashubh) * 100,
    `Mean Muhurat Score` = mean(score_muhurat),
    `SD Muhurat Score` = sd(score_muhurat)
  ) %>%
  pivot_longer(everything(), names_to = "Variable", values_to = "Value") %>%
  mutate(Value = round(Value, 2))

tab1 <- knitr::kable(panchang_summary, format = "latex", booktabs = TRUE,
                     caption = "Summary of Panchang Variables",
                     label = "tab:panchang_summary") %>%
  kableExtra::kable_styling(latex_options = "hold_position")

save_tex_table(tab1, "tab01_panchang_summary.tex")

# Table 2: Company incorporation summary
company_summary <- daily %>%
  summarise(
    `Total Days` = n(),
    `Mean Daily Incorporations` = mean(n_inc),
    `SD Daily Incorporations` = sd(n_inc),
    `Min Daily Incorporations` = min(n_inc),
    `Max Daily Incorporations` = max(n_inc),
    `Total Incorporations` = sum(n_inc),
    `Mean Private Ltd` = if ("n_Private" %in% names(daily)) mean(n_Private, na.rm = TRUE) else NA_real_,
    `Mean Public Ltd` = if ("n_Public" %in% names(daily)) mean(n_Public, na.rm = TRUE) else NA_real_,
    `Mean OPC` = if ("n_OPC" %in% names(daily)) mean(n_OPC, na.rm = TRUE) else NA_real_
  ) %>%
  pivot_longer(everything(), names_to = "Statistic", values_to = "Value") %>%
  filter(!is.na(Value)) %>%
  mutate(Value = ifelse(Value > 100, format(round(Value), big.mark = ","), round(Value, 2)))

tab2 <- knitr::kable(company_summary, format = "latex", booktabs = TRUE,
                     caption = "Summary Statistics: Daily Company Incorporations",
                     label = "tab:company_summary") %>%
  kableExtra::kable_styling(latex_options = "hold_position")

save_tex_table(tab2, "tab02_company_summary.tex")

# Figure 1: Time series of daily incorporations
fig1 <- daily %>%
  mutate(month_year = floor_date(date, "month")) %>%
  group_by(month_year) %>%
  summarise(n_inc = sum(n_inc)) %>%
  ggplot(aes(x = month_year, y = n_inc)) +
  geom_line(color = COL_NEUTRAL) +
  geom_vline(xintercept = as.Date("2016-11-08"), linetype = "dashed", color = "red", alpha = 0.7) +
  geom_vline(xintercept = as.Date("2017-07-01"), linetype = "dashed", color = "blue", alpha = 0.7) +
  geom_vline(xintercept = as.Date("2020-03-25"), linetype = "dashed", color = "purple", alpha = 0.7) +
  annotate("text", x = as.Date("2016-11-08"), y = max(daily %>% group_by(floor_date(date, "month")) %>%
    summarise(n = sum(n_inc)) %>% pull(n)) * 0.95, label = "Demonetization", angle = 90, vjust = -0.5, size = 3) +
  annotate("text", x = as.Date("2017-07-01"), y = max(daily %>% group_by(floor_date(date, "month")) %>%
    summarise(n = sum(n_inc)) %>% pull(n)) * 0.85, label = "GST", angle = 90, vjust = -0.5, size = 3) +
  annotate("text", x = as.Date("2020-03-25"), y = max(daily %>% group_by(floor_date(date, "month")) %>%
    summarise(n = sum(n_inc)) %>% pull(n)) * 0.95, label = "COVID", angle = 90, vjust = -0.5, size = 3) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Monthly Company Incorporations in India (2010-2023)",
    x = "Date",
    y = "Number of Incorporations"
  )

save_fig(fig1, "fig01_time_series.pdf", width = 10, height = 6)

# Figure 2: Distribution by tithi
tithi_summary <- daily %>%
  group_by(tithi_name) %>%
  summarise(
    mean_inc = mean(n_inc),
    se_inc = sd(n_inc) / sqrt(n()),
    tithi_num = first(tithi_num),
    tithi_ausp = first(tithi_ausp),
    tithi_inausp = first(tithi_inausp)
  ) %>%
  mutate(
    ausp_status = case_when(
      tithi_ausp == 1 ~ "Auspicious",
      tithi_inausp == 1 ~ "Inauspicious",
      TRUE ~ "Neutral"
    ),
    tithi_name = fct_reorder(tithi_name, tithi_num)
  )

fig2 <- ggplot(tithi_summary, aes(x = tithi_name, y = mean_inc, fill = ausp_status)) +
  geom_col() +
  geom_errorbar(aes(ymin = mean_inc - 1.96 * se_inc, ymax = mean_inc + 1.96 * se_inc), width = 0.2) +
  scale_fill_manual(values = c("Auspicious" = COL_AUSP, "Inauspicious" = COL_INAUSP, "Neutral" = COL_NEUTRAL)) +
  labs(
    title = "Mean Daily Incorporations by Tithi",
    x = "Tithi",
    y = "Mean Daily Incorporations",
    fill = "Auspiciousness"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

save_fig(fig2, "fig02_distribution_by_tithi.pdf", width = 12, height = 6)

message("Script 03 complete")
