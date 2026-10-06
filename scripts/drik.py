"""Fetch and parse Drik Panchang's New Delhi day pages, cached under data/raw/drik/."""

import html
import os
import re
import time
from datetime import date
from pathlib import Path
from urllib.request import Request, urlopen

CACHE = Path("data/raw/drik")
URL = (
    "https://www.drikpanchang.com/panchang/day-panchang.html?date={d:%d/%m/%Y}&geoname-id=1261481"
)
CAPTCHA = b"Recaptcha challenge"
# Each event is tied to its date in the markup: title="... on October 28th (Friday)">Dhanteras<
EVENT_RE = re.compile(r'on ([A-Z][a-z]+) (\d{1,2})[a-z]{2} \([A-Za-z]+\)">\s*([^<]+?)\s*<')


def fetch(d: date) -> bytes:
    """Drik answers fast requests with a captcha page; back off rather than cache it."""
    for attempt in range(8):
        req = Request(URL.format(d=d), headers={"User-Agent": "Mozilla/5.0 (Macintosh)"})
        with urlopen(req, timeout=60) as resp:
            body = resp.read()
        time.sleep(5.0)
        if CAPTCHA not in body:
            return body
        time.sleep(180 * (attempt + 1))
    raise RuntimeError(f"Drik keeps returning a captcha for {d}")


def raw_page(d: date) -> str:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{d.isoformat()}.html"
    if path.exists() and CAPTCHA in path.read_bytes():
        path.unlink()
    if not path.exists():
        if os.environ.get("DRIK_OFFLINE"):
            raise FileNotFoundError(f"{path} not cached (DRIK_OFFLINE is set)")
        path.write_bytes(fetch(d))
    return html.unescape(path.read_text(errors="ignore"))


def events_on(d: date) -> set[str]:
    """Event labels Drik attributes to date d itself (not to neighbouring days)."""
    month = d.strftime("%B")
    return {
        label
        for m, day, label in EVENT_RE.findall(raw_page(d))
        if m == month and int(day) == d.day
    }


def text(d: date) -> str:
    raw = raw_page(d)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", raw))


def sunrise_names(d: date) -> tuple[str, str]:
    """Tithi and nakshatra prevailing at sunrise: the first of each listed for the day."""
    t = text(d)
    tithi = re.search(r"Tithi (\w+) upto", t)
    nak = re.search(r"Nakshatra ([\w ]+?) upto", t)
    return (tithi.group(1) if tithi else ""), (nak.group(1) if nak else "")
