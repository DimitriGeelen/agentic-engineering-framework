"""Inception blueprint — inception task tracking and assumption registry."""

import re as re_mod

import yaml
from flask import Blueprint, abort, request

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("inception", __name__)


def _load_all_tasks():
    """Load all tasks from active and completed directories."""
    tasks = []
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if not task_dir.exists():
            continue
        for f in sorted(task_dir.glob("T-*.md")):
            file_text = f.read_text()
            fm_match = re_mod.match(r"^---\n(.*?)\n---\n(.*)", file_text, re_mod.DOTALL)
            if not fm_match:
                continue
            try:
                fm = yaml.safe_load(fm_match.group(1))
            except yaml.YAMLError:
                continue
            if not isinstance(fm, dict):
                continue
            fm["_location"] = location
            fm["_body"] = fm_match.group(2)
            tasks.append(fm)
    return tasks


def _extract_decision(body):
    """Extract decision state from task body."""
    for line in body.split("\n"):
        stripped = line.strip()
        if stripped.startswith("**Decision**:") or stripped.startswith("**Decision:**"):
            value = stripped.split(":", 1)[1].strip().strip("*").strip()
            if value and value != "<!--":
                return value
    return "pending"


def _extract_section(body, section_name):
    """Extract content of a markdown section (## heading) from body."""
    lines = body.split("\n")
    capture = False
    result = []
    for line in lines:
        if line.startswith(f"## {section_name}"):
            capture = True
            continue
        if capture and line.startswith("## "):
            break
        if capture:
            result.append(line)
    text = "\n".join(result).strip()
    # Strip HTML comments
    text = re_mod.sub(r"<!--.*?-->", "", text, flags=re_mod.DOTALL).strip()
    return text


def _load_assumptions():
    """Load assumptions from the project register."""
    af = PROJECT_ROOT / ".context" / "project" / "assumptions.yaml"
    if not af.exists():
        return []
    with open(af) as f:
        data = yaml.safe_load(f)
    if not data:
        return []
    return data.get("assumptions", [])


@bp.route("/inception")
def inception_list():
    all_tasks = _load_all_tasks()
    inception_tasks = [t for t in all_tasks if t.get("workflow_type") == "inception"]

    assumptions = _load_assumptions()

    # Enrich inception tasks with decision state and assumption counts
    for t in inception_tasks:
        body = t.get("_body", "")
        t["_decision"] = _extract_decision(body)
        task_id = t.get("id", "")
        linked = [a for a in assumptions if a.get("linked_task") == task_id]
        t["_assumption_total"] = len(linked)
        t["_assumption_validated"] = len([a for a in linked if a.get("status") == "validated"])
        t["_assumption_invalidated"] = len([a for a in linked if a.get("status") == "invalidated"])
        t["_assumption_untested"] = len([a for a in linked if a.get("status") == "untested"])

    # Filter
    decision_filter = request.args.get("decision", "").strip().lower()
    if decision_filter:
        inception_tasks = [
            t for t in inception_tasks
            if t["_decision"].lower() == decision_filter
        ]

    location_filter = request.args.get("location", "").strip()
    if location_filter:
        inception_tasks = [t for t in inception_tasks if t["_location"] == location_filter]

    # Sort: active first, then by ID
    inception_tasks.sort(key=lambda t: (0 if t["_location"] == "active" else 1, t.get("id", "")))

    # Summary counts
    all_inception = [t for t in all_tasks if t.get("workflow_type") == "inception"]
    summary = {
        "total": len(all_inception),
        "active": len([t for t in all_inception if t["_location"] == "active"]),
        "completed": len([t for t in all_inception if t["_location"] == "completed"]),
        "pending": len([t for t in all_inception if _extract_decision(t.get("_body", "")).lower() == "pending"]),
        "go": len([t for t in all_inception if _extract_decision(t.get("_body", "")).lower() == "go"]),
        "no_go": len([t for t in all_inception if _extract_decision(t.get("_body", "")).lower() in ("no-go", "no_go")]),
    }

    return render_page(
        "inception.html",
        page_title="Inception",
        inception_tasks=inception_tasks,
        summary=summary,
        decision_filter=decision_filter,
        location_filter=location_filter,
        assumptions_total=len(assumptions),
    )


@bp.route("/inception/<task_id>")
def inception_detail(task_id):
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    task_data = None
    task_body = ""
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if not task_dir.exists():
            continue
        for f in task_dir.glob(f"{task_id}-*.md"):
            file_content = f.read_text()
            fm_match = re_mod.match(r"^---\n(.*?)\n---\n(.*)", file_content, re_mod.DOTALL)
            if fm_match:
                try:
                    task_data = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    task_data = None
                if isinstance(task_data, dict):
                    task_body = fm_match.group(2)
                    task_data["_location"] = location
            break

    if not task_data or task_data.get("workflow_type") != "inception":
        abort(404)

    # Extract sections
    sections = {
        "problem": _extract_section(task_body, "Problem Statement"),
        "assumptions_text": _extract_section(task_body, "Assumptions"),
        "exploration": _extract_section(task_body, "Exploration Plan"),
        "scope": _extract_section(task_body, "Scope Fence"),
        "criteria": _extract_section(task_body, "Go/No-Go Criteria"),
        "decision": _extract_section(task_body, "Decision"),
        "updates": _extract_section(task_body, "Updates"),
    }

    decision_state = _extract_decision(task_body)

    # Load linked assumptions
    assumptions = _load_assumptions()
    linked_assumptions = [a for a in assumptions if a.get("linked_task") == task_id]

    # Episodic memory
    episodic = None
    episodic_file = PROJECT_ROOT / ".context" / "episodic" / f"{task_id}.yaml"
    if episodic_file.exists():
        with open(episodic_file) as f:
            episodic = yaml.safe_load(f)

    return render_page(
        "inception_detail.html",
        page_title=f"Inception {task_id}",
        task=task_data,
        sections=sections,
        decision_state=decision_state,
        linked_assumptions=linked_assumptions,
        episodic=episodic,
        task_id=task_id,
    )


@bp.route("/assumptions")
def assumptions_list():
    assumptions = _load_assumptions()

    # Filter
    status_filter = request.args.get("status", "").strip().lower()
    if status_filter:
        assumptions = [a for a in assumptions if a.get("status", "").lower() == status_filter]

    task_filter = request.args.get("task", "").strip()
    if task_filter:
        assumptions = [a for a in assumptions if a.get("linked_task") == task_filter]

    # Summary
    all_assumptions = _load_assumptions()
    summary = {
        "total": len(all_assumptions),
        "validated": len([a for a in all_assumptions if a.get("status") == "validated"]),
        "invalidated": len([a for a in all_assumptions if a.get("status") == "invalidated"]),
        "untested": len([a for a in all_assumptions if a.get("status") == "untested"]),
    }

    return render_page(
        "assumptions.html",
        page_title="Assumptions",
        assumptions=assumptions,
        summary=summary,
        status_filter=status_filter,
        task_filter=task_filter,
    )
