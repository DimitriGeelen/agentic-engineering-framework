"""Discoveries blueprint — audit discovery findings with trend sparklines."""

import yaml
from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("discoveries_bp", __name__)


def _load_discoveries():
    """Load latest discovery findings from LATEST.yaml."""
    path = PROJECT_ROOT / ".context" / "audits" / "discoveries" / "LATEST.yaml"
    if not path.exists():
        return None
    try:
        with open(path) as f:
            return yaml.safe_load(f)
    except Exception:
        return None


def _sparkline_points(series, width=120, height=30):
    """Convert (timestamp, value) pairs to SVG polyline points string.

    Returns points like "0,30 20,15 40,20 ..." for use in <polyline>.
    Values are scaled to fit within width x height.
    """
    if len(series) < 2:
        return ""
    values = [v for _, v in series]
    lo = min(values)
    hi = max(values)
    span = hi - lo if hi != lo else 1
    n = len(values)
    points = []
    for i, v in enumerate(values):
        x = round(i * width / (n - 1), 1)
        y = round(height - (v - lo) * height / span, 1)
        points.append(f"{x},{y}")
    return " ".join(points)


@bp.route("/discoveries")
def discoveries_dashboard():
    from web import metrics_history

    data = _load_discoveries()
    findings = data.get("findings", []) if data else []
    summary = data.get("summary", {}) if data else {}
    timestamp = data.get("timestamp", "N/A") if data else "N/A"

    # Build sparkline data from metrics-history
    sparklines = {}
    for field, label in [
        ("audit_warn_count", "Audit Warnings"),
        ("velocity_commits_24h", "Commit Velocity (24h)"),
        ("episodic_quality_pct", "Episodic Quality %"),
    ]:
        series = metrics_history.field_series(field, days=30)
        if series:
            sparklines[field] = {
                "label": label,
                "points": _sparkline_points(series),
                "latest": series[-1][1] if series else None,
                "count": len(series),
            }

    return render_page(
        "discoveries.html",
        page_title="Discoveries",
        findings=findings,
        summary=summary,
        timestamp=timestamp,
        sparklines=sparklines,
    )
