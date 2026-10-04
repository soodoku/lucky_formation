# Pre-analysis plan: does the panchang time company registrations in India?

Written and committed before any of the primary estimates below was run on the real
calendar. Git history is the timestamp. This is a versioned plan in the repository, not a
registry preregistration.

## What had already been seen

- An earlier version of this project fitted composite "auspicious day" indicators to the
  2010–2020 registry and got nulls (e.g. strict auspicious day +4.5 registrations/day,
  SE 7.6). That pipeline dropped every Monday through a weekday-coding bug, ignored
  holidays and computed the calendar at 05:30 IST rather than sunrise. Those results are
  void, but their direction was seen.
- Building the panel required looking at registration counts by day to detect registrar
  closures, without reference to the panchang. In doing so I saw that state ROCs registered
  nothing on some state holidays, including Gudi Padwa/Ugadi 2012 in Maharashtra and
  Karnataka.
- Nothing has been estimated for Pitru Paksha, the named muhurat days, the within-week tithi
  design, the post-CRC split or the religious-name split.

## Data and sample

- **Registry**: the MCA company master snapshot of December 2020
  (`data/registered_companies.csv.zip`), one row per company still on the register,
  including struck-off companies. Companies dissolved or amalgamated before the snapshot may
  be missing. That matters only if their absence is related to the panchang day they were
  registered on, which I assume it is not.
- **Window**: 2006-10-01 (electronic filing mandatory from 2006-09-16) to 2020-01-31 (end of
  snapshot).
- **Unit**: registrar (ROC, 25) x business day. Primary sample: Monday–Friday days on which
  that registrar was open.
- **Outcome**: count of companies registered that day by the ROC, excluding subsidiaries of
  foreign companies and government companies (`n_dom`). The registration date is the
  registrar's approval date, not the founder's filing date.
- **Closures**, in force for the primaries, using the union of:
  - the jurisdiction's public holidays from the `holidays` package (the state calendar before
    the CRC took over incorporations on 2016-03-23, the national calendar after);
  - detected closures: the whole country registering under a tenth of that week's median
    day, or a pre-CRC registrar averaging at least ten a day registering under a tenth of its
    weekly median.
- **Disrupted weeks**, also excluded: any week whose national registrations fall below half
  the 17-week rolling median around it (16 weeks, chiefly April–May 2014, when the
  Companies Act 2013 forms took effect, and late March–April 2016, when the CRC took over).
  Added before estimation; see Deviations.
- **Panchang**: computed at sunrise in New Delhi (Swiss Ephemeris, Lahiri ayanamsa). Named
  days use the classical time-of-day rules. Validated against Drik Panchang: all 98
  festival and Pitru Paksha boundary dates 2006–2019 and 40 random days' tithi and nakshatra
  match. The rules were tuned on that set; the 2020–2025 holdout result is reported in the
  paper.

## Primary hypotheses

Three tests, Holm-corrected at familywise alpha = 0.05, one-sided in the stated direction.
Model code: `scripts/specs.R`. All three are Poisson regressions; coefficients are log rate
ratios. Controls in every model: day after a closure, day before a closure, last three days
of a month, last three days of a quarter.

| | Hypothesis | Regressor | Fixed effects | Direction |
|---|---|---|---|---|
| P1 | Fewer registrations during Pitru Paksha (16 days before Navratri), avoided for new beginnings | `pitru_paksha`, with `navratri` as a separate term | ROC x year, ROC x ISO week of year, ROC x weekday | negative |
| P2 | More registrations on the named muhurat days: Gudi Padwa/Ugadi, Akshaya Tritiya, Vijayadashami, Dhanteras, pooled | `muhurat_day` | ROC x week of sample, ROC x weekday | positive |
| P3 | More registrations on auspicious tithis than inauspicious ones | `tithi_index` (+1 auspicious, -1 inauspicious, 0 otherwise), with nakshatra and Vishti terms | ROC x week of sample, ROC x weekday | positive |

**Identification.**

- P2 and P3 compare a day only with other days of the same week at the same registrar.
  Lunar days drift through the weekdays, so which day of a week is auspicious is set by
  astronomy, not by anything else that changes within the week. The remaining threat is a
  holiday or deadline that falls on a lunar date. Holidays are removed and month and quarter
  ends controlled.
- P1 compares the same week of the year across years. Pitru Paksha moves about 11 days a
  year and about 30 days in leap-month years, so a given September week falls inside it in
  some years and not others.

**Inference.** Primary p-values come from the calendar-shift distribution. Each model is
re-fitted with the whole panchang moved by k days, for every k from 20 to 300 days in either
direction that is not within 2 days of a whole number of lunar months: 482 shifts
(`scripts/03_null_distributions.R`).

- The one-sided p-value is (1 + number of shifted estimates at least as extreme in the
  stated direction) / (1 + 482).
- A shift keeps the calendar's own autocorrelation and its relation to weekdays but breaks
  its link to dates, so it tests the sharp null that the panchang is unrelated to
  registrations.
- Driscoll–Kraay standard errors (22-business-day lag) are reported alongside, for
  intervals.

**Power** (from the shift distributions, before estimation): the minimum detectable effect
at 80% power, one-sided 5%, is 13.8% for P1, 10.1% for P2, and 1.0% per unit of the tithi
index for P3.

**Expected magnitudes.** Trade press reports car sales down ~40% and property registrations
down far more during Pitru Paksha. Company registration is a paperwork step with an
approval lag, so I expect much less, if anything. A P1 effect under 14% would be missed with
material probability. A P3 effect of 1% per index unit (about 2% between auspicious and
inauspicious tithis) is detectable.

## Secondary analyses (pre-specified, not part of the familywise correction)

1. P3 unrestricted: auspicious and inauspicious tithi separately, nakshatra auspicious and
   inauspicious, Vishti karana.
2. Each named day separately. Days -3..-1 and +1..+3 around the pooled muhurat days, to
   separate shifting (a dip on neighbouring days) from added registrations.
3. Navratri rebound after Pitru Paksha (the `navratri` coefficient in P1).
4. Heterogeneity, each as an interaction in a stacked model where the group is a column of
   the fixed effects:
   - (a) post-CRC (from 2016-03-23) vs before, where approval is fast enough for founders
     to target a day; expected larger after;
   - (b) companies whose name contains a Hindu religious word (list in
     `scripts/00_setup.R`, 2.7% of companies) vs others; expected larger for religious
     names;
   - (c) authorized capital below vs above the registration-year median; expected larger
     for small companies.
5. Placebo populations: P1–P3 for subsidiaries of foreign companies and for government
   companies. Expected null.
6. Robustness, all pre-listed: Saturdays included; 2010–2020 only; closures from listed
   holidays only; detected closures only; OLS on log(1 + count) with the same fixed effects;
   Driscoll–Kraay p-values in place of shift p-values.

## Reporting and interpretation

- Effects are reported as percentage changes (exp(b) - 1) with 95% intervals, and for P1 as
  registrations moved per year.
- A null is reported with what its interval excludes, compared against the MDE. It is not
  reported as "no effect".
- Analyses added after this plan, and any deviation, are labelled exploratory in the paper.

## Deviations from the working plan, made before estimation

- Holidays: the plan said DoPT central circulars. Before the CRC, registrars observed state
  calendars, which those circulars do not cover, so I use the `holidays` package's state
  calendars plus detected closures.
- Kharmas (the Sun in Sagittarius or Pisces) dropped: it is set by the solar sidereal
  calendar, which falls on nearly the same Gregorian dates every year, so the week-of-year
  fixed effects absorb it.
- Disrupted weeks excluded (see Data). Found while plotting the weekly series, before any
  primary estimate. Within-week closure detection cannot catch a whole dead week, and
  Akshaya Tritiya 2014 falls inside one. The MDEs above were recomputed on the reduced
  sample.
- CIN serial-number gaps dropped as a survivorship check: serials are shared across entity
  types and cumulative within a state, so a gap does not identify a missing company.
