"""Step 4: clean the SC candidates and remove superseded filings.

1. EINs as 9-character text; names, addresses and cities in *_clean columns
   (originals kept).
2. Amounts numeric; cash and noncash kept apart; grant_amount = cash +
   noncash; mostly-noncash grants flagged.
3. Zero, negative or unreadable amounts -> review_invalid_amounts.csv.
4. Amended / duplicate filings: when a funder filed more than one return for
   the same tax year and tax period, only the amended (or, failing that, the
   most recently filed) return is kept. The other return's SC rows go to
   duplicates_log.csv with the reason. The choice is made from ALL of the
   funder's filings (every state), not just the ones with SC grants, so an
   amended return that dropped an SC grant still supersedes the original.
   Returns covering different tax periods in one tax year (e.g. a short year
   after a fiscal-year change) are separate returns and are both kept.
5. Repeated funder/recipient/amount rows inside one filing are kept: they
   can be separate grants.
6. County from ZIP via the Census ZCTA file (never from the city name).

Output: data/interim/clean.parquet
"""

from __future__ import annotations

import argparse
import sys

import pandas as pd

from common import (
    PROCESSED,
    YEARS,
    assign_county,
    clean_address,
    clean_name,
    join_lines,
    load_zcta_counties,
    normalize_ein_series,
    normalize_zip,
    record_counts,
    stage_path,
    tax_year_status,
    to_amount,
    zip_county_lookup,
)

NONCASH_SHARE = 0.5  # "mostly noncash" threshold


def load_years(years: list[int]) -> tuple[pd.DataFrame, pd.DataFrame]:
    raw, filings = [], []
    for y in years:
        p, f = stage_path(f"sc_raw_{y}.parquet"), stage_path(f"filings_{y}.parquet")
        if not p.exists() or not f.exists():
            sys.exit(f"Missing data/interim/sc_raw_{y}.parquet; run filter_south_carolina.py --years {y}")
        raw.append(pd.read_parquet(p))
        filings.append(pd.read_parquet(f))
    return pd.concat(raw, ignore_index=True), pd.concat(filings, ignore_index=True)


def standardize(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["tax_year"] = pd.to_numeric(out["tax_year"], errors="coerce").astype("Int64")
    out["tax_year_status"] = out["tax_year"].map(lambda y: tax_year_status(y) if pd.notna(y) else None)

    out["funder_ein"] = normalize_ein_series(out["funder_ein"])
    out["recipient_ein"] = normalize_ein_series(out["recipient_ein"]) if "recipient_ein" in out else pd.Series(pd.NA, index=out.index, dtype="string")

    org = [join_lines(a, b) for a, b in zip(out["recipient_name_l1"], out.get("recipient_name_l2", pd.Series(None, index=out.index)))]
    person = out.get("recipient_person", pd.Series(pd.NA, index=out.index))
    out["recipient_name"] = pd.Series(org, index=out.index, dtype="string").fillna(person.astype("string"))
    # The 990-PF table has a separate field for grants to named individuals.
    out["recipient_is_person_field"] =person.notna() & pd.Series([o is None for o in org], index=out.index)

    out["funder_name_clean"] = out["funder_name"].map(clean_name).astype("string")
    out["recipient_name_clean"] = out["recipient_name"].map(clean_name).astype("string")
    street = [join_lines(a, b) for a, b in zip(out.get("recipient_addr_l1", pd.Series(None, index=out.index)), out.get("recipient_addr_l2", pd.Series(None, index=out.index)))]
    out["recipient_street_address"] = pd.Series(street, index=out.index, dtype="string")
    out["recipient_street_address_clean"] = out["recipient_street_address"].map(clean_address).astype("string")
    out["recipient_city_clean"] = out["recipient_city"].map(clean_address).astype("string")
    out["recipient_state"] = "SC"  # every row passed the SC filter
    out["recipient_zip"] = out["recipient_zip"].map(normalize_zip).astype("string")
    out["funder_state"] = out["funder_state"].astype("string").str.strip().str.upper()

    cash = out["cash_amount"].map(to_amount)
    noncash = out["noncash_amount"].map(to_amount) if "noncash_amount" in out else pd.Series(None, index=out.index)
    out["cash_amount"] = pd.to_numeric(cash, errors="coerce")
    out["noncash_amount"] = pd.to_numeric(noncash, errors="coerce")
    both_missing = out["cash_amount"].isna() & out["noncash_amount"].isna()
    out["grant_amount"] = (out["cash_amount"].fillna(0) + out["noncash_amount"].fillna(0)).where(~both_missing)
    share = out["noncash_amount"].fillna(0) / out["grant_amount"].where(out["grant_amount"] > 0)
    out["is_mostly_noncash"] = share.fillna(0) > NONCASH_SHARE
    return out


def split_invalid_amounts(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    reason = pd.Series(pd.NA, index=df.index, dtype="string")
    reason[df["grant_amount"].isna()] = "amount_missing_or_unreadable"
    reason[df["grant_amount"].eq(0)] = "amount_zero"
    reason[df["grant_amount"] < 0] = "amount_negative"
    bad = reason.notna()
    review = df[bad].assign(review_reason=reason[bad])
    return df[~bad].copy(), review


def choose_filings(filings: pd.DataFrame) -> pd.DataFrame:
    """For each funder + tax year + tax period: the filing to keep."""
    f = filings.copy()
    f["funder_ein"] = normalize_ein_series(f["funder_ein"])
    f["tax_period_end"] = f.get("tax_period_end", pd.Series(pd.NA, index=f.index)).astype("string").fillna("")
    f["return_timestamp"] = f["return_timestamp"].astype("string").fillna("")
    f = f.sort_values(
        ["funder_ein", "tax_year", "tax_period_end", "is_amended_return", "return_timestamp", "filing_id"],
        ascending=[True, True, True, False, False, False],
    )
    key = ["funder_ein", "tax_year", "tax_period_end"]
    f["filings_in_group"] = f.groupby(key, dropna=False)["filing_id"].transform("size")
    keep = f.drop_duplicates(key, keep="first")
    return f[["filing_id", "funder_ein", "tax_year", "tax_period_end", "filings_in_group"]].merge(
        keep[key + ["filing_id", "is_amended_return", "return_timestamp"]].rename(
            columns={"filing_id": "kept_filing_id", "is_amended_return": "kept_is_amended", "return_timestamp": "kept_filed_at"}
        ),
        on=key,
        how="left",
    )


def dedupe_amended(df: pd.DataFrame, filings: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    choice = choose_filings(filings)[["filing_id", "filings_in_group", "kept_filing_id", "kept_is_amended", "kept_filed_at"]]
    choice = choice.drop_duplicates("filing_id")
    m = df.merge(choice, on="filing_id", how="left")
    superseded = m["kept_filing_id"].notna() & m["kept_filing_id"].ne(m["filing_id"])
    log = m[superseded].copy()
    log["duplicate_reason"] = [
        f"superseded_filing: funder filed {int(n)} returns for this tax year/period; kept "
        f"{k} ({'amended' if a else 'most recent'} return, filed {t or 'date unknown'})"
        for n, k, a, t in zip(log["filings_in_group"], log["kept_filing_id"], log["kept_is_amended"], log["kept_filed_at"])
    ]
    kept = m[~superseded].drop(columns=["kept_is_amended", "kept_filed_at"])
    return kept, log


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--years", type=int, nargs="+", default=None,
        help="years to combine (default: every year already filtered into data/interim/)",
    )
    args = ap.parse_args(argv)
    if args.years is None:
        # Combine every filtered year, so refreshing one year with
        # `run_pipeline.py --years 2023` doesn't drop the others.
        args.years = [y for y in YEARS if stage_path(f"sc_raw_{y}.parquet").exists()]
        if not args.years:
            sys.exit("No filtered years found; run filter_south_carolina.py first.")
    raw, filings = load_years(args.years)
    print(f"Loaded {len(raw):,} SC candidate rows for {args.years}")

    df = standardize(raw)
    df, invalid = split_invalid_amounts(df)
    df, dupes = dedupe_amended(df, filings)

    lookup = zip_county_lookup(load_zcta_counties())
    county = df["recipient_zip"].map(lambda z: assign_county(z if isinstance(z, str) else None, lookup))
    df["county_status"] = [c[0] for c in county]
    df["recipient_county"] = pd.Series([c[1] for c in county], index=df.index, dtype="string")
    df["recipient_county_fips"] = pd.Series([c[2] for c in county], index=df.index, dtype="string")
    df["county_candidates"] = pd.Series([c[3] for c in county], index=df.index, dtype="string")

    # Stable record ids: year, source, then original row order.
    df = df.reset_index(drop=True)
    abbr = df["source_type"].map({"schedule_i": "SI", "990pf_part_xv": "PF"})
    seq = df.groupby(["tax_year", "source_type"]).cumcount() + 1
    df.insert(0, "record_id", [f"{y}-{a}-{n:06d}" for y, a, n in zip(df["tax_year"], abbr, seq)])

    PROCESSED.mkdir(parents=True, exist_ok=True)
    df.to_parquet(stage_path("clean.parquet"), index=False)
    invalid.to_csv(PROCESSED / "review_invalid_amounts.csv", index=False)
    dupes.to_csv(PROCESSED / "duplicates_log.csv", index=False)

    counts = []
    for (y, s), g in raw.groupby(["tax_year", "source_type"]):
        y = int(y)
        counts.append({
            "tax_year": y, "source_type": s, "sc_candidates": len(g),
            "invalid_amount": int(((invalid["tax_year"] == y) & (invalid["source_type"] == s)).sum()),
            "superseded_filing": int(((dupes["tax_year"] == y) & (dupes["source_type"] == s)).sum()),
            "retained": int(((df["tax_year"] == y) & (df["source_type"] == s)).sum()),
        })
    record_counts("clean_grants", counts)
    for c in counts:
        print(f"  {c['tax_year']} {c['source_type']:<14} candidates {c['sc_candidates']:>7,}  invalid amount "
              f"{c['invalid_amount']:>5,}  superseded filing {c['superseded_filing']:>5,}  retained {c['retained']:>7,}")
    print("  county status:", df["county_status"].value_counts().to_dict())
    return 0


if __name__ == "__main__":
    sys.exit(main())
