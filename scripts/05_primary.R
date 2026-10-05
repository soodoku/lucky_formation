# 05_primary.R
# The three pre-specified primary tests (ms/pap.md).

source("scripts/00_setup.R")
source("scripts/specs.R")

panel <- read_parquet(file.path(PATH_DATA, "roc_panel.parquet"))
null <- read_parquet(file.path(PATH_DATA, "null_distributions.parquet"))
mde <- read_csv(file.path(PATH_TABS, "mde.csv"), show_col_types = FALSE)
d <- primary_sample(panel)

labels <- c(P1 = "Pitru Paksha", P2 = "Named muhurat day", P3 = "Tithi index")

results <- map_dfr(names(PRIMARY), function(h) {
  spec <- PRIMARY[[h]]
  m <- spec$fit(d, vcov = VCOV_DK)
  b <- unname(coef(m)[spec$term])
  se <- unname(se(m)[spec$term])
  draws <- null$estimate[null$hypothesis == h]
  extreme <- if (spec$direction > 0) draws >= b else draws <= b
  tibble(
    hypothesis = h,
    label = labels[h],
    estimate = b,
    se_dk = se,
    pct = 100 * (exp(b) - 1),
    pct_lo = 100 * (exp(b - 1.96 * se) - 1),
    pct_hi = 100 * (exp(b + 1.96 * se) - 1),
    p_shift = (1 + sum(extreme)) / (1 + length(draws)),
    p_dk = pnorm(spec$direction * b / se, lower.tail = FALSE),
    n_obs = nobs(m)
  )
}) %>%
  mutate(p_holm = p.adjust(p_shift, method = "holm")) %>%
  left_join(select(mde, hypothesis, mde_pct), by = "hypothesis")

print(results, width = Inf)
write_csv(results, file.path(PATH_TABS, "primary_results.csv"))

# --- Table --------------------------------------------------------------------------
fmt_p <- function(p) if_else(p < 0.001, "<0.001", sprintf("%.3f", p))
rows <- with(results, sprintf(
  "%s & %s & %+.2f [%+.2f, %+.2f] & %s & %s & %s & %.1f & %s \\\\",
  hypothesis, label, pct, pct_lo, pct_hi, fmt_p(p_shift), fmt_p(p_holm), fmt_p(p_dk),
  mde_pct, fmt_int(n_obs)
))
tab <- c(
  "\\begin{tabular}{llcccccr}", "\\toprule",
  paste(" & & Effect, \\% & \\multicolumn{2}{c}{$p$, calendar shift} & $p$, DK & MDE, \\%",
        "& Registrar-days \\\\"),
  " & & [95\\% CI] & raw & Holm & & & \\\\", "\\midrule",
  rows, "\\bottomrule", "\\end{tabular}"
)
save_tex_table(tab, "tab_primary.tex")

# --- Figure: each estimate against its no-effect distribution ------------------------
obs <- results %>% mutate(panel = paste0(hypothesis, ": ", label))
fig <- null %>%
  mutate(panel = paste0(hypothesis, ": ", labels[hypothesis])) %>%
  ggplot(aes(100 * (exp(estimate) - 1))) +
  geom_histogram(bins = 40, fill = "gray75", colour = "white") +
  geom_vline(data = obs, aes(xintercept = pct), colour = COL_MAIN, linewidth = 0.8) +
  facet_wrap(~panel, scales = "free") +
  labs(x = "Estimated effect, % (grey: calendar shifted by 20-300 days; line: actual)",
       y = "Shifts")
save_fig(fig, "fig_primary_null.pdf", width = 8, height = 3)

# --- Numbers for the text ----------------------------------------------------------
num <- function(h, col, fmt = "%.1f") sprintf(fmt, results[[col]][results$hypothesis == h])
write_numbers(c(
  POnePct = num("P1", "pct"), POneLo = num("P1", "pct_lo"), POneHi = num("P1", "pct_hi"),
  POneP = fmt_p(results$p_shift[1]), POneHolm = fmt_p(results$p_holm[1]),
  POneLoAbs = sprintf("%.0f", abs(results$pct_lo[1])),
  PTwoPct = num("P2", "pct"), PTwoLo = num("P2", "pct_lo"), PTwoHi = num("P2", "pct_hi"),
  PTwoP = fmt_p(results$p_shift[2]), PTwoHolm = fmt_p(results$p_holm[2]),
  PThreePct = num("P3", "pct", "%.2f"), PThreeLo = num("P3", "pct_lo", "%.2f"),
  PThreeHi = num("P3", "pct_hi", "%.2f"),
  PThreeP = fmt_p(results$p_shift[3]), PThreeHolm = fmt_p(results$p_holm[3]),
  NPrimary = fmt_int(results$n_obs[3]),
  # Auspicious vs inauspicious tithi: two steps of the index.
  PThreeGapLo = sprintf("%.1f", 100 * (exp(2 * (results$estimate[3] - 1.96 * results$se_dk[3])) - 1)),
  PThreeGapHi = sprintf("%.1f", 100 * (exp(2 * (results$estimate[3] + 1.96 * results$se_dk[3])) - 1))
), "numbers_primary.tex")
