"""Metrics history — read and query time-series audit data.

Used by Watchtower blueprints and discovery jobs.
Data file: .context/project/metrics-history.yaml
Created by T-238.
"""

from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

_HISTORY_FILE = ".context/project/metrics-history.yaml"


def _history_path(project_root=None):
    if project_root is None:
        from web.shared import PROJECT_ROOT
        project_root = PROJECT_ROOT
    return Path(project_root) / _HISTORY_FILE


def load_entries(project_root=None):
    """Load all entries from metrics-history.yaml, newest first."""
    path = _history_path(project_root)
    if not path.exists():
        return []
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        entries = data.get("entries", []) if isinstance(data, dict) else []
        # Parse timestamps and sort newest first
        for e in entries:
            if isinstance(e.get("timestamp"), str):
                try:
                    e["_ts"] = datetime.fromisoformat(
                        e["timestamp"].replace("Z", "+00:00")
                    )
                except (ValueError, TypeError):
                    e["_ts"] = datetime.min.replace(tzinfo=timezone.utc)
            elif isinstance(e.get("timestamp"), datetime):
                e["_ts"] = e["timestamp"]
                if e["_ts"].tzinfo is None:
                    e["_ts"] = e["_ts"].replace(tzinfo=timezone.utc)
            else:
                e["_ts"] = datetime.min.replace(tzinfo=timezone.utc)
        entries.sort(key=lambda x: x["_ts"], reverse=True)
        return entries
    except Exception:
        return []


def latest(project_root=None):
    """Return the most recent entry, or None."""
    entries = load_entries(project_root)
    return entries[0] if entries else None


def last_n(n=7, project_root=None):
    """Return the last N entries (newest first)."""
    return load_entries(project_root)[:n]


def last_days(days=7, project_root=None):
    """Return entries from the last N days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    return [e for e in load_entries(project_root) if e["_ts"] >= cutoff]


def field_series(field, days=30, project_root=None):
    """Return (timestamp_str, value) pairs for a field over N days.

    Returned in chronological order (oldest first) for charting.
    """
    entries = last_days(days, project_root)
    entries.reverse()  # oldest first for charts
    result = []
    for e in entries:
        val = e.get(field)
        if val is not None:
            result.append((e["timestamp"], val))
    return result


def rolling_average(field, window=7, project_root=None):
    """Compute rolling average of a field over the last `window` entries.

    Returns the average as a float, or None if no data.
    """
    entries = last_n(window, project_root)
    values = [e.get(field, 0) for e in entries if field in e]
    if not values:
        return None
    return sum(values) / len(values)


def compare_windows(field, window=7, project_root=None):
    """Compare current window average vs previous window average.

    Returns (current_avg, previous_avg, pct_change) or None if insufficient data.
    """
    entries = load_entries(project_root)
    if len(entries) < window:
        return None

    current = entries[:window]
    previous = entries[window:window * 2]
    if not previous:
        return None

    cur_vals = [e.get(field, 0) for e in current if field in e]
    prev_vals = [e.get(field, 0) for e in previous if field in e]

    if not cur_vals or not prev_vals:
        return None

    cur_avg = sum(cur_vals) / len(cur_vals)
    prev_avg = sum(prev_vals) / len(prev_vals)

    if prev_avg == 0:
        pct_change = 100.0 if cur_avg > 0 else 0.0
    else:
        pct_change = ((cur_avg - prev_avg) / prev_avg) * 100

    return cur_avg, prev_avg, pct_change


def summary(project_root=None):
    """Return a summary dict for Watchtower display."""
    entries = load_entries(project_root)
    lt = latest(project_root)
    return {
        "total_entries": len(entries),
        "latest": lt,
        "days_covered": _days_covered(entries),
    }


def _days_covered(entries):
    """How many days the history spans."""
    if len(entries) < 2:
        return 0
    oldest = entries[-1]["_ts"]
    newest = entries[0]["_ts"]
    return (newest - oldest).days
