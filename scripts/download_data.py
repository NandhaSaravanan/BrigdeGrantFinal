"""Download the raw files the pipeline needs into data/raw/.

Sources
- NCCS e-file v3.1 tables (Form 990 and 990-PF). The catalog pages embed the
  real S3 links; we read them from the catalogs instead of guessing.
- Census 2020 ZCTA-to-county relationship file (ZIP -> county).
- IRS Exempt Organizations Business Master File for South Carolina.
- IRS automatic revocation list.

Files already present with the expected size are skipped, so you can rerun
this safely, or place files in data/raw/ yourself if a download fails.

Usage:
    python scripts/download_data.py                 # all years 2020-2025
    python scripts/download_data.py --years 2023    # one year
    python scripts/download_data.py --reference-only
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"

CATALOGS = {
    "990": "https://nccs.urban.org/nccs/catalogs/catalog-efile-v3_1.html",
    "990pf": "https://nccs.urban.org/nccs/catalogs/catalog-efilepf-v3_1.html",
}
# (local file prefix, NCCS table name, catalog). The 990 tables live in
# efile_v3_1/ and the 990-PF tables in efilepf_v3_1/. The 990-PF folder also
# has its own F9-P00-T00-HEADER (the return header for PF filers, which is
# where the funder's state is); it is saved as PF-F9-P00-T00-HEADER-<year>
# so it doesn't overwrite the Form 990 header.
TABLES = [
    ("SI-P02-T01-GRANTS-US-ORGS-GOVTS", "SI-P02-T01-GRANTS-US-ORGS-GOVTS", "990"),
    ("F9-P00-T00-HEADER", "F9-P00-T00-HEADER", "990"),
    ("PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID", "PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID", "990pf"),
    ("PF-P00-T00-HEADER", "PF-P00-T00-HEADER", "990pf"),
    ("PF-F9-P00-T00-HEADER", "F9-P00-T00-HEADER", "990pf"),
]
FOLDER = {"990": "/efile_v3_1/", "990pf": "/efilepf_v3_1/"}
FALLBACK_BASE = {
    "990": "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v3_1/",
    "990pf": "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efilepf_v3_1/",
}

REFERENCE = {
    "tab20_zcta520_county20_natl.txt": (
        "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/"
        "tab20_zcta520_county20_natl.txt",
        "Census ZCTA-to-county file. If this fails, open "
        "https://www.census.gov/geographies/reference-files/time-series/geo/"
        "relationship-files.2020.html, find 'ZCTA' -> 'ZCTA to County', and save "
        "the .txt file into data/raw/.",
    ),
    "eo_sc.csv": (
        "https://www.irs.gov/pub/irs-soi/eo_sc.csv",
        "IRS EO BMF for South Carolina. Download it from "
        "https://www.irs.gov/charities-non-profits/exempt-organizations-business-master-file-extract-eo-bmf "
        "(South Carolina) and save it as data/raw/eo_sc.csv.",
    ),
    "data-download-revocation.zip": (
        "https://apps.irs.gov/pub/epostcard/data-download-revocation.zip",
        "IRS automatic revocation list. Download it from "
        "https://www.irs.gov/charities-non-profits/tax-exempt-organization-search-bulk-data-downloads "
        "('Automatic Revocation of Exemption List') into data/raw/.",
    ),
}

HEADERS = {"User-Agent": "BridgeGrant research pipeline (student project)"}


def catalog_urls() -> dict[tuple[str, str], str]:
    """Maps (catalog, file name) -> URL, read from both NCCS catalog pages."""
    found: dict[tuple[str, str], str] = {}
    for kind, url in CATALOGS.items():
        try:
            html = requests.get(url, headers=HEADERS, timeout=60).text
        except requests.RequestException as e:
            print(f"  ! could not read the {kind} catalog ({e}); using the known S3 path")
            continue
        for link in re.findall(r"https://nccs-efile[^\"'<>\s)]+", html):
            for k, folder in FOLDER.items():
                if folder in link:
                    found[(k, link.rsplit("/", 1)[-1])] = link
    return found


def remote_size(url: str) -> int | None:
    try:
        r = requests.head(url, headers=HEADERS, timeout=30, allow_redirects=True)
        if r.ok and r.headers.get("Content-Length"):
            return int(r.headers["Content-Length"])
    except requests.RequestException:
        pass
    return None


def download(url: str, dest: Path) -> tuple[bool, str]:
    size = remote_size(url)
    if size is not None and size < 1000:
        size = None  # not a real size (irs.gov answers HEAD with ~20 bytes)
    if dest.exists() and size is not None and dest.stat().st_size == size:
        return True, "already downloaded"
    if dest.exists() and size is None and dest.stat().st_size > 0:
        return True, "present (could not check remote size)"
    tmp = dest.with_suffix(dest.suffix + ".part")
    try:
        with requests.get(url, headers=HEADERS, stream=True, timeout=120) as r:
            if not r.ok:
                return False, f"HTTP {r.status_code}"
            # Trust the size on the download itself (some servers, like
            # irs.gov, report a wrong size to HEAD). Compressed transfers
            # can't be size-checked this way.
            size = None
            if r.headers.get("Content-Length") and not r.headers.get("Content-Encoding"):
                size = int(r.headers["Content-Length"])
            with open(tmp, "wb") as f:
                for chunk in r.iter_content(1 << 20):
                    f.write(chunk)
    except requests.RequestException as e:
        tmp.unlink(missing_ok=True)
        return False, str(e)
    if tmp.stat().st_size == 0:
        tmp.unlink(missing_ok=True)
        return False, "empty download"
    if size is not None and tmp.stat().st_size != size:
        got = tmp.stat().st_size
        tmp.unlink(missing_ok=True)
        return False, f"incomplete download ({got} of {size} bytes)"
    tmp.rename(dest)
    return True, f"downloaded {dest.stat().st_size / 1e6:.1f} MB"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--years", type=int, nargs="+", default=list(range(2020, 2026)))
    ap.add_argument("--reference-only", action="store_true", help="only the Census/IRS reference files")
    args = ap.parse_args(argv)
    RAW.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []

    if not args.reference_only:
        print("Reading NCCS catalogs for download links...")
        links = catalog_urls()
        for year in args.years:
            for local, table, kind in TABLES:
                remote = f"{table}-{year}.parquet"
                name = f"{local}-{year}.parquet"
                url = links.get((kind, remote)) or FALLBACK_BASE[kind] + remote
                ok, msg = download(url, RAW / name)
                print(f"  {'ok ' if ok else 'ERR'} {name}: {msg}")
                if not ok:
                    failures.append(f"{name}\n      from {url}\n      save to data/raw/{name}")

    print("Reference files...")
    for name, (url, help_text) in REFERENCE.items():
        ok, msg = download(url, RAW / name)
        print(f"  {'ok ' if ok else 'ERR'} {name}: {msg}")
        if not ok:
            failures.append(f"{name}\n      {help_text}")

    if failures:
        print("\nThese files could not be downloaded. Get them manually and put them in data/raw/:")
        for f in failures:
            print("  - " + f)
        return 1
    print("\nAll requested files are in data/raw/.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
