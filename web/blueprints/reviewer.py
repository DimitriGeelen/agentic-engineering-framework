"""Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a).

Read-only Watchtower surface for the static-scan reviewer:
- /reviewer/overrides — active overrides table + recent feedback events

Distinct from `web.blueprints.review` which serves the per-task human-review
page (`/review/<task_id>`).
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint, render_template

from web.shared import PROJECT_ROOT

bp = Blueprint("reviewer", __name__)


def _load_overrides() -> list[dict]:
    """Load active overrides via the canonical lib.reviewer.overrides module."""
    try:
        from lib.reviewer.overrides import load_overrides
    except ImportError:
        return []

    now = datetime.now(timezone.utc)
    rows: list[dict] = []
    for o in load_overrides():
        days = o.days_remaining(now)
        rows.append({
            "id": o.id,
            "task_id": o.task_id,
            "pattern_id": o.pattern_id,
            "ac_index": o.ac_index if o.ac_index is not None else "*",
            "reason": o.reason,
            "expires_at": o.expires_at,
            "days_remaining": days,
            "is_expired": o.is_expired(now),
            "added_by": o.added_by,
            "added_at": o.added_at,
        })
    return rows


def _load_feedback_events(limit: int = 50) -> list[dict]:
    """Tail the feedback-stream YAML and return last N events (newest first)."""
    stream = PROJECT_ROOT / ".context" / "working" / "feedback-stream.yaml"
    if not stream.exists():
        return []
    try:
        text = stream.read_text()
    except OSError:
        return []
    # Stream is multi-doc YAML separated by `---`. yaml.safe_load_all handles it.
    events: list[dict] = []
    try:
        for doc in yaml.safe_load_all(text):
            if isinstance(doc, dict) and doc.get("kind"):
                events.append(doc)
    except yaml.YAMLError:
        return events  # return what we managed to parse
    return list(reversed(events))[:limit]


def _latest_yaml(directory: Path, suffix: str) -> tuple[Path | None, dict | None]:
    """Return (path, parsed) for the lexicographically newest file matching `*-{suffix}.yaml`."""
    if not directory.exists():
        return None, None
    candidates = sorted(directory.glob(f"*-{suffix}.yaml"))
    if not candidates:
        return None, None
    latest = candidates[-1]
    try:
        return latest, yaml.safe_load(latest.read_text())
    except (OSError, yaml.YAMLError):
        return latest, None


@bp.route("/reviewer/audit")
def reviewer_audit():
    """Surface latest Pass A + Pass B corpus YAML state (T-1486)."""
    audit_dir = PROJECT_ROOT / ".context" / "audits" / "reviewer"
    pass_a_path, pass_a = _latest_yaml(audit_dir, "pass-a")
    pass_b_path, pass_b = _latest_yaml(audit_dir, "pass-b")

    return render_template(
        "reviewer_audit.html",
        page_title="Reviewer Audit",
        active_endpoint="reviewer.reviewer_audit",
        pass_a=pass_a,
        pass_a_path=pass_a_path.name if pass_a_path else None,
        pass_b=pass_b,
        pass_b_path=pass_b_path.name if pass_b_path else None,
    )


@bp.route("/reviewer/overrides")
def reviewer_overrides():
    overrides = _load_overrides()
    events = _load_feedback_events(limit=50)
    counts: dict[str, int] = {}
    for e in events:
        k = e.get("kind", "unknown")
        counts[k] = counts.get(k, 0) + 1
    return render_template(
        "reviewer_overrides.html",
        page_title="Reviewer Overrides",
        active_endpoint="reviewer.reviewer_overrides",
        overrides=overrides,
        events=events,
        event_counts=counts,
        active_count=sum(1 for o in overrides if not o["is_expired"]),
        expired_count=sum(1 for o in overrides if o["is_expired"]),
    )
