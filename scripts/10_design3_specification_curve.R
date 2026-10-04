# 10_design3_specification_curve.R
# Specification curve across 90 combinations (Design 3)

source("scripts/00_setup.R")

message("Loading daily panel...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

# Define specification dimensions
shubh_vars <- c("shubh_strict", "shubh_loose", "tithi_ausp", "nak_ausp", "score_muhurat")
control_sets <- list(
  minimal = "| weekday + month",
  standard = "| weekday + month + year",
  full = "| weekday + month + year + is_fiscal_yearend + is_demonetization + is_gst_rollout + is_covid"
)
outcomes <- c("n_inc", "n_Private")
samples <- list(
  full = daily,
  pre_covid = daily %>% filter(is_pre_covid),
  post_demonetization = daily %>% filter(is_post_demonetization)
)

# Generate all specifications
specs <- expand_grid(
  shubh_var = shubh_vars,
  control_name = names(control_sets),
  outcome = outcomes,
  sample_name = names(samples)
)

message("Running ", nrow(specs), " specifications...")

run_spec <- function(shubh_var, control_name, outcome, sample_name) {
  data <- samples[[sample_name]]
  controls <- control_sets[[control_name]]

  formula_str <- paste0(outcome, " ~ ", shubh_var, " ", controls)
  formula <- as.formula(formula_str)

  tryCatch({
    m <- feols(formula, data = data, vcov = "HC1")
    tidy_m <- tidy_fixest(m) %>%
      filter(term == shubh_var)

    tibble(
      shubh_var = shubh_var,
      control_name = control_name,
      outcome = outcome,
      sample_name = sample_name,
      estimate = tidy_m$estimate,
      std.error = tidy_m$std.error,
      conf.low = tidy_m$conf.low,
      conf.high = tidy_m$conf.high,
      p.value = tidy_m$p.value,
      n = nobs(m)
    )
  }, error = function(e) {
    tibble(
      shubh_var = shubh_var,
      control_name = control_name,
      outcome = outcome,
      sample_name = sample_name,
      estimate = NA_real_,
      std.error = NA_real_,
      conf.low = NA_real_,
      conf.high = NA_real_,
      p.value = NA_real_,
      n = NA_integer_
    )
  })
}

spec_results <- pmap_dfr(specs, run_spec)

# Remove failed specifications
spec_results <- spec_results %>%
  filter(!is.na(estimate))

message("Successfully ran ", nrow(spec_results), " specifications")

# Summary statistics
spec_summary <- spec_results %>%
  summarise(
    `N Specifications` = n(),
    `Mean Coefficient` = mean(estimate),
    `Median Coefficient` = median(estimate),
    `SD Coefficient` = sd(estimate),
    `Min Coefficient` = min(estimate),
    `Max Coefficient` = max(estimate),
    `Prop. Positive` = mean(estimate > 0),
    `Prop. Significant (p<0.05)` = mean(p.value < 0.05),
    `Prop. Positive & Significant` = mean(estimate > 0 & p.value < 0.05)
  ) %>%
  pivot_longer(everything(), names_to = "Statistic", values_to = "Value") %>%
  mutate(Value = round(Value, 3))

# Table 13: Specification curve summary
tab13 <- knitr::kable(spec_summary, format = "latex", booktabs = TRUE,
                      caption = "Specification Curve Summary",
                      label = "tab:spec_curve") %>%
  kableExtra::kable_styling(latex_options = "hold_position")

save_tex_table(tab13, "tab13_spec_curve_summary.tex")

# Figure 9: Specification curve
# Sort by coefficient magnitude
spec_results <- spec_results %>%
  arrange(estimate) %>%
  mutate(spec_id = row_number())

# Panel A: Coefficient plot
fig9a <- ggplot(spec_results, aes(x = spec_id, y = estimate)) +
  geom_point(aes(color = p.value < 0.05), size = 1) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high, color = p.value < 0.05),
                width = 0, alpha = 0.3) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  scale_color_manual(values = c("FALSE" = COL_NEUTRAL, "TRUE" = COL_AUSP),
                     labels = c("p >= 0.05", "p < 0.05")) +
  labs(
    x = "Specification (sorted by coefficient)",
    y = "Coefficient",
    color = "Significance"
  ) +
  theme(legend.position = "top")

# Panel B: Specification choices
spec_choices <- spec_results %>%
  select(spec_id, shubh_var, control_name, outcome, sample_name) %>%
  pivot_longer(-spec_id, names_to = "dimension", values_to = "choice")

fig9b <- ggplot(spec_choices, aes(x = spec_id, y = choice, color = dimension)) +
  geom_point(size = 0.5) +
  facet_wrap(~dimension, scales = "free_y", ncol = 1) +
  labs(x = "Specification (sorted by coefficient)", y = "") +
  theme(legend.position = "none",
        axis.text.y = element_text(size = 7))

fig9 <- cowplot::plot_grid(
  fig9a, fig9b,
  ncol = 1,
  rel_heights = c(2, 1.5),
  labels = c("A", "B")
)

save_fig(fig9, "fig09_spec_curve.pdf", width = 12, height = 10)

# Save specification results
write_parquet(spec_results, file.path(PATH_DATA, "spec_curve_results.parquet"))

message("Script 10 complete")
