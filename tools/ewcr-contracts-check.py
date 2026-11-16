#!/usr/bin/env python3
"""EWCR contracts — freeze check (T-3385, Arc 0 candidate 2; later versions T-5179).

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

Later versions (T-5179): --contracts-version N (default 1) checks contracts/vN.
A later version carries the previous one forward and changes only what it must,
so for N > 1 the same three assertions hold, with these differences:

  * each manifest row states the schema's own version (`schema_version`). A
    schema carried unchanged keeps its previous version and `carried_from`, and
    must be byte-identical to the previous contracts version; a changed schema
    carries version N, a /vN/ $id, and must differ;
  * every examples/<schema-name>-*.json validates too, not only the one worked
    instance per schema — a new example for a new refusal route is checked;
  * each `documents:` row marked `carried_from` is byte-identical to the
    previous version's file, and every listed document exists.

The previous version is the sibling directory of --contracts (…/v<N-1>), or
the repository's own when --contracts points at a lone copy.

Exit 0 = frozen and consistent. Exit 1 = a check failed (details on stderr).
Exit 2 = usage / environment (jsonschema missing is reported, never skipped).
"""
import argparse
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONTRACTS_BASE = ROOT / "docs/research/executable-workflow/contracts"
CONTRACTS = CONTRACTS_BASE / "v1"
MANIFEST = CONTRACTS / "MANIFEST.yaml"
FROZEN_BY = {1: "T-3385", 2: "T-5179"}
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
    ap.add_argument("--contracts-version", type=int, default=1, metavar="N",
                    help="contracts version to check (default: 1)")
    ap.add_argument("--contracts", type=pathlib.Path, default=None,
                    help="contracts/vN directory (default: the repo's, for the chosen version)")
    ap.add_argument("--write", action="store_true", help="write MANIFEST.yaml")
    ap.add_argument("--force", action="store_true", help="allow --write over an existing manifest")
    args = ap.parse_args()
    ver: int = args.contracts_version
    if ver < 1:
        print("ERROR: --contracts-version must be 1 or higher", file=sys.stderr)
        return 2
    cdir: pathlib.Path = args.contracts if args.contracts is not None else CONTRACTS_BASE / f"v{ver}"
    manifest = cdir / "MANIFEST.yaml"
    if not cdir.is_dir():
        fail(f"{cdir} is not a directory — contracts v{ver} does not exist")
        return 1
    # The previous contracts version a later one is compared against.
    prev_dir = None
    if ver > 1:
        prev_dir = cdir.parent / f"v{ver - 1}"
        if not prev_dir.is_dir():
            prev_dir = CONTRACTS_BASE / f"v{ver - 1}"
        if not prev_dir.is_dir():
            fail(f"contracts v{ver - 1} not found — v{ver} cannot be checked without the version it carries forward")
            return 1

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
        shape = [("$schema", "https://json-schema.org/draft/2020-12/schema"), ("additionalProperties", False)]
        if ver == 1:
            shape.insert(1, ("version", 1))
        for key, want in shape:
            if s.get(key) != want:
                fail(f"{p.name}: root {key!r} is {s.get(key)!r}, frozen value is {want!r}")
                ok = False
        if ver > 1:
            # Carried unchanged = the previous version's bytes, version and $id.
            # Changed = this version's number and a /vN/ $id. Nothing in between.
            prev = prev_dir / p.name
            carried = prev.is_file() and prev.read_bytes() == p.read_bytes()
            if not carried:
                if s.get("version") != ver:
                    fail(f"{p.name}: differs from v{ver - 1} but root 'version' is {s.get('version')!r}, "
                         f"expected {ver} — a changed schema takes the new version")
                    ok = False
                if f"/v{ver}/" not in str(s.get("$id", "")):
                    fail(f"{p.name}: differs from v{ver - 1} but its $id does not name /v{ver}/ — "
                         "two different schemas must not share one $id")
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

    n_examples = len(loaded)
    if ver > 1:
        # Later versions also validate every additional example, matched to its
        # schema by the longest schema name its file name starts with.
        exdir = cdir / "examples"
        for ex in sorted(exdir.glob("*.json")) if exdir.is_dir() else []:
            stem = ex.name[: -len(".json")]
            if stem in loaded:
                continue
            owners = [n for n in loaded if stem.startswith(n + "-")]
            if not owners:
                if not any(stem == n or stem.startswith(n + "-") for n in EXPECTED):
                    fail(f"examples/{ex.name}: matches no schema name — an example nothing validates is not evidence")
                    ok = False
                continue
            name = max(owners, key=len)
            try:
                inst = json.loads(ex.read_text())
            except json.JSONDecodeError as e:
                fail(f"examples/{ex.name}: not JSON — {e}")
                ok = False
                continue
            n_examples += 1
            errs = sorted(Draft202012Validator(loaded[name]).iter_errors(inst), key=lambda e: list(e.path))
            if errs:
                ok = False
                for e in errs[:5]:
                    loc = "/".join(str(x) for x in e.path) or "<root>"
                    fail(f"examples/{ex.name} @ {loc}: {e.message}")

    # 3. manifest
    on_disk = {p.name: sha256(p) for p in schemas}

    def schema_row(fname: str, digest: str) -> dict:
        row = {"file": fname, "sha256": digest}
        if ver > 1:
            prev = prev_dir / fname
            if prev.is_file() and sha256(prev) == digest:
                row["schema_version"] = json.loads(prev.read_text()).get("version")
                row["carried_from"] = f"v{ver - 1}"
            else:
                row["schema_version"] = ver
                row["changed_in"] = f"v{ver}"
        return row
    if args.write:
        if manifest.exists() and not args.force:
            fail(f"{manifest.relative_to(ROOT) if manifest.is_relative_to(ROOT) else manifest} exists; "
                 "refusing to re-bless without --force (a ratified contract is immutable — bump the version instead)")
            return 1
        if not ok:
            fail("not writing a manifest over failing schemas/examples")
            return 1
        doc = {
            "contracts_version": ver,
            "source": ARCH_TAG,
            "frozen_by": FROZEN_BY.get(ver, "UNSET — name the freezing task"),
            "schemas": [schema_row(k, v) for k, v in sorted(on_disk.items())],
        }
        flag = "" if ver == 1 else f" --contracts-version {ver}"
        manifest.write_text(f"# EWCR contracts v{ver} — frozen hashes. Regenerate ONLY with a version bump\n"
                            f"# (tools/ewcr-contracts-check.py{flag} --write --force). Drift here is a refusal, not a warning.\n"
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
    if m.get("contracts_version") != ver:
        fail(f"manifest contracts_version is {m.get('contracts_version')!r}, expected {ver}")
        ok = False

    carried_docs = 0
    if ver > 1:
        # Each row says whether the schema was carried or changed; the bytes decide.
        for row in m.get("schemas", []):
            f = row.get("file")
            if f not in on_disk:
                continue
            want = schema_row(f, on_disk[f])
            for key in ("schema_version", "carried_from", "changed_in"):
                if row.get(key) != want.get(key):
                    fail(f"{f}: manifest {key} is {row.get(key)!r}, the files say {want.get(key)!r} "
                         f"(compared with v{ver - 1})")
                    ok = False
            if loaded.get(f[: -len(".schema.json")], {}).get("version") != want["schema_version"]:
                fail(f"{f}: root 'version' is {loaded.get(f[: -len('.schema.json')], {}).get('version')!r}, "
                     f"expected {want['schema_version']}")
                ok = False
        for row in m.get("documents", []) or []:
            f = row.get("file")
            dpath = cdir / str(f)
            if not dpath.is_file():
                fail(f"manifest lists document {f} but it is not on disk")
                ok = False
                continue
            if row.get("carried_from"):
                prev = prev_dir / str(f)
                if not prev.is_file() or prev.read_bytes() != dpath.read_bytes():
                    fail(f"{f}: manifest says carried_from {row['carried_from']} but it is not byte-identical "
                         f"to v{ver - 1}'s — mark it changed_in v{ver} or restore it")
                    ok = False
                else:
                    carried_docs += 1

    if ok:
        msg = (f"OK: {len(loaded)} schemas valid (draft 2020-12), {n_examples} examples validate, "
               "manifest hashes match")
        if ver > 1:
            n_carried = sum(1 for r in m.get("schemas", []) if r.get("carried_from"))
            msg += (f"; contracts v{ver}: {n_carried} schemas carried from v{ver - 1} unchanged, "
                    f"{len(loaded) - n_carried} changed, {carried_docs} documents carried unchanged")
        print(msg)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
