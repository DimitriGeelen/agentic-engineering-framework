"""Inception blueprint — inception task tracking and assumption registry."""

import logging
import re as re_mod

import markdown2
import yaml
from flask import Blueprint, abort, redirect, request, url_for
from markupsafe import Markup

from web.shared import PROJECT_ROOT, render_page, parse_frontmatter

logger = logging.getLogger(__name__)
from web.subprocess_utils import run_fw_command


def _md(text):
    """Convert markdown text to safe HTML."""
    if not text:
        return ""
    # Ensure blank line before lists so markdown parser recognizes them
    text = re_mod.sub(r"([^\n])\n(- )", r"\1\n\n\2", text)
    text = re_mod.sub(r"([^\n])\n(\d+\. )", r"\1\n\n\2", text)
    html = markdown2.markdown(text, extras=["fenced-code-blocks", "tables"])
    return Markup(html)

bp = Blueprint("inception", __name__)


def _load_all_tasks():
    """Load all tasks from active and completed directories."""
    tasks = []
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if not task_dir.exists():
            continue
        for f in sorted(task_dir.glob("T-*.md")):
            fm, body = parse_frontmatter(f.read_text())
            if not fm:
                continue
            fm["_location"] = location
            fm["_body"] = body
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


def _extract_all_sections(body):
    """Extract all ## sections from markdown body as {heading: content} dict.

    Returns an OrderedDict preserving the order sections appear in the file.
    HTML comments are stripped from content. (T-1177, G-036)
    """
    from collections import OrderedDict
    sections = OrderedDict()
    lines = body.split("\n")
    current_heading = None
    current_lines = []

    for line in lines:
        if line.startswith("## "):
            # Save previous section
            if current_heading is not None:
                text = "\n".join(current_lines).strip()
                text = re_mod.sub(r"<!--.*?-->", "", text, flags=re_mod.DOTALL).strip()
                sections[current_heading] = text
            current_heading = line[3:].strip()
            current_lines = []
        elif current_heading is not None:
            current_lines.append(line)

    # Save last section
    if current_heading is not None:
        text = "\n".join(current_lines).strip()
        text = re_mod.sub(r"<!--.*?-->", "", text, flags=re_mod.DOTALL).strip()
        sections[current_heading] = text

    return sections


def _load_assumptions():
    """Load assumptions from the project register."""
    af = PROJECT_ROOT / ".context" / "project" / "assumptions.yaml"
    if not af.exists():
        return []
    try:
        with open(af) as f:
            data = yaml.safe_load(f)
    except Exception as e:
        logger.warning("Failed to parse %s: %s", af, e)
        return []
    if not data:
        return []
    return data.get("assumptions", [])


@bp.route("/inception")
def inception_list():
    all_tasks = _load_all_tasks()
    inception_tasks = [t for t in all_tasks if t.get("workflow_type") == "inception"]

    assumptions = _load_assumptions()

    # Enrich inception tasks with decision state, assumption counts, and recommendation (T-959)
    for t in inception_tasks:
        body = t.get("_body", "")
        t["_decision"] = _extract_decision(body)
        task_id = t.get("id", "")
        linked = [a for a in assumptions if a.get("linked_task") == task_id]
        t["_assumption_total"] = len(linked)
        t["_assumption_validated"] = len([a for a in linked if a.get("status") == "validated"])
        t["_assumption_invalidated"] = len([a for a in linked if a.get("status") == "invalidated"])
        t["_assumption_untested"] = len([a for a in linked if a.get("status") == "untested"])

        # T-959: Extract recommendation summary for batch review
        rec_section = _extract_section(body, "Recommendation")
        if rec_section:
            # Get first 200 chars of recommendation for inline display
            rec_lines = [l for l in rec_section.split("\n") if l.strip() and not l.startswith("#")]
            t["_recommendation"] = " ".join(rec_lines)[:300] if rec_lines else ""
            # Extract recommendation type (GO/NO-GO/DEFER)
            rec_type = ""
            for line in rec_lines[:3]:
                if re_mod.search(r"\bGO\b", line) and not re_mod.search(r"\bNO-GO\b", line):
                    rec_type = "GO"
                    break
                elif re_mod.search(r"\bNO-GO\b", line):
                    rec_type = "NO-GO"
                    break
                elif re_mod.search(r"\bDEFER\b", line):
                    rec_type = "DEFER"
                    break
            t["_rec_type"] = rec_type
        else:
            t["_recommendation"] = ""
            t["_rec_type"] = ""

        # T-959: Check for research artifact
        reports_dir = PROJECT_ROOT / "docs" / "reports"
        t["_has_artifact"] = False
        t["_artifact_path"] = ""
        if reports_dir.exists() and task_id:
            for rf in reports_dir.iterdir():
                if task_id.lower() in rf.name.lower() and rf.suffix == ".md":
                    t["_has_artifact"] = True
                    t["_artifact_path"] = f"docs/reports/{rf.name}"
                    break

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
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    task_data = None
    task_body = ""
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if not task_dir.exists():
            continue
        for f in task_dir.glob(f"{task_id}-*.md"):
            task_data, task_body = parse_frontmatter(f.read_text())
            if task_data:
                task_data["_location"] = location
            else:
                task_data = None
            break

    if not task_data or task_data.get("workflow_type") != "inception":
        abort(404)

    # Extract sections dynamically (T-1177, G-036)
    all_raw_sections = _extract_all_sections(task_body)

    # Known sections with template-specific rendering
    KNOWN_SECTIONS = {
        "Problem Statement", "Assumptions", "Exploration Plan",
        "Technical Constraints", "Scope Fence", "Go/No-Go Criteria",
        "Recommendation", "Structural Upgrade", "Decision", "Updates",
        "Acceptance Criteria", "Verification", "Decisions", "Context",
    }

    # Build legacy sections dict for backward compatibility with template
    sections = {
        "problem": _md(all_raw_sections.get("Problem Statement", "")),
        "assumptions_text": _md(all_raw_sections.get("Assumptions", "")),
        "exploration": _md(all_raw_sections.get("Exploration Plan", "")),
        "constraints": _md(all_raw_sections.get("Technical Constraints", "")),
        "scope": _md(all_raw_sections.get("Scope Fence", "")),
        "criteria": _md(all_raw_sections.get("Go/No-Go Criteria", "")),
        "recommendation": _md(all_raw_sections.get("Recommendation", "")),
        "structural_upgrade": _md(all_raw_sections.get("Structural Upgrade", "")),
        "decision": _md(all_raw_sections.get("Decision", "")),
        "updates": _md(all_raw_sections.get("Updates", "")),
    }

    # Extra sections not in the known set — rendered generically (G-036 fix)
    extra_sections = []
    for heading, content in all_raw_sections.items():
        if heading not in KNOWN_SECTIONS and content:
            extra_sections.append({"heading": heading, "content": _md(content)})

    # T-679: Pre-populate rationale from ## Recommendation section
    rec_raw = _extract_section(task_body, "Recommendation") or ""
    # Strip markdown formatting for the textarea hint.
    # T-1091: No truncation — the human recording the decision needs the full
    # Recommendation. Prior 500-char cap left the textarea with fragmented rationale
    # ending in "...". T-1150: approvals.py cap also removed — truncating the pre-fill
    # truncates the permanent decision rationale.
    rationale_hint = re_mod.sub(r"\*\*([^*]+)\*\*", r"\1", rec_raw).strip()

    decision_state = _extract_decision(task_body)

    # Load linked assumptions
    assumptions = _load_assumptions()
    linked_assumptions = [a for a in assumptions if a.get("linked_task") == task_id]

    # Episodic memory
    episodic = None
    episodic_file = PROJECT_ROOT / ".context" / "episodic" / f"{task_id}.yaml"
    if episodic_file.exists():
        try:
            with open(episodic_file) as f:
                episodic = yaml.safe_load(f)
        except Exception as e:
            logger.warning("Failed to parse %s: %s", episodic_file, e)

    return render_page(
        "inception_detail.html",
        page_title=f"Inception {task_id}",
        task=task_data,
        sections=sections,
        extra_sections=extra_sections,
        decision_state=decision_state,
        linked_assumptions=linked_assumptions,
        episodic=episodic,
        task_id=task_id,
        rationale_hint=rationale_hint,
    )


@bp.route("/inception/<task_id>/add-assumption", methods=["POST"])
def add_assumption(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)
    statement = request.form.get("statement", "").strip()
    if not statement:
        abort(400)
    run_fw_command(["assumption", "add", statement, "--task", task_id], timeout=10)
    return redirect(url_for("inception.inception_detail", task_id=task_id))


@bp.route("/assumptions/<assumption_id>/resolve", methods=["POST"])
def resolve_assumption(assumption_id):
    if not re_mod.match(r"^A-\d{3}$", assumption_id):
        abort(404)
    action = request.form.get("action", "").strip().lower()
    evidence = request.form.get("evidence", "").strip()
    if action not in ("validate", "invalidate") or not evidence:
        abort(400)
    run_fw_command(["assumption", action, assumption_id, "--evidence", evidence], timeout=10)
    # Redirect back to referrer or assumptions list
    referrer = request.form.get("redirect", "")
    if referrer:
        return redirect(referrer)
    return redirect(url_for("inception.assumptions_list"))


@bp.route("/inception/<task_id>/decide", methods=["POST"])
def record_decision(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)
    decision = request.form.get("decision", "").strip().lower()
    rationale = request.form.get("rationale", "").strip()
    if decision not in ("go", "no-go", "defer") or not rationale:
        abort(400)
    # T-1120: Create review marker — the human IS reviewing by being on this page.
    # Without this, fw inception decide blocks with "Task review required" because
    # the marker is normally created by fw task review (CLI), not Watchtower.
    import os
    marker_dir = os.path.join(PROJECT_ROOT, ".context", "working")
    os.makedirs(marker_dir, exist_ok=True)
    marker_path = os.path.join(marker_dir, f".reviewed-{task_id}")
    if not os.path.exists(marker_path):
        with open(marker_path, "w") as f:
            f.write(f"reviewed-via-watchtower {task_id}\n")
    stdout, stderr, ok = run_fw_command(
        ["inception", "decide", task_id, decision, "--rationale", rationale],
        timeout=30,
    )

    # If called via htmx (e.g., from /approvals page), return inline fragment (T-643)
    if request.headers.get("HX-Request"):
        if ok:
            color = "#10b981" if decision == "go" else "#ef4444" if decision == "no-go" else "#6b7280"
            label = decision.upper()
            return (
                f'<div class="approval-card" style="border-color:{color}; opacity:0.7;">'
                f'<strong>{task_id}</strong>: Decision recorded — '
                f'<span style="color:{color}; font-weight:700;">{label}</span>'
                f'</div>'
            )
        return f'<p style="color:var(--pico-del-color);">Error: {(stderr or stdout)[:200]}</p>', 500

    return redirect(url_for("inception.inception_detail", task_id=task_id))


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
