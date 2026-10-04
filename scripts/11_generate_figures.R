# 11_generate_figures.R
# Generate all publication-quality figures

source("scripts/00_setup.R")

message("Loading data...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Figure 1: Panchang Taxonomy (5-panel figure)
# Panel A: By Tithi
tithi_agg <- daily %>%
  group_by(tithi_name, tithi_num, tithi_ausp, tithi_inausp) %>%
  summarise(mean_inc = mean(n_inc), .groups = "drop") %>%
  mutate(
    status = case_when(
      tithi_ausp == 1 ~ "Auspicious",
      tithi_inausp == 1 ~ "Inauspicious",
      TRUE ~ "Neutral"
    ),
    tithi_name = fct_reorder(tithi_name, tithi_num)
  )

p_tithi <- ggplot(tithi_agg, aes(x = tithi_name, y = mean_inc, fill = status)) +
  geom_col() +
  scale_fill_manual(values = c("Auspicious" = COL_AUSP, "Inauspicious" = COL_INAUSP, "Neutral" = COL_NEUTRAL)) +
  labs(title = "A. By Tithi (Lunar Day)", x = NULL, y = "Mean Daily Inc.") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7), legend.position = "none")

# Panel B: By Nakshatra
nak_agg <- daily %>%
  group_by(nakshatra_name, nakshatra_num, nak_ausp, nak_inausp) %>%
  summarise(mean_inc = mean(n_inc), .groups = "drop") %>%
  mutate(
    status = case_when(
      nak_ausp == 1 ~ "Auspicious",
      nak_inausp == 1 ~ "Inauspicious",
      TRUE ~ "Neutral"
    ),
    nakshatra_name = fct_reorder(nakshatra_name, nakshatra_num)
  )

p_nak <- ggplot(nak_agg, aes(x = nakshatra_name, y = mean_inc, fill = status)) +
  geom_col() +
  scale_fill_manual(values = c("Auspicious" = COL_AUSP, "Inauspicious" = COL_INAUSP, "Neutral" = COL_NEUTRAL)) +
  labs(title = "B. By Nakshatra (Lunar Mansion)", x = NULL, y = "Mean Daily Inc.") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 6), legend.position = "none")

# Panel C: By Yoga
yoga_agg <- daily %>%
  group_by(yoga_name, yoga_num, yoga_ausp, yoga_inausp) %>%
  summarise(mean_inc = mean(n_inc), .groups = "drop") %>%
  mutate(
    status = case_when(
      yoga_ausp == 1 ~ "Auspicious",
      yoga_inausp == 1 ~ "Inauspicious",
      TRUE ~ "Neutral"
    ),
    yoga_name = fct_reorder(yoga_name, yoga_num)
  )

p_yoga <- ggplot(yoga_agg, aes(x = yoga_name, y = mean_inc, fill = status)) +
  geom_col() +
  scale_fill_manual(values = c("Auspicious" = COL_AUSP, "Inauspicious" = COL_INAUSP, "Neutral" = COL_NEUTRAL)) +
  labs(title = "C. By Yoga", x = NULL, y = "Mean Daily Inc.") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 6), legend.position = "none")

# Panel D: By Vishti Karana
vishti_agg <- daily %>%
  group_by(is_vishti) %>%
  summarise(mean_inc = mean(n_inc), se = sd(n_inc) / sqrt(n()), .groups = "drop") %>%
  mutate(
    status = if_else(is_vishti == 1, "Vishti (Inauspicious)", "Non-Vishti"),
    x_label = if_else(is_vishti == 1, "Vishti", "Non-Vishti")
  )

p_vishti <- ggplot(vishti_agg, aes(x = x_label, y = mean_inc, fill = status)) +
  geom_col() +
  geom_errorbar(aes(ymin = mean_inc - 1.96 * se, ymax = mean_inc + 1.96 * se), width = 0.2) +
  scale_fill_manual(values = c("Vishti (Inauspicious)" = COL_INAUSP, "Non-Vishti" = COL_NEUTRAL)) +
  labs(title = "D. By Vishti Karana", x = NULL, y = "Mean Daily Inc.") +
  theme(legend.position = "none")

# Panel E: By Muhurat Score
score_agg <- daily %>%
  mutate(score_bin = cut(score_muhurat, breaks = seq(-1, 1, by = 0.25), include.lowest = TRUE)) %>%
  group_by(score_bin) %>%
  summarise(mean_inc = mean(n_inc), se = sd(n_inc) / sqrt(n()), score_mid = mean(score_muhurat), .groups = "drop") %>%
  filter(!is.na(score_bin))

p_score <- ggplot(score_agg, aes(x = score_mid, y = mean_inc)) +
  geom_point(aes(color = score_mid), size = 3) +
  geom_errorbar(aes(ymin = mean_inc - 1.96 * se, ymax = mean_inc + 1.96 * se, color = score_mid), width = 0.05) +
  geom_smooth(method = "lm", se = TRUE, color = "black", fill = "gray80") +
  scale_color_gradient2(low = COL_INAUSP, mid = COL_NEUTRAL, high = COL_AUSP, midpoint = 0) +
  labs(title = "E. By Muhurat Score", x = "Score (Higher = More Auspicious)", y = "Mean Daily Inc.") +
  theme(legend.position = "none")

# Combine panels
fig_taxonomy <- cowplot::plot_grid(
  p_tithi, p_nak, p_yoga,
  cowplot::plot_grid(p_vishti, p_score, ncol = 2),
  ncol = 1,
  rel_heights = c(1, 1, 1, 0.8)
)

save_fig(fig_taxonomy, "fig_panchang_taxonomy.pdf", width = 14, height = 16)

# Figure: Time series with macro events (enhanced version)
monthly <- daily %>%
  mutate(month_year = floor_date(date, "month")) %>%
  group_by(month_year) %>%
  summarise(
    n_inc = sum(n_inc),
    mean_shubh = mean(shubh_strict),
    .groups = "drop"
  )

fig_ts <- ggplot(monthly, aes(x = month_year, y = n_inc)) +
  geom_rect(aes(xmin = as.Date("2016-11-01"), xmax = as.Date("2017-01-01"),
                ymin = -Inf, ymax = Inf), fill = "red", alpha = 0.1) +
  geom_rect(aes(xmin = as.Date("2017-07-01"), xmax = as.Date("2017-08-01"),
                ymin = -Inf, ymax = Inf), fill = "blue", alpha = 0.1) +
  geom_rect(aes(xmin = as.Date("2020-03-01"), xmax = as.Date("2020-06-01"),
                ymin = -Inf, ymax = Inf), fill = "purple", alpha = 0.1) +
  geom_line(linewidth = 0.8) +
  annotate("text", x = as.Date("2016-11-15"), y = max(monthly$n_inc) * 0.9,
           label = "Demonetization", size = 3, hjust = 0) +
  annotate("text", x = as.Date("2017-07-15"), y = max(monthly$n_inc) * 0.85,
           label = "GST", size = 3, hjust = 0) +
  annotate("text", x = as.Date("2020-04-15"), y = max(monthly$n_inc) * 0.9,
           label = "COVID", size = 3, hjust = 0) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Monthly Company Incorporations in India (2010-2023)",
    x = "Date",
    y = "Number of Incorporations"
  )

save_fig(fig_ts, "fig_time_series_enhanced.pdf", width = 12, height = 5)

# Figure: Coefficient forest plot (main results)
m1 <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m2 <- feols(n_inc ~ shubh_loose | weekday + month + year, data = daily, vcov = "HC1")
m3 <- feols(n_inc ~ tithi_ausp | weekday + month + year, data = daily, vcov = "HC1")
m4 <- feols(n_inc ~ nak_ausp | weekday + month + year, data = daily, vcov = "HC1")
m5 <- feols(n_inc ~ score_muhurat | weekday + month + year, data = daily, vcov = "HC1")

forest_data <- bind_rows(
  tidy_fixest(m1) %>% filter(term == "shubh_strict") %>% mutate(measure = "Shubh (Strict)"),
  tidy_fixest(m2) %>% filter(term == "shubh_loose") %>% mutate(measure = "Shubh (Loose)"),
  tidy_fixest(m3) %>% filter(term == "tithi_ausp") %>% mutate(measure = "Tithi Auspicious"),
  tidy_fixest(m4) %>% filter(term == "nak_ausp") %>% mutate(measure = "Nakshatra Auspicious"),
  tidy_fixest(m5) %>% filter(term == "score_muhurat") %>% mutate(measure = "Muhurat Score")
) %>%
  mutate(measure = fct_reorder(measure, estimate))

fig_forest <- ggplot(forest_data, aes(x = measure, y = estimate)) +
  geom_point(size = 4, color = COL_AUSP) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.2, color = COL_AUSP) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  coord_flip() +
  labs(
    title = "Effect of Auspiciousness Measures on Daily Incorporations",
    subtitle = "All models include weekday, month, and year fixed effects with HC1 SEs",
    x = NULL,
    y = "Coefficient (95% CI)"
  )

save_fig(fig_forest, "fig_forest_plot.pdf", width = 8, height = 5)

message("Script 11 complete")
