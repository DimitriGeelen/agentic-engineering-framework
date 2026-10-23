#!/usr/bin/env python3
"""T-4689 — every file the framework writes under .context/working/ must be
either gitignored in a consumer or deliberately kept tracked.

THE CLASS. T-4231 (lib/working-gitignore.sh) and T-3861 (lib/vec-index-gitignore.sh)
gave consumers an ignore list, but a list is a snapshot: every new writer added
after it was a new file in the consumer's uncommitted-changes rail until someone
on the consumer side patched their ignore by hand (1023 sidecar b3fcf74f: their
T-104/T-110/T-127/T-175 — four rounds). Nothing on the framework side compared
the list against the writers.

WHAT THIS DOES.
  1. Collects every name the framework code spells under .context/working/ —
     shell/any `.context/working/<name>` and `CONTEXT_DIR}/working/<name>`,
     python `... "working" / "<name>"` and `"working", "<name>"` (after a
     `context` token on the same line). `${var}`/`$var` parts become a
     placeholder, so `.reviewed-${task_id}` is checked as `.reviewed-X`.
  2. Builds the consumer's .context/working/.gitignore the way `fw init` does:
     the static heredoc in lib/init.sh plus fw_vec_index_ensure_ignored and
     fw_working_ensure_ignored (the same functions `fw upgrade` runs).
  3. Asks git which names that file ignores (a name also counts as ignored when
     `<name>/x` is, i.e. a directory rule).
  4. Fails on any name that is neither ignored nor on the keep-tracked list
     (fw_working_keep_tracked in lib/working-gitignore.sh), and on any name that
     is on the keep-tracked list but ignored anyway (a record silently hidden).

WHAT IT CANNOT SEE. A name assembled at run time from pieces that never appear
as a literal path (a constant joined three calls away) — those reach the
consumer as before. EXTERNAL_NAMES covers files other tools write into a
consumer's .context/working/; add to it when one is reported.

Usage:
  working-ignore-rail.py [--scan-root DIR] [--list]
Exit: 0 clean, 1 unclassified/conflicting names, 2 usage/setup error.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parent.parent
SCAN_DIRS = ("lib", "agents", "bin", "web")
SCAN_SUFFIXES = {".sh", ".py", ".bash"}

# Written into a consumer's .context/working/ by tooling outside this repo.
EXTERNAL_NAMES = {
    # TermLink fleet doctor's consecutive-failure counter (seen in 1023 and in
    # docs/reports/T-1602-consumer-W1.md); not written by any framework file.
    ".fleet-failure-state.json": "external: termlink fleet failure state",
}

NAME = r"[A-Za-z0-9._{}$*-]+"
SHELL_RE = re.compile(r"(?:\.context|CONTEXT_DIR\}?[\"']?)/working/(" + NAME + r")")
PY_RE = re.compile(
    r"context[^\n]{0,40}?[\"']working[\"']\s*[/,]\s*[\"']([^\"'\n]+)[\"']",
    re.IGNORECASE,
)
VAR_RE = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*")


def _normalise(raw: str) -> str | None:
    name = VAR_RE.sub("X", raw).rstrip(".}\"'/")
    if not name or "{" in name or "}" in name or "$" in name or "*" in name:
        return None
    if name in {".", "..", "X", "x", ".gitignore"}:
        return None
    return name


def _source_files(root: Path):
    for d in SCAN_DIRS:
        base = root / d
        if not base.is_dir():
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [n for n in dirnames if n not in {"__pycache__", "node_modules"}]
            for fn in filenames:
                p = Path(dirpath) / fn
                if p.suffix in SCAN_SUFFIXES:
                    yield p
                elif not p.suffix and d in {"bin", "agents"}:
                    try:
                        with open(p, "rb") as fh:
                            if fh.read(2) == b"#!":
                                yield p
                    except OSError:
                        pass


def collect(root: Path) -> dict[str, str]:
    """name -> first 'path:line' that spells it."""
    found: dict[str, str] = {}
    for p in sorted(_source_files(root)):
        try:
            text = p.read_text(errors="replace")
        except OSError:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for rx in (SHELL_RE, PY_RE):
                for m in rx.finditer(line):
                    n = _normalise(m.group(1))
                    if n and n not in found:
                        found[n] = f"{p.relative_to(root)}:{lineno}"
    for n, why in EXTERNAL_NAMES.items():
        found.setdefault(n, why)
    return found


def _bash(script: str, *args: str) -> str:
    return subprocess.run(
        ["bash", "-c", script, "rail", *args],
        check=True, capture_output=True, text=True,
    ).stdout


def keep_tracked() -> set[str]:
    out = _bash('source "$1/lib/working-gitignore.sh"; fw_working_keep_tracked',
                str(FRAMEWORK_ROOT))
    return {l.strip() for l in out.splitlines() if l.strip()}


def _init_heredoc() -> str:
    text = (FRAMEWORK_ROOT / "lib/init.sh").read_text()
    m = re.search(r"\.context/working/\.gitignore\" << 'WGIT'\n(.*?)\nWGIT\n", text, re.S)
    if not m:
        raise SystemExit("working-ignore-rail: cannot find the WGIT heredoc in lib/init.sh")
    return m.group(1) + "\n"


def ignored(names: list[str]) -> set[str]:
    with tempfile.TemporaryDirectory() as tmp:
        proj = Path(tmp)
        subprocess.run(["git", "init", "-q", str(proj)], check=True)
        wk = proj / ".context/working"
        wk.mkdir(parents=True)
        (wk / ".gitignore").write_text(_init_heredoc())
        _bash('source "$1/lib/vec-index-gitignore.sh"; source "$1/lib/working-gitignore.sh";'
              ' fw_vec_index_ensure_ignored "$2" >/dev/null; fw_working_ensure_ignored "$2" >/dev/null',
              str(FRAMEWORK_ROOT), str(proj))
        probes = []
        for n in names:
            probes += [f".context/working/{n}", f".context/working/{n}/x"]
        r = subprocess.run(
            ["git", "-C", str(proj), "check-ignore", "--no-index", "--stdin"],
            input="\n".join(probes) + "\n", capture_output=True, text=True,
        )
        if r.returncode not in (0, 1):
            raise SystemExit(f"working-ignore-rail: git check-ignore failed: {r.stderr.strip()}")
        hit = set()
        for line in r.stdout.splitlines():
            rel = line.strip()[len(".context/working/"):]
            hit.add(rel[:-2] if rel.endswith("/x") else rel)
        return hit


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--scan-root", default=str(FRAMEWORK_ROOT),
                    help="tree whose lib/ agents/ bin/ web/ are scanned for writers")
    ap.add_argument("--list", action="store_true", help="print every collected name and its class")
    a = ap.parse_args(argv)

    names = collect(Path(a.scan_root))
    keep = keep_tracked()
    ign = ignored(sorted(names))

    bad = []
    for n in sorted(names):
        cls = "keep-tracked" if n in keep else ("ignored" if n in ign else None)
        if n in keep and n in ign:
            bad.append(f"CONFLICT  {n}  (keep-tracked but ignored; first seen {names[n]})")
        elif cls is None:
            bad.append(f"UNIGNORED {n}  (first seen {names[n]})")
        if a.list:
            print(f"{cls or 'UNCLASSIFIED':13} {n}  {names[n]}")

    if bad:
        print("working-ignore-rail: FAIL — .context/working names a consumer would commit by accident:")
        for b in bad:
            print("  " + b)
        print("Fix: add a rule to fw_working_ignore_rules (lib/working-gitignore.sh) for runtime "
              "state, or the name to fw_working_keep_tracked if a project keeps it in git.")
        return 1
    print(f"working-ignore-rail: clean ({len(names)} names; {len(keep & set(names))} keep-tracked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
