#!/usr/bin/env python3
"""Check the computed daily panchang against Drik Panchang's New Delhi almanac.

The tithi and nakshatra prevailing at sunrise are computed from the ephemeris
(00_generate_panchang.py); Drik's day pages are an independent published source. Days are
sampled at random within each year, so every year of the data is checked.
"""

import argparse
import random
from datetime import date

import pandas as pd
from drik import sunrise_names


def norm(name: str) -> str:
    """Transliteration variants between the two sources (Dhanishta/Dhanishtha)."""
    return name.lower().replace(" ", "").replace("th", "t")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--panchang", default="data/panchang.csv")
    parser.add_argument("--first-year", type=int, default=2005)
    parser.add_argument("--last-year", type=int, default=2021)
    parser.add_argument("--per-year", type=int, default=8)
    parser.add_argument("--output", default="data/validation_days.csv")
    parser.add_argument("--list-dates", help="write the sampled dates to this file and stop")
    args = parser.parse_args()

    pan = pd.read_csv(args.panchang)
    rng = random.Random(1)
    rows = []
    for year in range(args.first_year, args.last_year + 1):
        days = pan[pan["date"].str[:4] == str(year)]
        for idx in rng.sample(list(days.index), args.per_year):
            r = pan.loc[idx]
            if args.list_dates:
                rows.append({"date": r["date"]})
                continue
            tithi, nak = sunrise_names(date.fromisoformat(r["date"]))
            rows.append(
                {
                    "date": r["date"],
                    "tithi_ours": r["tithi_name"],
                    "tithi_drik": tithi,
                    "nak_ours": r["nakshatra_name"],
                    "nak_drik": nak,
                    "tithi_ok": norm(tithi) == norm(r["tithi_name"]),
                    "nak_ok": norm(nak) == norm(r["nakshatra_name"]),
                }
            )
    out = pd.DataFrame(rows)
    if args.list_dates:
        out.to_csv(args.list_dates, index=False)
        return
    out.to_csv(args.output, index=False)
    print(
        f"{len(out)} days; tithi match {out.tithi_ok.mean():.1%}, "
        f"nakshatra match {out.nak_ok.mean():.1%}"
    )
    print(out[~(out.tithi_ok & out.nak_ok)].to_string(index=False))


if __name__ == "__main__":
    main()
