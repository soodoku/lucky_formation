#!/usr/bin/env python3
"""Named-day and festival-span dates from Drik Panchang's New Delhi almanac, 2005-2021.

Classical rules for placing festivals that straddle two civil days are contested (Diwali
2024 split almanacs between 31 October and 1 November), so the dates used in the analysis
are the published almanac's, not a reimplementation of its rules. The rule-based dates in
data/panchang.csv only anchor the search: each event is looked for on the anchor date and
up to three days either side.
"""

import argparse
from datetime import date, timedelta

import pandas as pd
from drik import events_on

# Our event -> (column in panchang.csv giving the anchor, which end of it, Drik labels)
EVENTS = {
    "gudi_padwa": ("gudi_padwa", "first", ["Gudi Padwa", "Ugadi"]),
    "akshaya_tritiya": ("akshaya_tritiya", "first", ["Akshaya Tritiya"]),
    "vijayadashami": ("vijayadashami", "first", ["Dussehra", "Vijayadashami"]),
    "dhanteras": ("dhanteras", "first", ["Dhanteras"]),
    "diwali": ("diwali", "first", ["Lakshmi Puja"]),
    "pitru_paksha_first": ("pitru_paksha", "first", ["Pitrupaksha Begins"]),
    "pitru_paksha_last": ("pitru_paksha", "last", ["Sarva Pitru Amavasya"]),
    "navratri_first": ("navratri", "first", ["Navratri Begins", "Ghatasthapana"]),
    "navratri_last": ("navratri", "last", ["Maha Navami"]),
}
OFFSETS = (0, -1, 1, -2, 2, -3, 3)


def find(anchor: date, labels: list[str]) -> tuple[date | None, int]:
    """First date in the search order carrying a label, and how many dates carry one."""
    hits = []
    for off in OFFSETS:
        d = anchor + timedelta(off)
        if events_on(d) & set(labels):
            hits.append(d)
            # Confirm the neighbours do not carry it too before accepting.
            for nb in (d - timedelta(1), d + timedelta(1)):
                if abs((nb - anchor).days) <= 3 and events_on(nb) & set(labels):
                    hits.append(nb)
            break
    return (min(hits) if hits else None), len(set(hits))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--panchang", default="data/panchang.csv")
    parser.add_argument("--first-year", type=int, default=2005)
    parser.add_argument("--last-year", type=int, default=2021)
    parser.add_argument("--output", default="data/festivals_drik.csv")
    args = parser.parse_args()

    pan = pd.read_csv(args.panchang)
    pan["year"] = pan["date"].str[:4].astype(int)
    rows = []
    for year in range(args.first_year, args.last_year + 1):
        days = pan[pan["year"] == year]
        for event, (col, end, labels) in EVENTS.items():
            # Anchor on the rule-based dates, which stay fixed once the almanac's are applied.
            anchor_col = f"{col}_rule" if f"{col}_rule" in days else col
            marked = days.loc[days[anchor_col] == 1, "date"]
            if marked.empty:
                rows.append(
                    {
                        "event": event,
                        "year": year,
                        "rule_date": None,
                        "drik_date": None,
                        "n_drik_dates": 0,
                    }
                )
                continue
            anchor = date.fromisoformat(marked.iloc[0] if end == "first" else marked.iloc[-1])
            found, n = find(anchor, labels)
            rows.append(
                {
                    "event": event,
                    "year": year,
                    "rule_date": anchor.isoformat(),
                    "drik_date": found.isoformat() if found else None,
                    "n_drik_dates": n,
                }
            )
            print(event, year, anchor, found, n, flush=True)

    df = pd.DataFrame(rows)
    df.to_csv(args.output, index=False)
    missing = df["drik_date"].isna().sum()
    ambiguous = (df["n_drik_dates"] > 1).sum()
    agree = (df["drik_date"] == df["rule_date"]).mean()
    print(
        f"\n{len(df)} event-years; not found {missing}; on two dates {ambiguous}; "
        f"rule agrees with Drik {agree:.1%}"
    )


if __name__ == "__main__":
    main()
