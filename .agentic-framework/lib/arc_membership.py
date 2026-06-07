"""Canonical Python helper for arc-membership scans.

T-1880 (T-NEW-15, arc-grooming): consolidates the union-of-`arc_id:`-frontmatter
plus legacy `arc:<slug>`-tag scan that previously lived inline in three
Watchtower blueprints (web/blueprints/arcs.py, core.py, tasks.py).

Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) showed that
each consumer re-implemented the scan, so a storage-format migration
(T-1850: `tags:[arc:X]` → `arc_id: X`, 162 tasks) left every inline
reader returning zero for migrated arcs. Captured as L-397.

Public API:
  scan_tasks_by_arc_membership(project_root)
      → (by_arc_id: dict[str, list[task_id]],
         by_tag:    dict[str, list[task_id]])
      Frontmatter-only (reads first 1KB of each task file). Returns BOTH
      indices so callers that want a strict-canonical view (arc_id only)
      can use by_arc_id alone, while callers that want backward-
      compatibility can union both.

  scan_tasks_by_arc_id(project_root)
      → dict[str, list[repo_relative_path]]
      arc_id_value → [path,...]. Used by audit's stale-arc check which
      needs file paths (for `git log -- <path>`), not task ids.

  task_has_arc_membership(task_file_path)
      → bool
      Single-task frontmatter check — true if either arc_id: is set OR
      a tags: line contains arc:<slug>.

All functions are pure (no caching) — Watchtower request-cached wrappers
live in web/blueprints/arcs.py (`_arc_membership()`, `_arc_tasks_by_id()`).
"""

from __future__ import annotations

import re
from pathlib import Path

# Frontmatter regexes — same patterns previously inline in arcs.py.
_ARC_ID_LINE_RE = re.compile(r"^arc_id:\s*(.+?)\s*$", re.MULTILINE)
_ID_LINE_RE = re.compile(r"^id:\s*(T-\d+)\s*$", re.MULTILINE)
_TAGS_LINE_RE = re.compile(r"^tags:\s*(.+?)\s*$", re.MULTILINE)
_TAG_ARC_RE = re.compile(r"arc:([A-Za-z0-9\-_]+)")

# Read budget: arc_id and tags live at the top of frontmatter. 1KB is
# enough to capture them on every task file in the corpus (largest
# frontmatter observed is ~700 bytes). Keeps scan fast: 1841 task files
# × 1KB ≈ 1.8MB total I/O, ~50ms wall-clock.
_HEAD_READ_BYTES = 1024


def _read_head(path: Path) -> str:
    """Read at most _HEAD_READ_BYTES from path; empty string on OSError."""
    try:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            return fh.read(_HEAD_READ_BYTES)
    except OSError:
        return ""


def _iter_task_files(project_root: Path):
    """Yield T-*.md files under .tasks/{active,completed}/."""
    tasks_dir = project_root / ".tasks"
    for sub in ("active", "completed"):
        sub_dir = tasks_dir / sub
        if not sub_dir.is_dir():
            continue
        for md in sub_dir.glob("T-*.md"):
            yield md


def scan_tasks_by_arc_membership(
    project_root: Path | str,
) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """One pass over all task files producing two indices.

    Returns (by_arc_id, by_tag) where:
      by_arc_id: arc_id value -> [task ids]   (canonical, T-1849)
      by_tag:    "arc:<slug>" -> [task ids]   (legacy, pre-T-1850)

    Frontmatter-only; reads first 1KB per file. Avoids the 5×N
    yaml.safe_load pattern that made /arcs render in 10s+ pre-T-1855.
    """
    root = Path(project_root)
    by_arc_id: dict[str, list[str]] = {}
    by_tag: dict[str, list[str]] = {}
    for md in _iter_task_files(root):
        head = _read_head(md)
        if not head:
            continue
        id_m = _ID_LINE_RE.search(head)
        if id_m is None:
            continue
        tid = id_m.group(1).strip()
        aid_m = _ARC_ID_LINE_RE.search(head)
        if aid_m is not None:
            aid = aid_m.group(1).strip().strip('"').strip("'")
            if aid and aid not in ("null", "~"):
                by_arc_id.setdefault(aid, []).append(tid)
        tags_m = _TAGS_LINE_RE.search(head)
        if tags_m is not None:
            for arc_slug in _TAG_ARC_RE.findall(tags_m.group(1)):
                by_tag.setdefault(f"arc:{arc_slug}", []).append(tid)
    return by_arc_id, by_tag


def scan_tasks_by_arc_id(project_root: Path | str) -> dict[str, list[str]]:
    """arc_id value → [repo-relative task path, ...]. Path-valued variant.

    Used by audit's stale-arc check, which needs `git log -- <path>`
    rather than task ids. Same frontmatter-only fast-scan strategy.
    """
    root = Path(project_root)
    by_arc: dict[str, list[str]] = {}
    for md in _iter_task_files(root):
        head = _read_head(md)
        if not head:
            continue
        m = _ARC_ID_LINE_RE.search(head)
        if not m:
            continue
        aid = m.group(1).strip().strip('"').strip("'")
        if not aid or aid in ("null", "~"):
            continue
        try:
            rel = str(md.relative_to(root))
        except ValueError:
            rel = str(md)
        by_arc.setdefault(aid, []).append(rel)
    return by_arc


def task_dict_in_arc(
    task: dict,
    arc_slug: str,
    arc_numeric_id: str | None = None,
) -> bool:
    """True iff an in-memory task dict (from `get_all_task_metadata()` or
    similar yaml.safe_load result) belongs to the named arc.

    Checks both canonical `arc_id` field (T-1849) and legacy `arc:<slug>`
    entries in the `tags` / `_tags` list (pre-T-1850). When `arc_numeric_id`
    is provided (e.g. "arc-005" for slug "arc-grooming"), accepts either
    form as a match — T-1848 dual identity.

    Used by /tasks?arc=<slug> filter (web/blueprints/tasks.py). Differs
    from scan_tasks_by_arc_membership() in that it operates on already-
    loaded task dicts, not a fresh file scan.
    """
    if not arc_slug:
        return False
    arc_slug_l = arc_slug.lower()
    arc_id_val = str(task.get("arc_id") or "").strip().lower()
    if arc_id_val:
        if arc_id_val == arc_slug_l:
            return True
        if arc_numeric_id and arc_id_val == arc_numeric_id.lower():
            return True
    # Tags may be under `tags` or the post-load `_tags` alias.
    tags = task.get("_tags") or task.get("tags") or []
    arc_tag = f"arc:{arc_slug_l}"
    for tg in tags:
        if str(tg).strip().lower() == arc_tag:
            return True
    return False


def task_has_arc_membership(task_file: Path | str) -> bool:
    """True iff the task's frontmatter declares arc membership.

    Frontmatter-scoped (avoids false positives from `arc:` mentions in
    commit refs / narrative body). Matches either:
      - `arc_id: <slug>` field (T-1849 canonical, T-1850 migrated), OR
      - `tags:` line containing `arc:<slug>` (legacy pre-T-1850).
    """
    path = Path(task_file)
    if not path.is_file():
        return False
    head = _read_head(path)
    if not head:
        return False
    # Restrict to frontmatter block: between the two `---` separators.
    parts = head.split("---", 2)
    fm = parts[1] if len(parts) >= 3 else head
    aid_m = _ARC_ID_LINE_RE.search(fm)
    if aid_m is not None:
        aid = aid_m.group(1).strip().strip('"').strip("'")
        if aid and aid not in ("null", "~"):
            return True
    tags_m = _TAGS_LINE_RE.search(fm)
    if tags_m is not None and _TAG_ARC_RE.search(tags_m.group(1)):
        return True
    return False
