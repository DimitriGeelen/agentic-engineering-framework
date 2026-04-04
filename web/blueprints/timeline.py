"""Timeline blueprint — session timeline with progressive disclosure."""

import logging
import re as re_mod

import yaml
from flask import Blueprint, abort, render_template

from web.shared import PROJECT_ROOT, render_page, parse_frontmatter

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
    """Build {task_id: name} dict from active and completed task files."""
    names = {}
    for subdir in ("active", "completed"):
        d = PROJECT_ROOT / ".tasks" / subdir
        if not d.exists():
            continue
        for f in d.glob("T-*.md"):
            fm, _ = parse_frontmatter(f.read_text())
            if not fm:
                continue
            tid = fm.get("id", "")
            name = fm.get("name", "")
            if tid and name:
                names[tid] = name
    return names


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


@bp.route("/timeline")
def timeline():
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    sessions = []
    task_names = _load_task_names()

    if handovers_dir.exists():
        for f in sorted(handovers_dir.glob("S-*.md"), reverse=True):
            content = f.read_text()
            fm, _ = parse_frontmatter(content)
            if not fm:
                continue

            where_match = re_mod.search(
                r"## Where We Are\n\n(.*?)(?=\n## |\Z)", content, re_mod.DOTALL
            )
            narrative = fm.get("session_narrative", "")
            if not narrative and where_match:
                narrative = where_match.group(1).strip()

            tasks_touched = fm.get("tasks_touched", []) or []
            tasks_completed = fm.get("tasks_completed", []) or []

            is_emergency = fm.get("type") == "emergency"

            # Enrich task IDs with names
            touched_rich = [
                {"id": t, "name": task_names.get(t, "")} for t in tasks_touched
            ]
            completed_rich = [
                {"id": t, "name": task_names.get(t, "")} for t in tasks_completed
            ]

            sessions.append(
                {
                    "id": fm.get("session_id", f.stem),
                    "timestamp": str(fm.get("timestamp", "")),
                    "tasks_touched": touched_rich,
                    "tasks_completed": completed_rich,
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
                    # Per-session deltas (T-852)
                    "session_commits_per_turn": fm.get("session_commits_per_turn", ""),
                    "session_failed_tool_call_rate": fm.get("session_failed_tool_call_rate", ""),
                    "session_edit_bursts": fm.get("session_edit_bursts", ""),
                    "session_productive_turns_ratio": fm.get("session_productive_turns_ratio", ""),
                    "session_commits": fm.get("session_commits", ""),
                }
            )

    sessions = _collapse_emergency_runs(sessions)
    _compute_session_deltas(sessions)

    return render_page("timeline.html", page_title="Timeline", sessions=sessions)


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
