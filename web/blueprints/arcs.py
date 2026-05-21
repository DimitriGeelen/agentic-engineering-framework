"""T-1662 (Phase 2 of T-1653 inception arc) — Watchtower /arcs surface.

Generic operator-facing surface for the Arc system shipped in T-1661.

  /arcs           — list every arc registered in .context/arcs/*.yaml
  /arcs/<arc_id>  — detail page for one arc (constituent tasks + Arc
                    Completion Discipline three-question check)

The orchestrator-specific /orchestrator page (T-1647) is preserved as a
specialized drill-down (MCP audit, live sessions, recent dispatches).
This page is the generic equivalent — the operator can look at /arcs
without needing to know which arc has specialized panels.

Data sources:
- .context/arcs/*.yaml — arc registry (T-1661)
- .context/working/arc-focus.yaml — current focus pointer
- .tasks/{active,completed}/T-XXX-*.md — constituent task metadata
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import time
from pathlib import Path
from typing import Any

import yaml
from flask import Blueprint, abort, request

from lib.arc_membership import (
    scan_tasks_by_arc_id as _scan_tasks_by_arc_id_shared,
    scan_tasks_by_arc_membership as _scan_tasks_by_arc_membership_shared,
)
from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("arcs", __name__)


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)

# T-1852: canonical four-state lifecycle. Order is presentation order on
# the filter tab strip (left → right). "all" is a synthetic filter; not a
# stored status. Keep this list in sync with lib/arc.sh ARC_STATES.
_LIFECYCLE_STATES = ("draft", "in-progress", "closed", "abandoned")
_DEFAULT_FILTER = "in-progress"
_FILTER_LABELS = _LIFECYCLE_STATES + ("all",)

# T-1855: stale-arc threshold (days). Matches FW_STALE_ARC_DAYS audit
# default. Watchtower may stay rendered for hours, so we cache the
# stale-check result for 60s to avoid running git log per request.
_STALE_DAYS = int(os.environ.get("FW_STALE_ARC_DAYS", "30"))
_STALE_CACHE_TTL_SEC = 60.0


def _arcs_dir() -> Path:
    return PROJECT_ROOT / ".context" / "arcs"


def _focus_file() -> Path:
    return PROJECT_ROOT / ".context" / "working" / "arc-focus.yaml"


def _read_focus() -> str | None:
    """Return the current arc id from arc-focus.yaml, or None."""
    f = _focus_file()
    if not f.is_file():
        return None
    try:
        data = yaml.safe_load(f.read_text()) or {}
    except (yaml.YAMLError, OSError):
        return None
    val = data.get("current_arc")
    if not val or val == "null":
        return None
    return str(val)


def _resolve_arc_slug(arc_id_or_slug: str) -> str | None:
    """T-1848: Resolve either a slug (filename stem) or arc-NNN id to the
    canonical slug. Returns None when no arc matches.

    Slug case: direct filename lookup (cheap path).
    arc-NNN case: scan files for matching `id:` field (rare; only when the
    user hits /arcs/arc-001 instead of /arcs/dispatch-safety).
    """
    arcs_dir = _arcs_dir()
    direct = arcs_dir / f"{arc_id_or_slug}.yaml"
    if direct.is_file():
        return arc_id_or_slug

    # Scan for arc-NNN id match
    if arc_id_or_slug.startswith("arc-") and arc_id_or_slug[4:].isdigit():
        for af in arcs_dir.glob("*.yaml"):
            try:
                data = yaml.safe_load(af.read_text()) or {}
            except (yaml.YAMLError, OSError):
                continue
            if isinstance(data, dict) and data.get("id") == arc_id_or_slug:
                return af.stem
    return None


def _read_arc(arc_id: str) -> dict[str, Any] | None:
    """Return arc YAML for arc_id (slug or arc-NNN), or None if not found."""
    slug = _resolve_arc_slug(arc_id)
    if slug is None:
        return None
    path = _arcs_dir() / f"{slug}.yaml"
    try:
        data = yaml.safe_load(path.read_text()) or {}
    except (yaml.YAMLError, OSError):
        return None
    if not isinstance(data, dict):
        return None
    # T-1848: ensure `slug` field exists in returned dict — older arcs predate
    # the dual-identity migration and rely on filename for slug semantics.
    data.setdefault("slug", slug)
    return data


# T-1969: arc-badge unified display form.
# Renders the arc identifier as "arc-NNN · slug" (e.g. "arc-006 · value-prioritisation")
# so the visual badge always carries both identities — the canonical immutable
# id (per T-1848 D-Immutability) AND the human-readable slug. Resolves whichever
# form was stored in `task.arc_id` and produces both at render time.
#
# Memoized via lru_cache: arc YAMLs change rarely; this helper is called once per
# badge on /tasks, /arcs, /bvp etc. (28× on /arcs/arc-006). Cache eviction is
# acceptable on app restart — no stale-write hazard since the helper reads
# fresh YAML on cold cache.
from functools import lru_cache


@lru_cache(maxsize=128)
def arc_display(arc_id_or_slug: str | None) -> str:
    """Return 'arc-NNN · slug' for a given arc_id or slug, with graceful
    fallback to the input when either form is unresolvable.

    Behaviour:
      - Empty/None input → returns "" (caller decides whether to render).
      - Resolvable: returns f"{canonical_id} · {slug}".
      - Slug resolves but YAML lacks `id:` field → returns slug alone.
      - Cannot resolve to a known arc → returns input verbatim (orphan ref).
    """
    if not arc_id_or_slug:
        return ""
    s = str(arc_id_or_slug).strip()
    if not s:
        return ""
    data = _read_arc(s)
    if not data:
        return s  # orphan reference — best-effort, render as-is
    canonical_id = data.get("id")
    slug = data.get("slug")
    if canonical_id and slug and canonical_id != slug:
        return f"{canonical_id} · {slug}"
    # Legacy arc missing canonical id, or id==slug (degenerate) — fall back to slug
    return str(slug or canonical_id or s)


_RECENT_PATHS_CACHE: tuple[float, set[str]] | None = None


def _recent_task_paths() -> set[str]:
    """T-1855 helper: single git log over the last FW_STALE_ARC_DAYS days
    returning all `.tasks/{active,completed}/T-*.md` file paths touched.

    One subprocess per request (or per TTL window) instead of one per arc —
    Watchtower /arcs hit 15s cold-cache timeouts on T-1853 Playwright when
    we shelled out per-arc. Cached for _STALE_CACHE_TTL_SEC seconds.
    """
    global _RECENT_PATHS_CACHE
    now = time.time()
    if _RECENT_PATHS_CACHE is not None and (now - _RECENT_PATHS_CACHE[0]) < _STALE_CACHE_TTL_SEC:
        return _RECENT_PATHS_CACHE[1]
    try:
        result = subprocess.run(
            ["git", "-C", str(PROJECT_ROOT), "log",
             f"--since={_STALE_DAYS}.days.ago", "--name-only", "--format=", "--",
             ".tasks/active/", ".tasks/completed/"],
            capture_output=True, text=True, timeout=10,
        )
        paths = {ln.strip() for ln in result.stdout.splitlines() if ln.strip()}
    except (subprocess.SubprocessError, OSError):
        paths = set()  # Defensive: empty set means "claim nothing recent",
                       # which makes every arc *look* stale — but we cache it
                       # for 60s and the next request retries.
    _RECENT_PATHS_CACHE = (now, paths)
    return paths


# T-1880 (T-NEW-15): scan helpers extracted to lib/arc_membership.py for
# shared use across web/blueprints/{arcs,core,tasks}.py. Cached wrappers
# below remain local to this blueprint (request-scoped TTL is a
# Watchtower concern, not a shared-library one).


def _scan_tasks_by_arc_id() -> dict[str, list[str]]:
    """T-1855: arc_id value → [repo-relative path, ...]. Path-valued.

    Pre-T-1880 this was inline. Now a thin pass-through to the shared
    helper. Wrapper kept so cached layer (`_arc_tasks_by_id`) and existing
    test imports stay stable.
    """
    return _scan_tasks_by_arc_id_shared(PROJECT_ROOT)


def _scan_tasks_by_arc_membership() -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """Returns (by_arc_id, by_tag). Thin pass-through to the shared
    helper (lib/arc_membership.py) — extracted in T-1880.
    """
    return _scan_tasks_by_arc_membership_shared(PROJECT_ROOT)


_ARC_TASKS_CACHE: tuple[float, dict[str, list[str]]] | None = None
_ARC_MEMBERSHIP_CACHE: tuple[float, tuple[dict[str, list[str]], dict[str, list[str]]]] | None = None


def _arc_membership() -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """Cached wrapper for _scan_tasks_by_arc_membership."""
    global _ARC_MEMBERSHIP_CACHE
    now = time.time()
    if _ARC_MEMBERSHIP_CACHE is not None and (now - _ARC_MEMBERSHIP_CACHE[0]) < _STALE_CACHE_TTL_SEC:
        return _ARC_MEMBERSHIP_CACHE[1]
    pair = _scan_tasks_by_arc_membership()
    _ARC_MEMBERSHIP_CACHE = (now, pair)
    return pair


def _arc_tasks_by_id() -> dict[str, list[str]]:
    """Cached wrapper for _scan_tasks_by_arc_id() with _STALE_CACHE_TTL_SEC TTL."""
    global _ARC_TASKS_CACHE
    now = time.time()
    if _ARC_TASKS_CACHE is not None and (now - _ARC_TASKS_CACHE[0]) < _STALE_CACHE_TTL_SEC:
        return _ARC_TASKS_CACHE[1]
    by_arc = _scan_tasks_by_arc_id()
    _ARC_TASKS_CACHE = (now, by_arc)
    return by_arc


def _arc_is_stale(arc_slug: str, arc_numeric: str, arc_status: str,
                  recent_paths: set[str], tasks_by_arc: dict[str, list[str]]) -> bool:
    """T-1855: True iff arc is in-progress AND no task with matching arc_id:
    has been touched in the last FW_STALE_ARC_DAYS days.

    Pre-computed inputs:
      - recent_paths: set of repo-relative paths from `_recent_task_paths()`
      - tasks_by_arc: dict from `_arc_tasks_by_id()` keyed on arc slug/arc-NNN

    Returns False on non-in-progress arcs, zero-population arcs, fresh arcs.
    Defensive: never claims staleness on uncertainty.
    """
    if arc_status != "in-progress":
        return False
    paths: list[str] = []
    paths.extend(tasks_by_arc.get(arc_slug, []))
    if arc_numeric and arc_numeric != arc_slug:
        paths.extend(tasks_by_arc.get(arc_numeric, []))
    if not paths:
        return False  # zero-population: never stale
    return not any(p in recent_paths for p in paths)


def _list_arcs() -> list[dict[str, Any]]:
    """Return all arcs sorted by status (in-progress first), then created desc."""
    arcs_dir = _arcs_dir()
    if not arcs_dir.is_dir():
        return []
    out: list[dict[str, Any]] = []
    focus = _read_focus()
    # T-1855: precompute "tasks touched in last N days" + "tasks by arc_id"
    # once per request — both are cached for _STALE_CACHE_TTL_SEC.
    recent_paths = _recent_task_paths()
    tasks_by_arc = _arc_tasks_by_id()
    # T-1853 perf: batch membership scan so we don't call _scan_tasks_by_tag
    # 5 times (each yaml-parses 1841 task files → 10s page renders).
    by_arc_id_idx, by_tag_idx = _arc_membership()
    for af in sorted(arcs_dir.glob("*.yaml")):
        try:
            data = yaml.safe_load(af.read_text()) or {}
        except (yaml.YAMLError, OSError):
            continue
        if not isinstance(data, dict):
            continue
        # T-1817: task_count must reflect merged source-of-truth (legacy + tag-scan + arc_id),
        # not just the YAML's denormalised cache.
        # T-1853 perf: use pre-batched membership indices (by_arc_id_idx, by_tag_idx)
        # — calling _scan_tasks_by_tag 5× per request blew /arcs to 10s page-render.
        legacy = data.get("constituent_tasks") or []
        legacy_ids = [str(t).strip() for t in legacy if str(t).strip()] if isinstance(legacy, list) else []
        slug = str(data.get("slug") or af.stem).strip()
        arc_numeric_id_pre = str(data.get("id") or slug).strip()
        tagged_ids = by_tag_idx.get(f"arc:{slug}", []) if slug else []
        arc_id_ids = by_arc_id_idx.get(slug, []) if slug else []
        if arc_numeric_id_pre and arc_numeric_id_pre != slug:
            arc_id_ids = list(arc_id_ids) + by_arc_id_idx.get(arc_numeric_id_pre, [])
        merged_count = len(set(legacy_ids) | set(tagged_ids) | set(arc_id_ids))
        # YAML may parse ISO-8601 to datetime; coerce to str for stable rendering + sort.
        created_raw = data.get("created", "")
        created_str = created_raw.isoformat() if hasattr(created_raw, "isoformat") else str(created_raw or "")
        closed_raw = data.get("closed_at")
        closed_str = closed_raw.isoformat() if hasattr(closed_raw, "isoformat") else (str(closed_raw) if closed_raw else None)
        # T-1848: `id` is now arc-NNN (immutable). `slug` is the filename stem
        # (human-readable). Both surface for routing / display.
        arc_numeric_id = str(data.get("id") or slug).strip()
        arc_status = str(data.get("status", "?"))
        out.append({
            "id": arc_numeric_id,
            "slug": slug,
            "name": data.get("name", "(no name)"),
            "status": arc_status,
            "decision": data.get("decision"),
            "anchor_task": data.get("anchor_task"),
            "task_count": merged_count,
            "created": created_str,
            "closed_at": closed_str,
            "focused": (focus is not None and (focus == arc_numeric_id or focus == slug)),
            # T-1855: stale signal — in-progress arc with no recent task commits.
            "stale": _arc_is_stale(slug, arc_numeric_id, arc_status, recent_paths, tasks_by_arc),
        })
    # T-1852: present-order rank — in-progress first (active work), then draft
    # (not-yet-started), then closed (shipped), abandoned last (parked).
    # Within each rank, newest created first.
    status_rank = {"in-progress": 0, "draft": 1, "closed": 2, "abandoned": 3}
    out.sort(key=lambda a: a["created"], reverse=True)
    out.sort(key=lambda a: status_rank.get(a["status"], 9))
    return out


def _filter_arcs(arcs: list[dict[str, Any]], filt: str) -> list[dict[str, Any]]:
    """T-1853: Restrict arc list to one lifecycle state. 'all' or unknown
    filter values pass through unchanged."""
    if filt == "all" or filt not in _LIFECYCLE_STATES:
        return arcs
    return [a for a in arcs if a.get("status") == filt]


def _state_counts(arcs: list[dict[str, Any]]) -> dict[str, int]:
    """T-1853: Counts per lifecycle state for filter-tab badges. Includes
    'all' as the total count."""
    counts = {s: 0 for s in _LIFECYCLE_STATES}
    for a in arcs:
        s = a.get("status")
        if s in counts:
            counts[s] += 1
    counts["all"] = len(arcs)
    return counts


def _read_task_meta(task_id: str) -> dict[str, Any] | None:
    """Locate task file in active/ or completed/ and return its frontmatter + completion."""
    tasks_dir = PROJECT_ROOT / ".tasks"
    for sub in ("active", "completed"):
        for cand in (tasks_dir / sub).glob(f"{task_id}-*.md"):
            try:
                text = cand.read_text()
            except OSError:
                continue
            m = _FRONTMATTER_RE.search(text)
            if not m:
                continue
            try:
                fm = yaml.safe_load(m.group(1)) or {}
            except yaml.YAMLError:
                continue
            return {
                "id": task_id,
                "name": fm.get("name", "(no name)"),
                "status": fm.get("status", "?"),
                "horizon": fm.get("horizon", "?"),
                "type": fm.get("workflow_type", "?"),
                "completed": (sub == "completed"),
                # T-1909: arc_id + tags so the arc_badge macro can render
                # membership on the arc-detail constituent-task table.
                "arc_id": fm.get("arc_id") or "",
                "_tags": [str(t) for t in (fm.get("tags") or [])],
            }
    return None


def _scan_tasks_by_tag(tag: str) -> list[str]:
    """Return T-IDs of tasks tagged with `tag` (e.g. 'arc:dispatch-safety').

    Mirrors `lib/arc.sh:_arc_tasks_with_tag` — the canonical source of truth for
    arc constituency (T-1813 audit precedent, T-1817 web sibling). The YAML's
    `constituent_tasks` field is a denormalised cache that misses tag-only
    additions.
    """
    if not tag:
        return []
    tasks_dir = PROJECT_ROOT / ".tasks"
    found: list[str] = []
    for sub in ("active", "completed"):
        sub_dir = tasks_dir / sub
        if not sub_dir.is_dir():
            continue
        for md in sub_dir.glob("T-*.md"):
            try:
                text = md.read_text()
            except OSError:
                continue
            m = _FRONTMATTER_RE.search(text)
            if not m:
                continue
            try:
                fm = yaml.safe_load(m.group(1)) or {}
            except yaml.YAMLError:
                continue
            tags = fm.get("tags") or []
            if not isinstance(tags, list):
                continue
            if tag in tags:
                tid = str(fm.get("id") or "").strip()
                if tid:
                    found.append(tid)
    return sorted(set(found))


def _resolve_constituents(arc: dict[str, Any]) -> list[dict[str, Any]]:
    """Merge legacy `constituent_tasks` with both arc-membership signals.

    Sources unioned (T-1876, sibling of T-1874/T-1875):
      1. Legacy `constituent_tasks:` (denormalised cache, preserves authored order)
      2. arc_id: frontmatter — canonical post-T-1850 (T-1849), keyed by slug
         OR arc-NNN (dual identity, T-1848)
      3. Legacy `arc:<slug>` tag scan — pre-T-1850 form, still honored

    Legacy entries first (preserves author order); membership-scan entries
    appended in sorted order; dedup by task id. The membership index comes
    from `_scan_tasks_by_arc_membership()` which is request-cached (60s) and
    avoids per-call yaml-parsing the full task corpus.
    """
    legacy = arc.get("constituent_tasks") or []
    if not isinstance(legacy, list):
        legacy = []
    # T-1848: tag/arc_id scan uses slug (filename stem). For arc_id we also
    # accept the arc-NNN form because authors write either.
    slug = str(arc.get("slug") or "").strip()
    arc_numeric = str(arc.get("id") or "").strip()

    by_arc_id, by_tag = _scan_tasks_by_arc_membership()
    membership: list[str] = []
    if slug:
        membership.extend(by_arc_id.get(slug, []))
        membership.extend(by_tag.get(f"arc:{slug}", []))
    if arc_numeric and arc_numeric != slug:
        membership.extend(by_arc_id.get(arc_numeric, []))
    # Sort for determinism on the appended portion (legacy stays in author order).
    membership = sorted(set(membership))

    merged_ids: list[str] = []
    seen: set[str] = set()
    for tid in list(legacy) + membership:
        s = str(tid).strip()
        if not s or s in seen:
            continue
        merged_ids.append(s)
        seen.add(s)

    out: list[dict[str, Any]] = []
    for tid in merged_ids:
        meta = _read_task_meta(tid)
        if meta is None:
            out.append({
                "id": tid,
                "name": "(task file not found)",
                "status": "?",
                "horizon": "?",
                "type": "?",
                "completed": False,
                "missing": True,
            })
        else:
            meta["missing"] = False
            out.append(meta)
    return out


def _enrich_constituents_with_bvp(constituents: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """T-1978: attach BVP_norm / BVP_raw / cost / mode to each constituent.

    Reuses _compute_bvp / _compute_cost from web.blueprints.bvp so the
    numbers shown here match the /bvp scatter exactly. Confirmed scores
    take precedence over proposed (mirrors _collect_task_points).
    Tasks with no score data carry None (template renders '—').
    """
    from web.blueprints.bvp import (
        _load_policy, _driver_weights, _compute_bvp, _compute_cost,
        _resolve_cost_estimate, _parse_frontmatter, _latest_proposed_scores,
    )
    policy = _load_policy()
    weights = _driver_weights(policy)

    tasks_dir = PROJECT_ROOT / ".tasks"
    out: list[dict[str, Any]] = []
    for c in constituents:
        c2 = dict(c)
        if c.get("missing"):
            c2.update({"bvp_norm": None, "bvp_raw": None, "cost": None, "bvp_mode": ""})
            out.append(c2)
            continue
        tid = c.get("id")
        path = None
        for sub in ("active", "completed"):
            cands = list((tasks_dir / sub).glob(f"{tid}-*.md"))
            if cands:
                path = cands[0]
                break
        if path is None:
            c2.update({"bvp_norm": None, "bvp_raw": None, "cost": None, "bvp_mode": ""})
            out.append(c2)
            continue
        fm = _parse_frontmatter(path) or {}
        confirmed = fm.get("bvp_scores") or {}
        proposed = _latest_proposed_scores(fm)
        if not confirmed and not proposed:
            c2.update({"bvp_norm": None, "bvp_raw": None, "cost": None, "bvp_mode": ""})
            out.append(c2)
            continue
        is_proposed = not confirmed
        scores = confirmed if confirmed else proposed
        raw, norm = _compute_bvp(scores, weights)
        ce, ce_mode = _resolve_cost_estimate(fm, is_proposed=is_proposed)
        cost, _br, _tier, _effort, src = _compute_cost(ce, default_when_absent=is_proposed)
        c2.update({
            "bvp_norm": round(norm, 3) if norm is not None else None,
            "bvp_raw": raw,
            "cost": round(cost, 2) if cost is not None else None,
            "cost_source": src,
            "bvp_mode": "proposed" if is_proposed else "confirmed",
        })
        out.append(c2)
    return out


def _completion_stats(constituents: list[dict[str, Any]]) -> dict[str, Any]:
    if not constituents:
        return {"completed": 0, "total": 0, "ratio": 0.0}
    completed = sum(1 for c in constituents if c["completed"])
    total = len(constituents)
    return {
        "completed": completed,
        "total": total,
        "ratio": (completed / total) if total else 0.0,
    }


_DEMO_HINT_RE = re.compile(
    r"(docs/reports/[^\s)\]\"'<>`]+|https?://[^\s)\]\"'<>`]+)"
)


def _anchor_recommendation(arc: dict[str, Any]) -> dict[str, Any]:
    """T-1960: read the arc's anchor-task `## Recommendation` block and return
    a structured dict for /arcs/<slug>/close.

    Returns keys: present (bool), verdict, rationale, evidence, raw,
    suggested_demo (first docs/reports/* path OR https?:// URL found in
    evidence text, '' when none), anchor_id ('' when no anchor_task).
    All keys always present.
    """
    out = {
        "present": False,
        "verdict": "?",
        "rationale": "",
        "evidence": "",
        "rationale_html": "",
        "evidence_html": "",
        "raw": "",
        "suggested_demo": "",
        "anchor_id": "",
    }
    anchor = str(arc.get("anchor_task") or "").strip()
    if not anchor:
        return out
    out["anchor_id"] = anchor
    body = None
    for sub in ("active", "completed"):
        candidates = sorted((PROJECT_ROOT / ".tasks" / sub).glob(f"{anchor}-*.md"))
        if candidates:
            try:
                body = candidates[0].read_text(encoding="utf-8")
            except OSError:
                body = None
            break
    if not body:
        return out
    from web.shared import extract_recommendation, render_markdown_safe
    rec = extract_recommendation(body)
    if not rec.get("raw"):
        return out
    out["present"] = True
    out["verdict"] = rec.get("verdict", "?")
    out["rationale"] = rec.get("rationale", "")
    out["evidence"] = rec.get("evidence", "")
    out["raw"] = rec.get("raw", "")
    out["rationale_html"] = render_markdown_safe(out["rationale"])
    out["evidence_html"] = render_markdown_safe(out["evidence"])
    m = _DEMO_HINT_RE.search(out["evidence"])
    if m:
        out["suggested_demo"] = m.group(1).rstrip(".,;:!?)")
    return out


def _arc_reports(arc_id: str) -> list[dict[str, str]]:
    """Find docs/reports/<arc_id>-*.md files for this arc.

    Returns list of {name, path} where path is relative to PROJECT_ROOT
    (the /file/ viewer route prepends /file/ for navigation).
    """
    reports_dir = PROJECT_ROOT / "docs" / "reports"
    if not reports_dir.is_dir():
        return []
    out: list[dict[str, str]] = []
    for f in sorted(reports_dir.glob(f"{arc_id}-*.md")):
        out.append({
            "name": f.stem,
            "path": f"docs/reports/{f.name}",
        })
    return out


@bp.route("/arcs")
def arcs_index():
    """T-1904: List arcs as a 4-column kanban (draft / in-progress / closed /
    abandoned), matching the visual pattern at /tasks.

    Supersedes T-1853 lifecycle filter tabs — the kanban shows every state
    at once. Query-param `?status=…` is still honoured for backward compat
    (returns the same flat list as before, no kanban), but the default
    landing view is the kanban.
    """
    all_arcs = _list_arcs()
    counts = _state_counts(all_arcs)

    # T-1910 Slice 4: filters orthogonal to view mode. Apply BEFORE choosing view.
    focused_only = request.args.get("focused", "").lower() in ("1", "true", "yes")
    stale_only = request.args.get("stale", "").lower() in ("1", "true", "yes")
    arcs_filtered = all_arcs
    if focused_only:
        arcs_filtered = [a for a in arcs_filtered if a.get("focused")]
    if stale_only:
        arcs_filtered = [a for a in arcs_filtered if a.get("stale")]

    # Backward-compat: ?status=… still renders the legacy flat list.
    # T-1910: also expose `?view=list` as the explicit see-all switch (same renderer).
    legacy_filter = request.args.get("status")
    view = request.args.get("view", "").lower()
    if legacy_filter is not None or view == "list":
        if legacy_filter is not None and legacy_filter not in _FILTER_LABELS:
            legacy_filter = _DEFAULT_FILTER
        arcs = _filter_arcs(arcs_filtered, legacy_filter) if legacy_filter else arcs_filtered
        return render_page(
            "arcs_index.html",
            page_title="Arcs",
            arcs=arcs,
            all_arcs_count=len(all_arcs),
            current_filter=legacy_filter or "all",
            filter_labels=list(_FILTER_LABELS),
            state_counts=counts,
            stale_days=_STALE_DAYS,
            kanban_mode=False,
            focused_only=focused_only,
            stale_only=stale_only,
            view="list",
        )

    # Default: kanban mode — group filtered arcs by status.
    columns = []
    for state in _LIFECYCLE_STATES:
        columns.append({
            "status": state,
            "arcs": [a for a in arcs_filtered if a.get("status") == state],
            "count": sum(1 for a in arcs_filtered if a.get("status") == state),
        })
    return render_page(
        "arcs_index.html",
        page_title="Arcs",
        all_arcs_count=len(all_arcs),
        columns=columns,
        state_counts=counts,
        stale_days=_STALE_DAYS,
        kanban_mode=True,
        focused_only=focused_only,
        stale_only=stale_only,
        view="board",
    )


@bp.route("/arcs/<arc_id>")
def arc_detail(arc_id: str):
    """Detail page for one arc.

    T-1848: arc_id may be the slug (e.g., dispatch-safety) or the numeric
    id (arc-001). Both resolve to the same arc; _read_arc handles dispatch.
    """
    arc = _read_arc(arc_id)
    if arc is None:
        abort(404, description=f"Arc '{arc_id}' not registered. Run `fw arc list` to see registered arcs.")
    # T-1848: use the slug (filename stem) for tag scans, reports lookup,
    # and focus comparison — even when the user navigated by arc-NNN.
    arc_slug = str(arc.get("slug") or arc_id).strip()
    constituents = _resolve_constituents(arc)
    stats = _completion_stats(constituents)
    # T-1978: enrich constituents with per-task BVP_norm / BVP_raw / cost so the
    # table answers "which tasks pull the average up/down". Reuses the /bvp
    # compute helpers — same math source, same numbers as the scatter.
    constituents = _enrich_constituents_with_bvp(constituents)
    focus_val = _read_focus()
    arc_numeric = str(arc.get("id") or "").strip()
    focused = (focus_val == arc_slug or (arc_numeric and focus_val == arc_numeric))
    has_specialized_view = (arc_slug == "orchestrator-rethink")
    reports = _arc_reports(arc_slug)
    # T-1930 (arc-006): BVP signals — arc-level scores, coherence, proposed drivers.
    bvp_info = _bvp_signals(arc, arc_slug, arc_numeric)
    return render_page(
        "arc_detail.html",
        page_title=f"Arc: {arc.get('name', arc_id)}",
        arc=arc,
        arc_id=arc_id,
        arc_slug=arc_slug,
        constituents=constituents,
        stats=stats,
        focused=focused,
        has_specialized_view=has_specialized_view,
        reports=reports,
        bvp_info=bvp_info,
    )


# ── T-1930 (arc-006): BVP signals on arc detail ───────────────────────────
# Reuses compute_bvp from web/blueprints/bvp.py to keep one math source.
# Coherence check mirrors agents/audit/audit.sh bvp_coherence_findings —
# same per-driver formula, scoped to a single arc.

def _bvp_coherence_for_arc(arc: dict, arc_slug: str, arc_numeric: str) -> list[dict]:
    """Return per-driver coherence findings for one arc.

    Same rules as agents/audit/audit.sh:
      - arc claims driver D_n with weight ≥ ARC_MIN (default 4)
      - constituents are tasks tagged arc_id=<slug or arc-NNN>
      - finding fires when ≥ FRACTION of scoring constituents score
        the driver ≤ TASK_MAX (default 1)
    Skips silently when the corpus can't answer (no scoring tasks).
    """
    if arc.get("status") != "in-progress":
        return []
    arc_min = int(os.environ.get("BVP_COHERENCE_ARC_MIN", "4"))
    task_max = int(os.environ.get("BVP_COHERENCE_TASK_MAX", "1"))
    fraction = float(os.environ.get("BVP_COHERENCE_FRACTION", "0.70"))

    claims: dict[str, int] = {}
    for sd in (arc.get("scoped_drivers") or []):
        try:
            w = int(sd.get("weight", 0))
        except (TypeError, ValueError):
            continue
        if w >= arc_min:
            claims[str(sd.get("name") or "?")] = w
    arc_bvp = arc.get("bvp_scores") or {}
    if isinstance(arc_bvp, dict):
        for did, val in arc_bvp.items():
            try:
                v = int(val)
            except (TypeError, ValueError):
                continue
            if v >= arc_min:
                claims[str(did)] = v
    if not claims:
        return []

    # Collect constituent task paths (either slug or arc-NNN form).
    constituent_paths: list[Path] = []
    tasks_dir = PROJECT_ROOT / ".tasks"
    for sub in ("active", "completed"):
        for p in (tasks_dir / sub).glob("T-*.md"):
            try:
                m = _FRONTMATTER_RE.match(p.read_text())
            except OSError:
                continue
            if not m:
                continue
            try:
                fm = yaml.safe_load(m.group(1)) or {}
            except yaml.YAMLError:
                continue
            aid = str(fm.get("arc_id") or "").strip()
            if aid and (aid == arc_slug or (arc_numeric and aid == arc_numeric)):
                constituent_paths.append(p)
    if not constituent_paths:
        return []

    findings: list[dict] = []
    for driver_id, claim_val in claims.items():
        scores = []
        for p in constituent_paths:
            try:
                m = _FRONTMATTER_RE.match(p.read_text())
            except OSError:
                continue
            if not m:
                continue
            try:
                fm = yaml.safe_load(m.group(1)) or {}
            except yaml.YAMLError:
                continue
            s = (fm.get("bvp_scores") or {}).get(driver_id)
            if s is None:
                continue
            try:
                scores.append(int(s))
            except (TypeError, ValueError):
                continue
        if not scores:
            continue
        n_low = sum(1 for s in scores if s <= task_max)
        n_total = len(scores)
        frac = n_low / n_total
        if frac >= fraction:
            findings.append({
                "driver": driver_id,
                "claim": claim_val,
                "n_low": n_low,
                "n_total": n_total,
                "frac": frac,
                "task_max": task_max,
                "fraction_threshold": fraction,
            })
    return findings


def _bvp_signals(arc: dict, arc_slug: str, arc_numeric: str) -> dict:
    """Aggregate BVP signals shown on /arcs/<id>.

    Returns:
      { has_scores, raw, norm, per_driver, weights, coherence_findings,
        proposed_drivers, scoped_drivers }

    has_scores is False when the arc has no `bvp_scores:` — the block
    still renders so the human sees proposed-driver approve buttons.
    """
    from web.blueprints.bvp import (
        _compute_bvp, _driver_weights, _load_policy,
        _latest_proposed_scores, _arc_member_tasks, _arc_rolled_up_scores,
    )

    policy = _load_policy()
    weights = _driver_weights(policy)
    arc_scores: dict = arc.get("bvp_scores") or {}
    bvp_mode = ""
    # T-1939: parity with /bvp scatter (T-1934 + T-1936). Resolution ladder
    # mirrors web.blueprints.bvp._collect_arc_points: direct-confirmed →
    # direct-proposed → constituent rollup → empty.
    if isinstance(arc_scores, dict) and arc_scores:
        bvp_mode = "direct-confirmed"
    else:
        direct_proposed = _latest_proposed_scores(arc)
        if direct_proposed:
            arc_scores, bvp_mode = direct_proposed, "direct-proposed"
        else:
            members = _arc_member_tasks(arc_slug, arc_numeric)
            rolled, mode = _arc_rolled_up_scores(members)
            if rolled:
                arc_scores, bvp_mode = rolled, mode  # derived-{confirmed,proposed}

    if isinstance(arc_scores, dict) and arc_scores:
        raw, norm = _compute_bvp(arc_scores, weights)
        has_scores = True
    else:
        raw, norm = 0, 0.0
        has_scores = False

    per_driver = []
    for d_id, w in weights.items():
        s = arc_scores.get(d_id) if isinstance(arc_scores, dict) else None
        try:
            s_int = int(s) if s is not None else None
        except (TypeError, ValueError):
            s_int = None
        per_driver.append({
            "id": d_id,
            "weight": w,
            "score": s_int,
            "contrib": (s_int * w) if s_int is not None else None,
        })

    proposed = arc.get("proposed_scoped_drivers") or []
    if not isinstance(proposed, list):
        proposed = []
    # Render newest first (D7).
    proposed_sorted = sorted(
        (p for p in proposed if isinstance(p, dict)),
        key=lambda p: str(p.get("ts") or ""),
        reverse=True,
    )

    scoped = arc.get("scoped_drivers") or []
    if not isinstance(scoped, list):
        scoped = []

    coherence = _bvp_coherence_for_arc(arc, arc_slug, arc_numeric)

    return {
        "has_scores": has_scores,
        "raw": raw,
        "norm": norm,
        "per_driver": per_driver,
        "weights": weights,
        "coherence_findings": coherence,
        "proposed_drivers": proposed_sorted,
        "scoped_drivers": scoped,
        "bvp_mode": bvp_mode,  # T-1939: provenance label (see ladder above)
    }


@bp.route("/api/arc/<arc_id>/approve-driver", methods=["POST"])
def arc_approve_driver(arc_id):
    """T-1930: shell `fw arc approve-driver <slug> '<name>' [--weight N] --from-watchtower`.

    Returns the rendered arc detail page (redirect) on success, or an
    error message inline on failure.
    """
    from flask import redirect
    if not _ARC_ID_RE.match(arc_id):
        abort(404)
    slug = _resolve_arc_slug(arc_id)
    if slug is None:
        abort(404)
    name = (request.form.get("name") or "").strip()
    weight_raw = (request.form.get("weight") or "").strip()
    rationale = (request.form.get("rationale") or "").strip()
    if not name:
        return '<p style="color: var(--pico-del-color);">Driver name required.</p>', 400
    if len(name) > 64:
        return '<p style="color: var(--pico-del-color);">Driver name too long (max 64).</p>', 400
    cmd = ["bin/fw", "arc", "approve-driver", slug, name, "--from-watchtower"]
    if weight_raw:
        try:
            w = int(weight_raw)
        except ValueError:
            return '<p style="color: var(--pico-del-color);">Weight must be an integer.</p>', 400
        cmd += ["--weight", str(w)]
    if rationale:
        cmd += ["--rationale", rationale]
    try:
        result = subprocess.run(
            cmd, cwd=str(PROJECT_ROOT),
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.SubprocessError, OSError) as e:
        return f'<p style="color: var(--pico-del-color);">Failed to invoke fw: {e}</p>', 500
    if result.returncode != 0:
        err = (result.stderr or "").strip() or f"fw arc approve-driver exited {result.returncode}"
        # Show only first line (block messages can be long).
        first = err.splitlines()[0] if err else "unknown error"
        return f'<p style="color: var(--pico-del-color);">{first}</p>', 400
    return redirect(f"/arcs/{slug}")


@bp.route("/api/arc/<arc_id>/add-driver", methods=["POST"])
def arc_add_driver(arc_id):
    """T-1976: shell `fw arc approve-driver <slug> '<name>' --weight N --rationale R --from-watchtower`.

    Dedicated route for adding a CUSTOM scoped driver (not from estimator
    proposals — those use /approve-driver). Stricter validation than the
    Approve flow: name, weight, and rationale (≥30 chars) are all required.
    Symmetric with /api/bvp/driver/add (T-1964).
    """
    from flask import redirect
    if not _ARC_ID_RE.match(arc_id):
        abort(404)
    slug = _resolve_arc_slug(arc_id)
    if slug is None:
        abort(404)
    name = (request.form.get("name") or "").strip()
    weight_raw = (request.form.get("weight") or "").strip()
    rationale = (request.form.get("rationale") or "").strip()
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", name):
        return '<p style="color: var(--pico-del-color);">Driver name must match [A-Za-z][A-Za-z0-9_-]*</p>', 400
    if len(name) > 64:
        return '<p style="color: var(--pico-del-color);">Driver name too long (max 64).</p>', 400
    try:
        weight = int(weight_raw)
    except ValueError:
        return '<p style="color: var(--pico-del-color);">Weight must be an integer 1-6.</p>', 400
    if not 1 <= weight <= 6:
        return f'<p style="color: var(--pico-del-color);">Weight {weight} out of range (1-6, M2 cap).</p>', 400
    if len(rationale) < 30:
        return '<p style="color: var(--pico-del-color);">Rationale must be ≥30 characters (R6).</p>', 400
    cmd = [
        "bin/fw", "arc", "approve-driver", slug, name,
        "--weight", str(weight),
        "--rationale", rationale,
        "--from-watchtower",
    ]
    try:
        result = subprocess.run(
            cmd, cwd=str(PROJECT_ROOT),
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.SubprocessError, OSError) as e:
        return f'<p style="color: var(--pico-del-color);">Failed to invoke fw: {e}</p>', 500
    if result.returncode != 0:
        err = (result.stderr or "").strip() or f"fw arc approve-driver exited {result.returncode}"
        first = err.splitlines()[0] if err else "unknown error"
        return f'<p style="color: var(--pico-del-color);">{first}</p>', 400
    return redirect(f"/arcs/{slug}")


@bp.route("/api/arc/<arc_id>/remove-driver", methods=["POST"])
def arc_remove_driver(arc_id):
    """T-1976: shell `fw arc remove-driver <slug> '<name>' --rationale R --from-watchtower`.

    Symmetric with /api/bvp/driver/remove (T-1965).
    """
    from flask import redirect
    if not _ARC_ID_RE.match(arc_id):
        abort(404)
    slug = _resolve_arc_slug(arc_id)
    if slug is None:
        abort(404)
    name = (request.form.get("name") or "").strip()
    rationale = (request.form.get("rationale") or "").strip()
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", name):
        return '<p style="color: var(--pico-del-color);">Driver name must match [A-Za-z][A-Za-z0-9_-]*</p>', 400
    if len(rationale) < 30:
        return '<p style="color: var(--pico-del-color);">Rationale must be ≥30 characters (R6).</p>', 400
    cmd = [
        "bin/fw", "arc", "remove-driver", slug, name,
        "--rationale", rationale,
        "--from-watchtower",
    ]
    try:
        result = subprocess.run(
            cmd, cwd=str(PROJECT_ROOT),
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.SubprocessError, OSError) as e:
        return f'<p style="color: var(--pico-del-color);">Failed to invoke fw: {e}</p>', 500
    if result.returncode != 0:
        err = (result.stderr or "").strip() or f"fw arc remove-driver exited {result.returncode}"
        first = err.splitlines()[0] if err else "unknown error"
        return f'<p style="color: var(--pico-del-color);">{first}</p>', 400
    return redirect(f"/arcs/{slug}")


@bp.route("/api/arc/<arc_id>/set-scoped-weight", methods=["POST"])
def arc_set_scoped_weight(arc_id):
    """T-1977: commit scoped-driver weight changes via `fw arc set-scoped-weight`.

    Mirrors /api/bvp/commit-weights (T-1929) at arc scope. Body fields:
      rationale : str (≥30 chars, R6)
      changes   : JSON list of {name: str, weight: 1-6}

    Shells once per change to `bin/fw arc set-scoped-weight <slug> <name>
    --weight N --rationale "<...>" --from-watchtower`. Stops on first failure.
    §ACD + history audit stay in the fw command.
    """
    if not _ARC_ID_RE.match(arc_id):
        abort(404)
    slug = _resolve_arc_slug(arc_id)
    if slug is None:
        abort(404)
    rationale = (request.form.get("rationale") or "").strip()
    raw_changes = request.form.get("changes") or "[]"
    if len(rationale) < 30:
        return "Rationale must be ≥30 characters (R6).", 400
    try:
        changes = json.loads(raw_changes)
    except json.JSONDecodeError:
        return "Invalid changes payload (not JSON).", 400
    if not isinstance(changes, list) or not changes:
        return "No changes provided.", 400
    if len(changes) > 3:
        return "Too many changes (max 3 — M2 cap).", 400

    results = []
    for change in changes:
        if not isinstance(change, dict):
            return f"Bad change shape: {change!r}", 400
        name = str(change.get("name") or "").strip()
        try:
            weight = int(change.get("weight"))
        except (TypeError, ValueError):
            return f"Bad weight for driver {name!r}", 400
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", name):
            return f"Bad driver name {name!r}", 400
        if not 1 <= weight <= 6:
            return f"Driver {name}: weight {weight} out of range (1-6, M2)", 400
        cmd = [
            "bin/fw", "arc", "set-scoped-weight", slug, name,
            "--weight", str(weight),
            "--rationale", rationale,
            "--from-watchtower",
        ]
        try:
            result = subprocess.run(
                cmd, cwd=str(PROJECT_ROOT),
                capture_output=True, text=True, timeout=30,
            )
        except (subprocess.SubprocessError, OSError) as e:
            return f"Subprocess error on {name}: {e}", 500
        if result.returncode != 0:
            err = (result.stderr or result.stdout or "").strip()
            first = err.splitlines()[0] if err else f"fw arc set-scoped-weight exited {result.returncode}"
            return f"Commit failed at {name}: {first}", 400
        results.append({"name": name, "weight": weight})
    return json.dumps({"committed": results, "count": len(results)}), 200, {"Content-Type": "application/json"}


@bp.route("/api/arc/<arc_id>/approve-none", methods=["POST"])
def arc_approve_none(arc_id):
    """T-1930: shell `fw arc approve-driver <slug> --none --justification "<≥30 chars>" --from-watchtower`."""
    from flask import redirect
    if not _ARC_ID_RE.match(arc_id):
        abort(404)
    slug = _resolve_arc_slug(arc_id)
    if slug is None:
        abort(404)
    justification = (request.form.get("justification") or "").strip()
    if len(justification) < 30:
        return '<p style="color: var(--pico-del-color);">Justification must be ≥30 characters (R6).</p>', 400
    cmd = [
        "bin/fw", "arc", "approve-driver", slug,
        "--none", "--justification", justification, "--from-watchtower",
    ]
    try:
        result = subprocess.run(
            cmd, cwd=str(PROJECT_ROOT),
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.SubprocessError, OSError) as e:
        return f'<p style="color: var(--pico-del-color);">Failed to invoke fw: {e}</p>', 500
    if result.returncode != 0:
        err = (result.stderr or "").strip() or f"fw arc approve-driver exited {result.returncode}"
        first = err.splitlines()[0] if err else "unknown error"
        return f'<p style="color: var(--pico-del-color);">{first}</p>', 400
    return redirect(f"/arcs/{slug}")


# ── T-1910: Slice 2 — inline edit endpoints ──────────────────────────────
# Updates a single top-level YAML field in .context/arcs/<slug>.yaml.
# Pure-regex (not yaml.dump) to preserve formatting, comments, and field order.

_ARC_ID_RE = re.compile(r"^(?:arc-\d+|[a-z][a-z0-9-]*)$")


def _update_arc_yaml_field(slug: str, field: str, value: str) -> tuple[bool, str]:
    """Regex-update a single top-level scalar field in the arc YAML file.

    Mirrors the pattern used in web/blueprints/tasks.py:_update_frontmatter_field
    so the surface behaves the same for arcs and tasks.
    """
    path = _arcs_dir() / f"{slug}.yaml"
    if not path.is_file():
        return False, f"Arc '{slug}' not found"
    try:
        text = path.read_text()
    except OSError as e:
        return False, f"Read error: {e}"
    # Quote the value so YAML-special characters don't break parsing.
    safe = value.replace("\\", "\\\\").replace('"', '\\"')
    quoted = f'"{safe}"'
    pattern = re.compile(rf'^({re.escape(field)}:\s*)(?:"[^"]*"|\S[^\n]*)?$', re.MULTILINE)
    if not pattern.search(text):
        return False, f"Field '{field}' not found in arc YAML"
    new_text = pattern.sub(rf"\g<1>{quoted}", text, count=1)
    try:
        path.write_text(new_text)
    except OSError as e:
        return False, f"Write error: {e}"
    return True, ""


@bp.route("/api/arc/<arc_id>/name", methods=["POST"])
def update_arc_name(arc_id):
    """T-1910: update arc YAML name field; return updated card-name HTML."""
    if not _ARC_ID_RE.match(arc_id):
        abort(404)
    slug = _resolve_arc_slug(arc_id)
    if slug is None:
        abort(404)
    name = (request.form.get("name", "") or "").strip()
    if not name:
        return '<p style="color: var(--pico-del-color);">Name cannot be empty</p>', 400
    if len(name) > 200:
        return '<p style="color: var(--pico-del-color);">Name too long (max 200)</p>', 400
    ok, err = _update_arc_yaml_field(slug, "name", name)
    if not ok:
        return f'<p style="color: var(--pico-del-color);">Error: {err}</p>', 500
    # Escape for HTML attribute + body
    import html as _html
    safe = _html.escape(name, quote=True)
    return f'<span class="arc-card-name editable-arc-name" title="{safe}">{safe}</span>'


@bp.route("/api/arc/<arc_id>/focus", methods=["POST"])
def toggle_arc_focus(arc_id):
    """T-1910: toggle focus for this arc (set if unfocused, clear if focused).

    Returns the updated focus-dot span HTML so htmx can swap it in place.
    """
    if not _ARC_ID_RE.match(arc_id):
        abort(404)
    slug = _resolve_arc_slug(arc_id)
    if slug is None:
        abort(404)

    focus_path = _focus_file()
    current = _read_focus()
    # The focus file stores either the slug or the arc-NNN id (whichever was
    # written by `fw arc focus`). Resolve current to a slug for comparison.
    current_slug = None
    if current:
        # current might be slug or arc-NNN — _resolve_arc_slug handles both
        current_slug = _resolve_arc_slug(current) or current

    now_focused = (current_slug != slug)  # toggle

    focus_path.parent.mkdir(parents=True, exist_ok=True)
    if now_focused:
        body = (
            "# Arc focus (T-1661). Set via 'fw arc focus <arc-id>'.\n"
            f"current_arc: {slug}\n"
            "focused_at: now\n"
        )
    else:
        body = (
            "# Arc focus (T-1661). Set via 'fw arc focus <arc-id>'.\n"
            "current_arc: null\n"
            "focused_at: null\n"
        )
    focus_path.write_text(body)

    cls = "on" if now_focused else "off"
    title = "Focused" if now_focused else "Not focused"
    return (
        f'<span class="focus-dot {cls}" '
        f'title="{title}" '
        f'data-focused="{ "true" if now_focused else "false" }"></span>'
    )


# T-1911 / T-1902: arc close-review Watchtower surface.
# GET renders the close form; POST shells to `fw arc close --from-watchtower`,
# which is the §ACD-exempt path designed for exactly this use case (T-1671).
# That answers the user's recurring question "why can't agent close" — agent
# CAN, on the human's behalf when the human clicks Submit here.

@bp.route("/arcs/<arc_id>/close", methods=["GET", "POST"])
def arc_close_surface(arc_id):
    from flask import redirect

    arc = _read_arc(arc_id)
    if arc is None:
        abort(404, description=f"Arc '{arc_id}' not registered.")
    arc_slug = str(arc.get("slug") or arc_id).strip()

    status = str(arc.get("status") or "").strip()
    if status in ("closed", "abandoned"):
        return redirect(f"/arcs/{arc_slug}")

    error_msg = None

    if request.method == "POST":
        demo_mode = (request.form.get("demo_mode") or "").strip()
        demo_value = (request.form.get("demo_value") or "").strip()
        decision = (request.form.get("decision") or "").strip()
        justification = (request.form.get("justification") or "").strip()

        if demo_mode not in ("path", "url", "none"):
            error_msg = "Pick a demo mode: file path, URL, or 'none'."
        elif demo_mode == "none" and len(justification) < 30:
            error_msg = "demo=none requires a justification of at least 30 characters (§ACD)."
        elif demo_mode in ("path", "url") and not demo_value:
            error_msg = f"Provide the {demo_mode} demo value."
        else:
            demo_arg = "none" if demo_mode == "none" else demo_value
            cmd = [
                "bin/fw", "arc", "close", arc_slug,
                "--from-watchtower",
                "--demo", demo_arg,
            ]
            if decision:
                cmd += ["--decision", decision]
            if demo_mode == "none":
                cmd += ["--justification", justification]

            try:
                result = subprocess.run(
                    cmd, cwd=str(PROJECT_ROOT),
                    capture_output=True, text=True, timeout=30,
                )
            except (subprocess.SubprocessError, OSError) as e:
                result = None
                error_msg = f"Failed to invoke fw arc close: {e}"

            if result is not None:
                if result.returncode == 0:
                    return redirect(f"/arcs/{arc_slug}")
                err_lines = (result.stderr or "").strip().splitlines()
                error_msg = err_lines[0] if err_lines else f"fw arc close exited {result.returncode}"
                if len(err_lines) > 1:
                    error_msg += " — " + err_lines[1]

    constituents = _resolve_constituents(arc)
    stats = _completion_stats(constituents)
    focus_val = _read_focus()
    arc_numeric = str(arc.get("id") or "").strip()
    focused = (focus_val == arc_slug or (arc_numeric and focus_val == arc_numeric))
    reports = _arc_reports(arc_slug)
    recommendation = _anchor_recommendation(arc)

    prev_demo_value = request.form.get("demo_value", "") if request.method == "POST" else ""
    if not prev_demo_value and recommendation.get("suggested_demo"):
        prev_demo_value = recommendation["suggested_demo"]

    return render_page(
        "arc_close.html",
        page_title=f"Close arc: {arc.get('name', arc_id)}",
        arc=arc,
        arc_id=arc_id,
        arc_slug=arc_slug,
        constituents=constituents,
        stats=stats,
        focused=focused,
        reports=reports,
        recommendation=recommendation,
        error_msg=error_msg,
        prev_demo_mode=request.form.get("demo_mode", "") if request.method == "POST" else "",
        prev_demo_value=prev_demo_value,
        prev_decision=request.form.get("decision", "") if request.method == "POST" else "",
        prev_justification=request.form.get("justification", "") if request.method == "POST" else "",
    )


# T-1963: read-only review surface for arc closure. Companion to /close.
# Parity with the inception flow (/inception/T-XXX vs /review/T-XXX): /review
# is the consume-the-rec surface, /close is the act-on-the-rec form. Closed
# and abandoned arcs still render here (vs /close which redirects), so the
# rec stays readable after closure.

@bp.route("/arcs/<arc_id>/review", methods=["GET"])
def arc_review_surface(arc_id):
    arc = _read_arc(arc_id)
    if arc is None:
        abort(404, description=f"Arc '{arc_id}' not registered.")
    arc_slug = str(arc.get("slug") or arc_id).strip()
    constituents = _resolve_constituents(arc)
    stats = _completion_stats(constituents)
    recommendation = _anchor_recommendation(arc)
    reports = _arc_reports(arc_slug)
    return render_page(
        "arc_review.html",
        page_title=f"Review arc: {arc.get('name', arc_id)}",
        arc=arc,
        arc_id=arc_id,
        arc_slug=arc_slug,
        constituents=constituents,
        stats=stats,
        recommendation=recommendation,
        reports=reports,
    )
