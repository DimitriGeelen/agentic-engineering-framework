"""Disjoint write-set policy validator (T-2337, arc-011 M1 §3).

Pure static validator: reads the `write_set:` frontmatter field from two task
files and reports whether their declared write sets are `disjoint`, `overlap`,
or `undecidable`. The orchestrator consults this before emitting parallel
dispatch for the arc-011 headline_mechanic (two agents on disjoint write-set
tasks running concurrently).

The `write_set:` field is a list of glob patterns (relative to PROJECT_ROOT)
declaring which paths the task expects to write. Globs expand against the
working tree; the comparison is set intersection on the expanded path strings.

Verdicts:
    disjoint    — both write-sets declared, no path overlap
    overlap     — both declared, at least one path in both
    undecidable — at least one task lacks `write_set:` frontmatter (can't
                  prove safety, default to refuse-to-dispatch)
"""

from __future__ import annotations

import glob
import os
import re
import sys
from typing import Iterable

try:
    import yaml
except ImportError:
    yaml = None


def _project_root() -> str:
    """Resolve PROJECT_ROOT from env or fall back to git toplevel of CWD."""
    root = os.environ.get("PROJECT_ROOT")
    if root and os.path.isdir(root):
        return root
    # Walk up from CWD looking for .tasks/ — the canonical project marker
    cur = os.path.abspath(os.getcwd())
    while cur != "/":
        if os.path.isdir(os.path.join(cur, ".tasks")):
            return cur
        cur = os.path.dirname(cur)
    return os.getcwd()


def _parse_frontmatter(task_path: str) -> dict:
    """Extract YAML frontmatter from a task file. Returns {} if absent/malformed."""
    if not os.path.isfile(task_path):
        raise FileNotFoundError(task_path)
    with open(task_path, encoding="utf-8") as f:
        text = f.read()
    if not text.startswith("---"):
        return {}
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    if yaml is None:
        return {}
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return {}
    return data if isinstance(data, dict) else {}


def read_write_set(task_path: str) -> list[str] | None:
    """Return the raw `write_set:` list from a task file, or None if absent.

    Returns:
        list of glob patterns (str)  — when `write_set:` frontmatter is present
        None                         — when the field is missing or empty
    """
    fm = _parse_frontmatter(task_path)
    ws = fm.get("write_set")
    if ws is None:
        return None
    if isinstance(ws, list) and all(isinstance(p, str) for p in ws):
        # An empty list is still "declared" — the task explicitly writes nothing.
        # Differentiate from missing-field by returning the empty list.
        return ws
    return None


def expand_globs(patterns: Iterable[str], root: str | None = None) -> set[str]:
    """Expand glob patterns against the working tree, return absolute path set.

    Patterns are interpreted relative to `root` (defaults to PROJECT_ROOT).
    Recursive globs (`**`) supported via glob.glob(recursive=True).
    Patterns that don't expand to any existing file are kept as-is (the
    intent is set-membership comparison, not file-existence verification).
    """
    if root is None:
        root = _project_root()
    out: set[str] = set()
    for pat in patterns:
        pat = pat.strip()
        if not pat:
            continue
        # Absolute paths stay absolute; relative are resolved against root
        if not os.path.isabs(pat):
            full = os.path.join(root, pat)
        else:
            full = pat
        # include_hidden=True (Python 3.11+) is REQUIRED — dot-directories
        # like .tasks/, .context/, .fabric/ are first-class in this codebase.
        # Without it, `**/T-*.md` skips .tasks/active/ entirely.
        try:
            matches = glob.glob(full, recursive=True, include_hidden=True)
        except TypeError:
            # Python < 3.11 fallback: walk the tree manually with fnmatch
            import fnmatch
            matches = []
            base_dir = os.path.dirname(full) if "*" in full else full
            # Strip glob characters to find the walk root
            star_idx = full.find("*")
            walk_root = full[:star_idx].rsplit(os.sep, 1)[0] if star_idx > 0 else root
            if os.path.isdir(walk_root):
                for dirpath, _dirnames, filenames in os.walk(walk_root):
                    for fn in filenames:
                        candidate = os.path.join(dirpath, fn)
                        if fnmatch.fnmatch(candidate, full):
                            matches.append(candidate)
        if matches:
            for m in matches:
                out.add(os.path.normpath(m))
        else:
            # Pattern doesn't match anything yet — keep the normalized form
            # so two tasks declaring the same unborn path overlap correctly.
            out.add(os.path.normpath(full))
    return out


def is_disjoint(set_a: set[str], set_b: set[str]) -> bool:
    """Return True iff the two expanded path sets share no element."""
    return set_a.isdisjoint(set_b)


def compare(task_a_path: str, task_b_path: str, root: str | None = None) -> str:
    """Compare two tasks' declared write-sets.

    Returns:
        "disjoint"    — both declared, no overlap
        "overlap"     — both declared, at least one path shared
        "undecidable" — at least one task lacks `write_set:` frontmatter
    """
    ws_a = read_write_set(task_a_path)
    ws_b = read_write_set(task_b_path)
    if ws_a is None or ws_b is None:
        return "undecidable"
    paths_a = expand_globs(ws_a, root=root)
    paths_b = expand_globs(ws_b, root=root)
    return "disjoint" if is_disjoint(paths_a, paths_b) else "overlap"


def resolve_task_path(task_id: str, root: str | None = None) -> str:
    """Resolve a T-XXX id to its file under .tasks/{active,completed}/.

    Accepts either the bare id (T-2337) or the full path. Raises
    FileNotFoundError when neither active/ nor completed/ contain a match.
    """
    if os.path.isfile(task_id):
        return os.path.abspath(task_id)
    if root is None:
        root = _project_root()
    # Match T-NNNN-*.md (or .yaml) in either active/ or completed/
    for sub in ("active", "completed"):
        d = os.path.join(root, ".tasks", sub)
        if not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            if name.startswith(f"{task_id}-") or name == f"{task_id}.md":
                return os.path.join(d, name)
    raise FileNotFoundError(f"task {task_id} not found under .tasks/")


def check(task_a: str, task_b: str, root: str | None = None) -> tuple[str, int]:
    """Resolve two task ids/paths and compare. Returns (verdict, exit_code).

    Exit codes:
        0 = disjoint
        1 = overlap
        2 = undecidable
    """
    path_a = resolve_task_path(task_a, root=root)
    path_b = resolve_task_path(task_b, root=root)
    verdict = compare(path_a, path_b, root=root)
    code = {"disjoint": 0, "overlap": 1, "undecidable": 2}[verdict]
    return verdict, code


def _main(argv: list[str]) -> int:
    if len(argv) < 3 or argv[1] != "check":
        sys.stderr.write("usage: write_set.py check <T-A> <T-B>\n")
        return 64
    try:
        verdict, code = check(argv[2], argv[3])
    except FileNotFoundError as e:
        sys.stderr.write(f"error: {e}\n")
        return 2
    print(verdict)
    return code


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
