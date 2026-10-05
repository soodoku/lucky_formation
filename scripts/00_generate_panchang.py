#!/usr/bin/env python3
"""Daily panchang at sunrise in New Delhi, computed from the Swiss Ephemeris.

Each civil day takes the tithi, nakshatra, yoga and karana prevailing at local
sunrise (udaya convention), sidereal longitudes with Lahiri ayanamsa. Lunar months
are amanta (new moon to new moon), named by the solar sign the Sun enters during
the month; a month with no solar ingress is adhik (intercalary).

Festival days in the output are the published almanac's (Drik Panchang, New Delhi), because
almanacs follow contested conventions when a festival's lunar day straddles two civil days.
The rules in FESTIVALS reproduce those dates where they can and are kept as `<column>_rule`.
"""

import argparse
from datetime import date, timedelta

import pandas as pd
import swisseph as swe

# Moshier's analytic ephemeris needs no data files; its lunar error (~1 arcsec) moves
# a tithi boundary by seconds, far below the hour-scale gap to sunrise that matters here.
FLAGS = swe.FLG_MOSEPH | swe.FLG_SIDEREAL
swe.set_sid_mode(swe.SIDM_LAHIRI)

# CRC Manesar and ROC Delhi, the largest registrar, are both in the Delhi region.
DELHI = (77.2090, 28.6139, 216.0)
IST_OFFSET_DAYS = 5.5 / 24

TITHI_NAMES = [
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi", "Saptami",
    "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi",
    "Purnima",
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi", "Saptami",
    "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi",
    "Amavasya",
]  # fmt: skip
NAKSHATRA_NAMES = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira", "Ardra", "Punarvasu",
    "Pushya", "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni", "Hasta", "Chitra",
    "Swati", "Vishakha", "Anuradha", "Jyeshtha", "Mula", "Purva Ashadha", "Uttara Ashadha",
    "Shravana", "Dhanishta", "Shatabhisha", "Purva Bhadrapada", "Uttara Bhadrapada", "Revati",
]  # fmt: skip
YOGA_NAMES = [
    "Vishkumbha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda", "Sukarma",
    "Dhriti", "Shula", "Ganda", "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra",
    "Siddhi", "Vyatipata", "Variyan", "Parigha", "Shiva", "Siddha", "Sadhya", "Shubha",
    "Shukla", "Brahma", "Indra", "Vaidhriti",
]  # fmt: skip
MOVABLE_KARANAS = ["Bava", "Balava", "Kaulava", "Taitila", "Garaja", "Vanija", "Vishti"]
MONTH_NAMES = [
    "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada", "Ashvin",
    "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna",
]  # fmt: skip

# Classifications for business beginnings (Muhurta Chintamani), fixed before estimation.
# Tithis are numbered 1-30 across the month; 16-30 are the waning (Krishna) half.
TITHI_AUSPICIOUS = {2, 3, 5, 7, 10, 11, 13, 17, 18, 20, 22, 25, 26}
TITHI_INAUSPICIOUS = {4, 8, 9, 14, 19, 23, 24, 29, 30}
NAKSHATRA_AUSPICIOUS = {4, 5, 8, 13, 14, 15, 17, 21, 22, 23, 26, 27}
NAKSHATRA_INAUSPICIOUS = {2, 3, 6, 9, 10, 11, 18, 19, 20, 25}
YOGA_AUSPICIOUS = {2, 3, 4, 7, 8, 11, 12, 14, 16, 18, 20, 21, 22, 23, 24, 25, 26}
YOGA_INAUSPICIOUS = {1, 6, 9, 10, 13, 15, 17, 19, 27}

# Named days as (lunar month, tithi 1-30, time of day). Almanacs place each festival on the
# day its tithi prevails at a prescribed time (kala), not always at sunrise: evening
# (pradosh) for Lakshmi Puja and Dhanteras, afternoon (aparahna) for Vijayadashami and the
# ancestral rites of Pitru Paksha, forenoon (purvahna) for Akshaya Tritiya.
FESTIVALS = {
    "gudi_padwa": ("Chaitra", 1, "sunrise"),
    "akshaya_tritiya": ("Vaishakha", 3, "purvahna"),
    "vijayadashami": ("Ashvin", 10, "aparahna"),
    "dhanteras": ("Ashvin", 28, "pradosh"),
    "diwali": ("Ashvin", 30, "pradosh"),
}
SPANS = {
    "pitru_paksha": ("Bhadrapada", range(16, 31), "aparahna"),
    "navratri": ("Ashvin", range(1, 10), "sunrise"),
}
# Daytime split in fifths: purvahna is the second fifth, aparahna the fourth. Pradosh is the
# 2h24m after sunset. A named day falls on the day whose window the tithi touches; the days
# of a span are those whose window midpoint lies in it (how both match published dates).
KALAS = ("sunrise", "purvahna", "aparahna", "pradosh")


def jd_of(d: date, hour_ut: float = 0.0) -> float:
    return swe.julday(d.year, d.month, d.day, hour_ut)


def longitudes(jd: float) -> tuple[float, float]:
    sun = swe.calc_ut(jd, swe.SUN, FLAGS)[0][0]
    moon = swe.calc_ut(jd, swe.MOON, FLAGS)[0][0]
    return sun, moon


def elongation(jd: float) -> float:
    sun, moon = longitudes(jd)
    return (moon - sun) % 360


def sunrise_sunset(d: date) -> tuple[float, float]:
    """Julian days (UT) of sunrise and the following sunset on civil date d in Delhi."""
    start = jd_of(d) - IST_OFFSET_DAYS
    _, rise = swe.rise_trans(start, swe.SUN, swe.CALC_RISE, DELHI, flags=swe.FLG_MOSEPH)
    _, sets = swe.rise_trans(rise[0], swe.SUN, swe.CALC_SET, DELHI, flags=swe.FLG_MOSEPH)
    return rise[0], sets[0]


def kala_windows(rise: float, sunset: float) -> dict[str, tuple[float, float]]:
    day = sunset - rise
    return {
        "sunrise": (rise, rise),
        "purvahna": (rise + 0.2 * day, rise + 0.4 * day),
        "aparahna": (rise + 0.6 * day, rise + 0.8 * day),
        "pradosh": (sunset, sunset + 0.1),
    }


def new_moons(jd_start: float, jd_end: float) -> list[float]:
    """Instants of conjunction, found by bisection on the elongation wrapping past 360."""
    out = []
    step = 0.5
    jd = jd_start
    prev = elongation(jd)
    while jd < jd_end:
        nxt = elongation(jd + step)
        if nxt < prev:
            lo, hi = jd, jd + step
            for _ in range(40):
                mid = (lo + hi) / 2
                if elongation(mid) > 180:
                    lo = mid
                else:
                    hi = mid
            out.append(hi)
        prev, jd = nxt, jd + step
    return out


def sun_sign(jd: float) -> int:
    return int(longitudes(jd)[0] // 30)


def lunar_months(conjunctions: list[float]) -> list[tuple[float, float, str, bool]]:
    """(start, end, name, is_adhik) per amanta month.

    The month in which the Sun enters Mesha is Chaitra, so the name follows the Sun's sign
    at the opening conjunction plus one. With no ingress, the month is adhik and takes the
    name of the month that follows it.
    """
    months = []
    for start, end in zip(conjunctions[:-1], conjunctions[1:]):
        sign_start, sign_end = sun_sign(start), sun_sign(end)
        name = MONTH_NAMES[(sign_start + 1) % 12]
        months.append((start, end, name, sign_start == sign_end))
    return months


def day_record(d: date, rise: float) -> dict:
    sun, moon = longitudes(rise)
    elong = (moon - sun) % 360
    tithi = int(elong // 12) + 1
    nakshatra = int(moon // (360 / 27)) + 1
    yoga = int(((sun + moon) % 360) // (360 / 27)) + 1
    k = int(elong // 6)
    if k == 0:
        karana = "Kimstughna"
    elif k >= 57:
        karana = ["Shakuni", "Chatushpada", "Naga"][k - 57]
    else:
        karana = MOVABLE_KARANAS[(k - 1) % 7]
    weekday = d.weekday()
    return {
        "date": d.isoformat(),
        "weekday": weekday + 1,
        "sunrise_ist": swe.revjul(rise + IST_OFFSET_DAYS)[3],
        "tithi_num": tithi,
        "tithi_name": TITHI_NAMES[tithi - 1],
        "paksha": "Shukla" if tithi <= 15 else "Krishna",
        "tithi_ausp": int(tithi in TITHI_AUSPICIOUS),
        "tithi_inausp": int(tithi in TITHI_INAUSPICIOUS),
        "nakshatra_num": nakshatra,
        "nakshatra_name": NAKSHATRA_NAMES[nakshatra - 1],
        "nak_ausp": int(nakshatra in NAKSHATRA_AUSPICIOUS),
        "nak_inausp": int(nakshatra in NAKSHATRA_INAUSPICIOUS),
        "yoga_num": yoga,
        "yoga_name": YOGA_NAMES[yoga - 1],
        "yoga_ausp": int(yoga in YOGA_AUSPICIOUS),
        "yoga_inausp": int(yoga in YOGA_INAUSPICIOUS),
        "karana_name": karana,
        "is_vishti": int(karana == "Vishti"),
        "sun_sid_lon": round(sun, 4),
        "moon_sid_lon": round(moon, 4),
    }


def tithi_at(jd: float) -> int:
    return int(elongation(jd) // 12) + 1


def generate(start: date, end: date) -> pd.DataFrame:
    days = [start + timedelta(n) for n in range((end - start).days + 2)]
    times = [kala_windows(*sunrise_sunset(d)) for d in days]
    months = lunar_months(new_moons(times[0]["sunrise"][0] - 35, times[-1]["sunrise"][0] + 35))

    def month_of(jd: float) -> tuple[str, bool, float]:
        start_m, _, name, adhik = next(m for m in months if m[0] <= jd < m[1])
        return name, adhik, start_m

    rows = []
    for d, kt, next_kt in zip(days[:-1], times[:-1], times[1:]):
        rec = day_record(d, kt["sunrise"][0])
        name, adhik, _ = month_of(kt["sunrise"][0])
        rec["lunar_month"] = name
        rec["is_adhik"] = int(adhik)
        for kala in KALAS:
            w_start, w_end = kt[kala]
            k_name, k_adhik, k_start = month_of(w_start)
            t0, t1 = tithi_at(w_start), tithi_at(w_end)
            in_window = [(t0 - 1 + i) % 30 + 1 for i in range((t1 - t0) % 30 + 1)]
            mid = tithi_at((w_start + w_end) / 2)
            rec[f"_{kala}"] = (in_window, k_name, k_adhik, k_start, mid)
            # A tithi that starts and ends between two windows never touches one (kshaya);
            # it belongs to the day whose window precedes it.
            t_next = tithi_at(next_kt[kala][0])
            rec[f"_{kala}_touched"] = [(t1 - 1 + i) % 30 + 1 for i in range((t_next - t1) % 30)]
        rows.append(rec)
    df = pd.DataFrame(rows)

    def mark(month: str, tithis: range | list[int], kala: str, first_only: bool) -> pd.Series:
        state = df[f"_{kala}"]
        in_month = state.map(lambda s: s[1] == month and not s[2])
        out = pd.Series(0, index=df.index)
        if not first_only:
            out[in_month & state.map(lambda s: s[4] in tithis)] = 1
            return out
        hit = in_month & state.map(lambda s: any(t in tithis for t in s[0]))
        for key in state[in_month].map(lambda s: s[3]).unique():
            same = state.map(lambda s, key=key: s[3] == key)
            exact = df.index[same & hit]
            if len(exact):
                # When the tithi holds the kala on two consecutive days, the almanacs take
                # the second (Dharmasindhu's rule for Dhanteras, Vijayadashami, Lakshmi Puja).
                last = exact[0]
                while last + 1 in exact:
                    last += 1
                out[last] = 1
                continue
            # Kshaya fallback: the day whose kala window contains the tithi. The window can
            # straddle the new moon, so the next day's month label is accepted too.
            nxt = same.shift(-1, fill_value=False)
            touched = df[f"_{kala}_touched"].map(lambda ts: any(t in tithis for t in ts))
            cand = df.index[(same | nxt) & touched]
            out[cand[:1]] = 1
        return out

    for col, (month, tithi, kala) in FESTIVALS.items():
        df[col] = mark(month, [tithi], kala, first_only=True)
    for col, (month, tithis, kala) in SPANS.items():
        df[col] = mark(month, tithis, kala, first_only=False)

    return df.drop(columns=[c for c in df.columns if c.startswith("_")])


def apply_almanac(df: pd.DataFrame, path: str) -> pd.DataFrame:
    """Replace the rule-based festival dates with the published almanac's.

    Almanacs disagree on festivals whose lunar day straddles two civil days, so the dates
    used are Drik Panchang's (scripts/scrape_drik_festivals.py). The rule-based dates stay in
    `<column>_rule` for comparison.
    """
    drik = pd.read_csv(path)
    years = set(df["date"].str[:4].astype(int))
    missing = drik[drik["year"].isin(years) & drik["drik_date"].isna()]
    if len(missing) or not years <= set(drik["year"]):
        raise SystemExit(f"Almanac dates missing:\n{missing}")
    dates = drik.set_index(["event", "year"])["drik_date"]
    for col in list(FESTIVALS) + list(SPANS):
        df[f"{col}_rule"] = df[col]
        df[col] = 0
    for (event, _), d in dates.items():
        if event in FESTIVALS:
            df.loc[df["date"] == d, event] = 1
    for span in SPANS:
        for year in years:
            first, last = dates[(f"{span}_first", year)], dates[(f"{span}_last", year)]
            df.loc[(df["date"] >= first) & (df["date"] <= last), span] = 1
    return df


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--start", default="2005-01-01")
    parser.add_argument("--end", default="2021-12-31")
    parser.add_argument("--output", default="data/panchang.csv")
    parser.add_argument(
        "--almanac",
        default="data/festivals_drik.csv",
        help="published festival dates; 'none' keeps the rule-based dates",
    )
    args = parser.parse_args()

    df = generate(date.fromisoformat(args.start), date.fromisoformat(args.end))
    if args.almanac != "none":
        df = apply_almanac(df, args.almanac)
    df.to_csv(args.output, index=False)
    print(f"Wrote {len(df):,} days to {args.output}")


if __name__ == "__main__":
    main()
