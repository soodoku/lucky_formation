# 09_design3_randomization_inference.R
# Randomization inference for sharp null (Design 3)

source("scripts/00_setup.R")

message("Loading daily panel...")
daily <- read_parquet(file.path(PATH_DATA, "daily_panel.parquet"))

set.seed(42)

# Step 1: Estimate observed coefficient
m_obs <- feols(n_inc ~ shubh_strict | weekday + month + year, data = daily, vcov = "HC1")
coef_obs <- coef(m_obs)["shubh_strict"]

message("Observed coefficient: ", round(coef_obs, 4))

# Step 2: Permutation distribution
# Permute shubh_strict WITHIN weekday strata (to preserve weekday structure)
n_perms <- 1000

permute_within_weekday <- function(data) {
  data %>%
    group_by(weekday) %>%
    mutate(shubh_strict_perm = sample(shubh_strict)) %>%
    ungroup()
}

message("Running ", n_perms, " permutations (stratified by weekday)...")

perm_coefs <- numeric(n_perms)

for (i in seq_len(n_perms)) {
  if (i %% 100 == 0) message("Permutation ", i, "/", n_perms)

  daily_perm <- permute_within_weekday(daily)

  m_perm <- feols(n_inc ~ shubh_strict_perm | weekday + month + year, data = daily_perm, vcov = "HC1")
  perm_coefs[i] <- coef(m_perm)["shubh_strict_perm"]
}

# Step 3: Compute RI p-value
# Two-sided: proportion of permutation coefs with |coef| >= |observed|
ri_pval_twosided <- mean(abs(perm_coefs) >= abs(coef_obs))

# One-sided (positive): proportion of permutation coefs >= observed
ri_pval_onesided <- mean(perm_coefs >= coef_obs)

message("RI p-value (two-sided): ", round(ri_pval_twosided, 4))
message("RI p-value (one-sided): ", round(ri_pval_onesided, 4))

# Table 12: RI summary
ri_summary <- tibble(
  Statistic = c(
    "Observed Coefficient",
    "Mean Permutation Coefficient",
    "SD Permutation Coefficient",
    "Min Permutation Coefficient",
    "Max Permutation Coefficient",
    "RI p-value (two-sided)",
    "RI p-value (one-sided)",
    "Number of Permutations"
  ),
  Value = c(
    round(coef_obs, 4),
    round(mean(perm_coefs), 4),
    round(sd(perm_coefs), 4),
    round(min(perm_coefs), 4),
    round(max(perm_coefs), 4),
    round(ri_pval_twosided, 4),
    round(ri_pval_onesided, 4),
    n_perms
  )
)

tab12 <- knitr::kable(ri_summary, format = "latex", booktabs = TRUE,
                      caption = "Randomization Inference Results",
                      label = "tab:ri") %>%
  kableExtra::kable_styling(latex_options = "hold_position")

save_tex_table(tab12, "tab12_randomization_inference.tex")

# Figure 8: RI histogram
perm_df <- tibble(coef = perm_coefs)

fig8 <- ggplot(perm_df, aes(x = coef)) +
  geom_histogram(bins = 50, fill = COL_NEUTRAL, color = "white", alpha = 0.7) +
  geom_vline(xintercept = coef_obs, color = COL_AUSP, linewidth = 1.5) +
  geom_vline(xintercept = -coef_obs, color = COL_AUSP, linewidth = 1.5, linetype = "dashed") +
  annotate("text", x = coef_obs, y = Inf, label = paste0("Observed\n", round(coef_obs, 2)),
           vjust = 2, hjust = -0.1, color = COL_AUSP, fontface = "bold") +
  labs(
    title = "Randomization Inference: Permutation Distribution",
    subtitle = paste0("RI p-value (two-sided) = ", round(ri_pval_twosided, 3),
                      " | ", n_perms, " permutations, stratified by weekday"),
    x = "Coefficient on Shubh Strict",
    y = "Frequency"
  )

save_fig(fig8, "fig08_ri_histogram.pdf", width = 8, height = 5)

# Save permutation results for potential further analysis
saveRDS(list(
  coef_obs = coef_obs,
  perm_coefs = perm_coefs,
  ri_pval_twosided = ri_pval_twosided,
  ri_pval_onesided = ri_pval_onesided
), file.path(PATH_DATA, "ri_results.rds"))

message("Script 09 complete")
