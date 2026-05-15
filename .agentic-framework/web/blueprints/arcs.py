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

import re
from pathlib import Path
from typing import Any

import yaml
from flask import Blueprint, abort

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("arcs", __name__)


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


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


def _read_arc(arc_id: str) -> dict[str, Any] | None:
    """Return arc YAML for arc_id, or None if not found / unreadable."""
    path = _arcs_dir() / f"{arc_id}.yaml"
    if not path.is_file():
        return None
    try:
        data = yaml.safe_load(path.read_text()) or {}
    except (yaml.YAMLError, OSError):
        return None
    if not isinstance(data, dict):
        return None
    return data


def _list_arcs() -> list[dict[str, Any]]:
    """Return all arcs sorted by status (in-progress first), then created desc."""
    arcs_dir = _arcs_dir()
    if not arcs_dir.is_dir():
        return []
    out: list[dict[str, Any]] = []
    focus = _read_focus()
    for af in sorted(arcs_dir.glob("*.yaml")):
        try:
            data = yaml.safe_load(af.read_text()) or {}
        except (yaml.YAMLError, OSError):
            continue
        if not isinstance(data, dict):
            continue
        # T-1817: task_count must reflect merged source-of-truth (legacy + tag-scan),
        # not just the YAML's denormalised cache.
        legacy = data.get("constituent_tasks") or []
        legacy_ids = [str(t).strip() for t in legacy if str(t).strip()] if isinstance(legacy, list) else []
        arc_id_for_scan = str(data.get("id") or af.stem).strip()
        tagged_ids = _scan_tasks_by_tag(f"arc:{arc_id_for_scan}") if arc_id_for_scan else []
        merged_count = len(set(legacy_ids) | set(tagged_ids))
        # YAML may parse ISO-8601 to datetime; coerce to str for stable rendering + sort.
        created_raw = data.get("created", "")
        created_str = created_raw.isoformat() if hasattr(created_raw, "isoformat") else str(created_raw or "")
        closed_raw = data.get("closed_at")
        closed_str = closed_raw.isoformat() if hasattr(closed_raw, "isoformat") else (str(closed_raw) if closed_raw else None)
        out.append({
            "id": data.get("id", af.stem),
            "name": data.get("name", "(no name)"),
            "status": data.get("status", "?"),
            "decision": data.get("decision"),
            "anchor_task": data.get("anchor_task"),
            "task_count": merged_count,
            "created": created_str,
            "closed_at": closed_str,
            "focused": (focus is not None and focus == data.get("id")),
        })
    # Sort: in-progress first (rank 0), then closed (rank 1), unknown (rank 9);
    # within each rank, newest created first. Python sort is stable so we do
    # two passes — secondary first, primary second.
    status_rank = {"in-progress": 0, "closed": 1}
    out.sort(key=lambda a: a["created"], reverse=True)
    out.sort(key=lambda a: status_rank.get(a["status"], 9))
    return out


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
    """Merge legacy `constituent_tasks` with arc-tag scan (T-1817).

    Legacy entries first (preserves order author wrote them in); tag-scan
    entries appended in sorted order; dedup by task id.
    """
    legacy = arc.get("constituent_tasks") or []
    if not isinstance(legacy, list):
        legacy = []
    arc_id = str(arc.get("id") or "").strip()
    tagged = _scan_tasks_by_tag(f"arc:{arc_id}") if arc_id else []

    merged_ids: list[str] = []
    seen: set[str] = set()
    for tid in list(legacy) + tagged:
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
    """List every arc."""
    arcs = _list_arcs()
    return render_page(
        "arcs_index.html",
        page_title="Arcs",
        arcs=arcs,
    )


@bp.route("/arcs/<arc_id>")
def arc_detail(arc_id: str):
    """Detail page for one arc."""
    arc = _read_arc(arc_id)
    if arc is None:
        abort(404, description=f"Arc '{arc_id}' not registered. Run `fw arc list` to see registered arcs.")
    constituents = _resolve_constituents(arc)
    stats = _completion_stats(constituents)
    focused = (_read_focus() == arc_id)
    has_specialized_view = (arc_id == "orchestrator-rethink")
    reports = _arc_reports(arc_id)
    return render_page(
        "arc_detail.html",
        page_title=f"Arc: {arc.get('name', arc_id)}",
        arc=arc,
        arc_id=arc_id,
        constituents=constituents,
        stats=stats,
        focused=focused,
        has_specialized_view=has_specialized_view,
        reports=reports,
    )
