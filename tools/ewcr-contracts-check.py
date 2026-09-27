#!/usr/bin/env python3
"""EWCR contracts v1 — freeze check (T-3385, Arc 0 candidate 2).

Three assertions, in order, each fatal:

  1. every *.schema.json under contracts/v1/ is a valid JSON Schema draft
     2020-12 document with the frozen root shape: $id, title, version == 1,
     description naming the architecture section it freezes, and
     additionalProperties: false at the root;
  2. every examples/<name>.json validates against <name>.schema.json — a
     schema nothing can satisfy is not a contract;
  3. MANIFEST.yaml lists exactly the schema set with matching sha256 — a
     ratified contract is immutable (arch §2.1, §7.1); drift is a new version,
     not an edit.

  --write  (re)generate MANIFEST.yaml from the files on disk. Refused when the
           manifest already exists unless --force is also given, so a drifted
           schema cannot be silently re-blessed.

Exit 0 = frozen and consistent. Exit 1 = a check failed (details on stderr).
Exit 2 = usage / environment (jsonschema missing is reported, never skipped).
"""
import argparse
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACTS = ROOT / "docs/research/executable-workflow/contracts/v1"
MANIFEST = CONTRACTS / "MANIFEST.yaml"
ARCH_TAG = "architecture-c9070637.md"
EXPECTED = {
    "procedure", "instance", "transition-envelope", "attempt",
    "evidence-reference", "refusal", "deadline-event",
}


def sha256(p: pathlib.Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--contracts", type=pathlib.Path, default=CONTRACTS,
                    help="contracts/v1 directory (default: the repo's)")
    ap.add_argument("--write", action="store_true", help="write MANIFEST.yaml")
    ap.add_argument("--force", action="store_true", help="allow --write over an existing manifest")
    args = ap.parse_args()
    cdir: pathlib.Path = args.contracts
    manifest = cdir / "MANIFEST.yaml"

    try:
        import jsonschema
        from jsonschema import Draft202012Validator
    except ImportError:
        print("ERROR: python3 'jsonschema' package is required (pip install jsonschema)", file=sys.stderr)
        return 2
    try:
        import yaml
    except ImportError:
        print("ERROR: python3 'yaml' package is required", file=sys.stderr)
        return 2

    schemas = sorted(cdir.glob("*.schema.json"))
    names = {p.name[: -len(".schema.json")] for p in schemas}
    ok = True
    if names != EXPECTED:
        fail(f"schema set is {sorted(names)}, frozen set is {sorted(EXPECTED)}")
        ok = False

    loaded = {}
    for p in schemas:
        name = p.name[: -len(".schema.json")]
        try:
            s = json.loads(p.read_text())
        except json.JSONDecodeError as e:
            fail(f"{p.name}: not JSON — {e}")
            ok = False
            continue
        # 1. metaschema + frozen root shape
        try:
            Draft202012Validator.check_schema(s)
        except jsonschema.SchemaError as e:
            fail(f"{p.name}: not a valid draft 2020-12 schema — {e.message}")
            ok = False
            continue
        for key, want in (("$schema", "https://json-schema.org/draft/2020-12/schema"), ("version", 1),
                          ("additionalProperties", False)):
            if s.get(key) != want:
                fail(f"{p.name}: root {key!r} is {s.get(key)!r}, frozen value is {want!r}")
                ok = False
        for key in ("$id", "title", "description"):
            if not isinstance(s.get(key), str) or not s[key]:
                fail(f"{p.name}: root {key!r} missing or empty")
                ok = False
        if ARCH_TAG not in s.get("description", ""):
            fail(f"{p.name}: description does not name {ARCH_TAG} — the contract must trace to its source section")
            ok = False
        loaded[name] = s

    # 2. examples
    for name, s in loaded.items():
        ex = cdir / "examples" / f"{name}.json"
        if not ex.is_file():
            fail(f"examples/{name}.json missing — every schema needs one worked instance")
            ok = False
            continue
        try:
            inst = json.loads(ex.read_text())
        except json.JSONDecodeError as e:
            fail(f"examples/{name}.json: not JSON — {e}")
            ok = False
            continue
        errs = sorted(Draft202012Validator(s).iter_errors(inst), key=lambda e: list(e.path))
        if errs:
            ok = False
            for e in errs[:5]:
                loc = "/".join(str(x) for x in e.path) or "<root>"
                fail(f"examples/{name}.json @ {loc}: {e.message}")

    # 3. manifest
    on_disk = {p.name: sha256(p) for p in schemas}
    if args.write:
        if manifest.exists() and not args.force:
            fail(f"{manifest.relative_to(ROOT) if manifest.is_relative_to(ROOT) else manifest} exists; "
                 "refusing to re-bless without --force (a ratified contract is immutable — bump the version instead)")
            return 1
        if not ok:
            fail("not writing a manifest over failing schemas/examples")
            return 1
        doc = {
            "contracts_version": 1,
            "source": ARCH_TAG,
            "frozen_by": "T-3385",
            "schemas": [{"file": k, "sha256": v} for k, v in sorted(on_disk.items())],
        }
        manifest.write_text("# EWCR contracts v1 — frozen hashes. Regenerate ONLY with a version bump\n"
                            "# (tools/ewcr-contracts-check.py --write --force). Drift here is a refusal, not a warning.\n"
                            + yaml.safe_dump(doc, sort_keys=False))
        print(f"wrote {manifest} ({len(on_disk)} schemas)")
        return 0 if ok else 1

    if not manifest.is_file():
        fail(f"{manifest} missing — run with --write once to freeze")
        return 1
    m = yaml.safe_load(manifest.read_text()) or {}
    listed = {row["file"]: row["sha256"] for row in m.get("schemas", [])}
    for f in sorted(set(listed) | set(on_disk)):
        if f not in on_disk:
            fail(f"manifest lists {f} but it is not on disk")
            ok = False
        elif f not in listed:
            fail(f"{f} on disk but not in manifest")
            ok = False
        elif listed[f] != on_disk[f]:
            fail(f"{f} DRIFT: manifest {listed[f][:12]}… disk {on_disk[f][:12]}… — a ratified contract is immutable")
            ok = False
    if m.get("contracts_version") != 1:
        fail(f"manifest contracts_version is {m.get('contracts_version')!r}, expected 1")
        ok = False

    if ok:
        print(f"OK: {len(loaded)} schemas valid (draft 2020-12), {len(loaded)} examples validate, manifest hashes match")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
