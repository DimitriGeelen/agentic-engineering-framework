"""Risks blueprint — unified concerns register (T-397, formerly T-194 three-register model)."""

import yaml
from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("risks", __name__)


def _load_yaml(filename):
    path = PROJECT_ROOT / ".context" / "project" / filename
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            return yaml.safe_load(f) or {}
    except yaml.YAMLError:
        return {}


@bp.route("/risks")
def risk_register():
    """Unified concerns register — gaps + risks in one view (T-397)."""
    concerns_data = _load_yaml("concerns.yaml")
    controls_data = _load_yaml("controls.yaml")

    all_concerns = concerns_data.get("concerns", [])
    controls = controls_data.get("controls", [])

    # Split by type
    gaps = [c for c in all_concerns if c.get("type") == "gap"]
    risks = [c for c in all_concerns if c.get("type") == "risk"]

    # Concerns by status
    watching = [c for c in all_concerns if c.get("status") == "watching"]
    closed = [c for c in all_concerns if c.get("status") == "closed"]

    # Risk-specific stats
    risk_by_ranking = {"urgent": 0, "high": 0, "medium": 0, "low": 0}
    for r in risks:
        ranking = r.get("ranking", "low")
        risk_by_ranking[ranking] = risk_by_ranking.get(ranking, 0) + 1

    # Control stats
    controls_active = [c for c in controls if c.get("status") == "active"]
    controls_blocking = [c for c in controls if c.get("blocking")]
    control_by_type = {}
    for c in controls:
        ctype = c.get("type", "unknown")
        control_by_type[ctype] = control_by_type.get(ctype, 0) + 1

    return render_page(
        "risks.html",
        page_title="Concerns",
        concerns=all_concerns,
        gaps=gaps,
        risks=risks,
        controls=controls,
        watching=watching,
        closed=closed,
        risk_by_ranking=risk_by_ranking,
        total_concerns=len(all_concerns),
        total_gaps=len(gaps),
        total_risks=len(risks),
        total_watching=len(watching),
        total_closed=len(closed),
        total_controls=len(controls),
        controls_active=len(controls_active),
        controls_blocking=len(controls_blocking),
        control_by_type=control_by_type,
    )
