#!/usr/bin/env python3
"""
Generate panchang data from astronomical first principles using Swiss Ephemeris.

Uses Lahiri Ayanamsa (Indian Government standard) for sidereal calculations.
"""

import argparse
from datetime import datetime, timedelta
from typing import Tuple

import pandas as pd
import swisseph as swe

# Initialize Swiss Ephemeris with Lahiri ayanamsa
swe.set_sid_mode(swe.SIDM_LAHIRI)

# Location: Delhi (default for Indian panchang)
DELHI_LAT = 28.6139
DELHI_LON = 77.2090

# Tithi names (1-30)
TITHI_NAMES = [
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Purnima",
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Amavasya"
]

# Nakshatra names (1-27)
NAKSHATRA_NAMES = [
    "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira",
    "Ardra", "Punarvasu", "Pushya", "Ashlesha", "Magha",
    "Purva Phalguni", "Uttara Phalguni", "Hasta", "Chitra", "Swati",
    "Vishakha", "Anuradha", "Jyeshtha", "Mula", "Purva Ashadha",
    "Uttara Ashadha", "Shravana", "Dhanishta", "Shatabhisha", "Purva Bhadrapada",
    "Uttara Bhadrapada", "Revati"
]

# Yoga names (1-27)
YOGA_NAMES = [
    "Vishkumbha", "Priti", "Ayushman", "Saubhagya", "Shobhana",
    "Atiganda", "Sukarma", "Dhriti", "Shula", "Ganda",
    "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra",
    "Siddhi", "Vyatipata", "Variyan", "Parigha", "Shiva",
    "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma",
    "Indra", "Vaidhriti"
]

# Karana names (11 types, cycle through 60 karanas per lunar month)
KARANA_NAMES = [
    "Bava", "Balava", "Kaulava", "Taitila", "Garaja", "Vanija", "Vishti",
    "Shakuni", "Chatushpada", "Naga", "Kimstughna"
]

# Weekday names
WEEKDAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

# Auspiciousness classifications based on Muhurta Chintamani & Brihat Samhita

# Auspicious tithis (1-indexed): 2,3,5,7,10,11,13 in Shukla; 17,18,20,22,25,26 in Krishna
TITHI_AUSPICIOUS = {2, 3, 5, 7, 10, 11, 13, 17, 18, 20, 22, 25, 26}
TITHI_INAUSPICIOUS = {4, 8, 9, 14, 19, 23, 24, 29, 30}

# Auspicious nakshatras (1-indexed)
NAKSHATRA_AUSPICIOUS = {
    4,   # Rohini
    5,   # Mrigashira
    8,   # Pushya
    13,  # Hasta
    14,  # Chitra
    15,  # Swati
    17,  # Anuradha
    21,  # Uttara Ashadha
    22,  # Shravana
    23,  # Dhanishta
    26,  # Uttara Bhadrapada
    27,  # Revati
}
NAKSHATRA_INAUSPICIOUS = {
    2,   # Bharani
    3,   # Krittika
    6,   # Ardra
    9,   # Ashlesha
    10,  # Magha
    11,  # Purva Phalguni
    18,  # Jyeshtha
    19,  # Mula
    20,  # Purva Ashadha
    25,  # Purva Bhadrapada
}

# Auspicious yogas (1-indexed)
YOGA_AUSPICIOUS = {
    2,   # Priti
    3,   # Ayushman
    4,   # Saubhagya
    7,   # Sukarma
    8,   # Dhriti
    11,  # Vriddhi
    12,  # Dhruva
    14,  # Harshana
    16,  # Siddhi
    18,  # Variyan
    20,  # Shiva
    21,  # Siddha
    22,  # Sadhya
    23,  # Shubha
    24,  # Shukla
    25,  # Brahma
    26,  # Indra
}
YOGA_INAUSPICIOUS = {
    1,   # Vishkumbha
    6,   # Atiganda
    9,   # Shula
    10,  # Ganda
    13,  # Vyaghata
    15,  # Vajra
    17,  # Vyatipata
    19,  # Parigha
    27,  # Vaidhriti
}

# Auspicious karanas: Bava, Balava, Kaulava, Taitila, Garaja, Vanija
KARANA_AUSPICIOUS = {"Bava", "Balava", "Kaulava", "Taitila", "Garaja", "Vanija"}
# Inauspicious: Vishti (Bhadra)
KARANA_INAUSPICIOUS = {"Vishti"}

# Auspicious weekdays (0=Monday): Monday, Wednesday, Thursday, Friday
VARA_AUSPICIOUS = {0, 2, 3, 4}  # Mon, Wed, Thu, Fri
VARA_INAUSPICIOUS = {1, 5}  # Tuesday, Saturday


def date_to_jd(date: datetime, hour: float = 12.0) -> float:
    """Convert datetime to Julian Day number."""
    return swe.julday(date.year, date.month, date.day, hour)


def get_sun_moon_positions(jd: float) -> Tuple[float, float, float]:
    """
    Get sidereal longitudes of Sun and Moon, plus ayanamsa.

    Returns:
        (sun_sidereal_lon, moon_sidereal_lon, ayanamsa)
    """
    # Get tropical positions
    sun_pos = swe.calc_ut(jd, swe.SUN)[0]
    moon_pos = swe.calc_ut(jd, swe.MOON)[0]

    sun_tropical = sun_pos[0]
    moon_tropical = moon_pos[0]

    # Get ayanamsa
    ayanamsa = swe.get_ayanamsa_ut(jd)

    # Convert to sidereal
    sun_sidereal = (sun_tropical - ayanamsa) % 360
    moon_sidereal = (moon_tropical - ayanamsa) % 360

    return sun_sidereal, moon_sidereal, ayanamsa


def compute_tithi(sun_lon: float, moon_lon: float) -> Tuple[int, str, str]:
    """
    Compute tithi from sidereal longitudes.

    Tithi = (Moon - Sun) / 12 degrees

    Returns:
        (tithi_num 1-30, tithi_name, paksha)
    """
    diff = (moon_lon - sun_lon) % 360
    tithi_num = int(diff / 12) + 1

    if tithi_num > 30:
        tithi_num = 30

    tithi_name = TITHI_NAMES[tithi_num - 1]
    paksha = "Shukla" if tithi_num <= 15 else "Krishna"

    return tithi_num, tithi_name, paksha


def compute_nakshatra(moon_lon: float) -> Tuple[int, str]:
    """
    Compute nakshatra from Moon's sidereal longitude.

    Each nakshatra spans 13°20' (13.333... degrees).

    Returns:
        (nakshatra_num 1-27, nakshatra_name)
    """
    nakshatra_num = int(moon_lon / (360 / 27)) + 1

    if nakshatra_num > 27:
        nakshatra_num = 27

    nakshatra_name = NAKSHATRA_NAMES[nakshatra_num - 1]

    return nakshatra_num, nakshatra_name


def compute_yoga(sun_lon: float, moon_lon: float) -> Tuple[int, str]:
    """
    Compute yoga from sidereal longitudes.

    Yoga = (Sun + Moon) / 13.333... degrees

    Returns:
        (yoga_num 1-27, yoga_name)
    """
    total = (sun_lon + moon_lon) % 360
    yoga_num = int(total / (360 / 27)) + 1

    if yoga_num > 27:
        yoga_num = 27

    yoga_name = YOGA_NAMES[yoga_num - 1]

    return yoga_num, yoga_name


def compute_karana(sun_lon: float, moon_lon: float) -> str:
    """
    Compute karana from sidereal longitudes.

    Karana = half-tithi, each spanning 6 degrees.
    There are 11 karanas cycling through 60 karanas per lunar month.

    Returns:
        karana_name
    """
    diff = (moon_lon - sun_lon) % 360
    karana_index = int(diff / 6)

    # First karana of lunar month is Kimstughna (fixed)
    # Last karana is Naga (fixed)
    # Karanas 2-58 cycle through the 7 repeating karanas

    if karana_index == 0:
        return "Kimstughna"
    elif karana_index >= 57:
        if karana_index == 57:
            return "Shakuni"
        elif karana_index == 58:
            return "Chatushpada"
        else:
            return "Naga"
    else:
        # Cycle through Bava, Balava, Kaulava, Taitila, Garaja, Vanija, Vishti
        cycle_index = (karana_index - 1) % 7
        return KARANA_NAMES[cycle_index]


def compute_panchang_for_date(date: datetime, hour: float = 0.0) -> dict:
    """Compute all panchang elements for a given date at specified hour (default: midnight UTC)."""
    jd = date_to_jd(date, hour=hour)

    # Get positions
    sun_lon, moon_lon, ayanamsa = get_sun_moon_positions(jd)

    # Compute elements
    tithi_num, tithi_name, paksha = compute_tithi(sun_lon, moon_lon)
    nakshatra_num, nakshatra_name = compute_nakshatra(moon_lon)
    yoga_num, yoga_name = compute_yoga(sun_lon, moon_lon)
    karana_name = compute_karana(sun_lon, moon_lon)

    # Weekday (0=Monday in our system to match R's week_start=1)
    weekday = date.weekday()
    weekday_name = WEEKDAY_NAMES[weekday]

    # Auspiciousness classifications
    tithi_ausp = 1 if tithi_num in TITHI_AUSPICIOUS else 0
    tithi_inausp = 1 if tithi_num in TITHI_INAUSPICIOUS else 0

    nak_ausp = 1 if nakshatra_num in NAKSHATRA_AUSPICIOUS else 0
    nak_inausp = 1 if nakshatra_num in NAKSHATRA_INAUSPICIOUS else 0

    yoga_ausp = 1 if yoga_num in YOGA_AUSPICIOUS else 0
    yoga_inausp = 1 if yoga_num in YOGA_INAUSPICIOUS else 0

    is_vishti = 1 if karana_name == "Vishti" else 0

    vara_ausp = 1 if weekday in VARA_AUSPICIOUS else 0
    vara_inausp = 1 if weekday in VARA_INAUSPICIOUS else 0

    # Composite scores
    # shubh_strict: all elements must be auspicious, none inauspicious
    shubh_strict = 1 if (
        tithi_ausp and nak_ausp and yoga_ausp and vara_ausp and
        not tithi_inausp and not nak_inausp and not yoga_inausp and not is_vishti and not vara_inausp
    ) else 0

    # shubh_loose: majority auspicious
    ausp_count = tithi_ausp + nak_ausp + yoga_ausp + vara_ausp
    shubh_loose = 1 if ausp_count >= 3 else 0

    # ashubh: any major inauspicious element
    ashubh = 1 if (tithi_inausp or nak_inausp or yoga_inausp or is_vishti) else 0

    # score_muhurat: weighted composite (-1 to 1 scale)
    # Weights based on traditional importance: tithi=0.2, nakshatra=0.2, yoga=0.2, karana=0.15, vara=0.15
    # Add 0.1 bonus for good karana (non-vishti)
    score = 0.0
    score += 0.20 * (1 if tithi_ausp else (-1 if tithi_inausp else 0))
    score += 0.20 * (1 if nak_ausp else (-1 if nak_inausp else 0))
    score += 0.20 * (1 if yoga_ausp else (-1 if yoga_inausp else 0))
    score += 0.15 * (-1 if is_vishti else (0.5 if karana_name in KARANA_AUSPICIOUS else 0))
    score += 0.15 * (1 if vara_ausp else (-1 if vara_inausp else 0))

    return {
        "date": date.strftime("%Y-%m-%d"),
        "weekday": weekday,
        "weekday_name": weekday_name,
        "tithi_num": tithi_num,
        "tithi_name": tithi_name,
        "paksha": paksha,
        "tithi_ausp": tithi_ausp,
        "tithi_inausp": tithi_inausp,
        "nakshatra_num": nakshatra_num,
        "nakshatra_name": nakshatra_name,
        "nak_ausp": nak_ausp,
        "nak_inausp": nak_inausp,
        "yoga_num": yoga_num,
        "yoga_name": yoga_name,
        "yoga_ausp": yoga_ausp,
        "yoga_inausp": yoga_inausp,
        "karana_name": karana_name,
        "is_vishti": is_vishti,
        "vara_ausp": vara_ausp,
        "vara_inausp": vara_inausp,
        "shubh_strict": shubh_strict,
        "shubh_loose": shubh_loose,
        "ashubh": ashubh,
        "score_muhurat": round(score, 4),
        "sun_sid_lon": round(sun_lon, 4),
        "moon_sid_lon": round(moon_lon, 4),
        "ayanamsa": round(ayanamsa, 4),
    }


def generate_panchang(start_date: datetime, end_date: datetime, hour: float = 0.0) -> pd.DataFrame:
    """Generate panchang for a date range."""
    rows = []
    current = start_date

    while current <= end_date:
        row = compute_panchang_for_date(current, hour=hour)
        rows.append(row)
        current += timedelta(days=1)

    return pd.DataFrame(rows)


def main():
    parser = argparse.ArgumentParser(
        description="Generate panchang data using Swiss Ephemeris"
    )
    parser.add_argument(
        "--start",
        type=str,
        required=True,
        help="Start date (YYYY-MM-DD)"
    )
    parser.add_argument(
        "--end",
        type=str,
        required=True,
        help="End date (YYYY-MM-DD)"
    )
    parser.add_argument(
        "--output",
        type=str,
        required=True,
        help="Output path (.parquet or .csv)"
    )
    parser.add_argument(
        "--hour",
        type=float,
        default=0.0,
        help="Calculation hour in UTC (default: 0.0 = midnight)"
    )

    args = parser.parse_args()

    start_date = datetime.strptime(args.start, "%Y-%m-%d")
    end_date = datetime.strptime(args.end, "%Y-%m-%d")

    print(f"Generating panchang from {args.start} to {args.end} (hour={args.hour})...")
    df = generate_panchang(start_date, end_date, hour=args.hour)
    print(f"Generated {len(df)} rows")

    if args.output.endswith(".parquet"):
        df.to_parquet(args.output, index=False)
    else:
        df.to_csv(args.output, index=False)

    print(f"Saved to {args.output}")


if __name__ == "__main__":
    main()
