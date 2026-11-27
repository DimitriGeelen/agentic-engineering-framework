#!/usr/bin/env python3
# Fabric — shared pattern expansion with exclude support (T-1842).
#
# Origin: Penelope (email-archive) T-1458 via framework:pickup offsets 5/6.
# Both do_scan (register.sh) and do_drift (drift.sh) read watch-patterns.yaml
# patterns: only and silently drop exclude:. In projects with node_modules/
# the scanner descended into the excluded tree and produced 5946/6339 (93.8%)
# junk cards, undetected for ~22 days because the bug appears in both code
# paths identically.
#
# Centralising the expansion here means the exclude predicate has one source
# of truth — the same bug class cannot recur independently in register.sh and
# drift.sh again.
#
# Usage:
#   python3 expand_patterns.py <watch-patterns.yaml> [project_root]
#
# Output: one relative path per line, in pattern-listed order, deduplicated.
# Exit codes: 0 ok, 2 unreadable yaml, 3 missing argv.

from __future__ import annotations

import fnmatch
import glob
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    sys.stderr.write(f"expand_patterns.py: PyYAML not available: {exc}\n")
    sys.exit(2)


def _excluded(rel_path: str, exclude_patterns: list[str]) -> bool:
    if not exclude_patterns:
        return False
    for pat in exclude_patterns:
        if fnmatch.fnmatch(rel_path, pat):
            return True
        # T-5433: fnmatch needs something before the slash of a leading `**/`, so
        # `**/node_modules/**` missed a node_modules/ at the project root. A leading
        # `**/` also matches zero directories, as in .gitignore.
        if pat.startswith("**/") and fnmatch.fnmatch(rel_path, pat[3:]):
            return True
    return False


def _as_list(value, where: str) -> list[str]:
    """T-5422 (050 item 4): an exclude may be written as one string or a list.

    `list("node_modules/**")` is a list of single characters, which match no path, so a
    scalar exclude used to be ignored without a word. Any other type is reported."""
    if value is None or value == "":
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, (list, tuple)):
        return [str(v) for v in value if v is not None and str(v) != ""]
    sys.stderr.write(f"expand_patterns.py: {where} exclude is a {type(value).__name__}, "
                     f"not a string or list; ignored: {value!r}\n")
    return []


def expand(watch_yaml: Path, project_root: Path) -> list[str]:
    try:
        data = yaml.safe_load(watch_yaml.read_text())
    except (OSError, yaml.YAMLError) as exc:
        sys.stderr.write(f"expand_patterns.py: cannot read {watch_yaml}: {exc}\n")
        sys.exit(2)
    if not isinstance(data, dict):
        return []

    top_exclude = _as_list(data.get("exclude"), "top-level")
    seen: set[str] = set()
    out: list[str] = []

    cwd = os.getcwd()
    try:
        os.chdir(project_root)
        for pattern in data.get("patterns", []) or []:
            if not isinstance(pattern, dict):
                continue
            glob_str = pattern.get("glob")
            if not glob_str:
                continue
            per_pattern_exclude = _as_list(pattern.get("exclude"), f"pattern {glob_str!r}")
            combined_exclude = top_exclude + per_pattern_exclude

            for match in glob.glob(glob_str, recursive=True):
                if not os.path.isfile(match):
                    continue
                rel = os.path.relpath(match, project_root)
                if _excluded(rel, combined_exclude):
                    continue
                if rel in seen:
                    continue
                seen.add(rel)
                out.append(rel)
    finally:
        os.chdir(cwd)
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: expand_patterns.py <watch-patterns.yaml> [project_root]\n")
        return 3
    watch_yaml = Path(argv[1]).resolve()
    project_root = Path(argv[2]).resolve() if len(argv) >= 3 else watch_yaml.parent.parent
    for rel in expand(watch_yaml, project_root):
        print(rel)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
