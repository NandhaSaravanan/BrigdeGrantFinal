"""Step 3: keep grants whose RECIPIENT is in South Carolina, then join the
filing headers for the funder's name, state, form type and amended flag.

The national grant tables are read in batches with only the needed columns,
so a laptop never holds a whole year in memory.

Eligibility is decided by the recipient's state only (never the funder's):
- recipient state normalizes to "SC" (SC, S.C., South Carolina, S Carolina)
- and the recipient country, when given, is the US.

Rows outside SC are counted (by year and source) but not saved, except
"near misses" that deserve a look, which go to data/processed/excluded_rows.csv:
- an SC ZIP code (290xx-299xx) but a different or missing state
- an SC state but a foreign country

Outputs (data/interim/):
- sc_raw_<year>.parquet   SC candidates with original NCCS columns (src_*)
- filings_<year>.parquet  every filing (all states) for the amended-return check

Usage: python scripts/filter_south_carolina.py --years 2023
"""

from __future__ import annotations

import argparse
import json
import sys

import pandas as pd
import pyarrow.compute as pc
import pyarrow.parquet as pq

from common import (
    PROCESSED,
    RAW,
    YEARS,
    looks_like_sc_zip,
    normalize_state,
    normalize_zip,
    record_counts,
    stage_path,
)

GRANT_TABLES = {
    "schedule_i": "SI-P02-T01-GRANTS-US-ORGS-GOVTS",
    "990pf_part_xv": "PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID",
}
US_COUNTRY = {"", "US", "USA", "UNITED STATES", "UNITED STATES OF AMERICA"}
BATCH = 250_000


def column_map() -> dict:
    path = stage_path("column_map.json")
    if not path.exists():
        sys.exit("Run scripts/inspect_data.py first (data/interim/column_map.json is missing).")
    return json.loads(path.read_text())


def as_bool(s: pd.Series) -> pd.Series:
    return s.astype("string").str.strip().str.upper().isin(["TRUE", "X", "1", "YES"])


def read_headers(year: int, cmap: dict) -> pd.DataFrame:
    """One row per filing (Form 990 and 990-PF), every state."""
    frames = []
    for table, form in [("F9-P00-T00-HEADER", "990"), ("PF-P00-T00-HEADER", "990-PF")]:
        cols = cmap[str(year)][table]["columns"]
        wanted = {f: c for f, c in cols.items() if c}
        df = pq.read_table(RAW / f"{table}-{year}.parquet", columns=list(set(wanted.values()))).to_pandas()
        df = pd.DataFrame({f: df[c] for f, c in wanted.items()})
        df["funder_form_type"] = form
        if form == "990-PF":
            pfcols = cmap[str(year)]["PF-F9-P00-T00-HEADER"]["columns"]
            st = pq.read_table(
                RAW / f"PF-F9-P00-T00-HEADER-{year}.parquet",
                columns=[pfcols["filing_id"], pfcols["funder_state"]],
            ).to_pandas()
            st.columns = ["filing_id", "funder_state"]
            df = df.merge(st.drop_duplicates("filing_id"), on="filing_id", how="left")
        frames.append(df)
    h = pd.concat(frames, ignore_index=True)
    h["is_amended_return"] = as_bool(h["amended"])
    h["funder_name"] = (
        h["funder_name_l1"].astype("string").str.strip()
        + h.get("funder_name_l2", pd.Series(pd.NA, index=h.index)).astype("string").fillna("").map(lambda x: f" {x.strip()}" if x.strip() else "")
    )
    return h.drop(columns=["amended", "funder_name_l1", "funder_name_l2"], errors="ignore")


def filter_table(year: int, source: str, cmap: dict) -> tuple[pd.DataFrame, pd.DataFrame, dict]:
    table = GRANT_TABLES[source]
    cols = cmap[str(year)][table]["columns"]
    wanted = {f: c for f, c in cols.items() if c}
    pf = pq.ParquetFile(RAW / f"{table}-{year}.parquet")
    keep, misses = [], []
    counts = {"tax_year": year, "source_type": source, "rows_read": 0, "sc_kept": 0,
              "out_of_state": 0, "missing_state": 0, "foreign_country": 0, "near_miss_logged": 0}
    for batch in pf.iter_batches(batch_size=BATCH, columns=list(set(wanted.values()))):
        raw = batch.to_pandas()
        counts["rows_read"] += len(raw)
        state = raw[wanted["recipient_state"]].map(normalize_state)
        zip5 = raw[wanted["recipient_zip"]].map(normalize_zip) if "recipient_zip" in wanted else pd.Series(None, index=raw.index)
        country = (
            raw[wanted["recipient_country"]].astype("string").fillna("").str.strip().str.upper()
            if "recipient_country" in wanted else pd.Series("", index=raw.index)
        )
        is_sc = state.eq("SC")
        foreign = ~country.isin(US_COUNTRY)
        sc_zip = zip5.map(looks_like_sc_zip)

        counts["missing_state"] += int(state.isna().sum())
        counts["foreign_country"] += int((is_sc & foreign).sum())
        counts["out_of_state"] += int((~is_sc & state.notna()).sum())

        kept = raw[is_sc & ~foreign]
        counts["sc_kept"] += len(kept)
        if len(kept):
            keep.append(kept)

        near = (~is_sc & sc_zip) | (is_sc & foreign)
        if near.any():
            m = raw[near].copy()
            m["exclusion_reason"] = "sc_state_but_foreign_country"
            m.loc[~is_sc[near] & state[near].isna(), "exclusion_reason"] = "sc_zip_but_state_missing"
            m.loc[~is_sc[near] & state[near].notna(), "exclusion_reason"] = "sc_zip_but_other_state"
            misses.append(m)
            counts["near_miss_logged"] += len(m)

    sc = pd.concat(keep, ignore_index=True) if keep else pd.DataFrame(columns=list(set(wanted.values())))
    miss = pd.concat(misses, ignore_index=True) if misses else pd.DataFrame()

    # Canonical columns + the untouched original NCCS columns (src_<name>).
    out = pd.DataFrame({f: sc[c] for f, c in wanted.items()})
    for c in sorted(set(wanted.values())):
        out[f"src_{c}"] = sc[c]
    out["source_type"] = source
    out["source_table"] = f"{table}-{year}"
    if len(miss):
        miss = pd.DataFrame({
            "tax_year": year,
            "source_type": source,
            "filing_id": miss[wanted["filing_id"]],
            "funder_ein": miss[wanted["funder_ein"]],
            "recipient_name": miss[wanted["recipient_name_l1"]],
            "recipient_state_raw": miss[wanted["recipient_state"]],
            "recipient_zip_raw": miss[wanted["recipient_zip"]] if "recipient_zip" in wanted else None,
            "recipient_country_raw": miss[wanted["recipient_country"]] if "recipient_country" in wanted else None,
            "amount_raw": miss[wanted["cash_amount"]],
            "source_url": miss[wanted["source_url"]],
            "exclusion_reason": miss["exclusion_reason"],
        })
    return out, miss, counts


def run_year(year: int, cmap: dict) -> tuple[list[dict], pd.DataFrame]:
    headers = read_headers(year, cmap)
    headers.to_parquet(stage_path(f"filings_{year}.parquet"), index=False)

    parts, misses, counts = [], [], []
    for source in GRANT_TABLES:
        sc, miss, c = filter_table(year, source, cmap)
        h = headers[headers["funder_form_type"].eq("990" if source == "schedule_i" else "990-PF")]
        h = h.drop_duplicates("filing_id").drop(columns=["funder_ein", "tax_year", "ein2"], errors="ignore")
        merged = sc.merge(h, on="filing_id", how="left", indicator=True)
        merged["header_joined"] = merged["_merge"].eq("both")
        merged = merged.drop(columns="_merge")
        # Only when a filing has no header row, fall back to the grant table's own fields.
        if "funder_name_grant_table" in merged:
            merged["funder_name"] = merged["funder_name"].fillna(merged["funder_name_grant_table"])
        if "amended_grant_table" in merged:
            merged["is_amended_return"] = merged["is_amended_return"].where(
                merged["header_joined"], as_bool(merged["amended_grant_table"])
            )
        merged["funder_form_type"] = "990" if source == "schedule_i" else "990-PF"
        c["header_unmatched"] = int((~merged["header_joined"]).sum())
        parts.append(merged)
        if len(miss):
            misses.append(miss)
        counts.append(c)

    out = pd.concat(parts, ignore_index=True)
    out = out.astype({c: "string" for c in out.columns if out[c].dtype == object})
    out.to_parquet(stage_path(f"sc_raw_{year}.parquet"), index=False)
    return counts, (pd.concat(misses, ignore_index=True) if misses else pd.DataFrame())


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--years", type=int, nargs="+", default=YEARS)
    args = ap.parse_args(argv)
    cmap = column_map()
    PROCESSED.mkdir(parents=True, exist_ok=True)

    all_counts, all_misses = [], []
    for year in args.years:
        if str(year) not in cmap:
            print(f"! {year} is not in the column map; run inspect_data.py --years {year}")
            return 1
        counts, misses = run_year(year, cmap)
        all_counts += counts
        if len(misses):
            all_misses.append(misses)
        for c in counts:
            print(
                f"{year} {c['source_type']:<14} read {c['rows_read']:>10,}  SC kept {c['sc_kept']:>7,}  "
                f"out-of-state {c['out_of_state']:>10,}  missing state {c['missing_state']:>6,}  "
                f"foreign {c['foreign_country']:>4,}  near-miss logged {c['near_miss_logged']:>5,}  "
                f"no header {c['header_unmatched']:>4,}"
            )

    # Keep counts and near misses for the other years already processed.
    prior = {}
    try:
        from common import load_counts
        prior = load_counts().get("filter_south_carolina", [])
    except Exception:
        prior = []
    done = {(c["tax_year"], c["source_type"]) for c in all_counts}
    merged_counts = [c for c in prior if (c["tax_year"], c["source_type"]) not in done] + all_counts
    record_counts("filter_south_carolina", sorted(merged_counts, key=lambda c: (c["tax_year"], c["source_type"])))

    miss_path = PROCESSED / "excluded_rows.csv"
    new = pd.concat(all_misses, ignore_index=True) if all_misses else pd.DataFrame()
    if miss_path.exists():
        old = pd.read_csv(miss_path, dtype=str)
        old = old[~old["tax_year"].astype(int).isin(args.years) | ~old["exclusion_reason"].str.startswith(("sc_zip", "sc_state"))]
        new = pd.concat([old, new.astype(str)], ignore_index=True) if len(new) else old
    if len(new):
        new.to_csv(miss_path, index=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
