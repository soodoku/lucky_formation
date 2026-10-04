# 08_design3_temporal_placebos.R
# Temporal placebo tests (Design 3)

source("scripts/00_setup.R")

message("Loading daily panel...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Model 1: Contemporaneous only (baseline)
m1_contemp <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Model 2: Lead placebos (future auspiciousness should NOT predict today's incorporations)
m2_leads <- feols(
  n_inc ~ shubh_strict + shubh_strict_lead1 + shubh_strict_lead2 + shubh_strict_lead3 |
          weekday + month + year,
  data = daily, vcov = "HC1"
)

# Model 3: Lag placebos (past auspiciousness should NOT predict today's incorporations)
m3_lags <- feols(
  n_inc ~ shubh_strict + shubh_strict_lag1 + shubh_strict_lag2 + shubh_strict_lag3 |
          weekday + month + year,
  data = daily, vcov = "HC1"
)

# Model 4: Full event study - all leads and lags
m4_event <- feols(
  n_inc ~ shubh_strict_lead3 + shubh_strict_lead2 + shubh_strict_lead1 +
          shubh_strict +
          shubh_strict_lag1 + shubh_strict_lag2 + shubh_strict_lag3 |
          weekday + month + year,
  data = daily, vcov = "HC1"
)

# Table 11: Temporal placebos
tab11 <- modelsummary(
  list(
    "Baseline" = m1_contemp,
    "With Leads" = m2_leads,
    "With Lags" = m3_lags,
    "Event Study" = m4_event
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Temporal Placebo Tests",
  notes = "Leads and lags should show null effects; contemporaneous should be significant."
)
save_tex_table(tab11, "tab11_temporal_placebos.tex")

# Figure 7: Event study plot
event_coefs <- tidy_fixest(m4_event) %>%
  mutate(
    time = case_when(
      term == "shubh_strict_lead3" ~ -3,
      term == "shubh_strict_lead2" ~ -2,
      term == "shubh_strict_lead1" ~ -1,
      term == "shubh_strict" ~ 0,
      term == "shubh_strict_lag1" ~ 1,
      term == "shubh_strict_lag2" ~ 2,
      term == "shubh_strict_lag3" ~ 3
    ),
    is_contemp = time == 0
  )

fig7 <- ggplot(event_coefs, aes(x = time, y = estimate)) +
  geom_point(aes(color = is_contemp), size = 4) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high, color = is_contemp), width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_vline(xintercept = -0.5, linetype = "dotted", alpha = 0.5) +
  scale_color_manual(values = c("FALSE" = COL_NEUTRAL, "TRUE" = COL_AUSP), guide = "none") +
  scale_x_continuous(breaks = -3:3, labels = c("t-3", "t-2", "t-1", "t", "t+1", "t+2", "t+3")) +
  labs(
    title = "Event Study: Effect of Auspiciousness on Incorporations",
    subtitle = "Only contemporaneous effect (t=0) should be significant",
    x = "Timing Relative to Auspicious Day",
    y = "Coefficient (95% CI)"
  )

save_fig(fig7, "fig07_event_study.pdf", width = 8, height = 5)

message("Script 08 complete")
