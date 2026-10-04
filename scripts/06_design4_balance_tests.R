# 06_design4_balance_tests.R
# Test randomness of panchang conditional on controls (Design 4)

source("scripts/00_setup.R")

message("Loading daily panel...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Balance regressions: expect null effects
# These test whether panchang variables are "as good as random" conditional on controls

# Model 1: Fiscal year end ~ shubh_strict
m1_fiscal <- feols(is_fiscal_yearend ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Model 2: Gregorian holiday ~ shubh_strict
m2_holiday <- feols(is_gregorian_holiday ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Model 3: Demonetization period ~ shubh_strict
m3_demon <- feols(is_demonetization ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Model 4: GST rollout ~ shubh_strict
m4_gst <- feols(is_gst_rollout ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Model 5: Diwali season ~ shubh_strict (this SHOULD correlate - it's a sanity check)
m5_diwali <- feols(is_diwali_season ~ shubh_strict | weekday + year, data = daily, vcov = "HC1")

# Month balance: regress shubh_strict on month dummies
m6_month_joint <- feols(shubh_strict ~ factor(month) | weekday + year, data = daily, vcov = "HC1")

# Weekday balance
m7_weekday_joint <- feols(shubh_strict ~ weekday | month + year, data = daily, vcov = "HC1")

# Table 7: Balance tests
tab7 <- modelsummary(
  list(
    "Fiscal YE" = m1_fiscal,
    "Holiday" = m2_holiday,
    "Demon." = m3_demon,
    "GST" = m4_gst,
    "Diwali" = m5_diwali
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Balance Tests: Panchang Auspiciousness and Secular Events",
  notes = "Expect null coefficients except for Diwali (Hindu festival)."
)
save_tex_table(tab7, "tab07_balance_tests.tex")

# Figure 5: Balance coefficients
balance_coefs <- bind_rows(
  tidy_fixest(m1_fiscal) %>% mutate(outcome = "Fiscal Year End"),
  tidy_fixest(m2_holiday) %>% mutate(outcome = "Gregorian Holiday"),
  tidy_fixest(m3_demon) %>% mutate(outcome = "Demonetization"),
  tidy_fixest(m4_gst) %>% mutate(outcome = "GST Rollout"),
  tidy_fixest(m5_diwali) %>% mutate(outcome = "Diwali Season")
) %>%
  filter(term == "shubh_strict")

fig5 <- ggplot(balance_coefs, aes(x = outcome, y = estimate)) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  coord_flip() +
  labs(
    title = "Balance Tests: Effect of Shubh Strict on Secular Variables",
    subtitle = "Expect null effects except Diwali (which is a Hindu festival)",
    x = "Outcome Variable",
    y = "Coefficient on Shubh Strict (95% CI)"
  )

save_fig(fig5, "fig05_balance_coefs.pdf", width = 8, height = 5)

# Joint F-test for month and weekday balance
message("Month balance F-test (H0: panchang is balanced across months):")
print(summary(m6_month_joint))

message("Weekday balance F-test (H0: panchang is balanced across weekdays):")
print(summary(m7_weekday_joint))

message("Script 06 complete")
