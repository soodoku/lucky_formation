# 05_design2_composite_scores.R
# Test composite auspiciousness measures (Design 2)

source("scripts/00_setup.R")

message("Loading daily panel...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Model 1: Shubh strict (strict definition of auspicious)
m1_strict <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Model 2: Shubh loose (loose definition of auspicious)
m2_loose <- feols(n_inc ~ shubh_loose | weekday + month + year, data = daily, vcov = "HC1")

# Model 3: Ashubh (inauspicious)
m3_ashubh <- feols(n_inc ~ ashubh | weekday + month + year, data = daily, vcov = "HC1")

# Model 4: Continuous muhurat score (dose-response)
m4_score <- feols(n_inc ~ score_muhurat | weekday + month + year, data = daily, vcov = "HC1")

# Model 5: Both strict and loose
m5_both <- feols(n_inc ~ shubh_strict + shubh_loose + ashubh | weekday + month + year, data = daily, vcov = "HC1")

# Model 6: Full specification with controls
m6_full <- feols(
  n_inc ~ shubh_strict + is_fiscal_yearend + is_demonetization + is_gst_rollout + is_covid |
          weekday + month + year,
  data = daily, vcov = "HC1"
)

# Table 6: Composite measures
tab6 <- modelsummary(
  list(
    "Shubh Strict" = m1_strict,
    "Shubh Loose" = m2_loose,
    "Ashubh" = m3_ashubh,
    "Score" = m4_score,
    "Combined" = m5_both,
    "Full Controls" = m6_full
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Effect of Composite Auspiciousness Measures on Daily Incorporations"
)
save_tex_table(tab6, "tab06_design2_composites.tex")

# Figure 4: Dose-response curve
# Bin the muhurat score and compute mean incorporations
score_bins <- daily %>%
  mutate(score_bin = cut(score_muhurat, breaks = seq(-1, 1, by = 0.2), include.lowest = TRUE)) %>%
  group_by(score_bin) %>%
  summarise(
    mean_inc = mean(n_inc),
    se_inc = sd(n_inc) / sqrt(n()),
    n = n(),
    score_mid = mean(score_muhurat)
  ) %>%
  filter(!is.na(score_bin))

fig4a <- ggplot(score_bins, aes(x = score_mid, y = mean_inc)) +
  geom_point(size = 3, color = COL_AUSP) +
  geom_errorbar(aes(ymin = mean_inc - 1.96 * se_inc, ymax = mean_inc + 1.96 * se_inc),
                width = 0.05, color = COL_AUSP) +
  geom_smooth(method = "lm", se = TRUE, color = COL_NEUTRAL, fill = "gray80") +
  labs(
    title = "Dose-Response: Muhurat Score and Daily Incorporations",
    x = "Muhurat Score (Higher = More Auspicious)",
    y = "Mean Daily Incorporations"
  )

# Residualized dose-response
# Filter to complete cases first
daily_complete <- daily %>%
  filter(!is.na(weekday), !is.na(month), !is.na(year), !is.na(n_inc), !is.na(score_muhurat))

m_resid_y <- feols(n_inc ~ 1 | weekday + month + year, data = daily_complete)
m_resid_x <- feols(score_muhurat ~ 1 | weekday + month + year, data = daily_complete)

daily_resid <- daily_complete %>%
  filter(row_number() %in% which(!is.na(fitted(m_resid_y)))) %>%
  mutate(
    n_inc_resid = resid(m_resid_y),
    score_resid = resid(m_resid_x)
  )

fig4b <- ggplot(daily_resid, aes(x = score_resid, y = n_inc_resid)) +
  geom_point(alpha = 0.1) +
  geom_smooth(method = "lm", se = TRUE, color = COL_AUSP, fill = "gray80") +
  labs(
    title = "Residualized Dose-Response",
    subtitle = "After partialling out weekday, month, and year FE",
    x = "Muhurat Score (Residualized)",
    y = "Daily Incorporations (Residualized)"
  )

fig4 <- cowplot::plot_grid(fig4a, fig4b, ncol = 2, labels = c("A", "B"))
save_fig(fig4, "fig04_dose_response.pdf", width = 12, height = 5)

message("Script 05 complete")
