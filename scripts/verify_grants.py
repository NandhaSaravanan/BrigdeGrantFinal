"""Step 6: verification. Each check has its own status column, and every check
on every row is written to the verification_evidence table.

Checks
- source_table_match        the row came from an NCCS e-file table (all rows)
- irs_filing_verified       the original IRS XML (source_url) lists a grant to
                            this recipient for this amount in this tax year.
                            Only a random sample stratified by tax year and
                            source type is fetched (default 300 rows), politely.
- recipient_identity_verified  recipient EIN is in the IRS EO Business Master
                            File for SC and the names are similar
- sc_address_verified       the BMF address for that EIN is in SC
- county_verified           the ZIP lies in exactly one county (ZCTA file)
- recipient_exemption_revoked  EIN is on the IRS automatic revocation list
                            without a reinstatement date (a warning flag)

verification_status
- fully_verified      irs_filing AND recipient_identity AND sc_address all true
- partially_verified  at least one of those three is true
- unverified          none of them is true (only the source table match)

Usage: python scripts/verify_grants.py [--sample-size 300] [--delay 0.5] [--skip-xml]
"""

from __future__ import annotations

import argparse
import math
import sys
import time
import zipfile

import pandas as pd
import requests
from lxml import etree
from rapidfuzz import fuzz

from common import RAW, clean_name, normalize_ein_series, normalize_zip, record_counts, stage_path, today

XML_CACHE = RAW / "xml_cache"
NAME_MATCH = 85  # rapidfuzz token_set_ratio threshold for EIN-name checks
XML_NAME_MATCH = 80  # slightly looser: XML names are often truncated in NCCS
HEADERS = {"User-Agent": "BridgeGrant research pipeline (student project)"}
NCCS_BASE = "https://nccs-efile.s3.us-east-1.amazonaws.com/public/"
BMF_URL = "https://www.irs.gov/pub/irs-soi/eo_sc.csv"
REVOCATION_URL = "https://apps.irs.gov/pub/epostcard/data-download-revocation.zip"
ZCTA_URL = "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_county20_natl.txt"


# ------------------------------------------------------------ reference data

def load_bmf() -> pd.DataFrame:
    path = RAW / "eo_sc.csv"
    if not path.exists():
        sys.exit("data/raw/eo_sc.csv is missing; run scripts/download_data.py --reference-only")
    bmf = pd.read_csv(path, dtype=str, usecols=["EIN", "NAME", "STREET", "CITY", "STATE", "ZIP"])
    bmf["ein"] = normalize_ein_series(bmf["EIN"])
    bmf["bmf_name_clean"] = bmf["NAME"].map(clean_name)
    bmf["bmf_zip"] = bmf["ZIP"].map(normalize_zip)
    return bmf.dropna(subset=["ein"]).drop_duplicates("ein").rename(
        columns={"NAME": "bmf_name", "CITY": "bmf_city", "STATE": "bmf_state", "STREET": "bmf_street"}
    )[["ein", "bmf_name", "bmf_name_clean", "bmf_street", "bmf_city", "bmf_state", "bmf_zip"]]


def load_revocations(eins: set[str]) -> pd.DataFrame:
    path = RAW / "data-download-revocation.zip"
    if not path.exists():
        print("  ! revocation list missing; revocation check skipped (run download_data.py --reference-only)")
        return pd.DataFrame(columns=["ein", "revocation_date", "reinstatement_date"])
    with zipfile.ZipFile(path) as z:
        with z.open(z.namelist()[0]) as f:
            rev = pd.read_csv(f, sep="|", header=None, dtype=str, usecols=[0, 9, 11], quoting=3,
                              names=["ein", "revocation_date", "reinstatement_date"], encoding="latin-1")
    rev["ein"] = normalize_ein_series(rev["ein"])
    return rev[rev["ein"].isin(eins)].drop_duplicates("ein", keep="last")


# ------------------------------------------------------------- IRS XML check

def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _text(el, *path: str) -> str | None:
    """Text of the first descendant matching the local-name path."""
    nodes = [el]
    for name in path:
        nodes = [c for n in nodes for c in n.iter() if _local(c.tag) == name]
        if not nodes:
            return None
    return (nodes[0].text or "").strip() or None


def parse_filing(path) -> tuple[str | None, list[dict]]:
    """(tax year, grants) from a 990 or 990-PF XML, streaming large files."""
    year, grants = None, []
    for _, el in etree.iterparse(str(path), events=("end",), huge_tree=True):
        tag = _local(el.tag)
        if tag == "TaxYr" and year is None:
            year = (el.text or "").strip()
        elif tag in ("RecipientTable", "GrantOrContributionPdDurYrGrp"):
            name = " ".join(
                t for t in (
                    _text(el, "BusinessNameLine1Txt") or _text(el, "BusinessNameLine1"),
                    _text(el, "BusinessNameLine2Txt"),
                ) if t
            ) or _text(el, "RecipientPersonNm") or ""
            amt = lambda *names: next((float(v) for n in names if (v := _text(el, n)) not in (None, "")), 0.0)  # noqa: E731
            grants.append({
                "name": name,
                "cash": amt("CashGrantAmt", "Amt", "AmountOfCashGrant", "Amount"),
                "noncash": amt("NonCashAssistanceAmt", "AmountOfNonCashAssistance"),
            })
            el.clear()
    return year, grants


def fetch_xml(url: str, filing_id: str, delay: float) -> tuple[object | None, str]:
    XML_CACHE.mkdir(parents=True, exist_ok=True)
    path = XML_CACHE / f"{filing_id}.xml"
    if path.exists() and path.stat().st_size > 0:
        return path, "cached"
    time.sleep(delay)
    try:
        with requests.get(url, headers=HEADERS, stream=True, timeout=120) as r:
            if not r.ok:
                return None, f"HTTP {r.status_code}"
            tmp = path.with_suffix(".part")
            with open(tmp, "wb") as f:
                for chunk in r.iter_content(1 << 20):
                    f.write(chunk)
            tmp.rename(path)
    except requests.RequestException as e:
        return None, f"fetch failed: {e}"
    return path, "fetched"


def check_xml(row, parsed: dict, delay: float) -> tuple[str, str]:
    """(result, notes) for one sampled row."""
    if row.filing_id not in parsed:
        path, how = fetch_xml(row.source_url, row.filing_id, delay)
        if path is None:
            parsed[row.filing_id] = ("fetch_error", how)
        else:
            try:
                parsed[row.filing_id] = parse_filing(path)
            except etree.XMLSyntaxError as e:
                parsed[row.filing_id] = ("parse_error", str(e)[:200])
    got = parsed[row.filing_id]
    if isinstance(got[0], str) and got[0] in ("fetch_error", "parse_error"):
        return got[0], got[1]
    year, grants = got
    if str(year) != str(row.tax_year):
        return "year_mismatch", f"XML TaxYr {year} vs record {row.tax_year}"
    want_name = clean_name(row.recipient_name) or ""
    cash = row.cash_amount if pd.notna(row.cash_amount) else 0.0
    noncash = row.noncash_amount if pd.notna(row.noncash_amount) else 0.0
    best = (0, None)
    for g in grants:
        if abs(g["cash"] - cash) > 0.5 or abs(g["noncash"] - noncash) > 0.5:
            continue
        score = fuzz.token_set_ratio(want_name, clean_name(g["name"]) or "")
        if score > best[0]:
            best = (score, g)
    if best[1] is not None and best[0] >= XML_NAME_MATCH:
        return "verified", f"XML lists '{best[1]['name']}' ${cash + noncash:,.0f} (name score {best[0]:.0f}); TaxYr {year}"
    if best[1] is not None:
        return "name_mismatch", f"amount found but closest name '{best[1]['name']}' scored {best[0]:.0f}"
    return "no_matching_grant", f"no grant of ${cash + noncash:,.0f} among {len(grants)} grants in the XML"


def stratified_sample(df: pd.DataFrame, total: int, seed: int = 2026) -> pd.DataFrame:
    groups = df.groupby(["tax_year", "source_type"])
    per = math.ceil(total / max(groups.ngroups, 1))
    parts = [g.sample(min(per, len(g)), random_state=seed) for _, g in groups]
    sample = pd.concat(parts)
    if len(sample) < total:  # small strata: top up from the rest
        rest = df.drop(sample.index)
        sample = pd.concat([sample, rest.sample(min(total - len(sample), len(rest)), random_state=seed)])
    return sample


# ---------------------------------------------------------------------- main

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample-size", type=int, default=300)
    ap.add_argument("--delay", type=float, default=0.5, help="seconds between IRS XML requests")
    ap.add_argument("--skip-xml", action="store_true", help="reuse no XML checks (all 'not_sampled')")
    args = ap.parse_args(argv)

    df = pd.read_parquet(stage_path("classified.parquet"))
    checked = today()
    evidence: list[pd.DataFrame] = []

    def add_evidence(ids, check, url, result, notes):
        evidence.append(pd.DataFrame({
            "record_id": ids.values, "check_name": check, "source_url": url,
            "check_date": checked, "result": result, "notes": notes,
        }))

    # 1. Source table match: every row came from an NCCS table.
    df["source_table_match"] = True
    add_evidence(df["record_id"], "source_table_match",
                 NCCS_BASE + df["source_table"].map(lambda t: ("efile_v3_1/" if t.startswith("SI") else "efilepf_v3_1/") + t + ".parquet"),
                 "verified", "row read from " + df["source_table"])

    # 2. Recipient identity and SC address (IRS BMF for SC).
    bmf = load_bmf()
    m = df[["record_id", "recipient_ein", "recipient_name_clean"]].merge(bmf, left_on="recipient_ein", right_on="ein", how="left")
    score = [
        fuzz.token_set_ratio(a or "", b or "") if isinstance(b, str) else None
        for a, b in zip(m["recipient_name_clean"].fillna(""), m["bmf_name_clean"])
    ]
    m["name_score"] = score
    in_bmf = m["ein"].notna()
    identity = pd.Series("no_recipient_ein", index=m.index)
    identity[m["recipient_ein"].notna()] = "ein_not_in_sc_bmf"
    identity[in_bmf] = "name_mismatch"
    identity[in_bmf & (m["name_score"].fillna(0) >= NAME_MATCH)] = "verified"
    df["recipient_identity_check"] = identity.values
    df["recipient_identity_verified"] = (identity == "verified").values
    df["bmf_name"] = m["bmf_name"].values
    df["bmf_name_score"] = m["name_score"].values
    df["sc_address_verified"] = (in_bmf & m["bmf_state"].eq("SC")).values
    df["bmf_city"] = m["bmf_city"].values
    df["bmf_zip"] = m["bmf_zip"].values
    notes = [
        f"BMF name '{n}' score {s:.0f}" if isinstance(n, str) else ("EIN not in IRS SC BMF" if isinstance(e, str) else "no recipient EIN reported")
        for n, s, e in zip(m["bmf_name"], m["name_score"].fillna(0), m["recipient_ein"])
    ]
    add_evidence(df["record_id"], "recipient_identity_verified", BMF_URL, df["recipient_identity_check"], notes)
    add_evidence(df["record_id"], "sc_address_verified", BMF_URL,
                 df["sc_address_verified"].map({True: "verified", False: "not_verified"}),
                 [f"BMF address {c}, SC {z}" if isinstance(c, str) else "no BMF record for this EIN" for c, z in zip(df["bmf_city"], df["bmf_zip"])])

    # 3. Revocation flag.
    rev = load_revocations(set(df["recipient_ein"].dropna()))
    revoked = rev[rev["reinstatement_date"].isna()]
    df["recipient_exemption_revoked"] = df["recipient_ein"].isin(set(revoked["ein"]))
    df = df.merge(revoked[["ein", "revocation_date"]].rename(columns={"ein": "recipient_ein", "revocation_date": "recipient_revocation_date"}),
                  on="recipient_ein", how="left")
    has_ein = df["recipient_ein"].notna()
    add_evidence(df.loc[has_ein, "record_id"], "recipient_exemption_revoked", REVOCATION_URL,
                 df.loc[has_ein, "recipient_exemption_revoked"].map({True: "revoked", False: "not_on_list"}),
                 df.loc[has_ein, "recipient_revocation_date"].map(lambda d: f"revoked {d}" if isinstance(d, str) else "not on the revocation list without reinstatement"))

    # 4. County.
    df["county_verified"] = df["county_status"].eq("zip_single_county")
    add_evidence(df["record_id"], "county_verified", ZCTA_URL, df["county_status"],
                 df["county_candidates"].fillna("ZIP missing, invalid, or not a Census ZCTA in SC"))

    # 5. IRS XML filing check on a stratified random sample.
    df["irs_filing_check"] = "not_sampled"
    if not args.skip_xml:
        sample = stratified_sample(df, args.sample_size)
        print(f"  Checking {len(sample)} sampled rows against the original IRS XML "
              f"({sample['filing_id'].nunique()} filings, {args.delay}s between requests)...")
        parsed: dict = {}
        results = []
        for i, row in enumerate(sample.itertuples(), 1):
            results.append(check_xml(row, parsed, args.delay))
            if i % 50 == 0:
                print(f"    {i}/{len(sample)}")
        df.loc[sample.index, "irs_filing_check"] = [r for r, _ in results]
        add_evidence(sample["record_id"], "irs_filing_verified", sample["source_url"],
                     [r for r, _ in results], [n for _, n in results])
    df["irs_filing_verified"] = df["irs_filing_check"].eq("verified")

    strong = df[["irs_filing_verified", "recipient_identity_verified", "sc_address_verified"]]
    df["verification_status"] = "unverified"
    df.loc[strong.any(axis=1), "verification_status"] = "partially_verified"
    df.loc[strong.all(axis=1), "verification_status"] = "fully_verified"

    df.to_parquet(stage_path("verified.parquet"), index=False)
    ev = pd.concat(evidence, ignore_index=True)
    ev.to_parquet(stage_path("verification_evidence.parquet"), index=False)

    sampled = df[df["irs_filing_check"] != "not_sampled"]
    rate = sampled["irs_filing_verified"].mean() if len(sampled) else float("nan")
    summary = [
        {"metric": "rows", "value": len(df)},
        {"metric": "recipient_identity_verified", "value": int(df["recipient_identity_verified"].sum())},
        {"metric": "sc_address_verified", "value": int(df["sc_address_verified"].sum())},
        {"metric": "county_verified", "value": int(df["county_verified"].sum())},
        {"metric": "recipient_exemption_revoked", "value": int(df["recipient_exemption_revoked"].sum())},
        {"metric": "xml_sample_size", "value": len(sampled)},
        {"metric": "xml_sample_verified", "value": int(sampled["irs_filing_verified"].sum())},
        {"metric": "xml_sample_match_rate", "value": round(float(rate), 4) if len(sampled) else None},
    ]
    summary += [{"metric": f"xml_result_{k}", "value": int(v)} for k, v in sampled["irs_filing_check"].value_counts().items()]
    summary += [{"metric": f"xml_rate_{y}_{s}", "value": round(float(g['irs_filing_verified'].mean()), 4)}
                for (y, s), g in sampled.groupby(["tax_year", "source_type"])]
    summary += [{"metric": f"status_{k}", "value": int(v)} for k, v in df["verification_status"].value_counts().items()]
    record_counts("verify_grants", summary)
    for s in summary:
        print(f"  {s['metric']}: {s['value']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
