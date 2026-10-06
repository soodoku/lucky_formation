# 07_exploratory.R
# NOT pre-specified. Written after seeing that P2 is driven by Dhanteras and Gudi Padwa, to
# test the two calendar explanations that compete with belief:
#   - Dhanteras is two business days before the Diwali closure: a pre-holiday rush?
#   - Gudi Padwa often falls in the last days of the fiscal year: a year-end rush?

source("scripts/00_setup.R")
source("scripts/specs.R")

panel <- read_parquet(file.path(PATH_DATA, "roc_panel.parquet"))

# Business days until the registrar's next closure (1 = the day before), counted on the full
# registrar calendar, and business days until 31 March.
panel <- panel %>%
  filter(weekday <= 5) %>%
  arrange(roc, date) %>%
  group_by(roc) %>%
  mutate(
    run_id = cumsum(closed),
    next_closed_idx = rev(cummin(rev(if_else(closed, row_number(), .Machine$integer.max)))),
    days_to_closure = next_closed_idx - row_number(),
    closure_ahead_1 = days_to_closure == 1,
    closure_ahead_2 = days_to_closure == 2,
    closure_ahead_3 = days_to_closure == 3
  ) %>%
  ungroup() %>%
  mutate(
    fy_end = make_date(if_else(month <= 3, year, year + 1L), 3, 31),
    bdays_to_fy_end = map2_int(date, fy_end, ~ sum(!wday(seq(.x, .y, by = "day"),
                                                          week_start = 1) %in% 6:7) - 1L)
  )

d <- primary_sample(panel) %>%
  mutate(fy_k = if_else(bdays_to_fy_end <= 9, paste0("fy", bdays_to_fy_end), "none"))

fit <- function(rhs) {
  fepois(as.formula(paste("n_dom ~", rhs, "+", CONTROLS, "| roc^week + roc^weekday")),
         data = d, vcov = VCOV_DK, panel.id = ~ roc + t)
}
days_rhs <- "gudi_padwa + akshaya_tritiya + dhanteras"
models <- list(
  "As specified" = fit(days_rhs),
  "+ days before closure" = fit(paste(days_rhs, "+ closure_ahead_2 + closure_ahead_3")),
  "+ fiscal-year-end days" = fit(paste(days_rhs, "+ i(fy_k, ref = 'none')")),
  "+ both" = fit(paste(days_rhs,
                       "+ closure_ahead_2 + closure_ahead_3 + i(fy_k, ref = 'none')"))
)

out <- imap_dfr(models, function(m, nm) {
  ct <- coeftable(m)
  tibble(model = nm, term = rownames(ct), b = ct[, 1], se = ct[, 2]) %>%
    filter(term %in% c("gudi_padwa", "akshaya_tritiya", "dhanteras",
                       "closure_aheadTRUE", "closure_ahead_2TRUE", "closure_ahead_3TRUE")) %>%
    mutate(pct = 100 * (exp(b) - 1), lo = 100 * (exp(b - 1.96 * se) - 1),
           hi = 100 * (exp(b + 1.96 * se) - 1))
})
print(as.data.frame(out), digits = 3)

# How often are the named days near a closure or the fiscal year-end?
exposure <- d %>%
  filter(gudi_padwa == 1 | dhanteras == 1 | akshaya_tritiya == 1) %>%
  mutate(day = case_when(gudi_padwa == 1 ~ "Gudi Padwa", dhanteras == 1 ~ "Dhanteras",
                         TRUE ~ "Akshaya Tritiya")) %>%
  group_by(day) %>%
  summarise(registrar_days = n(), dates = n_distinct(date),
            share_closure_within_3 = mean(days_to_closure <= 3),
            share_fy_last_10 = mean(bdays_to_fy_end <= 9))
print(exposure)

saveRDS(list(models = out, exposure = exposure), file.path(PATH_DATA, "exploratory.rds"))
