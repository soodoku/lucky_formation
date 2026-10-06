# 00_slim_registry.R
# The MCA company master snapshot (data/registered_companies.csv.zip, 117 MB) is over GitHub's
# file limit. This keeps the columns the analysis can use, as the original strings, in a
# committed parquet file. Free-text address and e-mail fields are dropped.
# Run once: Rscript scripts/00_slim_registry.R

suppressPackageStartupMessages({
  library(readr)
  library(arrow)
})

KEEP <- c(
  "CORPORATE_IDENTIFICATION_NUMBER", "COMPANY_NAME", "COMPANY_STATUS", "COMPANY_CLASS",
  "COMPANY_CATEGORY", "COMPANY_SUB_CATEGORY", "DATE_OF_REGISTRATION", "REGISTERED_STATE",
  "AUTHORIZED_CAP", "PAIDUP_CAPITAL", "REGISTRAR_OF_COMPANIES",
  "PRINCIPAL_BUSINESS_ACTIVITY_AS_PER_CIN"
)
out <- "data/sources/mca_company_master_2020-12.parquet"

raw <- read_csv(
  pipe("unzip -p data/registered_companies.csv.zip"),
  col_types = cols(.default = col_character()),
  col_select = all_of(KEEP),
  na = character()
)
write_parquet(raw, out, compression = "zstd", compression_level = 19)
message("Wrote ", out, ": ", nrow(raw), " rows, ", round(file.size(out) / 1e6, 1), " MB")
