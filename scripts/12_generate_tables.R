# 12_generate_tables.R
# Compile all LaTeX tables with consistent formatting

source("scripts/00_setup.R")

message("Loading data...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Table 1: Main results - Composite measures
m1 <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m2 <- feols(n_inc ~ shubh_loose | weekday + month + year, data = daily, vcov = "HC1")
m3 <- feols(n_inc ~ score_muhurat | weekday + month + year, data = daily, vcov = "HC1")
m4 <- feols(n_inc ~ shubh_strict + shubh_loose | weekday + month + year, data = daily, vcov = "HC1")
m5 <- feols(n_inc ~ shubh_strict + is_fiscal_yearend + is_demonetization + is_gst_rollout |
            weekday + month + year, data = daily, vcov = "HC1")

tab_main <- modelsummary(
  list(
    "(1)" = m1,
    "(2)" = m2,
    "(3)" = m3,
    "(4)" = m4,
    "(5)" = m5
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Effect of Auspiciousness on Daily Company Incorporations"
)
save_tex_table(tab_main, "tab_main_results.tex")

# Table 2: Individual panchang dimensions
m_tithi <- feols(n_inc ~ tithi_ausp + tithi_inausp | weekday + month + year, data = daily, vcov = "HC1")
m_nak <- feols(n_inc ~ nak_ausp + nak_inausp | weekday + month + year, data = daily, vcov = "HC1")
m_yoga <- feols(n_inc ~ yoga_ausp + yoga_inausp | weekday + month + year, data = daily, vcov = "HC1")
m_vishti <- feols(n_inc ~ is_vishti | weekday + month + year, data = daily, vcov = "HC1")
m_all <- feols(n_inc ~ tithi_ausp + tithi_inausp + nak_ausp + nak_inausp + yoga_ausp + yoga_inausp + is_vishti |
               weekday + month + year, data = daily, vcov = "HC1")

tab_dimensions <- modelsummary(
  list(
    "Tithi" = m_tithi,
    "Nakshatra" = m_nak,
    "Yoga" = m_yoga,
    "Vishti" = m_vishti,
    "All" = m_all
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Effect of Individual Panchang Dimensions on Daily Incorporations"
)
save_tex_table(tab_dimensions, "tab_panchang_dimensions.tex")

# Table 3: Heterogeneity - Geography
m_hindu <- feols(n_hindu_belt ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_cosmo <- feols(n_cosmopolitan ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_other <- feols(n_other ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

tab_geo <- modelsummary(
  list(
    "Hindu Belt" = m_hindu,
    "Cosmopolitan" = m_cosmo,
    "Other States" = m_other
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Heterogeneity by Geography"
)
save_tex_table(tab_geo, "tab_heterogeneity_geography.tex")

# Table 4: Heterogeneity - Company type
m_private <- feols(n_Private ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_public <- feols(n_Public ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_opc <- feols(n_OPC ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

tab_type <- modelsummary(
  list(
    "Private Ltd" = m_private,
    "Public Ltd" = m_public,
    "OPC" = m_opc
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Heterogeneity by Company Type"
)
save_tex_table(tab_type, "tab_heterogeneity_company_type.tex")

# Table 5: Heterogeneity - Size
m_small <- feols(n_small ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_large <- feols(n_large ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

tab_size <- modelsummary(
  list(
    "Small Firms" = m_small,
    "Large Firms" = m_large
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Heterogeneity by Firm Size"
)
save_tex_table(tab_size, "tab_heterogeneity_size.tex")

# Table 6: Temporal placebos
m_contemp <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_event <- feols(
  n_inc ~ shubh_strict_lead3 + shubh_strict_lead2 + shubh_strict_lead1 +
          shubh_strict +
          shubh_strict_lag1 + shubh_strict_lag2 + shubh_strict_lag3 |
          weekday + month + year,
  data = daily, vcov = "HC1"
)

tab_temporal <- modelsummary(
  list(
    "Baseline" = m_contemp,
    "Event Study" = m_event
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Temporal Placebo Tests"
)
save_tex_table(tab_temporal, "tab_temporal_placebos.tex")

# Table 7: Balance tests
m_fiscal <- feols(is_fiscal_yearend ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_holiday <- feols(is_gregorian_holiday ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_demon <- feols(is_demonetization ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_gst <- feols(is_gst_rollout ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_diwali <- feols(is_diwali_season ~ shubh_strict | weekday + year, data = daily, vcov = "HC1")

tab_balance <- modelsummary(
  list(
    "Fiscal YE" = m_fiscal,
    "Holiday" = m_holiday,
    "Demon." = m_demon,
    "GST" = m_gst,
    "Diwali" = m_diwali
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Balance Tests: Panchang and Secular Events"
)
save_tex_table(tab_balance, "tab_balance_tests.tex")

# Table 8: Robustness - Alternative SEs
m_hc1 <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_hc3 <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC3")
m_nw <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = NW ~ date)
m_cluster_month <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily,
                         vcov = ~year + month)

tab_robust <- modelsummary(
  list(
    "HC1" = m_hc1,
    "HC3" = m_hc3,
    "Newey-West" = m_nw,
    "Cluster (Year-Month)" = m_cluster_month
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Robustness: Alternative Standard Errors"
)
save_tex_table(tab_robust, "tab_robustness_se.tex")

# Table 9: Robustness - Alternative samples
m_full <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m_precovid <- feols(n_inc ~ shubh_strict | weekday + month + year,
                    data = daily %>% filter(is_pre_covid), vcov = "HC1")
m_postdemon <- feols(n_inc ~ shubh_strict | weekday + month + year,
                     data = daily %>% filter(is_post_demonetization), vcov = "HC1")
m_nodiwali <- feols(n_inc ~ shubh_strict | weekday + month + year,
                    data = daily %>% filter(!is_diwali_season), vcov = "HC1")

tab_samples <- modelsummary(
  list(
    "Full Sample" = m_full,
    "Pre-COVID" = m_precovid,
    "Post-Demon." = m_postdemon,
    "Excl. Diwali" = m_nodiwali
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Robustness: Alternative Samples"
)
save_tex_table(tab_samples, "tab_robustness_samples.tex")

message("Script 12 complete")
message("All tables saved to ", PATH_TABS)
