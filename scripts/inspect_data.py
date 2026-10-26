"""Builds and prints the per-year column map for every NCCS table.

Column names can change between NCCS years, so each pipeline field lists the
names it may appear under. This script reads each downloaded file's real
schema (without loading the data), picks the name that exists, prints the
map and row counts, and saves it to data/interim/column_map.json for the
later steps. A required field missing from a file is an error.

Usage:
    python scripts/inspect_data.py --years 2023
"""

from __future__ import annotations

import argparse
import json
import sys

import pyarrow.parquet as pq

from common import RAW, YEARS, stage_path

# table -> field -> (required, candidate column names in preference order)
SPEC: dict[str, dict[str, tuple[bool, list[str]]]] = {
    "SI-P02-T01-GRANTS-US-ORGS-GOVTS": {
        "filing_id": (True, ["OBJECTID"]),
        "ein2": (True, ["EIN2"]),
        "funder_ein": (True, ["ORG_EIN"]),
        "tax_year": (True, ["TAX_YEAR"]),
        "source_url": (True, ["URL"]),
        "recipient_name_l1": (True, ["SI_02_GRANT_US_ORG_NAME_L1"]),
        "recipient_name_l2": (False, ["SI_02_GRANT_US_ORG_NAME_L2"]),
        "recipient_ein": (False, ["SI_02_GRANT_US_ORG_EIN"]),
        "recipient_addr_l1": (False, ["SI_02_GRANT_US_ORG_ADDR_L1"]),
        "recipient_addr_l2": (False, ["SI_02_GRANT_US_ORG_ADDR_L2"]),
        "recipient_city": (False, ["SI_02_GRANT_US_ORG_ADDR_CITY"]),
        "recipient_state": (True, ["SI_02_GRANT_US_ORG_ADDR_STATE"]),
        "recipient_zip": (False, ["SI_02_GRANT_US_ORG_ADDR_ZIP"]),
        "recipient_country": (False, ["SI_02_GRANT_US_ORG_ADDR_CNTR"]),
        "recipient_irc_section": (False, ["SI_02_GRANT_US_ORG_IRC_SECTION"]),
        "cash_amount": (True, ["SI_02_GRANT_US_ORG_AMT_CASH"]),
        "noncash_amount": (False, ["SI_02_GRANT_US_ORG_AMT_NONCSH"]),
        "noncash_desc": (False, ["SI_02_GRANT_US_ORG_DESC_NONCSH"]),
        "grant_purpose": (False, ["SI_02_GRANT_US_ORG_PURPOSE"]),
        # Fallbacks used only when a filing has no header row.
        "funder_name_grant_table": (False, ["ORG_NAME_L1"]),
        "amended_grant_table": (False, ["RETURN_AMENDED_X"]),
    },
    "PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID": {
        "filing_id": (True, ["OBJECTID"]),
        "ein2": (True, ["EIN2"]),
        "funder_ein": (True, ["ORG_EIN"]),
        "tax_year": (True, ["TAX_YEAR"]),
        "source_url": (True, ["URL"]),
        "recipient_name_l1": (True, ["PF_15_G_PAID_RECIP_NAME_ORG_L1"]),
        "recipient_name_l2": (False, ["PF_15_G_PAID_RECIP_NAME_ORG_L2"]),
        "recipient_person": (False, ["PF_15_G_PAID_RECIP_NAME_PERS"]),
        "recipient_addr_l1": (False, ["PF_15_G_PAID_RECIP_ADDR_L1"]),
        "recipient_addr_l2": (False, ["PF_15_G_PAID_RECIP_ADDR_L2"]),
        "recipient_city": (False, ["PF_15_G_PAID_RECIP_ADDR_CITY"]),
        "recipient_state": (True, ["PF_15_G_PAID_RECIP_ADDR_STATE"]),
        "recipient_zip": (False, ["PF_15_G_PAID_RECIP_ADDR_ZIP"]),
        "recipient_country": (False, ["PF_15_G_PAID_RECIP_ADDR_CNTR"]),
        "recipient_relationship": (False, ["PF_15_G_PAID_RELATIONSHIP"]),
        "recipient_status": (False, ["PF_15_G_PAID_RECIP_STAT"]),
        "cash_amount": (True, ["PF_15_G_PAID_AMT"]),
        "grant_purpose": (False, ["PF_15_G_PAID_PURPOSE"]),
        "funder_name_grant_table": (False, ["ORG_NAME_L1"]),
        "amended_grant_table": (False, ["RETURN_AMENDED_X"]),
    },
    "F9-P00-T00-HEADER": {
        "filing_id": (True, ["OBJECTID"]),
        "ein2": (True, ["EIN2"]),
        "funder_ein": (True, ["ORG_EIN", "F9_00_ORG_EIN"]),
        "tax_year": (True, ["TAX_YEAR", "F9_00_TAX_YEAR"]),
        "funder_name_l1": (True, ["F9_00_ORG_NAME_L1", "ORG_NAME_L1"]),
        "funder_name_l2": (False, ["F9_00_ORG_NAME_L2", "ORG_NAME_L2"]),
        "funder_state": (False, ["F9_00_ORG_ADDR_STATE"]),
        "return_type": (True, ["F9_00_RETURN_TYPE", "RETURN_TYPE"]),
        "amended": (True, ["RETURN_AMENDED_X", "F9_00_RETURN_AMENDED_X"]),
        "return_timestamp": (False, ["F9_00_RETURN_TIME_STAMP", "RETURN_TIME_STAMP"]),
        "tax_period_end": (False, ["F9_00_TAX_PERIOD_END_DATE", "TAX_PERIOD_END_DATE"]),
    },
    "PF-P00-T00-HEADER": {
        "filing_id": (True, ["OBJECTID"]),
        "ein2": (True, ["EIN2"]),
        "funder_ein": (True, ["ORG_EIN"]),
        "tax_year": (True, ["TAX_YEAR"]),
        "funder_name_l1": (True, ["ORG_NAME_L1"]),
        "funder_name_l2": (False, ["ORG_NAME_L2"]),
        "return_type": (True, ["RETURN_TYPE"]),
        "amended": (True, ["RETURN_AMENDED_X", "PF_00_FORM_AMENDED_RETURN_X"]),
        "return_timestamp": (False, ["RETURN_TIME_STAMP"]),
        "tax_period_end": (False, ["TAX_PERIOD_END_DATE"]),
    },
    # Return header for 990-PF filers (from the efilepf folder); has the state.
    "PF-F9-P00-T00-HEADER": {
        "filing_id": (True, ["OBJECTID"]),
        "funder_state": (True, ["F9_00_ORG_ADDR_STATE"]),
        "funder_name_l1": (False, ["F9_00_ORG_NAME_L1"]),
    },
}


def build_map(years: list[int]) -> tuple[dict, list[str]]:
    column_map: dict = {}
    problems: list[str] = []
    for year in years:
        column_map[str(year)] = {}
        for table, fields in SPEC.items():
            path = RAW / f"{table}-{year}.parquet"
            if not path.exists():
                problems.append(f"missing file data/raw/{path.name} (run scripts/download_data.py)")
                continue
            pf = pq.ParquetFile(path)
            names = set(pf.schema_arrow.names)
            mapping = {}
            for field, (required, candidates) in fields.items():
                hit = next((c for c in candidates if c in names), None)
                if hit is None and required:
                    problems.append(f"{path.name}: required field '{field}' not found (looked for {candidates})")
                mapping[field] = hit
            column_map[str(year)][table] = {"rows": pf.metadata.num_rows, "columns": mapping}
    return column_map, problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--years", type=int, nargs="+", default=YEARS)
    args = ap.parse_args(argv)
    column_map, problems = build_map(args.years)

    for year, tables in column_map.items():
        print(f"\n=== Tax year {year} ===")
        for table, info in tables.items():
            print(f"  {table}  ({info['rows']:,} rows)")
            for field, col in info["columns"].items():
                print(f"      {field:<24} <- {col or '(not in this year)'}")

    stage_path("column_map.json").write_text(json.dumps(column_map, indent=1))
    if problems:
        print("\nProblems:")
        for p in problems:
            print("  - " + p)
        return 1
    print("\nColumn map saved to data/interim/column_map.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
