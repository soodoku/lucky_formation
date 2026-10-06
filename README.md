# Do Indian companies register on auspicious days?

Hindu almanacs (the *panchang*) mark some days as good for starting a business and some as
bad. This project asks whether that shows up in when Indian companies are registered, using
every domestic company the Ministry of Corporate Affairs registered from January 2007 to
January 2020 (about 1.1 million), counted by registrar and business day.

## Findings

<!-- RESULTS:START -->
| Pre-specified test | Effect, % [95% CI] | p, calendar shift (Holm) | MDE, % |
|---|---|---|---|
| P1: Pitru Paksha | -0.6 [-9.7, +9.5] | 0.431 (0.861) | 14.0 |
| P2: Named muhurat day | +12.9 [-1.0, +28.8] | 0.008 (0.025) | 10.2 |
| P3: Tithi index | -0.4 [-1.4, +0.7] | 0.828 (0.861) | 1.1 |
<!-- RESULTS:END -->

- **Pitru Paksha** (the fortnight avoided for new beginnings): registrations change little;
  a drop of more than about a tenth is unlikely.
- **Lunar day (tithi)**: auspicious and inauspicious days are within a few percent of each
  other.
- **Named muhurat days**: registrations rise, driven by Dhanteras, the day before Diwali. The
  pre-specified calendar-shift test rejects chance, but the Driscoll–Kraay interval includes
  zero and so do most robustness checks; whether the rise adds registrations or moves them
  from nearby days cannot be told apart.

Effects are percentage changes in daily registrations at a registrar. MDE is the minimum
detectable effect at 80% power, computed before estimation. The paper is `ms/main.tex`; the
pre-analysis plan, with its timestamped revision, is `ms/pap.md`.

## Design

- **Tests** (Poisson regressions of registrar-day counts):
  - P1 compares the same week of the year across years; Pitru Paksha moves about 11 days a
    year against the Gregorian calendar.
  - P2 and P3 compare a day only with other weekdays of the same week at the same registrar.
- **Inference**: each model is re-estimated with the whole panchang shifted by 20–300 days
  (482 shifts), which gives the distribution of estimates when the calendar has no link to
  registrations. p-values are Holm-adjusted; Driscoll–Kraay intervals are reported alongside.
- **Closures**: registrars are central government offices. Their holidays come from the
  government's annual holiday orders, and a listed holiday is excluded only where the registry
  shows the office actually stopped approving.

## Data

All inputs are committed; `data/README.md` lists sources and licences.

- **Companies**: MCA company master data, December 2020 snapshot (Government Open Data
  License – India), as a slim parquet of the columns used.
- **Panchang**: tithi and nakshatra at New Delhi sunrise from the Swiss Ephemeris, checked
  against Drik Panchang on random days in every year. Festival dates are taken from the
  almanac itself.
- **Holidays**: DoPT office memoranda for 2007–2020, transcribed from the scans in
  `data/sources/dopt/`.

## Reproduce

Requires R (tidyverse, arrow, fixest, zoo), [uv](https://docs.astral.sh/uv/) and LaTeX.

```bash
uv sync
make all        # data, analysis, paper (about 10 minutes)
make lint       # black, isort, flake8
```

`make sources` and `make validate` re-fetch the almanac pages; Drik Panchang rate-limits, and
`scripts/drik_browser_fetch.py` handles its captcha through a browser window.

## Layout

```
scripts/   00–08 pipeline, specs.R (model specifications), source fetchers and checks
data/      sources/ (registry, DoPT orders), almanac and holiday tables, validation output
tabs/      generated tables and the LaTeX macros the paper's numbers come from
figs/      generated figures
ms/        paper, pre-analysis plan, references
```
