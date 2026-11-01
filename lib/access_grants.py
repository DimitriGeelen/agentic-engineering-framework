#!/usr/bin/env python3
"""access_grants — operator-owned, per-directory access outside the project (T-4965, T-4988).

The grant file is `policy/access-grants.yaml`, and only its COMMITTED version counts: it is read
from HEAD with `git show`, never from the working tree. An uncommitted edit, by a script or by
anything else, grants nothing until it is committed, and a commit that changes it without the
`Grants-Change: operator` trailer is named by `fw audit` (T-4965 review, finding 7).

    grants:
      - path: /mnt/share-create/Projects      # recursive
        level: create                         # read | create | create-project
        via: /mnt/share-create                # the mount this path must be reached through
    never_write: [/mnt/share-admin]           # no typed agent write, ever, even under a grant

Scope (the same as Tier 0 and the boundary hook): this governs TYPED commands and Write/Edit
targets. Scripts are fenced by the NAS accounts behind the `via` mounts, not by this file.

CLI:
    access_grants.py read-paths ROOT   paths a typed command may read (read and create levels)
    access_grants.py create-paths ROOT paths a typed command may write (create levels; T-4989)
    access_grants.py write-ok ROOT P   exit 0 when a typed write to P is allowed by a grant
    access_grants.py never-write ROOT  the never_write roots
    access_grants.py show ROOT         the grants, one per line, or the reason none apply
    access_grants.py doctor ROOT       one doctor line per finding: OK|WARN <text>
    access_grants.py audit ROOT        WARN lines for commits without the operator trailer
"""
from __future__ import annotations

import os
import subprocess
import sys

GRANT_FILE = "policy/access-grants.yaml"
LEVELS = ("read", "create", "create-project")
TRAILER = "Grants-Change: operator"


def _git(root: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=30)


def _committed_text(root: str) -> str | None:
    """The grant file as committed at HEAD, or None when HEAD has no such file (or no git)."""
    try:
        r = _git(root, "show", f"HEAD:{GRANT_FILE}")
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout if r.returncode == 0 else None


def _norm(p: str) -> str:
    return os.path.normpath(p).rstrip("/") or "/"


def _under(p: str, base: str) -> bool:
    return p == base or p.startswith(base.rstrip("/") + "/")


def _abs_ok(p) -> bool:
    return isinstance(p, str) and p.startswith("/") and ".." not in p.split("/") and _norm(p) != "/"


def validate(data) -> tuple[list[dict], list[str], list[str]]:
    """(grants, never_write, errors). Any error means the file grants nothing."""
    errors: list[str] = []
    if data is None:
        return [], [], []
    if not isinstance(data, dict):
        return [], [], ["the file is not a mapping"]
    grants: list[dict] = []
    for i, g in enumerate(data.get("grants") or []):
        if not isinstance(g, dict):
            errors.append(f"grant {i + 1}: not a mapping")
            continue
        path, level, via = g.get("path"), g.get("level"), g.get("via")
        if not _abs_ok(path):
            errors.append(f"grant {i + 1}: path must be absolute, not '/', without '..'")
        if level not in LEVELS:
            errors.append(f"grant {i + 1}: level must be one of {', '.join(LEVELS)}")
        if not _abs_ok(via):
            errors.append(f"grant {i + 1}: via must be an absolute mount path")
        elif _abs_ok(path) and not _under(_norm(path), _norm(via)):
            errors.append(f"grant {i + 1}: path {path} is not under its via mount {via}")
        if _abs_ok(path) and level in LEVELS and _abs_ok(via):
            grants.append({"path": _norm(path), "level": level, "via": _norm(via)})
    nw_raw = data.get("never_write") or []
    if not isinstance(nw_raw, list):
        errors.append("never_write must be a list")
        nw_raw = []
    never: list[str] = []
    for p in nw_raw:
        if _abs_ok(p):
            never.append(_norm(p))
        else:
            errors.append(f"never_write entry {p!r} must be absolute, not '/', without '..'")
    for a in grants:
        for b in grants:
            if a is not b and _under(a["path"], b["path"]) and a["level"] != b["level"]:
                errors.append(f"grants overlap with different levels: {a['path']} ({a['level']}) "
                              f"under {b['path']} ({b['level']})")
    for g in grants:
        for n in never:
            if g["level"] != "read" and _under(g["path"], n):
                errors.append(f"grant {g['path']} ({g['level']}) lies under never_write {n}")
    extra = set(data) - {"grants", "never_write"}
    if extra:
        errors.append(f"unknown key(s): {', '.join(sorted(extra))}")
    return grants, never, sorted(set(errors), key=errors.index)


def load(root: str) -> dict:
    """{'present', 'grants', 'never_write', 'errors'} from the COMMITTED grant file."""
    text = _committed_text(root)
    if text is None:
        return {"present": False, "grants": [], "never_write": [], "errors": []}
    try:
        import yaml
        data = yaml.safe_load(text)
    except Exception as e:  # noqa: BLE001 - a broken file grants nothing
        return {"present": True, "grants": [], "never_write": [], "errors": [f"unparseable: {e}"]}
    grants, never, errors = validate(data)
    if errors:
        # fail closed: an invalid file grants nothing, but its never_write roots still hold
        return {"present": True, "grants": [], "never_write": never, "errors": errors}
    return {"present": True, "grants": grants, "never_write": never, "errors": []}


def read_paths(root: str) -> list[str]:
    return [g["path"] for g in load(root)["grants"]]


def create_paths(root: str) -> list[str]:
    """Paths where typed writes are allowed (T-4989): create and create-project levels. The NAS
    behind each `via` mount judges ownership, renames and deletes."""
    return [g["path"] for g in load(root)["grants"] if g["level"] in ("create", "create-project")]


def write_allowed(path: str, create: list[str], never: list[str]) -> bool:
    """True when a typed write to `path` is allowed by a create grant: the path, both as typed
    (normalised) and fully resolved, lies under a create path and under no never_write root.
    Resolving catches a symlink inside a grant that points elsewhere (review finding 6)."""
    if not path.startswith("/"):
        return False
    cands = {_norm(path), _norm(os.path.realpath(path))}
    if any(_under(c, n) for c in cands for n in never):
        return False
    return all(any(_under(c, g) for g in create) for c in cands)


_PRESENT: dict = {}


def _grant_file_exists(root: str) -> bool:
    """The grant file is in the working tree or at HEAD (cached per process: the hook asks
    once per write target)."""
    if root not in _PRESENT:
        present = os.path.exists(os.path.join(root, GRANT_FILE))
        if not present:
            try:
                present = _git(root, "cat-file", "-e", f"HEAD:{GRANT_FILE}").returncode == 0
            except (OSError, subprocess.SubprocessError):
                present = False
        _PRESENT[root] = present
    return _PRESENT[root]


def is_grant_file_or_ancestor(path: str, root: str) -> bool:
    """True when `path` is the grant file, or a directory between it and the project root
    (`policy/`): writing, moving or removing either replaces the file (review finding 7).
    The project root itself is not included: a command that merely NAMES the root must not
    read as a write to the grant file. Projects without a grant file are not affected."""
    if not path.startswith("/") or not _grant_file_exists(root):
        return False
    gf = _norm(os.path.join(root, GRANT_FILE))
    roots = {_norm(root), _norm(os.path.realpath(root))}
    for c in {_norm(path), _norm(os.path.realpath(path))}:
        if c in roots or not any(_under(c, r) for r in roots):
            continue
        if c == gf or gf.startswith(c.rstrip("/") + "/"):
            return True
    return False


def doctor(root: str) -> list[str]:
    st = load(root)
    if not st["present"]:
        return ["OK no access grants (policy/access-grants.yaml not committed)"]
    out = [f"WARN access grants: {e} — the file grants nothing" for e in st["errors"]]
    for g in st["grants"]:
        line = f"{g['level']} {g['path']} via {g['via']}"
        if not os.path.ismount(g["via"]):
            out.append(f"WARN access grant {line}: {g['via']} is not a mount point")
        else:
            out.append(f"OK access grant {line}")
    for n in st["never_write"]:
        out.append(f"OK never_write {n}")
    return out


def audit(root: str) -> list[str]:
    """WARN for every commit that touched the grant file without the operator trailer."""
    try:
        r = _git(root, "log", "--format=%H%x1f%s%x1f%(trailers:key=Grants-Change,valueonly)%x1e",
                 "--", GRANT_FILE)
    except (OSError, subprocess.SubprocessError):
        return ["WARN access grants: git log unavailable — provenance not checked"]
    out = []
    for rec in r.stdout.split("\x1e"):
        parts = rec.strip().split("\x1f")
        if len(parts) < 2 or not parts[0]:
            continue
        sha, subject = parts[0], parts[1]
        trailer = parts[2].strip() if len(parts) > 2 else ""
        if trailer != "operator":
            out.append(f"WARN {sha[:10]} changed {GRANT_FILE} without '{TRAILER}': {subject[:80]}")
    return out


def _main(argv: list[str]) -> int:
    if len(argv) == 4 and argv[1] == "write-ok":
        st = load(argv[2])
        create = [g["path"] for g in st["grants"] if g["level"] in ("create", "create-project")]
        return 0 if write_allowed(argv[3], create, st["never_write"]) else 1
    if len(argv) != 3 or argv[1] not in ("read-paths", "create-paths", "never-write", "show",
                                         "doctor", "audit"):
        print(__doc__.split("CLI:")[1].rstrip(), file=sys.stderr)
        return 2
    cmd, root = argv[1], argv[2]
    if cmd == "read-paths":
        print("\n".join(read_paths(root)))
    elif cmd == "create-paths":
        print("\n".join(create_paths(root)))
    elif cmd == "never-write":
        print("\n".join(load(root)["never_write"]))
    elif cmd == "show":
        st = load(root)
        if not st["present"]:
            print(f"No access grants: {GRANT_FILE} is not committed.")
        for e in st["errors"]:
            print(f"INVALID: {e} (the file grants nothing)")
        for g in st["grants"]:
            print(f"{g['level']:<14} {g['path']}  (via {g['via']})")
        for n in st["never_write"]:
            print(f"{'never_write':<14} {n}")
    elif cmd == "doctor":
        print("\n".join(doctor(root)))
    else:
        lines = audit(root)
        print("\n".join(lines))
        return 1 if lines else 0
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
