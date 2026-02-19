"""Risks blueprint — ISO 27001-aligned risk and issue register (T-194)."""

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
    """Risk & Issue register page under Govern."""
    risks_data = _load_yaml("risks.yaml")
    issues_data = _load_yaml("issues.yaml")
    gaps_data = _load_yaml("gaps.yaml")

    risks = risks_data.get("risks", [])
    issues = issues_data.get("issues", [])
    gaps = gaps_data.get("gaps", [])

    # Compute summary stats
    risk_by_ranking = {"urgent": 0, "high": 0, "medium": 0, "low": 0}
    risk_by_status = {"closed": 0, "decided-build": 0, "acknowledged": 0, "watching": 0}
    risk_by_category = {}
    open_risks = []

    for r in risks:
        ranking = r.get("ranking", "low")
        status = r.get("control_status", "acknowledged")
        category = r.get("category", "unknown")

        risk_by_ranking[ranking] = risk_by_ranking.get(ranking, 0) + 1
        risk_by_status[status] = risk_by_status.get(status, 0) + 1
        risk_by_category[category] = risk_by_category.get(category, 0) + 1

        if status != "closed":
            open_risks.append(r)

    # Sort open risks by score descending
    open_risks.sort(key=lambda r: r.get("score", 0), reverse=True)

    # Issue stats
    open_issues = [i for i in issues if i.get("status") != "resolved"]
    resolved_issues = [i for i in issues if i.get("status") == "resolved"]

    # Gaps stats
    watching_gaps = [g for g in gaps if g.get("status") == "watching"]

    return render_page(
        "risks.html",
        page_title="Risk Register",
        risks=risks,
        issues=issues,
        open_risks=open_risks,
        risk_by_ranking=risk_by_ranking,
        risk_by_status=risk_by_status,
        risk_by_category=risk_by_category,
        open_issues=open_issues,
        resolved_issues=resolved_issues,
        watching_gaps=watching_gaps,
        total_risks=len(risks),
        total_issues=len(issues),
    )
