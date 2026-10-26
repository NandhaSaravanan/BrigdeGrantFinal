import pandas as pd
import pytest

from common import (
    COUNTY_MULTI,
    COUNTY_SINGLE,
    COUNTY_UNVERIFIED,
    assign_county,
    clean_name,
    is_sc,
    looks_like_person,
    normalize_ein,
    normalize_state,
    normalize_zip,
    zip_county_lookup,
)
from clean_grants import dedupe_amended, split_invalid_amounts


# ------------------------------------------------------------- EIN padding

@pytest.mark.parametrize(
    "raw, expected",
    [
        ("20615986", "020615986"),
        (20615986, "020615986"),
        ("02-0615986", "020615986"),
        ("570426344", "570426344"),
        ("570426344.0", "570426344"),
        ("", None),
        (None, None),
        ("000000000", None),
        ("1234567890", None),
        ("N/A", None),
    ],
)
def test_ein_is_nine_character_text(raw, expected):
    got = normalize_ein(raw)
    assert got == expected
    assert got is None or isinstance(got, str)


# ----------------------------------------------------- state normalization

@pytest.mark.parametrize("raw", ["SC", "sc", "S.C.", "S. C.", "South Carolina", "SOUTH CAROLINA", "S Carolina", " sc "])
def test_south_carolina_spellings(raw):
    assert normalize_state(raw) == "SC"
    assert is_sc(raw)


@pytest.mark.parametrize("raw", ["NC", "North Carolina", "SCOTLAND", "SCARBOROUGH", "", None])
def test_not_south_carolina(raw):
    assert not is_sc(raw)


def test_zip_normalization():
    assert normalize_zip("29730-1234") == "29730"
    assert normalize_zip("297301234") == "29730"
    assert normalize_zip("2973") is None
    assert normalize_zip(None) is None


# ------------------------------------------------------------ ZIP -> county

@pytest.fixture
def zcta():
    return pd.DataFrame(
        {
            "zip": ["29730", "29707", "29715", "29715", "28173", "28173"],
            "county_fips": ["45091", "45057", "45091", "45057", "37179", "45057"],
            "county_name": ["York County", "Lancaster County", "York County", "Lancaster County", "Union County", "Lancaster County"],
            "land_share": [1.0, 1.0, 0.9, 0.1, 0.99, 0.01],
        }
    )


def test_single_county_zip(zcta):
    status, county, fips, _ = assign_county("29730", zip_county_lookup(zcta))
    assert (status, county, fips) == (COUNTY_SINGLE, "York County", "45091")


def test_29707_is_lancaster_not_york(zcta):
    _, county, _, _ = assign_county("29707", zip_county_lookup(zcta))
    assert county == "Lancaster County"


def test_multi_county_zip_has_no_county_but_keeps_candidates(zcta):
    status, county, _, candidates = assign_county("29715", zip_county_lookup(zcta))
    assert status == COUNTY_MULTI and county is None
    assert "York County (90%)" in candidates and "Lancaster County (10%)" in candidates


def test_zip_crossing_state_line_is_multi_county(zcta):
    status, county, _, _ = assign_county("28173", zip_county_lookup(zcta))
    assert status == COUNTY_MULTI and county is None


@pytest.mark.parametrize("zip5", [None, "", "99999"])
def test_missing_or_unknown_zip_is_unverified(zcta, zip5):
    status, county, _, _ = assign_county(zip5, zip_county_lookup(zcta))
    assert status == COUNTY_UNVERIFIED and county is None


# ---------------------------------------------------- amended-return dedupe

def _grants():
    rows = [
        # Funder A filed an original and an amended return for 2023.
        ("OID-1", "111111111", "Rock Hill Reads", 5000.0),
        ("OID-1", "111111111", "Food Pantry", 2500.0),
        ("OID-2", "111111111", "Rock Hill Reads", 5000.0),
        ("OID-2", "111111111", "Food Pantry", 2500.0),
        # Funder B: one return with two identical rows (real separate grants).
        ("OID-3", "222222222", "Youth League", 1000.0),
        ("OID-3", "222222222", "Youth League", 1000.0),
    ]
    df = pd.DataFrame(rows, columns=["filing_id", "funder_ein", "recipient_name", "grant_amount"])
    df["tax_year"] = 2023
    return df


def _filings(amended_is_older=False):
    return pd.DataFrame(
        {
            "filing_id": ["OID-1", "OID-2", "OID-3"],
            "funder_ein": ["111111111", "111111111", "222222222"],
            "tax_year": [2023, 2023, 2023],
            "tax_period_end": ["2023-12-31"] * 3,
            "is_amended_return": [False, True, False],
            "return_timestamp": (
                ["2024-11-01T00:00:00", "2024-05-01T00:00:00", "2024-05-01T00:00:00"]
                if amended_is_older
                else ["2024-05-01T00:00:00", "2024-11-01T00:00:00", "2024-05-01T00:00:00"]
            ),
        }
    )


def test_amended_filing_replaces_original():
    kept, log = dedupe_amended(_grants(), _filings())
    assert set(kept.loc[kept["funder_ein"] == "111111111", "filing_id"]) == {"OID-2"}
    assert len(log) == 2 and set(log["filing_id"]) == {"OID-1"}
    assert log["duplicate_reason"].str.contains("kept OID-2").all()


def test_amended_wins_even_when_filed_earlier():
    kept, _ = dedupe_amended(_grants(), _filings(amended_is_older=True))
    assert set(kept.loc[kept["funder_ein"] == "111111111", "filing_id"]) == {"OID-2"}


def test_identical_rows_within_one_filing_are_kept():
    kept, _ = dedupe_amended(_grants(), _filings())
    assert len(kept[kept["filing_id"] == "OID-3"]) == 2


def test_most_recent_wins_when_neither_is_amended():
    f = _filings()
    f["is_amended_return"] = False
    kept, _ = dedupe_amended(_grants(), f)
    assert set(kept.loc[kept["funder_ein"] == "111111111", "filing_id"]) == {"OID-2"}


def test_returns_for_different_tax_periods_are_both_kept():
    f = _filings()
    f.loc[f["filing_id"] == "OID-1", "tax_period_end"] = "2023-06-30"
    kept, log = dedupe_amended(_grants(), f)
    assert len(log) == 0
    assert set(kept["filing_id"]) == {"OID-1", "OID-2", "OID-3"}


# ------------------------------------------------------- amounts and names

def test_invalid_amounts_go_to_review():
    df = pd.DataFrame({"grant_amount": [100.0, 0.0, -5.0, None]})
    ok, review = split_invalid_amounts(df)
    assert list(ok["grant_amount"]) == [100.0]
    assert sorted(review["review_reason"]) == ["amount_missing_or_unreadable", "amount_negative", "amount_zero"]


def test_clean_name():
    assert clean_name("The Lowe's Companies, Inc.") == "LOWES COMPANIES INC"
    assert clean_name("Boys & Girls Club") == "BOYS AND GIRLS CLUB"


def test_person_detection():
    assert looks_like_person("JANE A DOE")
    assert not looks_like_person("VISION TO LEARN")
    assert not looks_like_person("ROCK HILL SCHOOL DISTRICT")
