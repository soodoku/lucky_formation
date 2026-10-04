#!/usr/bin/env python3
"""Check data/panchang.csv against Drik Panchang's New Delhi daily pages.

Deliberately shares no code with 00_generate_panchang.py: the reference is a published
almanac, parsed from its HTML. Pages are cached under data/raw/drik/.

Two checks:
  1. Every named day and Pitru Paksha boundary in the sample window: does Drik list the
     festival on our date? If not, which nearby date does it list it on?
  2. A random sample of days: do the sunrise tithi and nakshatra names match?
"""

import argparse
import html
import random
import re
import time
from datetime import date, timedelta
from pathlib import Path
from urllib.request import Request, urlopen

import pandas as pd

CACHE = Path("data/raw/drik")
URL = (
    "https://www.drikpanchang.com/panchang/day-panchang.html?date={d:%d/%m/%Y}&geoname-id=1261481"
)

# Drik's festival labels for each of our columns; any one match counts.
LABELS = {
    "gudi_padwa": ["Gudi Padwa", "Ugadi", "Chaitra Navratri"],
    "akshaya_tritiya": ["Akshaya Tritiya"],
    "vijayadashami": ["Dussehra", "Vijayadashami"],
    "dhanteras": ["Dhanteras", "Dhanatrayodashi"],
    "diwali": ["Lakshmi Puja", "Diwali"],
    "pitru_paksha_first": ["Pratipada Shraddha"],
    "pitru_paksha_last": ["Sarva Pitru Amavasya"],
}


def fetch(d: date) -> bytes:
    """Drik answers fast requests with a captcha page; back off rather than cache it."""
    for attempt in range(6):
        req = Request(URL.format(d=d), headers={"User-Agent": "Mozilla/5.0 (Macintosh)"})
        with urlopen(req, timeout=60) as resp:
            body = resp.read()
        time.sleep(4.0)
        if b"Recaptcha challenge" not in body:
            return body
        time.sleep(120 * (attempt + 1))
    raise RuntimeError(f"Drik keeps returning a captcha for {d}")


def page(d: date) -> str:
    path = CACHE / f"{d.isoformat()}.html"
    if not path.exists():
        path.write_bytes(fetch(d))
    raw = path.read_text(errors="ignore")
    return html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", raw)))


def festivals_on(d: date) -> str:
    raw = (CACHE / f"{d.isoformat()}.html").read_text(errors="ignore")
    return html.unescape(raw)


def has_label(d: date, labels: list[str]) -> bool:
    page(d)
    text = festivals_on(d)
    return any(re.search(rf'">\s*{re.escape(lab)}\b', text) for lab in labels)


def sunrise_names(d: date) -> tuple[str, str]:
    text = page(d)
    tithi = re.search(r"Tithi (\w+) upto", text)
    nak = re.search(r"Nakshatra ([\w ]+?) upto", text)
    return (tithi.group(1) if tithi else ""), (nak.group(1) if nak else "")


def check_festivals(pan: pd.DataFrame, years: range) -> pd.DataFrame:
    pan = pan.assign(
        pitru_paksha_first=pan["pitru_paksha"].diff().eq(1).astype(int),
        pitru_paksha_last=pan["pitru_paksha"].diff(-1).eq(1).astype(int),
    )
    rows = []
    for col, labels in LABELS.items():
        for d in pan.loc[pan[col] == 1, "date"]:
            d = date.fromisoformat(d)
            if d.year not in years:
                continue
            found = None
            for off in (0, -1, 1, -2, 2):
                if has_label(d + timedelta(off), labels):
                    found = off
                    break
            rows.append({"event": col, "ours": d, "drik_offset_days": found})
    return pd.DataFrame(rows)


def norm(name: str) -> str:
    """Transliteration variants between the two sources (Dhanishta/Dhanishtha)."""
    return name.lower().replace(" ", "").replace("th", "t")


def check_days(pan: pd.DataFrame, n: int, years: range, seed: int) -> pd.DataFrame:
    pool = pan[pan["date"].str[:4].astype(int).isin(years)]
    sample = pool.sample(n, random_state=seed)
    rows = []
    for _, r in sample.iterrows():
        d = date.fromisoformat(r["date"])
        t, k = sunrise_names(d)
        rows.append(
            {
                "date": d,
                "tithi_ours": r["tithi_name"],
                "tithi_drik": t,
                "nak_ours": r["nakshatra_name"],
                "nak_drik": k,
                "tithi_ok": norm(t) == norm(r["tithi_name"]),
                "nak_ok": norm(k) == norm(r["nakshatra_name"]),
            }
        )
    return pd.DataFrame(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--panchang", default="data/panchang.csv")
    parser.add_argument("--first-year", type=int, default=2006)
    parser.add_argument("--last-year", type=int, default=2019)
    parser.add_argument("--n-days", type=int, default=40)
    parser.add_argument("--tag", default="", help="suffix for output files, e.g. _holdout")
    args = parser.parse_args()

    CACHE.mkdir(parents=True, exist_ok=True)
    random.seed(0)
    pan = pd.read_csv(args.panchang)
    years = range(args.first_year, args.last_year + 1)

    fest = check_festivals(pan, years)
    fest.to_csv(f"data/validation_festivals{args.tag}.csv", index=False)
    print(fest.groupby("event")["drik_offset_days"].value_counts(dropna=False).to_string())

    days = check_days(pan, args.n_days, years, seed=1)
    days.to_csv(f"data/validation_days{args.tag}.csv", index=False)
    print(f"\nTithi match {days.tithi_ok.mean():.0%}, nakshatra match {days.nak_ok.mean():.0%}")
    print(days[~(days.tithi_ok & days.nak_ok)].to_string())


if __name__ == "__main__":
    main()
