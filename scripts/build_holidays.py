#!/usr/bin/env python3
"""Official holiday calendar for the registrars, from DoPT's annual office memoranda.

Registrars of Companies are central government offices. Each year DoPT lists 14 holidays
every central office observes (compulsory) and 12 occasions from which the coordination
committee in each state capital picks 3 (optional). The Delhi list (Annexure I) is the 14
plus Delhi's 3; the restricted list (Annexure II) carries the dates of the remaining
occasions. State committees' choices were not published centrally, so for registrars outside
Delhi the optional occasions are candidates; 02_build_panel.R marks one closed only where the
registrar visibly shut.

Input: data/dopt_holidays_transcribed.csv, transcribed from the scanned memoranda in
data/sources/dopt/ (one row per printed row, with the printed weekday as a checksum).
"""

import re

import pandas as pd

# Printing errors in the memoranda, resolved by the printed Saka date.
CORRECTIONS = {
    # Printed "July 07 ... Asadha 26 ... Thursday"; Asadha 26, 1930 Saka is 17 July 2008,
    # a Thursday. Not a registrar holiday in any case.
    (2008, "II", 19): "2008-07-17",
}

COMPULSORY = {
    "republic day": r"republic day",
    "independence day": r"independence day",
    "gandhi jayanti": r"gandhi",
    "buddha purnima": r"buddha purnima",
    "christmas": r"christmas day",
    "dussehra": r"vijaya dashami",
    "diwali": r"^diwali",
    "good friday": r"good friday",
    "guru nanak": r"guru nanak",
    "id ul fitr": r"fitr",
    "id ul zuha": r"zuha",
    "mahavir jayanti": r"mahavir",
    "muharram": r"muharram",
    "milad un nabi": r"milad",
}
# The 12 occasions of para 3.1, as named in the restricted lists.
OPTIONAL = {
    "dussehra additional day": r"maha saptami|maha ashtami|maha navami",
    "holi": r"^holi$|dolyatra",
    "janmashtami": r"janmashtami",
    "ram navami": r"ram navami",
    "maha shivaratri": r"shivaratri",
    "ganesh chaturthi": r"ganesh|vinayaka",
    "makar sankranti": r"makar sankranti",
    "rath yatra": r"rath yatra",
    "onam": r"onam",
    "pongal": r"pongal",
    "sri panchami": r"panchami",
    "vishu group": (
        r"vishu|vaisakhi|vaisakhadi|bahag bihu|mesadi|chaitra sukladi|gudi padava|ugadi"
        r"|cheti chand|parsi new year|chhath|karva chauth"
    ),
}
# Islamic holidays move with the sighting of the moon; state committees may shift them
# (para 5.2). Deepavali may be observed on Naraka Chaturdasi instead (para 6).
MOVABLE = {"id ul fitr", "id ul zuha", "muharram", "milad un nabi", "diwali"}


def classify(name: str, table: dict[str, str]) -> str | None:
    low = name.lower()
    for key, pattern in table.items():
        if re.search(pattern, low):
            return key
    return None


def main() -> None:
    d = pd.read_csv("data/dopt_holidays_transcribed.csv")
    for (year, annex, row), fixed in CORRECTIONS.items():
        hit = (d["year"] == year) & (d["annexure"] == annex) & (d["row"] == row)
        assert hit.sum() == 1
        d.loc[hit, "date"] = fixed
    wrong_day = pd.to_datetime(d["date"]).dt.day_name() != d["weekday_printed"]
    print(f"Rows whose printed weekday disagrees with the date: {wrong_day.sum()}")

    d["compulsory"] = d["holiday"].map(lambda n: classify(n, COMPULSORY))
    d["optional"] = d["holiday"].map(lambda n: classify(n, OPTIONAL))
    annex1 = d["annexure"] == "I"
    rows = []
    for _, r in d.iterrows():
        if r["annexure"] == "I" and pd.notna(r["compulsory"]):
            kind, group = "compulsory", r["compulsory"]
        elif pd.notna(r["optional"]):
            # In Annexure I, an optional occasion is one of Delhi's three choices.
            kind = "delhi_choice" if r["annexure"] == "I" else "optional"
            group = r["optional"]
        else:
            continue
        rows.append(
            {
                "date": r["date"],
                "holiday": r["holiday"],
                "kind": kind,
                "group": group,
                "movable": group in MOVABLE,
            }
        )
    out = pd.DataFrame(rows).drop_duplicates(["date", "kind", "group"]).sort_values("date")

    per_year = d[annex1 & d["compulsory"].notna()].groupby("year")["compulsory"].nunique()
    print("Distinct compulsory holidays listed per year:", per_year.to_dict())
    out.to_csv("data/holidays_official.csv", index=False)
    print(out["kind"].value_counts().to_string())


if __name__ == "__main__":
    main()
