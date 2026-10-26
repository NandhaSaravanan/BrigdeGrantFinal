"""Runs every BridgeGrant SC pipeline step in order.

    python run_pipeline.py                      # all years 2020-2025
    python run_pipeline.py --years 2023         # refresh one year; outputs still
                                                # include every year already processed
    python run_pipeline.py --skip-download      # use files already in data/raw/
    python run_pipeline.py --sample-size 600    # bigger IRS XML check sample

Stops at the first step that fails.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"


def run(step: str, *args: str) -> None:
    print(f"\n=== {step} {' '.join(args)}".rstrip())
    start = time.time()
    result = subprocess.run([sys.executable, str(SCRIPTS / f"{step}.py"), *args], cwd=SCRIPTS)
    if result.returncode != 0:
        sys.exit(f"\n{step} failed (exit code {result.returncode}). Fix the problem above and rerun.")
    print(f"--- {step} done in {time.time() - start:.0f}s")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--years", nargs="+", default=[str(y) for y in range(2020, 2026)])
    ap.add_argument("--skip-download", action="store_true")
    ap.add_argument("--sample-size", default="300")
    ap.add_argument("--delay", default="0.5", help="seconds between IRS XML requests")
    args = ap.parse_args()

    years = ["--years", *args.years]
    if not args.skip_download:
        run("download_data", *years)
    run("inspect_data", *years)
    run("filter_south_carolina", *years)
    # Combines every year filtered so far, not just --years.
    run("clean_grants")
    run("classify_grants")
    run("verify_grants", "--sample-size", args.sample_size, "--delay", args.delay)
    run("generate_reports")
    run("build_database")
    print("\nPipeline finished. Outputs are in data/processed/.")


if __name__ == "__main__":
    main()
