# Data

## Sources (committed)

| File | What it is | Source |
|---|---|---|
| `sources/mca_company_master_2020-12.parquet` | Every company on the Ministry of Corporate Affairs register in the December 2020 snapshot (1,992,170 rows), 12 of its 17 columns as the original strings. Registered-office address and e-mail columns are dropped. Built by `scripts/00_slim_registry.R` from `registered_companies.csv.zip`, which is too large for GitHub. | MCA company master data, as published on data.gov.in under the Government Open Data License – India |
| `sources/dopt/HolidaysYYYY.pdf` | DoPT office memoranda listing holidays in central government offices, 2008–2020 | Department of Personnel and Training, Government of India (copies from referencer.in) |
| `dopt_holidays_transcribed.csv` | The memoranda's Annexure I and II tables, transcribed from the scans, one row per printed row with the printed weekday | Transcribed for this project; checked by `scripts/check_transcription.py` |
| `festivals_drik.csv` | Dates of the named muhurat days and of Pitru Paksha and Navratri, 2005–2021 | Drik Panchang day pages for New Delhi (`scripts/scrape_drik_festivals.py`) |

## Built by the pipeline

| File | Script |
|---|---|
| `panchang.csv` | `scripts/00_generate_panchang.py` (Swiss Ephemeris; festival dates from `festivals_drik.csv`) |
| `holidays_official.csv` | `scripts/build_holidays.py` |
| `companies_clean.parquet`, `roc_panel.parquet` (not committed) | `scripts/01_clean_companies.R`, `scripts/02_build_panel.R` |
| `validation_days.csv` | `scripts/validate_panchang.py` (needs the Drik page cache in `raw/`) |
| `check_transcription.csv` | `scripts/check_transcription.py` |
| `closures_unexplained.csv`, `compulsory_holidays_open.csv` | `scripts/02_build_panel.R` (diagnostics) |

`raw/` (not committed) caches fetched web pages and the browser profile used when Drik Panchang
asks for a captcha.
