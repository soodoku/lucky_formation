#!/usr/bin/env python3
"""Fill the Drik Panchang page cache through a visible browser when plain requests are blocked.

Drik answers rate-limited clients with a reCAPTCHA. Solving it once in a real browser clears
the block for that session, so this opens Chromium with a persistent profile, waits for a
person to solve any challenge, and then fetches the day pages the festival scraper needs
(each anchor date and three days either side) into data/raw/drik/. The scraper then runs from
the cache.
"""

import argparse
import time
from datetime import date, timedelta
from pathlib import Path

import pandas as pd
from drik import CACHE, CAPTCHA, URL
from playwright.sync_api import sync_playwright
from scrape_drik_festivals import EVENTS

PROFILE = Path("data/raw/drik_profile")


def needed(panchang: str, first: int, last: int) -> list[date]:
    pan = pd.read_csv(panchang)
    pan["year"] = pan["date"].str[:4].astype(int)
    out = set()
    for year in range(first, last + 1):
        days = pan[pan["year"] == year]
        for col, end, _ in EVENTS.values():
            anchor_col = f"{col}_rule" if f"{col}_rule" in days else col
            marked = days.loc[days[anchor_col] == 1, "date"]
            if marked.empty:
                continue
            anchor = date.fromisoformat(marked.iloc[0] if end == "first" else marked.iloc[-1])
            out.update(anchor + timedelta(off) for off in range(-3, 4))
    return sorted(d for d in out if not (CACHE / f"{d.isoformat()}.html").exists())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--panchang", default="data/panchang.csv")
    parser.add_argument("--first-year", type=int, default=2005)
    parser.add_argument("--last-year", type=int, default=2021)
    parser.add_argument("--dates", help="CSV with a date column to fetch instead")
    args = parser.parse_args()

    if args.dates:
        todo = [
            date.fromisoformat(d)
            for d in pd.read_csv(args.dates)["date"]
            if not (CACHE / f"{d}.html").exists()
        ]
    else:
        todo = needed(args.panchang, args.first_year, args.last_year)
    print(f"{len(todo)} pages to fetch", flush=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        ctx = p.chromium.launch_persistent_context(str(PROFILE), headless=False)
        page = ctx.new_page()
        for i, d in enumerate(todo, 1):
            page.goto(URL.format(d=d), wait_until="domcontentloaded", timeout=90000)
            while CAPTCHA.decode() in page.content():
                print(f"Captcha on {d}: please solve it in the browser window.", flush=True)
                page.wait_for_timeout(5000)
                if "day-panchang" in page.url and CAPTCHA.decode() not in page.content():
                    break
                if CAPTCHA.decode() not in page.content():
                    page.goto(URL.format(d=d), wait_until="domcontentloaded", timeout=90000)
            (CACHE / f"{d.isoformat()}.html").write_text(page.content())
            print(f"{i}/{len(todo)} {d}", flush=True)
            time.sleep(4)
        ctx.close()


if __name__ == "__main__":
    main()
