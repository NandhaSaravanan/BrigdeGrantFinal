"""Step 7: write the CSV outputs to data/processed/ and print the processing
report.

- bridgegrant_sc_2020_2025_all_candidates.csv
- bridgegrant_sc_2020_2025_verified_only.csv   (fully_verified rows only)
- bridgegrant_sc_funders.csv                    (one row per funder EIN)
- bridgegrant_sc_county_summary.csv
- bridgegrant_sc_data_quality_report.csv

Funder rankings use standard grants only (never matching gifts, grants to
individuals, or in-kind grants). Tax years 2024-2025 are partial.
"""

from __future__ import annotations

import sys

import pandas as pd

from common import PARTIAL_YEARS, PROCESSED, load_counts, stage_path

MAIN_COLUMNS = [
    "record_id", "funder_ein", "funder_name", "funder_name_clean", "funder_state", "funder_form_type",
    "funder_type", "funder_type_reason", "tax_year", "tax_year_status", "filing_id", "is_amended_return",
    "recipient_name", "recipient_name_clean", "recipient_ein", "recipient_street_address",
    "recipient_street_address_clean", "recipient_city", "recipient_city_clean", "recipient_state",
    "recipient_zip", "recipient_county", "recipient_county_fips", "county_status", "county_candidates",
    "cash_amount", "noncash_amount", "grant_amount", "is_mostly_noncash", "grant_purpose", "grant_type",
    "recipient_type", "recipient_is_individual", "source_type", "source_table", "source_url",
    "header_joined", "filings_in_group", "source_table_match", "irs_filing_check", "irs_filing_verified",
    "recipient_identity_check", "recipient_identity_verified", "bmf_name", "bmf_name_score",
    "sc_address_verified", "bmf_city", "bmf_zip", "county_verified", "recipient_exemption_revoked",
    "recipient_revocation_date", "verification_status",
]


def recipient_key(df: pd.DataFrame) -> pd.Series:
    return df["recipient_ein"].fillna("name:" + df["recipient_name_clean"].fillna("?") + "|" + df["recipient_zip"].fillna("?"))


def funders_table(df: pd.DataFrame) -> pd.DataFrame:
    df = df.assign(recipient_key=recipient_key(df))
    std = df[df["grant_type"] == "standard"]
    rows = []
    for ein, g in df.groupby("funder_ein", dropna=False):
        s = std[std["funder_ein"] == ein] if pd.notna(ein) else std[std["funder_ein"].isna() & std["funder_name"].isin(g["funder_name"])]
        total = g["grant_amount"].sum()
        share = lambda t: round(g.loc[g["grant_type"] == t, "grant_amount"].sum() / total, 4) if total else 0.0  # noqa: E731
        latest = g.sort_values("tax_year").iloc[-1]
        years = sorted(int(y) for y in g["tax_year"].dropna().unique())
        counties = sorted(g.loc[g["recipient_county"].notna(), "recipient_county"].unique())
        ftype = latest["funder_type"]
        mostly_not_standard = (share("matching_gift") + share("individual")) > 0.5
        rows.append({
            "funder_ein": ein,
            "funder_name": latest["funder_name"],
            "funder_state": latest["funder_state"],
            "funder_form_type": latest["funder_form_type"],
            "funder_type": ftype,
            "years_active": ", ".join(map(str, years)),
            "first_year": years[0] if years else None,
            "last_year": years[-1] if years else None,
            "active_in_partial_years_only": bool(years) and set(years) <= PARTIAL_YEARS,
            "grants_all_types": len(g),
            "total_amount_all_types": round(total, 2),
            "sc_recipients_all_types": g["recipient_key"].nunique(),
            "standard_grants": len(s),
            "standard_total_amount": round(s["grant_amount"].sum(), 2),
            "standard_median_grant": s["grant_amount"].median() if len(s) else None,
            "standard_p25_grant": s["grant_amount"].quantile(0.25) if len(s) else None,
            "standard_p75_grant": s["grant_amount"].quantile(0.75) if len(s) else None,
            "standard_sc_recipients": s["recipient_key"].nunique(),
            "counties_served": "; ".join(counties),
            "counties_served_count": len(counties),
            "share_dollars_matching_gift": share("matching_gift"),
            "share_dollars_individual": share("individual"),
            "share_dollars_in_kind": share("in_kind"),
            "likely_open_to_applicants": ftype not in {"daf_sponsor", "defunct", "affiliate_passthrough"} and not mostly_not_standard,
            "fully_verified_grants": int((g["verification_status"] == "fully_verified").sum()),
        })
    out = pd.DataFrame(rows)
    # Rank by standard grants only (recipients reached, then dollars), and
    # only funders likely open to applicants; the rest get no rank.
    out = out.sort_values(
        ["likely_open_to_applicants", "standard_sc_recipients", "standard_total_amount"], ascending=False
    ).reset_index(drop=True)
    rankable = out["likely_open_to_applicants"] & (out["standard_grants"] > 0)
    out.insert(0, "rank_standard_grants", pd.Series(range(1, len(out) + 1)).where(rankable).astype("Int64"))
    return out


def county_table(df: pd.DataFrame) -> pd.DataFrame:
    label = df["recipient_county"].copy()
    label[df["county_status"] == "zip_multi_county"] = "Multiple counties (ZIP crosses county lines)"
    label[df["county_status"] == "unverified"] = "Unknown county (ZIP missing, invalid, or a PO-box ZIP)"
    df = df.assign(county=label, standard_amount=df["grant_amount"].where(df["grant_type"] == "standard", 0))
    out = df.groupby(["county", "tax_year"], dropna=False).agg(
        grants=("record_id", "size"),
        total_amount=("grant_amount", "sum"),
        standard_grants=("grant_type", lambda s: int((s == "standard").sum())),
        standard_amount=("standard_amount", "sum"),
        distinct_funders=("funder_ein", "nunique"),
    ).reset_index()
    out["tax_year_status"] = out["tax_year"].map(lambda y: "partial" if int(y) in PARTIAL_YEARS else "complete")
    out["note"] = out["tax_year_status"].map(
        lambda s: "Partial year: NCCS keeps adding late returns for 2-3 years; lower totals are not real declines." if s == "partial" else ""
    )
    return out.sort_values(["county", "tax_year"])


def quality_table(df: pd.DataFrame) -> pd.DataFrame:
    counts = load_counts()
    rows = []

    def add(section, metric, value, year=None, source=None, notes=""):
        rows.append({"section": section, "metric": metric, "tax_year": year, "source_type": source, "value": value, "notes": notes})

    for c in counts.get("filter_south_carolina", []):
        for k in ("rows_read", "sc_kept", "out_of_state", "missing_state", "foreign_country", "near_miss_logged", "header_unmatched"):
            add("1_filter", k, c.get(k), c["tax_year"], c["source_type"],
                "near misses are in excluded_rows.csv" if k == "near_miss_logged" else "")
    for c in counts.get("clean_grants", []):
        for k in ("sc_candidates", "invalid_amount", "superseded_filing", "retained"):
            add("2_clean", k, c[k], c["tax_year"], c["source_type"],
                {"invalid_amount": "see review_invalid_amounts.csv", "superseded_filing": "see duplicates_log.csv"}.get(k, ""))
    dupes = PROCESSED / "duplicates_log.csv"
    if dupes.exists():
        d = pd.read_csv(dupes, usecols=["duplicate_reason"], dtype=str)
        add("2_clean", "duplicates_removed_reason_superseded_filing", int(d["duplicate_reason"].str.startswith("superseded").sum()))
    inv = PROCESSED / "review_invalid_amounts.csv"
    if inv.exists():
        for reason, n in pd.read_csv(inv, usecols=["review_reason"], dtype=str)["review_reason"].value_counts().items():
            add("2_clean", f"invalid_amount_{reason}", int(n))
    exc = PROCESSED / "excluded_rows.csv"
    if exc.exists():
        for reason, n in pd.read_csv(exc, usecols=["exclusion_reason"], dtype=str)["exclusion_reason"].value_counts().items():
            add("1_filter", f"excluded_{reason}", int(n))
    for (y, s), g in df.groupby(["tax_year", "source_type"]):
        for col in ("funder_name", "funder_state", "recipient_name", "recipient_ein", "recipient_street_address",
                    "recipient_city", "recipient_zip", "grant_purpose", "source_url"):
            add("3_missing_fields", f"missing_{col}", int(g[col].isna().sum()), int(y), s, f"of {len(g)} rows")
    for c in counts.get("classify_grants", []):
        add("4_classify", f"{c['flag']}={c['value']}", c["rows"])
    for c in counts.get("verify_grants", []):
        add("5_verify", c["metric"], c["value"])
    for k, v in df["irs_filing_check"].value_counts().items():
        if k in ("fetch_error", "parse_error"):
            add("6_processing_errors", f"xml_{k}", int(v))
    return pd.DataFrame(rows)


def main() -> int:
    df = pd.read_parquet(stage_path("verified.parquet"))
    PROCESSED.mkdir(parents=True, exist_ok=True)
    src_cols = sorted(c for c in df.columns if c.startswith("src_"))
    cols = [c for c in MAIN_COLUMNS if c in df.columns] + src_cols
    all_df = df[cols].sort_values(["tax_year", "funder_name", "recipient_name"])
    all_df.to_csv(PROCESSED / "bridgegrant_sc_2020_2025_all_candidates.csv", index=False)
    all_df[all_df["verification_status"] == "fully_verified"].to_csv(
        PROCESSED / "bridgegrant_sc_2020_2025_verified_only.csv", index=False)
    funders = funders_table(df)
    funders.to_csv(PROCESSED / "bridgegrant_sc_funders.csv", index=False)
    county_table(df).to_csv(PROCESSED / "bridgegrant_sc_county_summary.csv", index=False)
    quality = quality_table(df)
    quality.to_csv(PROCESSED / "bridgegrant_sc_data_quality_report.csv", index=False)

    print_report(df, funders)
    return 0


def print_report(df: pd.DataFrame, funders: pd.DataFrame) -> None:
    counts = load_counts()
    print("\n================ BridgeGrant SC processing report ================")
    print(f"{'year':<6}{'source':<15}{'read':>12}{'SC kept':>10}{'invalid':>9}{'superseded':>12}{'retained':>10}  status")
    clean = {(c["tax_year"], c["source_type"]): c for c in counts.get("clean_grants", [])}
    for c in counts.get("filter_south_carolina", []):
        k = (c["tax_year"], c["source_type"])
        cl = clean.get(k, {})
        status = "PARTIAL" if c["tax_year"] in PARTIAL_YEARS else "complete"
        print(f"{c['tax_year']:<6}{c['source_type']:<15}{c['rows_read']:>12,}{c['sc_kept']:>10,}"
              f"{cl.get('invalid_amount', 0):>9,}{cl.get('superseded_filing', 0):>12,}{cl.get('retained', 0):>10,}  {status}")
    print(f"\nRetained rows: {len(df):,}   total ${df['grant_amount'].sum():,.0f}")
    print("Verification status:", df["verification_status"].value_counts().to_dict())
    print("Grant types:", df["grant_type"].value_counts().to_dict())
    open_ = funders[funders["likely_open_to_applicants"] & funders["rank_standard_grants"].notna()]
    print(f"Funders: {len(funders):,} ({len(open_):,} likely open to applicants)")
    print("\nTop 10 likely-open funders (standard grants only):")
    for r in open_.head(10).itertuples():
        print(f"  {int(r.rank_standard_grants):>4}. {r.funder_name[:48]:<48} {r.funder_type:<20} "
              f"{r.standard_sc_recipients:>4} recipients  ${r.standard_total_amount:>13,.0f}")
    print(f"\nOutputs written to {PROCESSED}")


if __name__ == "__main__":
    sys.exit(main())
