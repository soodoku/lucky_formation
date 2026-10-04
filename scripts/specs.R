# specs.R
# The three pre-specified primary models (ms/pap.md), and the calendar shift used for their
# null distributions. Sourced by 03_null_distributions.R and 04_primary.R so that power
# calculations and estimates come from identical code.

PANCHANG_COLS <- c(
  "tithi_num", "tithi_ausp", "tithi_inausp", "tithi_index", "nakshatra_num", "nak_ausp",
  "nak_inausp", "yoga_ausp", "yoga_inausp", "is_vishti", "lunar_month", "is_adhik",
  "gudi_padwa", "akshaya_tritiya", "vijayadashami", "dhanteras", "diwali",
  "pitru_paksha", "navratri"
)

SYNODIC <- 29.530589

# Registrar-days the primaries are estimated on: weekdays when the registrar was open, outside
# weeks of system-wide disruption.
primary_sample <- function(panel) {
  panel %>%
    filter(weekday <= 5, !closed, !disrupted_week) %>%
    mutate(
      muhurat_day = pmax(gudi_padwa, akshaya_tritiya, vijayadashami, dhanteras),
      t = as.integer(date - SAMPLE_START)
    )
}

# Give every date the panchang of date + k. The calendar keeps its own serial structure
# but loses its alignment with the registry, so estimates under a shift are draws from the
# no-effect distribution with the real data's dependence.
shift_panchang <- function(panel, panchang, k) {
  shifted <- panchang %>%
    mutate(date = as.Date(date) - k, tithi_index = tithi_ausp - tithi_inausp) %>%
    select(date, all_of(PANCHANG_COLS))
  panel %>%
    select(-any_of(c(PANCHANG_COLS, "muhurat_day"))) %>%
    left_join(shifted, by = "date") %>%
    mutate(muhurat_day = pmax(gudi_padwa, akshaya_tritiya, vijayadashami, dhanteras))
}

# Shifts that cannot realign the lunar calendar with itself: at least 20 days, at most 300
# (well short of a lunar year), and not within 2 days of a whole number of lunar months.
valid_shifts <- function() {
  k <- c(-300:-20, 20:300)
  k[abs(k / SYNODIC - round(k / SYNODIC)) * SYNODIC > 2]
}

CONTROLS <- "after_closure + before_closure + month_end + quarter_end"

# P3: tithi index (+1 auspicious, -1 inauspicious, 0 neutral), days compared within the
# same registrar-week.
fit_p3 <- function(d, vcov = "iid") {
  fepois(
    as.formula(paste("n_dom ~ tithi_index + nak_ausp + nak_inausp + is_vishti +", CONTROLS,
                     "| roc^week + roc^weekday")),
    data = d, vcov = vcov, panel.id = ~ roc + t
  )
}

# P2: the four named muhurat days pooled, within registrar-week.
fit_p2 <- function(d, vcov = "iid") {
  fepois(
    as.formula(paste("n_dom ~ muhurat_day +", CONTROLS, "| roc^week + roc^weekday")),
    data = d, vcov = vcov, panel.id = ~ roc + t
  )
}

# P1: Pitru Paksha. Its dates move about 11 days a year against the Gregorian calendar, so
# the same week of the year is compared across years with and without it.
fit_p1 <- function(d, vcov = "iid") {
  fepois(
    as.formula(paste("n_dom ~ pitru_paksha + navratri +", CONTROLS,
                     "| roc^year + roc^week_of_year + roc^weekday")),
    data = d, vcov = vcov, panel.id = ~ roc + t
  )
}

PRIMARY <- list(
  P1 = list(fit = fit_p1, term = "pitru_paksha", direction = -1),
  P2 = list(fit = fit_p2, term = "muhurat_day", direction = 1),
  P3 = list(fit = fit_p3, term = "tithi_index", direction = 1)
)

# Driscoll-Kraay: robust to arbitrary correlation across registrars on a day and to serial
# correlation up to the lag, here a full lunar month of business days.
VCOV_DK <- DK(22)
