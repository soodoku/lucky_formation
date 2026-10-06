#!/usr/bin/env python3
"""Compare the transcribed DoPT holiday lists with independent text copies, 2013-2020.

The transcription in data/dopt_holidays_transcribed.csv was read off the scanned memoranda.
staffnews.in and gconnect.in republished the same memoranda as HTML text, typed
independently (2019-2020 staffnews pages carry only images, so gconnect is used), so agreement
between the two is evidence that neither introduced errors. Pages are cached in data/raw/.
"""

import html
import re
import time
from datetime import datetime
from pathlib import Path
from urllib.request import Request, urlopen

import pandas as pd

SN = "https://www.staffnews.in/"
GC = "https://www.gconnect.in/orders-in-brief/leave-ltc/leave/"
PAGES = {
    2013: SN + "2012/06/list-of-holiday-2013-central-govt.html",
    2014: SN + "2013/06/list-of-holidays-2014-for-central.html",
    2015: SN + "2014/06/list-of-holidays-2015-for-central.html",
    2016: SN + "2015/06/list-of-holidays-2016-for-central-govt-office-delhi.html",
    2017: SN + "2016/06/holidays-to-be-observed-in-central.html",
    2018: SN + "2017/06/holidays-to-be-observed-in-central-2.html",
    2019: GC + "central-government-holidays-list-2019.html",
    2020: GC + "central-government-holidays-2020.html",
}
CACHE = Path("data/raw/holiday_mirrors")
MONTHS = "January|February|March|April|May|June|July|August|September|October|November|December"
DATE_RE = re.compile(
    rf"({MONTHS}|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?,?\s*(\d{{1,2}})\b"
)


def text(year: int) -> str:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{year}.html"
    if not path.exists():
        req = Request(PAGES[year], headers={"User-Agent": "Mozilla/5.0"})
        with urlopen(req, timeout=60) as resp:
            path.write_bytes(resp.read())
        time.sleep(2)
    raw = path.read_text(errors="ignore")
    start = max(raw.find("entry-content"), raw.find("article"), 0)
    body = raw[start:]
    return html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", body)))


def dates_in(year: int) -> set[str]:
    out = set()
    for month, day in DATE_RE.findall(text(year)):
        m = month[:3]
        try:
            out.add(datetime.strptime(f"{m} {int(day)} {year}", "%b %d %Y").date().isoformat())
        except ValueError:
            continue
    return out


def main() -> None:
    ours = pd.read_csv("data/dopt_holidays_transcribed.csv")
    rows = []
    for year in PAGES:
        theirs = dates_in(year)
        mine = ours[ours["year"] == year]
        for _, r in mine.iterrows():
            rows.append(
                {
                    "year": year,
                    "holiday": r["holiday"],
                    "date": r["date"],
                    "in_text_copy": r["date"] in theirs,
                }
            )
    df = pd.DataFrame(rows)
    df.to_csv("data/check_transcription.csv", index=False)
    print(df.groupby("year")["in_text_copy"].agg(["sum", "size"]).to_string())
    print(df[~df["in_text_copy"]].to_string(index=False))


if __name__ == "__main__":
    main()
