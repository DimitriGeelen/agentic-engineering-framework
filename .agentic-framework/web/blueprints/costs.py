"""Costs blueprint — token usage tracking dashboard (T-802)."""

import json
import glob
import os
from pathlib import Path

from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("costs", __name__)


def _jsonl_dir():
    """Find the JSONL transcript directory for this project."""
    project_dir_name = str(PROJECT_ROOT).replace("/", "-").lstrip("-")
    return Path.home() / ".claude" / "projects" / f"-{project_dir_name}"


def _fmt_tokens(n):
    """Format token count with K/M/B suffixes."""
    if n >= 1_000_000_000:
        return f"{n / 1_000_000_000:.1f}B"
    elif n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    elif n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)


def _fresh_stats(filepath):
    """Zeroed stats accumulator for a session file."""
    session = os.path.basename(filepath).replace(".jsonl", "")
    return {
        "id": session[:8],
        "id_full": session,
        "turns": 0,
        "input_tokens": 0,
        "cache_read": 0,
        "cache_create": 0,
        "output_tokens": 0,
        "first_ts": None,
        "last_ts": None,
        "model": "",
        "file_size": 0,
    }


def _finalize_total(stats):
    """Recompute the derived `total` from the additive fields."""
    stats["total"] = (
        stats["input_tokens"]
        + stats["cache_read"]
        + stats["cache_create"]
        + stats["output_tokens"]
    )
    return stats


def _accumulate(filepath, start_offset, stats):
    """Fold complete (newline-terminated) JSONL records from `start_offset`
    into `stats` (all fields are additive sums or set-once). Returns the byte
    offset after the last COMPLETE line consumed — any trailing partial line
    (a record still being written) is left unconsumed so it is re-read intact
    on the next call. This is what makes incremental append-parsing exact."""
    with open(filepath, "rb") as f:
        f.seek(start_offset)
        data = f.read()
    if not data:
        return start_offset
    last_nl = data.rfind(b"\n")
    if last_nl == -1:
        return start_offset  # no complete line available yet
    chunk = data[: last_nl + 1]
    consumed = start_offset + last_nl + 1

    for raw in chunk.split(b"\n"):
        if not raw:
            continue
        try:
            e = json.loads(raw)
        except (json.JSONDecodeError, ValueError):
            continue

        ts = e.get("timestamp")
        if ts:
            if stats["first_ts"] is None:
                stats["first_ts"] = ts
            stats["last_ts"] = ts

        msg = e.get("message", {})
        if not isinstance(msg, dict):
            continue

        usage = msg.get("usage")
        if not usage or not isinstance(usage, dict):
            continue

        model = msg.get("model", "")
        if model == "<synthetic>" or model.startswith("<"):
            continue

        if not stats["model"] and model:
            stats["model"] = model

        stats["turns"] += 1
        stats["input_tokens"] += usage.get("input_tokens", 0)
        stats["cache_read"] += usage.get("cache_read_input_tokens", 0)
        stats["cache_create"] += usage.get("cache_creation_input_tokens", 0)
        stats["output_tokens"] += usage.get("output_tokens", 0)

    return consumed


def _parse_session(filepath):
    """Parse a single JSONL file from scratch, return session stats dict."""
    stats = _fresh_stats(filepath)
    _accumulate(filepath, 0, stats)
    stats["file_size"] = os.path.getsize(filepath)
    return _finalize_total(stats)


# T-2035: per-file memo keyed on (mtime, size). Historical transcripts never change,
# so they parse once per process; the growing current-session file is parsed
# INCREMENTALLY (seek to last offset, fold only appended complete lines). Fixes the
# 22s cockpit load — the T-1235 count-keyed cache re-parsed all ~1.5GB on every expiry.
_parse_memo = {}


def _parse_session_cached(filepath):
    """Memoized `_parse_session`. Returns cached stats when (mtime, size) are
    unchanged; folds only appended bytes when the file grew; re-parses from
    scratch when the file shrank (truncation/rotation) or is unseen."""
    try:
        st = os.stat(filepath)
    except OSError:
        return _parse_session(filepath)

    cached = _parse_memo.get(filepath)
    if cached and cached["mtime"] == st.st_mtime and cached["size"] == st.st_size:
        return cached["stats"]

    if cached and st.st_size >= cached["size"]:
        # append-only growth → incremental fold from the last consumed offset
        stats = cached["stats"]
        offset = _accumulate(filepath, cached["offset"], stats)
    else:
        # cold, shrunk, or rotated → full re-parse
        stats = _fresh_stats(filepath)
        offset = _accumulate(filepath, 0, stats)

    stats["file_size"] = st.st_size
    _finalize_total(stats)
    _parse_memo[filepath] = {
        "mtime": st.st_mtime,
        "size": st.st_size,
        "offset": offset,
        "stats": stats,
    }
    return stats


# T-1235: Cache parsed JSONL sessions (71 files, 242MB+ — parsing takes ~2s)
import time as _time_mod

_session_cache = {"data": None, "count": 0, "ts": 0}
_SESSION_CACHE_TTL = 120  # seconds — JSONL files change slowly


def _load_all_sessions():
    """Load and parse all JSONL transcripts for this project.

    T-1235: Cached for 120s. Cache invalidates when file count changes.
    """
    jdir = _jsonl_dir()
    if not jdir.exists():
        return []

    files = sorted(jdir.glob("*.jsonl"), key=lambda f: f.stat().st_mtime)
    files = [f for f in files if not f.name.startswith("agent-")]
    current_count = len(files)
    now = _time_mod.monotonic()

    if (_session_cache["data"] is not None
            and current_count == _session_cache["count"]
            and (now - _session_cache["ts"]) < _SESSION_CACHE_TTL):
        return _session_cache["data"]

    sessions = []
    for f in files:
        sessions.append(_parse_session_cached(str(f)))

    _session_cache["data"] = sessions
    _session_cache["count"] = current_count
    _session_cache["ts"] = now
    return sessions


@bp.route("/costs")
def costs_dashboard():
    """Token usage dashboard."""
    sessions = _load_all_sessions()

    total_turns = sum(s["turns"] for s in sessions)
    total_input = sum(s["input_tokens"] for s in sessions)
    total_cache_read = sum(s["cache_read"] for s in sessions)
    total_cache_create = sum(s["cache_create"] for s in sessions)
    total_output = sum(s["output_tokens"] for s in sessions)
    total_all = sum(s["total"] for s in sessions)

    cache_hit = (total_cache_read * 100 / total_all) if total_all > 0 else 0
    avg_per_turn = total_all // max(total_turns, 1)

    # Format sessions for template
    for s in sessions:
        s["date"] = (s["first_ts"] or s["last_ts"] or "?")[:10]
        s["input_fmt"] = _fmt_tokens(s["input_tokens"])
        s["cache_read_fmt"] = _fmt_tokens(s["cache_read"])
        s["cache_create_fmt"] = _fmt_tokens(s["cache_create"])
        s["output_fmt"] = _fmt_tokens(s["output_tokens"])
        s["total_fmt"] = _fmt_tokens(s["total"])
        s["size_mb"] = f"{s['file_size'] / (1024 * 1024):.1f}"

    # Current session is most recent by mtime
    current = sessions[-1] if sessions else None

    # Category breakdown for summary
    categories = []
    if total_all > 0:
        categories = [
            {"name": "Fresh input", "tokens": total_input, "fmt": _fmt_tokens(total_input),
             "pct": f"{total_input * 100 / total_all:.1f}"},
            {"name": "Cache read", "tokens": total_cache_read, "fmt": _fmt_tokens(total_cache_read),
             "pct": f"{total_cache_read * 100 / total_all:.1f}"},
            {"name": "Cache create", "tokens": total_cache_create, "fmt": _fmt_tokens(total_cache_create),
             "pct": f"{total_cache_create * 100 / total_all:.1f}"},
            {"name": "Output", "tokens": total_output, "fmt": _fmt_tokens(total_output),
             "pct": f"{total_output * 100 / total_all:.1f}"},
        ]

    # Date range
    first_dates = [s["first_ts"] for s in sessions if s["first_ts"]]
    last_dates = [s["last_ts"] for s in sessions if s["last_ts"]]
    date_range = ""
    if first_dates and last_dates:
        date_range = f"{min(first_dates)[:10]} — {max(last_dates)[:10]}"

    return render_page(
        "costs.html",
        page_title="Token Usage",
        sessions=sessions,
        total_tokens=_fmt_tokens(total_all),
        total_tokens_raw=total_all,
        total_turns=f"{total_turns:,}",
        total_sessions=len(sessions),
        cache_hit=f"{cache_hit:.1f}",
        avg_per_turn=_fmt_tokens(avg_per_turn),
        categories=categories,
        date_range=date_range,
        current_session=current,
    )
