#!/usr/bin/env python3
"""Second check on festival dates: the `holidays` package's Indian calendars.

Covers the three named days the package lists. Unlike Drik Panchang it needs no network
and was never used to tune the rules, so it gives an out-of-sample comparison for 2020-2025.
"""

import holidays
import pandas as pd

# (our column, package subdivision, package label)
CHECKS = [
    ("diwali", "DL", "Diwali"),
    ("vijayadashami", "DL", "Dussehra"),
    ("gudi_padwa", "MH", "Gudi Padwa"),
]


def main() -> None:
    pan = pd.read_csv("data/panchang.csv")
    rows = []
    for col, subdiv, label in CHECKS:
        ours = set(pan.loc[pan[col] == 1, "date"])
        cal = holidays.India(years=range(2006, 2026), subdiv=subdiv)
        for day, name in sorted(cal.items()):
            if label in name:
                rows.append({"event": col, "package": day.isoformat(), "match": str(day) in ours})
    df = pd.DataFrame(rows)
    df.to_csv("data/validation_holidays_pkg.csv", index=False)
    print(df[~df["match"]].to_string(index=False))


if __name__ == "__main__":
    main()
