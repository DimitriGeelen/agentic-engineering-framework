"""Timeline blueprint — session timeline with progressive disclosure."""

import logging
import re as re_mod
from pathlib import Path

import yaml
from flask import Blueprint, abort, render_template, request

from web.shared import PROJECT_ROOT, render_page, parse_frontmatter, get_task_names, mtime_cached_get


# T-2106/T-2109: per-file frontmatter cache keyed on (path, mtime_ns).
# The session cache (_session_cache, 30s TTL) flushes the entire list every TTL,
# forcing a full re-walk of 1000+ handover files (parse_frontmatter @ ~4ms ea =
# 4-5s steady-state cost). This cache survives the TTL — unchanged files return
# instantly from memory; only added/modified files pay parse cost.
# T-2109: migrated from local stat+cache logic to shared.mtime_cached_get.
_FM_CACHE: dict[str, tuple[int, tuple[dict, str]]] = {}


def _parse_fm_body_from_path(p: Path) -> tuple[dict, str]:
    """Read file and split into (fm_dict, body). Empty pair on read failure."""
    try:
        content = p.read_text()
    except OSError:
        return ({}, "")
    fm, body = parse_frontmatter(content)
    return fm, body


def _get_frontmatter_cached(path: Path | str) -> tuple[dict, str]:
    """Return (frontmatter_dict, body) for path, mtime-invalidated.

    Mirrors parse_frontmatter(content) semantics — empty dict + full content
    on parse failure or no-frontmatter file.

    T-2109: migrated to shared.mtime_cached_get; semantics unchanged.
    """
    return mtime_cached_get(Path(path), _parse_fm_body_from_path, _FM_CACHE, default=({}, ""))

logger = logging.getLogger(__name__)

bp = Blueprint("timeline", __name__)


def _parse_token_usage(usage_str):
    """Parse '809.7M tokens, 6608 turns' → (tokens_millions, turns) or None."""
    if not usage_str:
        return None
    m = re_mod.match(r"([\d.]+)M tokens,\s*(\d+) turns", usage_str)
    if m:
        return float(m.group(1)), int(m.group(2))
    return None


def _compute_session_deltas(sessions):
    """Add session_tokens/session_turns deltas (newest-first list)."""
    for i, s in enumerate(sessions):
        parsed = _parse_token_usage(s.get("token_usage", ""))
        if not parsed:
            continue
        curr_tokens, curr_turns = parsed
        # Next item in list is the predecessor (older session)
        prev = None
        for j in range(i + 1, len(sessions)):
            prev_parsed = _parse_token_usage(sessions[j].get("token_usage", ""))
            if prev_parsed:
                prev = prev_parsed
                break
        if prev:
            delta_tokens = curr_tokens - prev[0]
            delta_turns = curr_turns - prev[1]
            if delta_tokens >= 0:
                s["session_tokens"] = f"{delta_tokens:.1f}M"
                s["session_turns"] = str(delta_turns)
        else:
            # First session — cumulative IS the session total
            s["session_tokens"] = f"{curr_tokens:.1f}M"
            s["session_turns"] = str(curr_turns)


def _load_task_names():
    """Build {task_id: name} dict. T-1233: Delegates to shared cache."""
    return get_task_names()


def _truncate(text, max_len=100):
    """Truncate text at a word boundary, adding ellipsis if needed."""
    if not text or len(text) <= max_len:
        return text or ""
    truncated = text[:max_len].rsplit(" ", 1)[0]
    return truncated + "..."


def _collapse_emergency_runs(sessions):
    """Collapse consecutive emergency handovers into single summary entries."""
    collapsed = []
    emergency_run = []

    def flush_run():
        if not emergency_run:
            return
        if len(emergency_run) == 1:
            collapsed.append(emergency_run[0])
        else:
            # Merge run into one summary entry (list is newest-first)
            first_ts = emergency_run[-1]["timestamp"]
            last_ts = emergency_run[0]["timestamp"]
            count = len(emergency_run)
            collapsed.append({
                "id": f"{emergency_run[-1]['id']} ... {emergency_run[0]['id']}",
                "timestamp": first_ts,
                "tasks_touched": [],
                "tasks_completed": [],
                "touched_count": 0,
                "completed_count": 0,
                "narrative": f"{count} emergency handovers from {first_ts[:16]} to {last_ts[:16]} (context compactions during heavy work)",
                "narrative_short": f"{count} emergency handovers collapsed",
                "predecessor": emergency_run[-1].get("predecessor", ""),
                "is_emergency": True,
                "emergency_count": count,
            })

    for s in sessions:
        if s.get("is_emergency"):
            emergency_run.append(s)
        else:
            flush_run()
            emergency_run = []
            collapsed.append(s)
    flush_run()
    return collapsed


# T-1233: Session cache for timeline (580+ handover files are append-only)
import time as _time

_session_cache = {"data": None, "count": 0, "ts": 0}
_SESSION_CACHE_TTL = 30  # seconds


def _build_sessions():
    """Parse all handover files into session dicts (without task name enrichment)."""
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    sessions = []
    if not handovers_dir.exists():
        return sessions

    for f in sorted(handovers_dir.glob("S-*.md"), reverse=True):
        # T-2106: cached (frontmatter, body) — survives _SESSION_CACHE_TTL on unchanged files.
        fm, body = _get_frontmatter_cached(f)
        if not fm:
            continue

        where_match = re_mod.search(
            r"## Where We Are\n\n(.*?)(?=\n## |\Z)", body, re_mod.DOTALL
        )
        narrative = fm.get("session_narrative", "")
        if not narrative and where_match:
            narrative = where_match.group(1).strip()

        tasks_touched = fm.get("tasks_touched", []) or []
        tasks_completed = fm.get("tasks_completed", []) or []
        is_emergency = fm.get("type") == "emergency"

        sessions.append(
            {
                "id": fm.get("session_id", f.stem),
                "timestamp": str(fm.get("timestamp", "")),
                "_tasks_touched_ids": tasks_touched,
                "_tasks_completed_ids": tasks_completed,
                "tasks_touched": [],   # enriched later
                "tasks_completed": [],  # enriched later
                "touched_count": len(tasks_touched),
                "completed_count": len(tasks_completed),
                "narrative": narrative,
                "narrative_short": _truncate(narrative),
                "predecessor": fm.get("predecessor", ""),
                "is_emergency": is_emergency,
                "token_usage": fm.get("token_usage", ""),
                "token_input": fm.get("token_input", ""),
                "token_cache_read": fm.get("token_cache_read", ""),
                "token_cache_create": fm.get("token_cache_create", ""),
                "token_output": fm.get("token_output", ""),
                "commits_per_turn": fm.get("commits_per_turn", ""),
                "first_commit_turn": fm.get("first_commit_turn", ""),
                "failed_tool_call_rate": fm.get("failed_tool_call_rate", ""),
                "edit_bursts": fm.get("edit_bursts", ""),
                "productive_turns_ratio": fm.get("productive_turns_ratio", ""),
                "session_commits_per_turn": fm.get("session_commits_per_turn", ""),
                "session_failed_tool_call_rate": fm.get("session_failed_tool_call_rate", ""),
                "session_edit_bursts": fm.get("session_edit_bursts", ""),
                "session_productive_turns_ratio": fm.get("session_productive_turns_ratio", ""),
                "session_commits": fm.get("session_commits", ""),
            }
        )
    return sessions


def _get_cached_sessions():
    """Return cached session list, rebuilding if stale or new handovers added."""
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    current_count = len(list(handovers_dir.glob("S-*.md"))) if handovers_dir.exists() else 0
    now = _time.monotonic()

    if (_session_cache["data"] is not None
            and current_count == _session_cache["count"]
            and (now - _session_cache["ts"]) < _SESSION_CACHE_TTL):
        return _session_cache["data"]

    sessions = _build_sessions()
    _session_cache["data"] = sessions
    _session_cache["count"] = current_count
    _session_cache["ts"] = now
    return sessions


# T-2775: sessions per page. The page previously rendered every session ever recorded —
# 1,524 of them, carrying 182,541 task entries, for a 69.8 MB response.
#
# T-2041 had already capped this page, but on the *height* axis: it rendered everything and
# wrapped the overflow in a collapsed <details>, which is display:none and so drops out of
# scrollHeight. That satisfied the 8000px height guard exactly as intended while every one of
# those bytes still crossed the wire. The lesson is not that T-2041 was wrong — it fixed what
# it measured — but that "bounded" is per-axis, and a page is only bounded on the axis some
# check actually looks at.
_TIMELINE_PAGE_SIZE = 25

# T-2775: per-session task-list cap. Paging bounds how many sessions render; it does not
# bound how large one session is. Sessions are wildly uneven — the median carries ~37 task
# references and the largest carries 2,499 — so with paging alone the worst page measured
# 12.6 MB while page 1 measured 609 KB. Two independent axes, and only sweeping every page
# showed the second one; the landing page looked fixed.
_TIMELINE_TASKS_PER_SESSION = 40


@bp.route("/timeline")
def timeline():
    import copy

    all_sessions = [copy.copy(s) for s in _get_cached_sessions()]

    # Collapse and delta BEFORE slicing: both are cross-session. _collapse_emergency_runs
    # merges consecutive runs (so it changes what index N means), and _compute_session_deltas
    # reads each session's predecessor to compute a difference — slicing first would compute
    # a wrong delta at every page boundary rather than a missing one, which is worse.
    all_sessions = _collapse_emergency_runs(all_sessions)
    _compute_session_deltas(all_sessions)

    total = len(all_sessions)
    page_count = max(1, (total + _TIMELINE_PAGE_SIZE - 1) // _TIMELINE_PAGE_SIZE)
    try:
        page = int(request.args.get("page", 1))
    except (TypeError, ValueError):
        page = 1
    page = max(1, min(page, page_count))

    start = (page - 1) * _TIMELINE_PAGE_SIZE
    sessions = all_sessions[start:start + _TIMELINE_PAGE_SIZE]

    # Enrich only the page being rendered. This is the step that scaled with the whole
    # corpus: it built a dict per task reference, 182,541 of them, to fill lists the browser
    # then had to parse.
    task_names = _load_task_names()
    for s in sessions:
        if "_tasks_touched_ids" in s:
            ids = s["_tasks_touched_ids"]
            s["tasks_touched"] = [
                {"id": t, "name": task_names.get(t, "")}
                for t in ids[:_TIMELINE_TASKS_PER_SESSION]
            ]
            # Surfaced in the template as a link to this session's own page, so the
            # remainder stays reachable rather than being quietly dropped.
            s["tasks_touched_hidden"] = max(0, len(ids) - _TIMELINE_TASKS_PER_SESSION)
        if "_tasks_completed_ids" in s:
            ids = s["_tasks_completed_ids"]
            s["tasks_completed"] = [
                {"id": t, "name": task_names.get(t, "")}
                for t in ids[:_TIMELINE_TASKS_PER_SESSION]
            ]
            s["tasks_completed_hidden"] = max(0, len(ids) - _TIMELINE_TASKS_PER_SESSION)

    return render_page(
        "timeline.html",
        page_title="Timeline",
        sessions=sessions,
        page=page,
        page_count=page_count,
        page_size=_TIMELINE_PAGE_SIZE,
        total_sessions=total,
        range_start=(start + 1) if total else 0,
        range_end=min(start + _TIMELINE_PAGE_SIZE, total),
    )


@bp.route("/timeline/session/<session_id>")
def timeline_session(session_id):
    """Full task lists for one session.

    T-2775: the timeline caps each session's task list so one outlier cannot blow up a page
    (the largest session carries 2,499 task references). This is where the rest lives — the
    cap is a window onto the data, not a deletion of it, and the timeline links here whenever
    it has hidden anything.
    """
    if not re_mod.match(r"^S-[0-9A-Za-z._-]{1,64}$", session_id):
        abort(404)

    match = next((s for s in _get_cached_sessions() if s.get("id") == session_id), None)
    if match is None:
        abort(404)

    task_names = _load_task_names()
    session = dict(match)
    session["tasks_touched"] = [
        {"id": t, "name": task_names.get(t, "")}
        for t in session.get("_tasks_touched_ids", [])
    ]
    session["tasks_completed"] = [
        {"id": t, "name": task_names.get(t, "")}
        for t in session.get("_tasks_completed_ids", [])
    ]

    return render_page(
        "timeline_session.html",
        page_title=f"Session {session_id}",
        session=session,
    )


@bp.route("/api/timeline/task/<task_id>")
def timeline_task_detail(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    episodic_file = PROJECT_ROOT / ".context" / "episodic" / f"{task_id}.yaml"
    if not episodic_file.exists():
        return f"<p><em>No episodic data for {task_id}</em></p>"

    try:
        with open(episodic_file) as ef:
            data = yaml.safe_load(ef)
    except Exception as e:
        logger.warning("Failed to parse %s: %s", episodic_file, e)
        return f"<p><em>Error reading episodic data for {task_id}</em></p>"

    return render_template("_timeline_task.html", task=data, task_id=task_id)
