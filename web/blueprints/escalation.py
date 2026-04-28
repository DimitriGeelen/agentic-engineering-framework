"""Escalation drift blueprint — G-019 Layer C surface (T-1595).

Read-only Watchtower surface for the escalation-drift scanner output. The
daily `escalation-drift-daily` cron (T-1555) writes a machine-readable
summary to `.context/working/escalation-drift-LATEST.yaml`; this blueprint
renders it as a human-readable page so findings are visible, not buried.

H1 = bug-class task without ## RCA section
H2 = repeat learning IDs across 3+ tasks in 30 days
H3 = bug-class without RCA AND no learning capture
"""

from __future__ import annotations

from pathlib import Path

import yaml
from flask import Blueprint, render_template

from web.shared import PROJECT_ROOT

bp = Blueprint("escalation", __name__)

LATEST_PATH = PROJECT_ROOT / ".context" / "working" / "escalation-drift-LATEST.yaml"


def _load_latest() -> dict | None:
    """Parse the latest scanner output. Return None if missing/malformed."""
    path: Path = LATEST_PATH
    if not path.exists():
        return None
    try:
        text = path.read_text()
    except OSError:
        return None
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError:
        return None
    if not isinstance(data, dict):
        return None
    return data


def _display_path() -> str | None:
    """Return a project-relative path string when possible, otherwise the raw path."""
    if not LATEST_PATH.exists():
        return None
    try:
        return str(LATEST_PATH.relative_to(PROJECT_ROOT))
    except ValueError:
        return str(LATEST_PATH)


@bp.route("/escalation-drift")
def escalation_drift():
    data = _load_latest()
    return render_template(
        "escalation_drift.html",
        page_title="Escalation Drift",
        active_endpoint="escalation.escalation_drift",
        data=data,
        source_path=_display_path(),
    )
