# 06_secondary.R
# Pre-specified secondary analyses (ms/pap.md): components, timing around the muhurat days,
# heterogeneity, placebo populations and robustness. Driscoll-Kraay intervals throughout.

source("scripts/00_setup.R")
source("scripts/specs.R")

panel <- read_parquet(file.path(PATH_DATA, "roc_panel.parquet"))
d <- primary_sample(panel)

FE_WEEK <- "roc^week + roc^weekday"
FE_YEAR <- "roc^year + roc^week_of_year + roc^weekday"

fit <- function(data, outcome, rhs, fe, family = "poisson") {
  f <- as.formula(paste(outcome, "~", rhs, "+", CONTROLS, "|", fe))
  if (family == "poisson") {
    fepois(f, data = data, vcov = VCOV_DK, panel.id = ~ roc + t)
  } else {
    feols(f, data = data, vcov = VCOV_DK, panel.id = ~ roc + t)
  }
}

tidy <- function(m, terms = NULL, ...) {
  ct <- coeftable(m)
  out <- tibble(term = rownames(ct), b = ct[, 1], se = ct[, 2], p = ct[, 4], n = nobs(m))
  if (!is.null(terms)) out <- filter(out, term %in% terms)
  mutate(out, pct = 100 * (exp(b) - 1), lo = 100 * (exp(b - 1.96 * se) - 1),
         hi = 100 * (exp(b + 1.96 * se) - 1), ...)
}

PRIMARY_RHS <- list(
  P1 = list(rhs = "pitru_paksha + navratri", fe = FE_YEAR, term = "pitru_paksha"),
  P2 = list(rhs = "muhurat_day", fe = FE_WEEK, term = "muhurat_day"),
  P3 = list(rhs = "tithi_index + nak_ausp + nak_inausp + is_vishti", fe = FE_WEEK,
            term = "tithi_index")
)

# --- 1. Daily panchang components, unrestricted ------------------------------------
m_comp <- fit(d, "n_dom",
              "tithi_ausp + tithi_inausp + nak_ausp + nak_inausp + yoga_ausp + yoga_inausp + is_vishti",
              FE_WEEK)
components <- tidy(m_comp, c("tithi_ausp", "tithi_inausp", "nak_ausp", "nak_inausp",
                             "yoga_ausp", "yoga_inausp", "is_vishti"))

# --- 2. Each named day, and the days around them -------------------------------------
m_days <- fit(d, "n_dom", "gudi_padwa + akshaya_tritiya + vijayadashami + dhanteras", FE_WEEK)
named <- tidy(m_days, c("gudi_padwa", "akshaya_tritiya", "vijayadashami", "dhanteras"))

# Event time relative to the nearest muhurat day, built on the full calendar so that
# neighbours of a day dropped as closed are still marked. Vijayadashami is left out: it is
# always a closure, so its neighbours would measure holiday catch-up, not shifting.
cal <- panel %>%
  distinct(date) %>%
  left_join(distinct(panel, date, gudi_padwa, akshaya_tritiya, vijayadashami, dhanteras),
            by = "date") %>%
  arrange(date) %>%
  mutate(any_md = pmax(gudi_padwa, akshaya_tritiya, dhanteras) == 1)
md_dates <- cal$date[cal$any_md]
event <- tibble(date = cal$date) %>%
  mutate(rel = map_int(date, function(x) {
    gap <- as.integer(x - md_dates)
    gap <- gap[abs(gap) <= 3]
    if (length(gap)) gap[which.min(abs(gap))] else NA_integer_
  }))
d_ev <- d %>%
  left_join(event, by = "date") %>%
  mutate(
    ev_m3 = rel %in% -3, ev_m2 = rel %in% -2, ev_m1 = rel %in% -1, ev_0 = rel %in% 0,
    ev_p1 = rel %in% 1, ev_p2 = rel %in% 2, ev_p3 = rel %in% 3
  )
ev_terms <- c("ev_m3", "ev_m2", "ev_m1", "ev_0", "ev_p1", "ev_p2", "ev_p3")
m_ev <- fit(d_ev, "n_dom", paste(ev_terms, collapse = " + "), FE_WEEK)
event_study <- tidy(m_ev, paste0(ev_terms, "TRUE")) %>%
  mutate(rel = c(-3, -2, -1, 0, 1, 2, 3))
# Net effect over the week: if registrations are only moved onto the muhurat day, the
# coefficients across -3..+3 sum to about zero.
net_week <- {
  w <- rep(1, length(ev_terms))
  nm <- paste0(ev_terms, "TRUE")
  v <- vcov(m_ev)[nm, nm]
  b <- sum(coef(m_ev)[nm])
  tibble(b = b, se = sqrt(drop(t(w) %*% v %*% w)))
}

# --- 3. Navratri, from the P1 model ----------------------------------------------------
m_p1 <- fit(d, "n_dom", PRIMARY_RHS$P1$rhs, FE_YEAR)
navratri <- tidy(m_p1, "navratri")

# --- 4. Heterogeneity ---------------------------------------------------------------------
# (a) After the CRC, when approval follows filing within a day or two.
crc <- map_dfr(names(PRIMARY_RHS), function(h) {
  s <- PRIMARY_RHS[[h]]
  rhs <- paste0(s$rhs, " + ", s$term, ":post_crc")
  # P1's ROC x year effects already nest post_crc; P2/P3's ROC x week effects do too.
  m <- fit(d, "n_dom", rhs, s$fe)
  tidy(m, c(s$term, paste0(s$term, ":post_crcTRUE")), hypothesis = h)
})

# (b), (c): two groups of companies in one model, each with its own fixed effects.
stack <- function(data, out_a, out_b, group_names) {
  bind_rows(
    data %>% mutate(n = .data[[out_a]], grp = group_names[1]),
    data %>% mutate(n = .data[[out_b]], grp = group_names[2])
  ) %>%
    mutate(grp = factor(grp, levels = group_names), roc_grp = paste(roc, grp))
}
fit_stacked <- function(data, h) {
  s <- PRIMARY_RHS[[h]]
  # Group levels are absorbed by the group-specific fixed effects.
  rhs <- paste0("(", s$rhs, "):grp")
  fe <- gsub("roc", "roc_grp", s$fe)
  f <- as.formula(paste("n ~", rhs, "+ (", CONTROLS, "):grp |", fe))
  m <- fepois(f, data = data, vcov = VCOV_DK, panel.id = ~ roc_grp + t)
  tidy(m, paste0(s$term, ":grp", levels(data$grp)), hypothesis = h)
}
d_rel <- stack(d, "n_relig", "n_secular", c("religious", "secular"))
d_size <- stack(d, "n_small", "n_large", c("small", "large"))
het <- bind_rows(
  map_dfr(names(PRIMARY_RHS), ~ fit_stacked(d_rel, .x)) %>% mutate(split = "name"),
  map_dfr(names(PRIMARY_RHS), ~ fit_stacked(d_size, .x)) %>% mutate(split = "size")
)

# Difference between groups (log points) with its own SE, from the stacked models.
het_diff <- het %>%
  group_by(split, hypothesis) %>%
  summarise(diff = b[1] - b[2], .groups = "drop")

# --- 5. Placebo populations ------------------------------------------------------------
placebo <- map_dfr(c("n_foreign", "n_govt"), function(y) {
  map_dfr(names(PRIMARY_RHS), function(h) {
    s <- PRIMARY_RHS[[h]]
    m <- fit(d, y, s$rhs, s$fe)
    tidy(m, s$term, hypothesis = h, outcome = y)
  })
})

# --- 6. Robustness -------------------------------------------------------------------------
with_md <- function(data) {
  mutate(data, muhurat_day = pmax(gudi_padwa, akshaya_tritiya, vijayadashami, dhanteras),
         t = as.integer(date - SAMPLE_START))
}
variants <- list(
  "Saturdays included" = panel %>%
    filter(!closed, !disrupted_week) %>%
    with_md(),
  "2010--2020 only" = filter(d, date >= as.Date("2010-01-01")),
  # Every listed holiday out, worked or not; shut-downs off the list stay out too.
  "All listed holidays excluded" = panel %>%
    filter(weekday <= 5, !closed, !holiday_listed, !disrupted_week) %>%
    with_md(),
  # Single-registrar shut-downs on days no official calendar lists, treated as open.
  "Unexplained shut-downs kept" = panel %>%
    filter(weekday <= 5, !closed | closure_type == "unexplained shut-down", !disrupted_week) %>%
    with_md()
)
robust <- imap_dfr(variants, function(data, nm) {
  map_dfr(names(PRIMARY_RHS), function(h) {
    s <- PRIMARY_RHS[[h]]
    tidy(fit(data, "n_dom", s$rhs, s$fe), s$term, hypothesis = h, variant = nm)
  })
})
robust_ols <- map_dfr(names(PRIMARY_RHS), function(h) {
  s <- PRIMARY_RHS[[h]]
  m <- fit(mutate(d, log_n = log1p(n_dom)), "log_n", s$rhs, s$fe, family = "ols")
  tidy(m, s$term, hypothesis = h, variant = "OLS, log(1 + count)")
})
robust <- bind_rows(robust, robust_ols)

# --- Save ------------------------------------------------------------------------------
secondary <- list(components = components, named = named, event_study = event_study,
                  net_week = net_week, navratri = navratri, crc = crc, het = het,
                  het_diff = het_diff, placebo = placebo, robust = robust)
saveRDS(secondary, file.path(PATH_DATA, "secondary.rds"))
iwalk(secondary, function(x, nm) {
  cat("\n==", nm, "==\n")
  print(as.data.frame(x), digits = 3)
})
