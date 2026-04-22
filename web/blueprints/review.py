"""Review blueprint — Mobile-first task review page for QR scan (T-667).

Lightweight approval card at /review/T-XXX:
- Standalone template (no base.html chrome)
- Human ACs only with large touch targets
- Pending Tier 0 approvals with approve/reject
- htmx polling for live updates
"""

import re

from flask import Blueprint, abort, render_template

from web.shared import PROJECT_ROOT, parse_frontmatter

bp = Blueprint("review", __name__)


def _find_task_file(task_id):
    """Find task markdown file by ID. Returns Path or None."""
    for location in ("active", "completed"):
        task_dir = PROJECT_ROOT / ".tasks" / location
        if task_dir.exists():
            for f in task_dir.glob(f"{task_id}-*.md"):
                return f
    return None


def _parse_human_acs(body_text):
    """Parse only Human AC checkboxes from task body.

    Returns list of dicts: line_idx, checked, text, confidence, steps, expected, if_not
    """
    from web.blueprints.tasks import _parse_acceptance_criteria, _parse_ac_body

    all_acs = _parse_acceptance_criteria(body_text)
    return [ac for ac in all_acs if ac.get("section") == "human"]


def _load_pending_approvals():
    """Load pending Tier 0 approval YAML files."""
    import time

    import yaml

    approvals_dir = PROJECT_ROOT / ".context" / "approvals"
    if not approvals_dir.exists():
        return []

    results = []
    now = time.time()
    for f in sorted(approvals_dir.glob("pending-*.yaml"), reverse=True):
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh)
            if not isinstance(data, dict):
                continue
            data["_file"] = f.name
            # Check expiry (1 hour)
            ts = data.get("timestamp", "")
            if ts:
                try:
                    from datetime import datetime
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    if now - dt.timestamp() > 3600:
                        data["status"] = "expired"
                except (ValueError, OSError):
                    pass
            results.append(data)
        except yaml.YAMLError:
            continue
    return results


def _parse_recommendation(body_text):
    """Extract the ## Recommendation section content (T-1195).

    Returns stripped content between `## Recommendation` and the next `## ` header.
    HTML comments (template boilerplate) are removed. Empty/whitespace-only returns "".
    """
    lines = body_text.split("\n")
    in_section = False
    collected = []
    for line in lines:
        stripped = line.strip()
        if stripped == "## Recommendation":
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if in_section:
            collected.append(line)
    content = "\n".join(collected)
    # Strip HTML comments (template placeholders)
    content = re.sub(r"<!--.*?-->", "", content, flags=re.DOTALL)
    return content.strip()


def _find_research_artifacts(task_id):
    """Find research artifact files for a task."""
    reports_dir = PROJECT_ROOT / "docs" / "reports"
    if not reports_dir.exists():
        return []

    artifacts = []
    tid_lower = task_id.lower().replace("-", "")
    for rpt in sorted(reports_dir.iterdir()):
        if rpt.suffix == ".md" and tid_lower in rpt.name.lower().replace("-", ""):
            artifacts.append({
                "name": rpt.name,
                "path": f"docs/reports/{rpt.name}",
            })
    return artifacts


def _render_review_404(task_id, reason="not_found"):
    """Render a mobile-friendly error page for review routes."""
    messages = {
        "not_found": ("Task Not Found", f"{task_id} does not exist or has no task file."),
        "invalid": ("Invalid Task ID", f"'{task_id}' is not a valid task identifier. Expected format: T-001"),
        "completed": ("Task Completed", f"{task_id} has been completed. No pending Human ACs."),
    }
    title, detail = messages.get(reason, messages["not_found"])
    return render_template("_review_error.html",
                           task_id=task_id, error_title=title, error_detail=detail,
                           reason=reason), 404 if reason != "completed" else 200


@bp.route("/review/<task_id>")
def review(task_id):
    """Mobile-first review page for a single task."""
    if not re.match(r"^T-\d{3,}$", task_id):
        return _render_review_404(task_id, "invalid")

    task_file = _find_task_file(task_id)
    if not task_file:
        # Check if it's in completed/
        completed_dir = PROJECT_ROOT / ".tasks" / "completed"
        if completed_dir.exists() and list(completed_dir.glob(f"{task_id}-*.md")):
            return _render_review_404(task_id, "completed")
        return _render_review_404(task_id, "not_found")

    content = task_file.read_text()
    fm, body = parse_frontmatter(content)
    if not fm:
        return _render_review_404(task_id, "not_found")

    human_acs = _parse_human_acs(body)
    checked_count = sum(1 for ac in human_acs if ac["checked"])
    total_count = len(human_acs)
    all_checked = total_count > 0 and checked_count == total_count

    pending_tier0 = _load_pending_approvals()
    active_tier0 = [a for a in pending_tier0 if a.get("status") == "pending"]

    artifacts = _find_research_artifacts(task_id)
    recommendation = _parse_recommendation(body)  # T-1195

    return render_template(
        "review.html",
        task_id=task_id,
        task_name=fm.get("name", ""),
        task_status=fm.get("status", ""),
        task_owner=fm.get("owner", ""),
        human_acs=human_acs,
        checked_count=checked_count,
        total_count=total_count,
        all_checked=all_checked,
        pending_tier0=active_tier0,
        artifacts=artifacts,
        recommendation=recommendation,
    )


@bp.route("/review/<task_id>/acs")
def review_acs_fragment(task_id):
    """htmx polling endpoint — returns just the AC list fragment."""
    if not re.match(r"^T-\d{3,}$", task_id):
        abort(404)

    task_file = _find_task_file(task_id)
    if not task_file:
        abort(404)

    content = task_file.read_text()
    fm, body = parse_frontmatter(content)
    if not fm:
        abort(404)

    human_acs = _parse_human_acs(body)
    checked_count = sum(1 for ac in human_acs if ac["checked"])
    total_count = len(human_acs)
    all_checked = total_count > 0 and checked_count == total_count

    return render_template(
        "_review_acs.html",
        task_id=task_id,
        human_acs=human_acs,
        checked_count=checked_count,
        total_count=total_count,
        all_checked=all_checked,
    )
