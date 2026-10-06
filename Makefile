# Full pipeline: make all. Everything it needs is committed (see data/README.md).
R := Rscript
PY := uv run python

.PHONY: all data analysis paper sources validate lint clean

all: data analysis paper

# Built from committed sources: the ephemeris, data/festivals_drik.csv (almanac dates) and
# data/dopt_holidays_transcribed.csv (from the memoranda in data/sources/dopt/).
data:
	$(PY) scripts/00_generate_panchang.py
	$(PY) scripts/build_holidays.py
	$(R) scripts/01_clean_companies.R
	$(R) scripts/02_build_panel.R

analysis:
	$(R) scripts/03_null_distributions.R
	$(R) scripts/04_describe.R
	$(R) scripts/05_primary.R
	$(R) scripts/06_secondary.R
	$(R) scripts/07_exploratory.R
	$(R) scripts/08_tables.R

paper:
	$(PY) scripts/update_readme.py
	cd ms && latexmk -pdf -interaction=nonstopmode -quiet main.tex

# Network steps (slow, rate-limited by Drik Panchang); their outputs are committed.
sources:
	$(PY) scripts/00_generate_panchang.py --almanac none
	$(PY) scripts/scrape_drik_festivals.py
	$(PY) scripts/00_generate_panchang.py

validate:
	$(PY) scripts/validate_panchang.py

lint:
	uv run black --check scripts
	uv run isort --check-only scripts
	uv run flake8 scripts

clean:
	cd ms && latexmk -C
