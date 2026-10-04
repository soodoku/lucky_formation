# 07_design5_heterogeneity.R
# Test heterogeneity across subgroups (Design 5)

source("scripts/00_setup.R")

message("Loading daily panel...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Heterogeneity by firm size
m1_small <- feols(n_small ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m2_large <- feols(n_large ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Table 8: Heterogeneity by size
tab8 <- modelsummary(
  list(
    "Small Firms" = m1_small,
    "Large Firms" = m2_large
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Heterogeneity by Firm Size"
)
save_tex_table(tab8, "tab08_heterogeneity_size.tex")

# Heterogeneity by geography
m3_hindu <- feols(n_hindu_belt ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m4_cosmo <- feols(n_cosmopolitan ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m5_other <- feols(n_other ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Table 9: Heterogeneity by geography
tab9 <- modelsummary(
  list(
    "Hindu Belt" = m3_hindu,
    "Cosmopolitan" = m4_cosmo,
    "Other States" = m5_other
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Heterogeneity by Geography",
  notes = "Hindu Belt: UP, MP, Gujarat, Rajasthan, Bihar, etc. Cosmopolitan: Maharashtra, Karnataka, Delhi, TN, Telangana."
)
save_tex_table(tab9, "tab09_heterogeneity_geography.tex")

# Heterogeneity by company type (only available types)
m6_private <- feols(n_Private ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m7_public <- feols(n_Public ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
m8_opc <- feols(n_OPC ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")

# Table 10: Heterogeneity by company type
tab10 <- modelsummary(
  list(
    "Private Ltd" = m6_private,
    "Public Ltd" = m7_public,
    "OPC" = m8_opc
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Heterogeneity by Company Type"
)
save_tex_table(tab10, "tab10_heterogeneity_company_type.tex")

# Heterogeneity by Diwali season
m9_diwali <- feols(n_inc ~ shubh_strict | weekday + month + year,
                    data = daily %>% filter(is_diwali_season), vcov = "HC1")
m10_nondiwali <- feols(n_inc ~ shubh_strict | weekday + month + year,
                       data = daily %>% filter(!is_diwali_season), vcov = "HC1")

# Heterogeneity by year
yearly_coefs <- daily %>%
  group_by(year) %>%
  group_modify(~ {
    m <- feols(n_inc ~ shubh_strict | weekday + month, data = .x, vcov = "HC1")
    tidy_fixest(m) %>% filter(term == "shubh_strict")
  })

# Figure 6: Heterogeneity coefficients
het_coefs <- bind_rows(
  tidy_fixest(m1_small) %>% filter(term == "shubh_strict") %>% mutate(group = "Small Firms", category = "Size"),
  tidy_fixest(m2_large) %>% filter(term == "shubh_strict") %>% mutate(group = "Large Firms", category = "Size"),
  tidy_fixest(m3_hindu) %>% filter(term == "shubh_strict") %>% mutate(group = "Hindu Belt", category = "Geography"),
  tidy_fixest(m4_cosmo) %>% filter(term == "shubh_strict") %>% mutate(group = "Cosmopolitan", category = "Geography"),
  tidy_fixest(m6_private) %>% filter(term == "shubh_strict") %>% mutate(group = "Private Ltd", category = "Company Type"),
  tidy_fixest(m7_public) %>% filter(term == "shubh_strict") %>% mutate(group = "Public Ltd", category = "Company Type"),
  tidy_fixest(m8_opc) %>% filter(term == "shubh_strict") %>% mutate(group = "OPC", category = "Company Type"),
  tidy_fixest(m9_diwali) %>% filter(term == "shubh_strict") %>% mutate(group = "Diwali Season", category = "Temporal"),
  tidy_fixest(m10_nondiwali) %>% filter(term == "shubh_strict") %>% mutate(group = "Non-Diwali", category = "Temporal")
)

fig6 <- ggplot(het_coefs, aes(x = group, y = estimate, color = category)) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  facet_wrap(~category, scales = "free_x") +
  labs(
    title = "Heterogeneity in Effect of Auspiciousness",
    x = "Subgroup",
    y = "Coefficient on Shubh Strict (95% CI)",
    color = "Category"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "none")

save_fig(fig6, "fig06_heterogeneity_coefs.pdf", width = 12, height = 6)

# Yearly trend figure
fig6b <- ggplot(yearly_coefs, aes(x = year, y = estimate)) +
  geom_point(size = 3, color = COL_AUSP) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.3, color = COL_AUSP) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_smooth(method = "lm", se = FALSE, color = COL_NEUTRAL, linetype = "dotted") +
  scale_x_continuous(breaks = 2010:2020) +
  labs(
    title = "Effect of Auspiciousness by Year",
    x = "Year",
    y = "Coefficient on Shubh Strict (95% CI)"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

save_fig(fig6b, "fig06b_yearly_trend.pdf", width = 10, height = 5)

message("Script 07 complete")
