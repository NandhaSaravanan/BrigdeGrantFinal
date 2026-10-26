"""Step 5: flag funder, grant and recipient types (nothing is deleted).

funder_type   from config/funder_type_rules.yaml (first matching rule wins),
              else private_family for 990-PF filers, public_charity for 990.
grant_type    matching_gift  purpose mentions "match"
              individual     a named person (990-PF person field, or no EIN and
                             the name looks like a person)
              in_kind        mostly noncash
              standard       everything else
recipient_type  individual, government, school_university, church,
              nonprofit (has an EIN or an organization-style name), unknown

Output: data/interim/classified.parquet
"""

from __future__ import annotations

import re
import sys
from functools import lru_cache

import pandas as pd
import yaml

from common import CONFIG, looks_like_person, record_counts, stage_path

RULES_PATH = CONFIG / "funder_type_rules.yaml"


@lru_cache(maxsize=1)
def load_rules() -> dict:
    rules = yaml.safe_load(RULES_PATH.read_text())
    compiled = []
    for ftype, spec in rules["funder_types"].items():
        pats = [re.compile(p) for p in spec.get("patterns") or []]
        pats += [re.compile(r"\b" + re.escape(n.upper()) + r"\b") for n in spec.get("names") or []]
        compiled.append((ftype, pats, {str(e).zfill(9) for e in spec.get("eins") or []}))
    return {
        "funder": compiled,
        "matching": [re.compile(p, re.I) for p in rules.get("matching_gift_patterns") or []],
        "recipient": [(t, [re.compile(p) for p in pats]) for t, pats in rules.get("recipient_types", {}).items()],
    }


def funder_type(name_clean: str | None, ein: str | None, form: str | None) -> tuple[str, str]:
    """(type, reason). EIN rules win over name rules."""
    rules = load_rules()["funder"]
    for ftype, _, eins in rules:
        if ein and ein in eins:
            return ftype, f"ein rule ({ftype})"
    for ftype, pats, _ in rules:
        for p in pats:
            if name_clean and p.search(name_clean):
                return ftype, f"name rule: {p.pattern}"
    if form == "990-PF":
        return "private_family", "default for 990-PF filers"
    return "public_charity", "default for Form 990 filers"


def grant_type(purpose: str | None, is_person: bool, mostly_noncash: bool) -> str:
    if purpose and any(p.search(purpose) for p in load_rules()["matching"]):
        return "matching_gift"
    if is_person:
        return "individual"
    if mostly_noncash:
        return "in_kind"
    return "standard"


def recipient_type(name_clean: str | None, ein: str | None, is_person: bool) -> str:
    if is_person:
        return "individual"
    for rtype, pats in load_rules()["recipient"]:
        if name_clean and any(p.search(name_clean) for p in pats):
            return rtype
    if ein or (name_clean and not looks_like_person(name_clean)):
        return "nonprofit"
    return "unknown"


_PERSON_STATUS = {"I", "IND", "INDIVIDUAL"}
_BLANK_STATUS = {"", "NONE", "N/A", "NA", "-", "NAN"}


def is_individual(row) -> bool:
    """A grant to a person.

    990-PF rows carry a recipient status: "I" means an individual and codes
    like PC, GOV or 501(C)(3) mean an organization, so the status decides
    when it is filled in. Only when it is blank do we fall back to the name:
    no EIN and a name that looks like a person's. Filers often type
    organization names into the 990-PF person field, so that field alone
    isn't trusted. Schedule I lists organizations and governments, so its
    rows count as individuals only with no EIN, no IRC section and a
    person-like name.
    """
    status = str(row.recipient_status or "").strip().upper()
    if status in _PERSON_STATUS:
        return True
    if status not in _BLANK_STATUS:
        return False
    if row.recipient_ein:
        return False
    if row.source_type == "schedule_i" and row.recipient_irc_section:
        return False
    return looks_like_person(row.recipient_name_clean)


def main() -> int:
    df = pd.read_parquet(stage_path("clean.parquet"))
    for col in ("recipient_status", "recipient_irc_section"):
        if col not in df:
            df[col] = pd.NA

    ft = [funder_type(n, e, f) for n, e, f in zip(df["funder_name_clean"], df["funder_ein"], df["funder_form_type"])]
    df["funder_type"] = [t for t, _ in ft]
    df["funder_type_reason"] = [r for _, r in ft]

    cols = ["recipient_status", "recipient_ein", "recipient_irc_section", "recipient_name_clean", "source_type"]
    person = [is_individual(r) for r in df[cols].astype(object).where(df[cols].notna(), None).itertuples(index=False)]
    df["recipient_is_individual"] = person
    df["grant_type"] = [
        grant_type(p if isinstance(p, str) else None, i, bool(n))
        for p, i, n in zip(df["grant_purpose"], person, df["is_mostly_noncash"])
    ]
    df["recipient_type"] = [
        recipient_type(n if isinstance(n, str) else None, e if isinstance(e, str) else None, i)
        for n, e, i in zip(df["recipient_name_clean"], df["recipient_ein"], person)
    ]
    df.to_parquet(stage_path("classified.parquet"), index=False)

    rows = []
    for col in ("funder_type", "grant_type", "recipient_type"):
        vc = df[col].value_counts()
        print(f"  {col}: {vc.to_dict()}")
        rows += [{"flag": col, "value": k, "rows": int(v)} for k, v in vc.items()]
    record_counts("classify_grants", rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
