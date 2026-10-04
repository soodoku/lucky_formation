#!/usr/bin/env python3
"""Public holidays by registrar (ROC) jurisdiction, from the `holidays` package.

Before the Central Registration Centre (March 2016) each ROC approved incorporations and
closed on its state's holidays. After it, approvals came from Manesar, which keeps the
central government calendar (the package's national list, subdiv=None).
"""

import argparse

import holidays
import pandas as pd

ROC_STATE = {
    "AHMEDABAD": "GJ",
    "ANDAMAN": "AN",
    "BANGALORE": "KA",
    "CHANDIGARH": "CH",
    "CHENNAI": "TN",
    "CHHATTISGARH": "CG",
    "COIMBATORE": "TN",
    "CUTTAK": "OD",
    "DELHI": "DL",
    "ERNAKULAM": "KL",
    "GOA": "GA",
    "GWALIOR": "MP",
    "HP": "HP",
    "HYDERABAD": "TS",
    "JAIPUR": "RJ",
    "JAMMU": "JK",
    "JHARKHAND": "JH",
    "KANPUR": "UP",
    "KOLKATA": "WB",
    "MUMBAI": "MH",
    "PATNA": "BR",
    "PONDICHERRY": "PY",
    "PUNE": "MH",
    "SHILLONG": "ML",
    "UTTARAKHAND": "UK",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--first-year", type=int, default=2006)
    parser.add_argument("--last-year", type=int, default=2020)
    parser.add_argument("--output", default="data/holidays.csv")
    args = parser.parse_args()
    years = range(args.first_year, args.last_year + 1)

    rows = []
    calendars = {roc: holidays.India(years=years, subdiv=s) for roc, s in ROC_STATE.items()}
    calendars["NATIONAL"] = holidays.India(years=years)
    for roc, cal in calendars.items():
        for day, name in cal.items():
            rows.append({"roc": roc, "date": day.isoformat(), "holiday": name})

    df = pd.DataFrame(rows).sort_values(["roc", "date"])
    df.to_csv(args.output, index=False)
    print(f"Wrote {len(df):,} ROC-holiday rows for {len(calendars)} calendars to {args.output}")


if __name__ == "__main__":
    main()
