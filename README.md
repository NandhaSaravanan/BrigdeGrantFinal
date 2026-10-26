# BridgeGrant

A Flutter app (Android, iOS, web) for exploring source-matched grant records
stored in Supabase. There is no sign-in; the app opens straight to the explorer.

**Data caveat:** records were matched to an IRS-derived source table but are
**not fully verified**, and York County location has **not** been independently
confirmed. The app labels every view accordingly.

## Data source

The app reads only these public views, created by
`../supabase_grants_setup.sql`:

`grants_public`, `grants_by_city`, `grants_by_funder`, `grants_by_recipient`,
`grants_by_zip`, `grants_by_tax_year`.

## Configuration

Two values are supplied at build/run time with `--dart-define`:

| Define              | Value                                              |
| ------------------- | -------------------------------------------------- |
| `SUPABASE_URL`      | `https://<project-ref>.supabase.co`                |
| `SUPABASE_ANON_KEY` | The project's publishable (`sb_publishable_…`) or legacy anon key |

Never use a service-role or `sb_secret_…` key. The app refuses to start
if it detects one.

Copy `env.example.json` to `env.json` (already git-ignored), fill it in, and
pass it with `--dart-define-from-file`:

```sh
flutter pub get
flutter run -d chrome --dart-define-from-file=env.json
flutter run -d <android-or-ios-device-id> --dart-define-from-file=env.json

flutter build web --release --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
flutter build ipa --release --dart-define-from-file=env.json
```

Or pass the values inline:

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

## Development

```sh
dart format lib test
flutter analyze
flutter test
```

Tests use an in-memory repository and need no network access or keys.

## South Carolina grant data pipeline (Python)

A separate Python pipeline in this folder builds a statewide dataset of IRS-reported grants to
South Carolina recipients for tax years 2020–2025 from the NCCS e-file tables (release v3.1).
It doesn't touch the Flutter app or Supabase.

### Setup (once)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Run

```bash
source .venv/bin/activate
python run_pipeline.py                  # download + process 2020-2025 (about 1.1 GB of downloads the first time)
python run_pipeline.py --skip-download  # reuse files already in data/raw/
python run_pipeline.py --years 2023     # refresh one year; outputs keep every year already processed
python -m pytest tests                  # unit tests (run from the project folder, not scripts/)
```

Each step can also be run on its own from `scripts/` (same order as `run_pipeline.py`):
`download_data.py` → `inspect_data.py` → `filter_south_carolina.py` → `clean_grants.py` →
`classify_grants.py` → `verify_grants.py` → `generate_reports.py` → `build_database.py`.
After editing `config/funder_type_rules.yaml`, rerun from `classify_grants.py` onward.

### Where the data comes from

| File | Source |
|---|---|
| `SI-P02-T01-GRANTS-US-ORGS-GOVTS-<year>.parquet`, `F9-P00-T00-HEADER-<year>.parquet` | `https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v3_1/` |
| `PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID-<year>.parquet`, `PF-P00-T00-HEADER-<year>.parquet` | `https://nccs-efile.s3.us-east-1.amazonaws.com/public/efilepf_v3_1/` |
| `PF-F9-P00-T00-HEADER-<year>.parquet` | `efilepf_v3_1/F9-P00-T00-HEADER-<year>.parquet` (the 990-PF filers' return header, which has the funder's state; renamed so it doesn't overwrite the Form 990 header) |
| `tab20_zcta520_county20_natl.txt` | Census 2020 ZCTA-to-county relationship file |
| `eo_sc.csv` | IRS EO Business Master File, South Carolina |
| `data-download-revocation.zip` | IRS automatic revocation list |

If a download fails, `download_data.py` prints exactly which file to get and from where; save it in
`data/raw/` under the same name and rerun.

### Outputs (`data/processed/`)

- `bridgegrant_sc_2020_2025_all_candidates.csv`: every retained SC grant with all flags, statuses, and the original NCCS columns (`src_*`)
- `bridgegrant_sc_2020_2025_verified_only.csv`: `fully_verified` rows only (small by design: only the XML-sampled rows can qualify)
- `bridgegrant_sc_funders.csv`: one row per funder; ranked on standard grants only, and only funders likely open to applicants get a rank
- `bridgegrant_sc_county_summary.csv`: by county and year, with multi-county and unknown ZIPs as their own categories
- `bridgegrant_sc_data_quality_report.csv`: counts read, excluded (by reason), and retained, by year and source, plus missing fields and verification results
- `excluded_rows.csv` (near misses such as an SC ZIP with another state), `duplicates_log.csv` (superseded filings), `review_invalid_amounts.csv`
- `bridgegrant.db`: SQLite (`funders`, `recipients`, `grants`, `verification_evidence`); `prisma/schema.prisma` matches it

### Things to know when using the data

- **2024 and 2025 are partial.** NCCS keeps adding late and extended returns for 2–3 years, so lower totals in those years are not real declines.
- **Eligibility is by recipient state**, never the funder's. Counties come only from ZIP codes: a ZIP that crosses county lines gets no county (its candidates are listed), and PO-box ZIPs (not Census ZCTAs) are `unverified`.
- **Amended returns:** when a funder filed more than one return for the same tax year and tax period, only the amended (or most recent) one is kept; the other's rows are in `duplicates_log.csv`.
- **Flags, not deletions:** donor-advised fund sponsors, AmazonSmile, national pass-throughs, matching gifts, grants to individuals, and in-kind grants stay in the data but are excluded from funder rankings. The rules are in `config/funder_type_rules.yaml`.
- **Verification:** `fully_verified` needs the original IRS XML check (a random sample, stratified by year and source), a recipient EIN found in the IRS SC master file with a matching name, and an SC address there. 990-PF grant tables have no recipient EINs, so 990-PF rows can't reach `recipient_identity_verified` this way.

### Using the database from Next.js (Prisma)

`prisma/schema.prisma` is generated to match `bridgegrant.db`. To check it against the real file instead:

```bash
npm install prisma @prisma/client
npx prisma db pull     # reads data/processed/bridgegrant.db via the datasource url in the schema
npx prisma generate
```
