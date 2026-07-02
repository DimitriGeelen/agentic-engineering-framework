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
LATEST_V05_PATH = PROJECT_ROOT / ".context" / "working" / "escalation-drift-LATEST-v0.5.yaml"
RULES_PATH = PROJECT_ROOT / ".context" / "working" / "escalation-exclusion-rules.yaml"


def _load_yaml(path: Path) -> dict | None:
    """Parse a YAML file, return None on missing/malformed/non-dict."""
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


def _load_latest() -> dict | None:
    return _load_yaml(LATEST_PATH)


def _load_v05() -> dict | None:
    return _load_yaml(LATEST_V05_PATH)


def _v05_by_task(v05: dict | None) -> dict[str, dict]:
    """Index v0.5 candidates by short task id ('T-1014') for template merge."""
    if not v05:
        return {}
    out: dict[str, dict] = {}
    for c in v05.get("candidates") or []:
        tid = c.get("task_id")
        if tid:
            out[tid] = c
    return out


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
    v05 = _load_v05()
    v05_by_task = _v05_by_task(v05)
    v05_source = None
    if LATEST_V05_PATH.exists():
        try:
            v05_source = str(LATEST_V05_PATH.relative_to(PROJECT_ROOT))
        except ValueError:
            v05_source = str(LATEST_V05_PATH)
    return render_template(
        "escalation_drift.html",
        page_title="Escalation Drift",
        active_endpoint="escalation.escalation_drift",
        data=data,
        source_path=_display_path(),
        v05=v05,
        v05_by_task=v05_by_task,
        v05_source=v05_source,
    )


@bp.route("/escalation/rules")
def escalation_rules():
    """Display escalation exclusion rules with lifecycle status (T-2497).

    Shows all rules from escalation-exclusion-rules.yaml grouped by status
    (dry-run, active, expired) with evidence (sample_size, confidence, task_ids).
    """
    data = _load_yaml(RULES_PATH)

    # Group rules by status
    dry_run_rules = []
    active_rules = []
    expired_rules = []

    if data:
        for rule in data.get("rules", []):
            status = rule.get("status")
            if status == "dry-run":
                dry_run_rules.append(rule)
            elif status == "active":
                active_rules.append(rule)
            elif status == "expired":
                expired_rules.append(rule)

    # Compute source path for display
    source_path = None
    if RULES_PATH.exists():
        try:
            source_path = str(RULES_PATH.relative_to(PROJECT_ROOT))
        except ValueError:
            source_path = str(RULES_PATH)

    return render_template(
        "escalation_rules.html",
        page_title="Escalation Rules",
        active_endpoint="escalation.escalation_rules",
        dry_run_rules=dry_run_rules,
        active_rules=active_rules,
        expired_rules=expired_rules,
        source_path=source_path,
        rules_exist=data is not None,
    )
