"""Uploads data/processed/bridgegrant.db to the Supabase sc_ tables.

Create the tables first by running supabase/sc_grants.sql (Supabase SQL
Editor, or `supabase db query --linked -f supabase/sc_grants.sql`).

Rows are upserted on `id`, so rerunning after an interruption is safe and
doesn't create duplicates. Tables load in dependency order: funders,
recipients, grants, then verification_evidence.

The tables are private (RLS, no policies), so this needs the project's
service-role (secret) key. Pass it in an environment variable; never put it
in the app or commit it:

    export SUPABASE_SERVICE_ROLE_KEY="..."     (Supabase -> Project Settings -> API keys)
    python scripts/upload_to_supabase.py

SUPABASE_URL defaults to the URL in env.json.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time

import requests

from common import PROCESSED, ROOT

DB_PATH = PROCESSED / "bridgegrant.db"
TABLES = [
    ("funders", "sc_funders"),
    ("recipients", "sc_recipients"),
    ("grants", "sc_grants"),
    ("verification_evidence", "sc_verification_evidence"),
]


def supabase_url() -> str:
    url = os.environ.get("SUPABASE_URL")
    if not url:
        env = ROOT / "env.json"
        if env.exists():
            url = json.loads(env.read_text()).get("SUPABASE_URL")
    if not url:
        sys.exit("Set SUPABASE_URL (or add it to env.json).")
    return url.rstrip("/")


def headers(key: str) -> dict:
    h = {
        "apikey": key,
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    if not key.startswith("sb_"):  # legacy JWT keys also go in Authorization
        h["Authorization"] = f"Bearer {key}"
    return h


def post(url: str, hdrs: dict, rows: list[dict]) -> None:
    body = json.dumps(rows)
    for attempt in range(1, 6):
        try:
            r = requests.post(url, headers=hdrs, data=body, timeout=120)
            if r.ok:
                return
            if r.status_code < 500 and r.status_code != 429:
                sys.exit(f"Upload refused ({r.status_code}): {r.text[:500]}")
            problem = f"HTTP {r.status_code}"
        except requests.RequestException as e:
            problem = str(e)
        wait = 2 ** attempt
        print(f"    retry {attempt}/5 in {wait}s ({problem})")
        time.sleep(wait)
    sys.exit("Upload failed after 5 retries; rerun the script to continue where it stopped.")


def upload_table(con: sqlite3.Connection, base: str, hdrs: dict, src: str, dst: str, batch: int) -> int:
    info = con.execute(f"PRAGMA table_info({src})").fetchall()
    cols = [c[1] for c in info]
    bools = {c[1] for c in info if c[2].upper() == "BOOLEAN"}
    total = con.execute(f"SELECT COUNT(*) FROM {src}").fetchone()[0]
    url = f"{base}/rest/v1/{dst}?on_conflict=id"
    cur = con.execute(f"SELECT {', '.join(cols)} FROM {src} ORDER BY id")
    sent, start = 0, time.time()
    while rows := cur.fetchmany(batch):
        payload = [
            {c: (bool(v) if c in bools and v is not None else v) for c, v in zip(cols, row)}
            for row in rows
        ]
        post(url, hdrs, payload)
        sent += len(rows)
        if sent == total or sent % (batch * 25) == 0:
            print(f"  {dst}: {sent:,}/{total:,} ({time.time() - start:.0f}s)")
    return sent


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tables", nargs="+", choices=[d for _, d in TABLES], help="only these tables")
    ap.add_argument("--batch-size", type=int, default=2000)
    args = ap.parse_args(argv)

    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not key:
        sys.exit("Set SUPABASE_SERVICE_ROLE_KEY first (Supabase -> Project Settings -> API keys -> service_role / secret).")
    if not DB_PATH.exists():
        sys.exit("data/processed/bridgegrant.db is missing; run the pipeline first.")

    base, hdrs = supabase_url(), headers(key)
    with sqlite3.connect(DB_PATH) as con:
        for src, dst in TABLES:
            if args.tables and dst not in args.tables:
                continue
            upload_table(con, base, hdrs, src, dst, args.batch_size)

    # The app reads precomputed totals (supabase/sc_app_views.sql); rebuild them.
    r = requests.post(f"{base}/rest/v1/rpc/sc_refresh_aggregates", headers=hdrs, json={}, timeout=600)
    if r.ok:
        print("App totals refreshed (sc_aggregates).")
    elif r.status_code == 404:
        print("Note: sc_refresh_aggregates() not found; run supabase/sc_app_views.sql so the app sees this data.")
    else:
        sys.exit(f"Upload finished, but refreshing the app totals failed ({r.status_code}): {r.text[:300]}")
    print("Upload finished.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
