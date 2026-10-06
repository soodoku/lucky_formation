# 03_null_distributions.R
# No-effect distributions of the three primary coefficients, from calendar shifts.
# Never fits the unshifted calendar, so it can run, and fix the power numbers, before
# any primary estimate is seen.

source("scripts/00_setup.R")
source("scripts/specs.R")

panel <- read_parquet(file.path(PATH_DATA, "roc_panel.parquet"))
panchang <- read_csv(CONFIG$panchang_path, show_col_types = FALSE)
base <- primary_sample(panel)

shifts <- valid_shifts()
stopifnot(!0 %in% shifts)
message("Fitting ", length(shifts), " shifts x ", length(PRIMARY), " models")

null <- map_dfr(shifts, function(k) {
  d <- shift_panchang(base, panchang, k)
  map_dfr(names(PRIMARY), function(h) {
    m <- suppressMessages(PRIMARY[[h]]$fit(d))
    tibble(hypothesis = h, shift = k, estimate = unname(coef(m)[PRIMARY[[h]]$term]))
  })
})
write_parquet(null, file.path(PATH_DATA, "null_distributions.parquet"))

# Minimum detectable effect at 80% power for a one-sided 5% test against this distribution.
mde <- null %>%
  group_by(hypothesis) %>%
  summarise(
    n_shifts = n(),
    null_mean = mean(estimate),
    null_sd = sd(estimate),
    mde_log = (qnorm(0.95) + qnorm(0.80)) * null_sd,
    mde_pct = 100 * (exp(mde_log) - 1)
  )
print(mde)
write_csv(mde, file.path(PATH_TABS, "mde.csv"))

write_numbers(c(
  NShifts = length(shifts),
  MdePOne = sprintf("%.1f", mde$mde_pct[mde$hypothesis == "P1"]),
  MdePTwo = sprintf("%.1f", mde$mde_pct[mde$hypothesis == "P2"]),
  MdePThree = sprintf("%.1f", mde$mde_pct[mde$hypothesis == "P3"])
), "numbers_mde.tex")
