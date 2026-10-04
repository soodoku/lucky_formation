# Full pipeline: make all. The registry snapshot must be at data/registered_companies.csv.zip.
R := Rscript
PY := uv run python

.PHONY: all data analysis paper validate lint clean

all: data analysis paper

data:
	$(PY) scripts/00_generate_panchang.py
	$(PY) scripts/build_holidays.py
	$(PY) scripts/validate_holidays_pkg.py
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
	cd ms && latexmk -pdf -interaction=nonstopmode -quiet main.tex

# Fetches Drik Panchang pages (slow, rate-limited); not part of `all`.
validate:
	$(PY) scripts/validate_panchang.py

lint:
	uv run black --check scripts
	uv run isort --check-only scripts
	uv run flake8 scripts

clean:
	cd ms && latexmk -C
