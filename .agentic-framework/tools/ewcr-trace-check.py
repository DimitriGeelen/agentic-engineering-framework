#!/usr/bin/env python3
"""EWCR Arc 0 — fence for the §13 invariant traceability matrix (T-3393).

Exit 0 only when every row of traceability.yaml resolves:

  * exactly 20 rows, ids 1..20 each once;
  * every statement matches architecture §13 VERBATIM (the matrix cannot drift
    from the invariant it claims to trace);
  * status is covered or gap, never absent;
  * covered rows: contract file exists, the named section string is present in
    it, refusal scenario / component / fence are non-empty, the fence script
    exists, and reason_code is in the frozen refusal enum;
  * gap rows: a reason is stated, and any expected_reason_code is in the enum.

A contract naming a reason_code the schema does not know is a contract nothing
can honour — that is why the enum check is here and not advisory.

Usage: ewcr-trace-check.py [--file PATH]   (--file lets control legs point at a
                                            deliberately mutated copy)
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTRACTS = ROOT / "docs/research/executable-workflow/contracts/v1"
ARCH = ROOT / "docs/research/executable-workflow/architecture-c9070637.md"
DEFAULT_MATRIX = CONTRACTS / "traceability.yaml"
EXPECTED_ROWS = 20


def fail(errors):
    for e in errors:
        print(f"FAIL: {e}", file=sys.stderr)
    print(f"\n{len(errors)} problem(s) — traceability matrix does not resolve.", file=sys.stderr)
    return 1


def arch_invariants():
    """Parse the numbered list under '## 13. Initial acceptance scenarios'."""
    text = ARCH.read_text(encoding="utf-8")
    m = re.search(r"^## 13\. Initial acceptance scenarios\s*$(.*?)^## ", text,
                  re.S | re.M)
    if not m:
        return {}
    out = {}
    for line in m.group(1).splitlines():
        lm = re.match(r"^(\d+)\.\s+(.*\S)\s*$", line)
        if lm:
            out[int(lm.group(1))] = lm.group(2)
    return out


def refusal_enum():
    schema = json.loads((CONTRACTS / "refusal.schema.json").read_text(encoding="utf-8"))
    return set(schema["properties"]["reason_code"]["enum"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default=str(DEFAULT_MATRIX))
    args = ap.parse_args()

    try:
        import yaml
    except ImportError:
        print("FAIL: PyYAML is required", file=sys.stderr)
        return 1

    path = Path(args.file)
    if not path.exists():
        print(f"FAIL: matrix not found: {path}", file=sys.stderr)
        return 1

    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    rows = data.get("invariants")
    if not isinstance(rows, list):
        print("FAIL: matrix has no 'invariants:' list", file=sys.stderr)
        return 1

    errors = []
    arch = arch_invariants()
    if len(arch) != EXPECTED_ROWS:
        errors.append(
            f"architecture §13 parsed {len(arch)} scenarios, expected {EXPECTED_ROWS} "
            "— the matrix's own source moved")

    ids = [r.get("id") for r in rows]
    if len(rows) != EXPECTED_ROWS:
        errors.append(f"{len(rows)} rows, expected {EXPECTED_ROWS}")
    missing = [i for i in range(1, EXPECTED_ROWS + 1) if i not in ids]
    if missing:
        errors.append(f"missing invariant id(s): {missing}")
    dupes = sorted({i for i in ids if ids.count(i) > 1})
    if dupes:
        errors.append(f"duplicate invariant id(s): {dupes}")

    enum = refusal_enum()
    file_cache = {}

    for row in rows:
        rid = row.get("id")
        tag = f"#{rid}"

        want = arch.get(rid)
        got = (row.get("statement") or "").strip()
        if want and got != want:
            errors.append(f"{tag} statement does not match architecture §13 verbatim\n"
                          f"       matrix: {got}\n"
                          f"       §13:    {want}")

        status = row.get("status")
        if status not in ("covered", "gap"):
            errors.append(f"{tag} status must be 'covered' or 'gap', got {status!r}")
            continue

        if status == "covered":
            contract = row.get("contract")
            if not contract:
                errors.append(f"{tag} covered row names no contract")
                continue
            cpath = CONTRACTS / contract
            if not cpath.exists():
                errors.append(f"{tag} contract not found: {contract}")
                continue
            body = file_cache.setdefault(contract, cpath.read_text(encoding="utf-8"))
            section = row.get("section") or ""
            if not section:
                errors.append(f"{tag} covered row names no section")
            elif section not in body:
                errors.append(f"{tag} section {section!r} not present in {contract}")
            for field in ("refusal_scenario", "component"):
                if not (row.get(field) or "").strip():
                    errors.append(f"{tag} covered row has empty {field}")
            code = row.get("reason_code")
            if code not in enum:
                errors.append(f"{tag} reason_code {code!r} is not in the frozen "
                              f"refusal.schema.json enum")
            fence = row.get("fence")
            if not fence:
                errors.append(f"{tag} covered row names no fence")
            elif not (ROOT / fence).exists():
                errors.append(f"{tag} fence script not found: {fence}")
        else:
            if not (row.get("reason") or "").strip():
                errors.append(f"{tag} gap row states no reason — an uncovered "
                              "invariant must be named, not silent")
            exp = row.get("expected_reason_code")
            if exp is not None and exp not in enum:
                errors.append(f"{tag} expected_reason_code {exp!r} is not in the "
                              "frozen refusal.schema.json enum")

    if errors:
        return fail(errors)

    covered = sum(1 for r in rows if r["status"] == "covered")
    gaps = len(rows) - covered
    print(f"OK: {len(rows)} invariants traced — {covered} covered by a frozen "
          f"contract, {gaps} named as gaps; every reference resolves.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
