#!/usr/bin/env python3
"""Reader for an external backend's conformance mapping (T-4752).

An external backend (spec v0.3.3 §6.6) publishes, for every §9 case CC-01..CC-25, a
verdict PASS | N/A | GAP. The format is ring20's draft `wc-conformance-mapping/0.1`
(their scripts/wc-mapping-check.py, received under docs/reports/T-4752/received/).
This is a reimplementation of that checker's rules, not a copy, with one change the
spec owners are asked to adopt (docs/reports/T-4752/spec-proposal.md): whether a case
may be N/A is read from the spec's own table, `applicability.n_a_allowed` in
vectors.yaml, never from the backend's `exercises_section3` declaration.

Rules: format and header present; spec_version a wc/0.3 revision; the seven §6.6
declarations present and non-empty, G a number; cases exactly CC-01..CC-25 once each;
verdict PASS | N/A | GAP; every case has a rationale; PASS lists evidence; GAP names a
task (T-N or project:T-N); N/A only where the vectors allow it; a declared
exercises_section3 that contradicts the vectors is refused.

Usage: check_mapping.py MAPPING.yaml [vectors.yaml]
       exit 0 = valid, 1 = invalid, 2 = unreadable
Stdlib + PyYAML only.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
DEFAULT_VECTORS = HERE / "vectors.yaml"

FORMAT = "wc-conformance-mapping/0.1"
REQUIRED_IDS = [f"CC-{i:02d}" for i in range(1, 26)]
VERDICTS = {"PASS", "N/A", "GAP"}
HEADER = ("spec_version", "spec_commit", "code_commit", "date")
DECLARATIONS = ("backend", "id_scheme", "single_writer", "writer_auth",
                "evidence_channel", "persisted_at_source", "G")
SPEC_VERSION = re.compile(r"^wc/0\.3(\.\d+)?$")
TASK_REF = re.compile(r"^([A-Za-z0-9-]+:)?T-\d+$")


def na_table(vectors_doc) -> dict[str, bool]:
    """Case id -> may be N/A, from the vectors' applicability blocks (the §9 table)."""
    table = {}
    for vec in (vectors_doc or {}).get("vectors") or []:
        if isinstance(vec, dict) and isinstance(vec.get("applicability"), dict):
            table[vec.get("id")] = vec["applicability"].get("n_a_allowed") is True
    return table


def _str_list(value) -> bool:
    return (isinstance(value, list) and bool(value)
            and all(isinstance(v, str) and v.strip() for v in value))


def check(doc, table: dict[str, bool]) -> list[str]:
    errs: list[str] = []
    if not isinstance(doc, dict):
        return ["file: top level must be a mapping"]
    if doc.get("format") != FORMAT:
        errs.append(f"header: format must be {FORMAT}")
    for key in HEADER:
        if not doc.get(key):
            errs.append(f"header: {key} missing")
    sv = doc.get("spec_version")
    if sv and not (isinstance(sv, str) and SPEC_VERSION.match(sv)):
        errs.append(f"header: spec_version {sv!r} is not a wc/0.3 revision")

    decl = doc.get("declarations")
    if not isinstance(decl, dict):
        errs.append("declarations must be a mapping")
        decl = {}
    for key in DECLARATIONS:
        val = decl.get(key)
        if key == "G":
            if isinstance(val, bool) or not isinstance(val, (int, float)):
                errs.append("declarations: G must be a number (seconds)")
        elif not (isinstance(val, str) and val.strip()):
            errs.append(f"declarations: {key} missing or empty")
    if decl.get("backend") in ("hub", "local"):
        errs.append("declarations: backend must be a registered name other than hub and local")

    cases = doc.get("cases")
    if not isinstance(cases, list):
        errs.append("cases must be a list")
        return errs
    seen: dict[str, int] = {}
    for i, case in enumerate(cases):
        if not isinstance(case, dict):
            errs.append(f"cases[{i}]: must be a mapping")
            continue
        cid = case.get("id")
        where = cid if isinstance(cid, str) else f"cases[{i}]"
        if cid not in REQUIRED_IDS:
            errs.append(f"{where}: not a §9 case id")
        elif cid in seen:
            errs.append(f"{cid}: duplicate id")
        else:
            seen[cid] = i
        _check_case(where, case, table, errs)
    missing = [c for c in REQUIRED_IDS if c not in seen]
    if missing:
        errs.append(f"cases: missing {', '.join(missing)}")
    return errs


def _check_case(where: str, case: dict, table: dict[str, bool], errs: list[str]) -> None:
    verdict = case.get("verdict")
    if verdict not in VERDICTS:
        errs.append(f"{where}: verdict {verdict!r} not in {sorted(VERDICTS)}")
    if not (isinstance(case.get("rationale"), str) and case["rationale"].strip()):
        errs.append(f"{where}: rationale missing")
    if verdict == "PASS" and not _str_list(case.get("evidence")):
        errs.append(f"{where}: PASS without evidence")
    if "evidence" in case and verdict != "PASS" and not _str_list(case.get("evidence")):
        errs.append(f"{where}: evidence must be a non-empty list of strings")
    if verdict == "GAP":
        tasks = case.get("tasks")
        if not (_str_list(tasks) and any(TASK_REF.match(t) for t in tasks)):
            errs.append(f"{where}: GAP names no task")
    cid = case.get("id")
    if cid not in table:
        return
    allowed = table[cid]
    if verdict == "N/A" and not allowed:
        errs.append(f"{where}: N/A not allowed — the §9 table (vectors.yaml applicability) "
                    f"says this case exercises a §3 row")
    declared = case.get("exercises_section3")
    if declared is not None and declared is not (not allowed):
        errs.append(f"{where}: exercises_section3: {declared!r} contradicts the §9 table "
                    f"(exercises a §3 row: {not allowed})")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: check_mapping.py MAPPING.yaml [vectors.yaml]", file=sys.stderr)
        return 2
    path = Path(argv[1])
    vectors = Path(argv[2]) if len(argv) > 2 else DEFAULT_VECTORS
    try:
        doc = yaml.safe_load(path.read_text())
        table = na_table(yaml.safe_load(vectors.read_text()))
    except (OSError, yaml.YAMLError) as exc:
        print(f"check_mapping: cannot read: {exc}", file=sys.stderr)
        return 2
    if sorted(table) != REQUIRED_IDS:
        print(f"check_mapping: {vectors} has no applicability for every case", file=sys.stderr)
        return 2
    errors = check(doc, table)
    if errors:
        for e in errors:
            print(f"INVALID {e}", file=sys.stderr)
        print(f"check_mapping: {len(errors)} error(s) in {path}", file=sys.stderr)
        return 1
    n = {v: sum(c["verdict"] == v for c in doc["cases"]) for v in ("PASS", "N/A", "GAP")}
    print(f"check_mapping: OK — {doc['declarations']['backend']}: "
          f"PASS {n['PASS']}, N/A {n['N/A']}, GAP {n['GAP']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
