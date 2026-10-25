#!/usr/bin/env python3
"""T-2525: check an external-backend conformance mapping for the shared worker contract (draft format for AEF T-4752).

  wc-mapping-check.py FILE.yaml     exit 0 = valid, 1 = invalid (each problem printed), 2 = unreadable

Rules (wc/0.3 §6.6 + §9 intro): exactly one entry per CC-01..CC-25; verdict PASS | N/A | GAP; N/A only for a capability
the backend does not offer, so an N/A entry must say exercises_section3: false and give a rationale; every PASS lists
evidence; every GAP names at least one task; the header carries the §6.6 declarations.
"""
import re
import sys

import yaml

CASES = [f"CC-{i:02d}" for i in range(1, 26)]
VERDICTS = {"PASS", "N/A", "GAP"}
DECLARATIONS = {"backend", "id_scheme", "single_writer", "writer_auth", "evidence_channel", "persisted_at_source", "G"}


def check(doc):
    errs = []
    if doc.get("format") != "wc-conformance-mapping/0.1":
        errs.append("format must be wc-conformance-mapping/0.1")
    for k in ("spec_version", "spec_commit", "code_commit", "date"):
        if not doc.get(k):
            errs.append(f"header: {k} missing")
    missing = DECLARATIONS - set((doc.get("declarations") or {}).keys())
    if missing:
        errs.append(f"declarations missing: {sorted(missing)}")
    cases = doc.get("cases") or []
    ids = [c.get("id") for c in cases]
    if sorted(ids) != CASES:
        errs.append(f"cases must be exactly CC-01..CC-25 once each (got {len(ids)}, dupes/missing: "
                    f"{sorted(set(CASES) ^ set(ids)) or [i for i in ids if ids.count(i) > 1]})")
    for c in cases:
        cid, v = c.get("id"), c.get("verdict")
        if v not in VERDICTS:
            errs.append(f"{cid}: verdict {v!r} not in {sorted(VERDICTS)}")
        if not c.get("rationale"):
            errs.append(f"{cid}: rationale missing")
        if v == "PASS" and not c.get("evidence"):
            errs.append(f"{cid}: PASS without evidence")
        if v == "GAP" and not [t for t in c.get("tasks") or [] if re.match(r"^[A-Za-z0-9-]+:T-\d+$|^T-\d+$", str(t))]:
            errs.append(f"{cid}: GAP names no task")
        if v == "N/A" and c.get("exercises_section3") is not False:
            errs.append(f"{cid}: N/A is only allowed for a case that exercises no §3 row (exercises_section3: false)")
    return errs


def main():
    try:
        doc = yaml.safe_load(open(sys.argv[1]))
    except (OSError, IndexError, yaml.YAMLError) as e:
        print(f"unreadable: {e}")
        return 2
    errs = check(doc or {})
    for e in errs:
        print("INVALID", e)
    if not errs:
        n = {v: sum(c["verdict"] == v for c in doc["cases"]) for v in VERDICTS}
        print(f"OK {doc['declarations']['backend']}: PASS {n['PASS']}, N/A {n['N/A']}, GAP {n['GAP']}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
