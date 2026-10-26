"""Shared paths, constants and cleaning helpers for the BridgeGrant pipeline.

Every function here is pure (no file access except the loaders at the end),
so it can be unit-tested directly.
"""

from __future__ import annotations

import json
import re
from datetime import date
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
PROCESSED = ROOT / "data" / "processed"
STAGE = ROOT / "data" / "interim"  # intermediate files between steps
CONFIG = ROOT / "config"

YEARS = list(range(2020, 2026))
# NCCS: recent years keep growing for 2-3 years as late returns arrive.
PARTIAL_YEARS = {2024, 2025}

SC_STATE_FIPS = "45"


def tax_year_status(year: int) -> str:
    return "partial" if int(year) in PARTIAL_YEARS else "complete"


def today() -> str:
    return date.today().isoformat()


# ---------------------------------------------------------------- EINs / IDs

def normalize_ein(value: object) -> str | None:
    """9-digit EIN as text, zero-padded ("20615986" -> "020615986").

    Returns None for blanks, non-numeric values, all-zero EINs and values
    longer than 9 digits. Never returns an integer.
    """
    if value is None or (isinstance(value, float) and pd.isna(value)) or value is pd.NA:
        return None
    text = str(value).strip()
    if text.endswith(".0"):  # e.g. a float that went through a spreadsheet
        text = text[:-2]
    digits = re.sub(r"\D", "", text)
    if not digits or len(digits) > 9 or not re.fullmatch(r"[\d\s-]+", text):
        return None
    ein = digits.zfill(9)
    return None if ein == "000000000" else ein


def normalize_ein_series(s: pd.Series) -> pd.Series:
    return s.map(normalize_ein).astype("string")


# ------------------------------------------------------------------- states

_SC_FORMS = {"SC", "S C", "SOUTH CAROLINA", "S CAROLINA", "SO CAROLINA", "SOUTHCAROLINA"}


def normalize_state(value: object) -> str | None:
    """Two-letter code for South Carolina spellings, otherwise the cleaned
    uppercase text (or None when blank).

    "S.C." -> "SC", "South Carolina" -> "SC", "S Carolina" -> "SC";
    "SCOTLAND" stays "SCOTLAND" (whole-value match, not a prefix).
    """
    if value is None or value is pd.NA or (isinstance(value, float) and pd.isna(value)):
        return None
    text = re.sub(r"[.,]", " ", str(value).upper())
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return None
    if text in _SC_FORMS:
        return "SC"
    return text


def is_sc(value: object) -> bool:
    return normalize_state(value) == "SC"


# --------------------------------------------------------------- ZIP codes

def normalize_zip(value: object) -> str | None:
    """First five digits of a US ZIP as text ("29730-1234" -> "29730")."""
    if value is None or value is pd.NA or (isinstance(value, float) and pd.isna(value)):
        return None
    digits = re.sub(r"\D", "", str(value))
    if len(digits) in (5, 9):
        return digits[:5]
    return None


_SC_ZIP3 = {str(n) for n in range(290, 300)}


def looks_like_sc_zip(zip5: object) -> bool:
    """True for ZIPs 29000-29999 (South Carolina's ZIP range)."""
    return isinstance(zip5, str) and zip5[:3] in _SC_ZIP3


# ------------------------------------------------------------ names / text

_SUFFIXES = [
    (r"\bINCORPORATED\b", "INC"),
    (r"\bCORPORATION\b", "CORP"),
    (r"\bCOMPANY\b", "CO"),
    (r"\bLIMITED\b", "LTD"),
    (r"\bASSOCIATION\b", "ASSN"),
    (r"\bASSOC\b", "ASSN"),
    (r"\bFDN\b", "FOUNDATION"),
    (r"\bFNDTN\b", "FOUNDATION"),
    (r"\bUNIV\b", "UNIVERSITY"),
    (r"\bST\b", "SAINT"),
    (r"&", " AND "),
]


def clean_name(value: object) -> str | None:
    """Uppercase, punctuation-free, standardized organization name."""
    if value is None or value is pd.NA or (isinstance(value, float) and pd.isna(value)):
        return None
    text = re.sub(r"['’`]", "", str(value).upper())  # LOWE'S -> LOWES
    for pattern, repl in _SUFFIXES:
        text = re.sub(pattern, repl, text)
    text = re.sub(r"[^A-Z0-9 ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"^THE ", "", text)
    return text or None


def clean_address(value: object) -> str | None:
    if value is None or value is pd.NA or (isinstance(value, float) and pd.isna(value)):
        return None
    text = re.sub(r"[^A-Z0-9 #]+", " ", str(value).upper())
    text = re.sub(r"\s+", " ", text).strip()
    return text or None


def join_lines(a: object, b: object) -> str | None:
    parts = [str(x).strip() for x in (a, b) if x is not None and x is not pd.NA and not (isinstance(x, float) and pd.isna(x)) and str(x).strip()]
    return " ".join(parts) or None


def to_amount(value: object) -> float | None:
    """Numeric dollar amount, or None when missing/unparseable."""
    if value is None or value is pd.NA or (isinstance(value, float) and pd.isna(value)):
        return None
    text = re.sub(r"[,$\s]", "", str(value))
    if text in {"", "-", "."}:
        return None
    try:
        return float(text)
    except ValueError:
        return None


_ORG_WORDS = re.compile(
    r"\b(INC|CORP|CO|LLC|LTD|ASSN|FOUNDATION|FUND|TRUST|SCHOOL|SCHOOLS|UNIVERSITY|COLLEGE|ACADEMY|"
    r"CHURCH|MINISTRY|MINISTRIES|CENTER|CENTRE|CLUB|SOCIETY|COUNCIL|COMMITTEE|DEPARTMENT|DEPT|COUNTY|"
    r"CITY|TOWN|STATE|DISTRICT|HOSPITAL|HEALTH|SERVICES|PROGRAM|PROJECT|ALLIANCE|NETWORK|PARTNERS|"
    r"LEAGUE|UNITED|AMERICAN|NATIONAL|INTERNATIONAL|MISSION|HABITAT|YMCA|YWCA|PTA|PTO|BOOSTER|BOOSTERS|"
    r"LIBRARY|MUSEUM|THEATRE|THEATER|ORCHESTRA|SYMPHONY|BAND|CHOIR|ARTS|HOUSE|HOME|SHELTER|PANTRY|"
    r"BANK|KITCHEN|CAMP|PARK|FARM|INSTITUTE|ORGANIZATION|ORG|FRIENDS|GUILD|CHAPTER|POST|LODGE|"
    r"FELLOWSHIP|CONFERENCE|DIOCESE|PARISH|TEMPLE|SYNAGOGUE|CONGREGATION|RESCUE|HUMANE|SPCA|"
    r"CHARITIES|CHARITY|RELIEF|AID|CARE|HOSPICE|ASSOCIATES|GROUP|INITIATIVE|COALITION|BOARD|OF|FOR|AND|"
    r"THE|TO|IN|ON|AT|OUTREACH|ENDOWMENT|PRESERVATION|ELEMENTARY|MIDDLE|CDC|LEARN|LEARNING|EDUCATION|"
    r"YOUTH|KIDS|CHILDREN|FAMILY|FAMILIES|ANIMAL|ANIMALS|PETS|SPORTS|ATHLETIC|ATHLETICS|BASEBALL|"
    r"FOOTBALL|SOCCER|BASKETBALL|SCOUTS|TROOP|PACK|LEGION|VFW|ROTARY|LIONS|KIWANIS|JAYCEES|PHC|CLINIC|"
    r"MEDICAL|DENTAL|COMMUNITY|NEIGHBORHOOD|HOUSING|HABITAT|FOOD|PANTRY|KITCHEN|CAFE|STOREHOUSE|"
    r"CENTER|GARDEN|GARDENS|TRAIL|TRAILS|GREENWAY|RIVER|LAKE|COAST|COASTAL|ISLAND|HISTORIC|HISTORICAL|"
    r"HERITAGE|CONSERVANCY|LAND|WILDLIFE|MINISTRY|GOSPEL|FAITH|GRACE|HOPE|LIFE|VISION|PROJECTS)\b"
)


def looks_like_person(name: str | None) -> bool:
    """True for names like "JANE A DOE": 2-4 alphabetic words, no org words."""
    if not name:
        return False
    if _ORG_WORDS.search(name) or re.search(r"\d", name):
        return False
    words = name.split()
    return 2 <= len(words) <= 4 and all(re.fullmatch(r"[A-Z]+", w) for w in words)


# --------------------------------------------------------------- ZIP county

COUNTY_SINGLE = "zip_single_county"
COUNTY_MULTI = "zip_multi_county"
COUNTY_UNVERIFIED = "unverified"


def load_zcta_counties(path: Path | None = None) -> pd.DataFrame:
    """ZIP (ZCTA) -> county rows with each county's share of the ZIP's land.

    Columns: zip, county_fips, county_name, land_share.
    """
    path = path or RAW / "tab20_zcta520_county20_natl.txt"
    if not path.exists():
        raise FileNotFoundError(
            f"{path.name} is missing. Download it from "
            "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/"
            "tab20_zcta520_county20_natl.txt (or the 'ZCTA' section of "
            "https://www.census.gov/geographies/reference-files/time-series/geo/"
            "relationship-files.2020.html) and put it in data/raw/."
        )
    df = pd.read_csv(
        path,
        sep="|",
        dtype=str,
        encoding="utf-8-sig",
        usecols=["GEOID_ZCTA5_20", "GEOID_COUNTY_20", "NAMELSAD_COUNTY_20", "AREALAND_PART"],
    )
    df = df.dropna(subset=["GEOID_ZCTA5_20", "GEOID_COUNTY_20"])
    df = df.rename(
        columns={
            "GEOID_ZCTA5_20": "zip",
            "GEOID_COUNTY_20": "county_fips",
            "NAMELSAD_COUNTY_20": "county_name",
            "AREALAND_PART": "land_part",
        }
    )
    df["land_part"] = pd.to_numeric(df["land_part"], errors="coerce").fillna(0)
    total = df.groupby("zip")["land_part"].transform("sum")
    df["land_share"] = (df["land_part"] / total.where(total > 0, 1)).round(4)
    return df[["zip", "county_fips", "county_name", "land_share"]]


def zip_county_lookup(zcta: pd.DataFrame) -> dict[str, tuple[str, str | None, str | None, str]]:
    """zip -> (status, county, county_fips, candidates).

    A ZIP whose land lies in exactly one county gets that county. A ZIP that
    crosses counties gets no county; its candidates (with land shares) are
    kept for review. Only South Carolina counties count; a ZIP that lies
    only outside SC is not in the lookup (so it is unverified).
    """
    out: dict[str, tuple[str, str | None, str | None, str]] = {}
    sc_zips = set(zcta.loc[zcta["county_fips"].str.startswith(SC_STATE_FIPS), "zip"])
    # Every county the ZIP touches, including any across the state line.
    for zip5, all_rows in zcta[zcta["zip"].isin(sc_zips)].groupby("zip"):
        all_rows = all_rows.sort_values("land_share", ascending=False)
        candidates = "; ".join(
            f"{r.county_name} ({r.land_share:.0%})" for r in all_rows.itertuples()
        )
        if len(all_rows) == 1:
            r = all_rows.iloc[0]
            out[zip5] = (COUNTY_SINGLE, r.county_name, r.county_fips, candidates)
        else:
            out[zip5] = (COUNTY_MULTI, None, None, candidates)
    return out


def assign_county(zip5: str | None, lookup: dict) -> tuple[str, str | None, str | None, str | None]:
    """(county_status, county, county_fips, candidates) for one ZIP.

    Never guesses a county from a city name.
    """
    if not zip5:
        return COUNTY_UNVERIFIED, None, None, None
    hit = lookup.get(zip5)
    if hit is None:
        return COUNTY_UNVERIFIED, None, None, None
    return hit


# ------------------------------------------------------------ stage files

def stage_path(name: str) -> Path:
    STAGE.mkdir(parents=True, exist_ok=True)
    return STAGE / name


def record_counts(step: str, rows: list[dict]) -> None:
    """Appends processing counts for the data quality report."""
    path = stage_path("counts.json")
    data = json.loads(path.read_text()) if path.exists() else {}
    data[step] = rows
    path.write_text(json.dumps(data, indent=1, default=str))


def load_counts() -> dict:
    path = stage_path("counts.json")
    return json.loads(path.read_text()) if path.exists() else {}
