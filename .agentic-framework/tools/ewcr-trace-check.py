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

Contracts v2 and later (T-5179): --contracts-version N reads contracts/vN. On
top of the twenty §13 rows, the matrix must carry `accepted_scenarios:` — the
scenarios accepted after §13 was frozen (N-1, N-2). Each row must resolve:

  * id of the form N-<number>, each once, at least one row;
  * the statement appears VERBATIM in the contract document it names, and the
    named section is present there;
  * the source finding, source report (which must exist and name the finding),
    acceptance (by whom, when, under which id) and test are stated;
  * every reason code is in that version's refusal enum, components are named,
    the fence script exists;
  * the example refusal record exists, validates against that version's
    refusal.schema.json, uses one of the row's reason codes and names the
    scenario id in scenario_refs.

Usage: ewcr-trace-check.py [--contracts-version N] [--file PATH]
       (--file lets control legs point at a deliberately mutated copy)
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTRACTS_BASE = ROOT / "docs/research/executable-workflow/contracts"
CONTRACTS = CONTRACTS_BASE / "v1"
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


def refusal_schema():
    return json.loads((CONTRACTS / "refusal.schema.json").read_text(encoding="utf-8"))


def refusal_enum():
    return set(refusal_schema()["properties"]["reason_code"]["enum"])


def check_accepted(rows, enum, errors):
    """Rows for scenarios accepted after §13 was frozen (contracts v2+)."""
    if not isinstance(rows, list) or not rows:
        errors.append("no 'accepted_scenarios:' rows — this contracts version exists to carry them")
        return 0
    ids = [r.get("id") for r in rows]
    for i in sorted({i for i in ids if ids.count(i) > 1}, key=str):
        errors.append(f"duplicate accepted scenario id: {i}")
    schema = refusal_schema()
    for row in rows:
        rid = row.get("id")
        tag = str(rid)
        if not isinstance(rid, str) or not re.fullmatch(r"N-[1-9][0-9]*", rid):
            errors.append(f"{tag} accepted scenario id must look like N-1")
            continue
        if row.get("status") != "covered":
            errors.append(f"{tag} status must be 'covered', got {row.get('status')!r}")
        for field in ("source_finding", "accepted_by", "accepted_on", "accepted_in",
                      "refusal_scenario", "test"):
            if not str(row.get(field) or "").strip():
                errors.append(f"{tag} has empty {field}")
        report = row.get("source_report")
        if not report or not (ROOT / report).is_file():
            errors.append(f"{tag} source_report not found: {report}")
        elif row.get("source_finding") and \
                str(row["source_finding"]) not in (ROOT / report).read_text(encoding="utf-8"):
            errors.append(f"{tag} source finding {row['source_finding']!r} is not named in {report}")
        contract = row.get("contract")
        cpath = CONTRACTS / contract if contract else None
        if not cpath or not cpath.is_file():
            errors.append(f"{tag} contract not found: {contract}")
        else:
            body = cpath.read_text(encoding="utf-8")
            statement = (row.get("statement") or "").strip()
            if not statement or statement not in body:
                errors.append(f"{tag} statement is not present verbatim in {contract}")
            section = row.get("section") or ""
            if not section or section not in body:
                errors.append(f"{tag} section {section!r} not present in {contract}")
        codes = row.get("reason_codes")
        if not isinstance(codes, list) or not codes:
            errors.append(f"{tag} names no reason_codes")
            codes = []
        for code in codes:
            if code not in enum:
                errors.append(f"{tag} reason_code {code!r} is not in the frozen "
                              f"refusal.schema.json enum")
        comps = row.get("components")
        if not isinstance(comps, list) or not comps or not all(str(c or "").strip() for c in comps):
            errors.append(f"{tag} names no responsible components")
        fence = row.get("fence")
        if not fence or not (ROOT / fence).exists():
            errors.append(f"{tag} fence script not found: {fence}")
        example = row.get("example")
        epath = CONTRACTS / example if example else None
        if not epath or not epath.is_file():
            errors.append(f"{tag} example refusal record not found: {example}")
            continue
        try:
            from jsonschema import Draft202012Validator
        except ImportError:
            errors.append("python3 'jsonschema' package is required to validate example refusals")
            continue
        try:
            inst = json.loads(epath.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{tag} example {example} is not JSON — {e}")
            continue
        for e in list(Draft202012Validator(schema).iter_errors(inst))[:3]:
            errors.append(f"{tag} example {example} does not validate: {e.message}")
        if inst.get("reason_code") not in codes:
            errors.append(f"{tag} example {example} uses reason_code {inst.get('reason_code')!r}, "
                          f"not one of the row's {codes}")
        if rid not in (inst.get("scenario_refs") or []):
            errors.append(f"{tag} example {example} does not name {rid} in scenario_refs")
    return len(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default=None)
    ap.add_argument("--contracts-version", type=int, default=1, metavar="N",
                    help="contracts version to check (default: 1)")
    args = ap.parse_args()
    ver = args.contracts_version
    global CONTRACTS
    CONTRACTS = CONTRACTS_BASE / f"v{ver}"
    if ver < 1 or not CONTRACTS.is_dir():
        print(f"FAIL: contracts v{ver} not found: {CONTRACTS}", file=sys.stderr)
        return 1
    if args.file is None:
        args.file = str(CONTRACTS / "traceability.yaml")

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
    if data.get("contracts_version") != ver:
        errors.append(f"matrix contracts_version is {data.get('contracts_version')!r}, expected {ver}")
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

    n_accepted = 0
    if ver > 1:
        n_accepted = check_accepted(data.get("accepted_scenarios"), enum, errors)
    elif "accepted_scenarios" in data:
        errors.append("accepted_scenarios is not part of contracts v1 — v1 is frozen at twenty rows")

    if errors:
        return fail(errors)

    covered = sum(1 for r in rows if r["status"] == "covered")
    gaps = len(rows) - covered
    print(f"OK: {len(rows)} invariants traced — {covered} covered by a frozen "
          f"contract, {gaps} named as gaps; every reference resolves."
          + (f" Contracts v{ver}: {n_accepted} accepted scenario(s) traced." if ver > 1 else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
