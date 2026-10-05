# 08_tables.R
# LaTeX tables, the event-time figure and text macros for the secondary and exploratory
# results saved by 06_secondary.R and 07_exploratory.R.

source("scripts/00_setup.R")

s <- readRDS(file.path(PATH_DATA, "secondary.rds"))
x <- readRDS(file.path(PATH_DATA, "exploratory.rds"))

ci <- function(pct, lo, hi, digits = 1) {
  f <- paste0("%+.", digits, "f [%+.", digits, "f, %+.", digits, "f]")
  sprintf(f, pct, lo, hi)
}
wrap <- function(cols, header, body) {
  c(paste0("\\begin{tabular}{", cols, "}"), "\\toprule", header, "\\midrule", body,
    "\\bottomrule", "\\end{tabular}")
}
HYP <- c(P1 = "Pitru Paksha", P2 = "Named muhurat day", P3 = "Tithi index")

# --- Components and named days -----------------------------------------------------------
comp_labels <- c(
  tithi_ausp = "Auspicious tithi", tithi_inausp = "Inauspicious tithi",
  nak_ausp = "Auspicious nakshatra", nak_inausp = "Inauspicious nakshatra",
  yoga_ausp = "Auspicious yoga", yoga_inausp = "Inauspicious yoga",
  is_vishti = "Vishti karana",
  gudi_padwa = "Gudi Padwa / Ugadi", akshaya_tritiya = "Akshaya Tritiya",
  dhanteras = "Dhanteras"
)
comp <- bind_rows(
  s$components %>% mutate(block = "Daily attributes (one model)"),
  s$named %>% mutate(block = "Named days (one model)")
)
body <- unlist(map(unique(comp$block), function(blk) {
  rows <- filter(comp, block == .env$blk)
  c(sprintf("\\multicolumn{2}{l}{\\textit{%s}} \\\\", blk),
    sprintf("\\quad %s & %s \\\\", comp_labels[rows$term], ci(rows$pct, rows$lo, rows$hi)))
}))
save_tex_table(wrap("lc", " & Effect, \\% [95\\% CI] \\\\", body), "tab_components.tex")

# --- Heterogeneity and placebo populations ---------------------------------------------
crc <- s$crc %>%
  mutate(group = if_else(grepl(":post_crc", term), "Change after CRC", "Before CRC"))
het <- s$het %>%
  mutate(group = c(religious = "Religious name", secular = "Other name", small = "Small capital",
                   large = "Large capital")[sub(".*:grp", "", term)])
plac <- s$placebo %>%
  mutate(group = c(n_foreign = "Foreign subsidiaries", n_govt = "Government companies")[outcome])
rows <- bind_rows(crc, het, plac) %>%
  select(hypothesis, group, pct, lo, hi) %>%
  mutate(cell = ci(pct, lo, hi)) %>%
  select(-pct, -lo, -hi) %>%
  pivot_wider(names_from = hypothesis, values_from = cell)
body <- sprintf("%s & %s & %s & %s \\\\", rows$group, rows$P1, rows$P2, rows$P3)
body <- append(body, "\\midrule", after = 2)
body <- append(body, "\\midrule", after = 7)
save_tex_table(
  wrap("lccc", sprintf(" & %s & %s & %s \\\\", HYP["P1"], HYP["P2"], HYP["P3"]), body),
  "tab_heterogeneity.tex"
)

# --- Robustness ---------------------------------------------------------------------
prim <- read_csv(file.path(PATH_TABS, "primary_results.csv"), show_col_types = FALSE) %>%
  transmute(hypothesis, variant = "As specified", pct, lo = pct_lo, hi = pct_hi)
rob <- bind_rows(prim, select(s$robust, hypothesis, variant, pct, lo, hi)) %>%
  mutate(cell = ci(pct, lo, hi), variant = factor(variant, unique(variant))) %>%
  select(hypothesis, variant, cell) %>%
  pivot_wider(names_from = hypothesis, values_from = cell) %>%
  arrange(variant)
body <- sprintf("%s & %s & %s & %s \\\\", rob$variant, rob$P1, rob$P2, rob$P3)
save_tex_table(
  wrap("lccc", sprintf(" & %s & %s & %s \\\\", HYP["P1"], HYP["P2"], HYP["P3"]), body),
  "tab_robustness.tex"
)

# --- Exploratory ----------------------------------------------------------------------
ex <- x$models %>%
  filter(term %in% c("gudi_padwa", "akshaya_tritiya", "dhanteras")) %>%
  mutate(cell = ci(pct, lo, hi), model = factor(model, unique(model))) %>%
  select(model, term, cell) %>%
  pivot_wider(names_from = term, values_from = cell) %>%
  arrange(model)
body <- sprintf("%s & %s & %s & %s \\\\", ex$model, ex$gudi_padwa, ex$akshaya_tritiya,
                ex$dhanteras)
save_tex_table(wrap("lccc", " & Gudi Padwa / Ugadi & Akshaya Tritiya & Dhanteras \\\\", body),
               "tab_exploratory.tex")

# --- Event-time figure ----------------------------------------------------------------
fig <- ggplot(s$event_study, aes(rel, pct)) +
  geom_hline(yintercept = 0, colour = COL_REF) +
  geom_pointrange(aes(ymin = lo, ymax = hi), colour = COL_MAIN) +
  scale_x_continuous(breaks = -3:3) +
  labs(x = "Calendar days from the nearest muhurat day",
       y = "Registrations relative to the\nrest of the week, % (95% CI)")
save_fig(fig, "fig_event_time.pdf", width = 6, height = 3.2)

# --- Text macros ----------------------------------------------------------------------
g <- function(df, t, col = "pct", digits = 1) sprintf(paste0("%.", digits, "f"),
                                                      df[[col]][df$term == t])
ex_both <- filter(x$models, model == "+ both")
nw <- s$net_week
write_numbers(c(
  DhanterasPct = g(s$named, "dhanteras"), DhanterasLo = g(s$named, "dhanteras", "lo"),
  DhanterasHi = g(s$named, "dhanteras", "hi"),
  GudiPct = g(s$named, "gudi_padwa"), GudiLo = g(s$named, "gudi_padwa", "lo"),
  GudiHi = g(s$named, "gudi_padwa", "hi"),
  AksPct = g(s$named, "akshaya_tritiya"), AksLo = g(s$named, "akshaya_tritiya", "lo"),
  AksHi = g(s$named, "akshaya_tritiya", "hi"),
  # Sum of the seven daily log effects: roughly the net change in the week's registrations,
  # in units of one day's volume.
  NetWeekSum = sprintf("%.2f", nw$b), NetWeekSe = sprintf("%.2f", nw$se),
  NavratriPct = sprintf("%.1f", s$navratri$pct), NavratriLo = sprintf("%.1f", s$navratri$lo),
  NavratriHi = sprintf("%.1f", s$navratri$hi),
  DhanterasBoth = g(ex_both, "dhanteras"), GudiBoth = g(ex_both, "gudi_padwa"),
  DhanterasNearClosure = fmt_pct(x$exposure$share_closure_within_3[
    x$exposure$day == "Dhanteras"], 0),
  AheadLo = sprintf("%.1f", min(filter(ex_both, grepl("closure_ahead", term))$lo)),
  AheadHi = sprintf("%.1f", max(filter(ex_both, grepl("closure_ahead", term))$hi)),
  RobPOneMax = sprintf("%.0f", ceiling(max(abs(c(s$robust$lo, s$robust$hi)[
    rep(s$robust$hypothesis == "P1", 2)])))),
  RobPThreeMax = sprintf("%.0f", ceiling(max(abs(c(s$robust$lo, s$robust$hi)[
    rep(s$robust$hypothesis == "P3", 2)])))),
  NDhanterasDates = x$exposure$dates[x$exposure$day == "Dhanteras"],
  NGudiDates = x$exposure$dates[x$exposure$day == "Gudi Padwa"],
  GudiNearFy = fmt_pct(x$exposure$share_fy_last_10[x$exposure$day == "Gudi Padwa"], 0),
  RobSatPTwo = sprintf("%.1f", s$robust$pct[s$robust$variant == "Saturdays included" &
                                               s$robust$hypothesis == "P2"]),
  RobOlsPTwo = sprintf("%.1f", s$robust$pct[s$robust$variant == "OLS, log(1 + count)" &
                                               s$robust$hypothesis == "P2"]),
  RobAllHolPTwo = sprintf("%.1f", s$robust$pct[s$robust$variant ==
                                                  "All listed holidays excluded" &
                                                  s$robust$hypothesis == "P2"])
), "numbers_secondary.tex")
