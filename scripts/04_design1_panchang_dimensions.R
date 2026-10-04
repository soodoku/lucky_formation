# 04_design1_panchang_dimensions.R
# Test each panchang dimension separately (Design 1)

source("scripts/00_setup.R")

message("Loading daily panel...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Model 1: Tithi only
m1_tithi <- feols(n_inc ~ tithi_ausp + tithi_inausp | weekday + month + year, data = daily, vcov = "HC1")

# Model 2: Nakshatra only
m2_nak <- feols(n_inc ~ nak_ausp + nak_inausp | weekday + month + year, data = daily, vcov = "HC1")

# Model 3: Yoga only
m3_yoga <- feols(n_inc ~ yoga_ausp + yoga_inausp | weekday + month + year, data = daily, vcov = "HC1")

# Model 4: Vishti karana
m4_vishti <- feols(n_inc ~ is_vishti | weekday + month + year, data = daily, vcov = "HC1")

# Model 5: Vara (weekday auspiciousness)
m5_vara <- feols(n_inc ~ vara_ausp + vara_inausp | month + year, data = daily, vcov = "HC1")

# Model 6: Combined - all dimensions
m6_combined <- feols(
  n_inc ~ tithi_ausp + tithi_inausp + nak_ausp + nak_inausp +
          yoga_ausp + yoga_inausp + is_vishti | weekday + month + year,
  data = daily, vcov = "HC1"
)

# Table 3: Tithi results
tab3 <- modelsummary(
  list("Tithi Only" = m1_tithi),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Effect of Tithi Auspiciousness on Daily Incorporations"
)
save_tex_table(tab3, "tab03_design1_tithi.tex")

# Table 4: Nakshatra results
tab4 <- modelsummary(
  list("Nakshatra Only" = m2_nak),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Effect of Nakshatra Auspiciousness on Daily Incorporations"
)
save_tex_table(tab4, "tab04_design1_nakshatra.tex")

# Table 5: Combined results
tab5 <- modelsummary(
  list(
    "Tithi" = m1_tithi,
    "Nakshatra" = m2_nak,
    "Yoga" = m3_yoga,
    "Vishti" = m4_vishti,
    "Combined" = m6_combined
  ),
  stars = c('*' = 0.1, '**' = 0.05, '***' = 0.01),
  gof_map = gm,
  output = "latex_tabular",
  title = "Effect of Panchang Dimensions on Daily Incorporations"
)
save_tex_table(tab5, "tab05_design1_combined.tex")

# Figure 3: Coefficient plot by dimension
coef_data <- bind_rows(
  tidy_fixest(m1_tithi) %>% mutate(model = "Tithi"),
  tidy_fixest(m2_nak) %>% mutate(model = "Nakshatra"),
  tidy_fixest(m3_yoga) %>% mutate(model = "Yoga"),
  tidy_fixest(m4_vishti) %>% mutate(model = "Vishti")
) %>%
  filter(!str_detect(term, "Intercept")) %>%
  mutate(
    ausp_type = case_when(
      str_detect(term, "_ausp") ~ "Auspicious",
      str_detect(term, "_inausp|vishti") ~ "Inauspicious",
      TRUE ~ "Other"
    )
  )

fig3 <- ggplot(coef_data, aes(x = term, y = estimate, color = ausp_type)) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_color_manual(values = c("Auspicious" = COL_AUSP, "Inauspicious" = COL_INAUSP)) +
  facet_wrap(~model, scales = "free_x") +
  labs(
    title = "Effect of Panchang Dimensions on Daily Incorporations",
    x = "Variable",
    y = "Coefficient (95% CI)",
    color = "Type"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

save_fig(fig3, "fig03_coef_by_dimension.pdf", width = 10, height = 6)

message("Script 04 complete")
