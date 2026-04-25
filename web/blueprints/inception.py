"""Inception blueprint — inception task tracking and assumption registry."""

import logging
import re as re_mod

import markdown2
import yaml
from flask import Blueprint, abort, redirect, request, url_for
from markupsafe import Markup

from web.shared import PROJECT_ROOT, render_page, parse_frontmatter, task_id_sort_key, get_all_task_metadata

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


def _extract_rationale_from_recommendation(rec_body):
    """T-1390 (F4 fix): Extract only the rationale body from a structured
    ## Recommendation block, not the whole section.

    The structured format is:
        **Recommendation:** GO / NO-GO / DEFER
        **Rationale:** <text that may span paragraphs>
        **Evidence:**
        - bullet 1
        - bullet 2

    Without this filter, pre-filling the decision textarea with the whole
    block produced rationale values like "Recommendation: GO\\n\\nRationale:
    ... Evidence: - ..." — the human's recorded decision then contained the
    self-referential prefix plus full evidence bullets (observed on T-1284
    and 60 other decided inceptions, see T-1388 F4).

    Fallback: when no `**Rationale:**` marker exists, return the full body
    stripped of ** formatting (preserves behavior for free-form recommendations).
    """
    if not rec_body:
        return ""
    # Strip **bold** markers first so we work with plain text
    plain = re_mod.sub(r"\*\*([^*]+)\*\*", r"\1", rec_body).strip()
    # Look for "Rationale:" marker and slice to next top-level marker
    m = re_mod.search(r"(?m)^Rationale:\s*(.*?)(?=^(?:Evidence|Recommendation|Build|Reversibility|Alternative|See):|\Z)",
                      plain, re_mod.DOTALL)
    if m:
        return m.group(1).strip()
    # Fallback — no structured markers
    return plain


def _extract_recommendation_stance(rec_body):
    """T-1391 (F3 fix): Extract the Recommendation stance (GO/NO-GO/DEFER) from
    the `**Recommendation:**` header line of a structured ## Recommendation
    section. Returns the stance lowercased ('go', 'no-go', 'defer') or None
    when the section is unstructured/empty.

    Enables the template to compare agent's recommendation vs human's decision
    and collapse duplicate UI when the human adopted the recommendation as-is.
    """
    if not rec_body:
        return None
    plain = re_mod.sub(r"\*\*([^*]+)\*\*", r"\1", rec_body)
    m = re_mod.search(r"(?mi)^Recommendation:\s*(GO|NO-GO|NO_GO|DEFER)\b", plain)
    if not m:
        return None
    stance = m.group(1).lower().replace("_", "-")
    return stance

bp = Blueprint("inception", __name__)


import time as _time_mod
import copy as _copy_mod

# Cache for inception task bodies (frontmatter from shared cache, bodies read on demand)
_inception_cache = {"data": None, "all_count": 0, "ts": 0}
_INCEPTION_CACHE_TTL = 30


def _load_all_tasks():
    """Load all tasks with inception tasks enriched with body text.

    Uses the shared task metadata cache for frontmatter (avoids reading 1200+ files).
    Only reads body text for inception tasks (~200 files instead of 1200+).
    """
    import copy
    now = _time_mod.monotonic()
    all_meta = get_all_task_metadata()

    # Check if cache is still valid (same task count + within TTL)
    if (_inception_cache["data"] is not None
            and len(all_meta) == _inception_cache["all_count"]
            and (now - _inception_cache["ts"]) < _INCEPTION_CACHE_TTL):
        return _inception_cache["data"]

    tasks = []
    for fm in all_meta:
        t = copy.copy(fm)
        if fm.get("workflow_type") == "inception":
            # Read body text only for inception tasks
            task_id = fm.get("id", "")
            location = fm.get("_location", "active")
            task_dir = PROJECT_ROOT / ".tasks" / location
            body = ""
            if task_dir.exists():
                for f in task_dir.glob(f"{task_id}-*.md"):
                    _, body = parse_frontmatter(f.read_text())
                    break
            t["_body"] = body
        else:
            t["_body"] = ""
        tasks.append(t)

    _inception_cache["data"] = tasks
    _inception_cache["all_count"] = len(all_meta)
    _inception_cache["ts"] = now
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


# --- Reports index cache (T-1245) ---
_reports_cache = {"index": None, "count": 0, "ts": 0}
_REPORTS_CACHE_TTL = 60


def _get_reports_index():
    """Build {task_id: 'docs/reports/filename.md'} index from reports directory."""
    now = _time_mod.monotonic()
    reports_dir = PROJECT_ROOT / "docs" / "reports"
    if not reports_dir.exists():
        return {}
    current_count = len(list(reports_dir.glob("*.md")))
    if (_reports_cache["index"] is not None
            and current_count == _reports_cache["count"]
            and (now - _reports_cache["ts"]) < _REPORTS_CACHE_TTL):
        return _reports_cache["index"]

    index = {}
    for rf in reports_dir.iterdir():
        if rf.suffix != ".md":
            continue
        m = re_mod.search(r"(T-\d+)", rf.name, re_mod.IGNORECASE)
        if m:
            tid = m.group(1).upper()
            index[tid] = f"docs/reports/{rf.name}"
    _reports_cache["index"] = index
    _reports_cache["count"] = current_count
    _reports_cache["ts"] = now
    return index


@bp.route("/inception")
def inception_list():
    all_tasks = _load_all_tasks()
    inception_tasks = [t for t in all_tasks if t.get("workflow_type") == "inception"]

    assumptions = _load_assumptions()
    _reports_index = _get_reports_index()

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

        # T-959: Check for research artifact (T-1245: cached index)
        t["_has_artifact"] = False
        t["_artifact_path"] = ""
        if task_id and task_id in _reports_index:
            t["_has_artifact"] = True
            t["_artifact_path"] = _reports_index[task_id]

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
    inception_tasks.sort(key=lambda t: (0 if t["_location"] == "active" else 1, task_id_sort_key(t)))

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
    # T-1390 (F4 fix): extract only the Rationale body from structured
    # recommendations (Recommendation/Rationale/Evidence format). Without
    # this, pre-fill contained the whole block including "Recommendation: GO"
    # prefix and Evidence bullets — the stored decision then embedded the
    # self-referential prefix + all evidence bullets (see T-1388 F4).
    # T-1246 (G-046 fix): when the task file lacks a Recommendation section,
    # fall back to docs/reports/T-{task_id}-inception.md (CTL-027 artifact).
    # Tries canonical name first, then T-{id}-*-inception.md for older
    # descriptive-slug artifacts. Rewards thorough research artifacts instead
    # of punishing them with an empty pre-fill.
    rec_raw = _extract_section(task_body, "Recommendation") or ""
    if not rec_raw:
        reports_dir = PROJECT_ROOT / "docs" / "reports"
        candidates = [reports_dir / f"{task_id}-inception.md"]
        candidates.extend(sorted(reports_dir.glob(f"{task_id}-*-inception.md")))
        for artifact_path in candidates:
            if artifact_path.exists():
                try:
                    artifact_body = artifact_path.read_text()
                    rec_raw = _extract_section(artifact_body, "Recommendation") or ""
                    if rec_raw:
                        break
                except Exception as e:
                    logger.warning("Failed to read %s: %s", artifact_path, e)
    rationale_hint = _extract_rationale_from_recommendation(rec_raw)

    decision_state = _extract_decision(task_body)

    # T-1391 (F3 fix): compute rec_stance + decision_matches_recommendation so
    # the template can collapse the duplicate Recommendation card when the
    # human adopted the recommendation, or label both cards when overridden.
    rec_stance = _extract_recommendation_stance(rec_raw)
    _dec_norm = (decision_state or "").lower().replace("_", "-")
    decision_matches_recommendation = (
        rec_stance is not None
        and _dec_norm not in ("", "pending")
        and rec_stance == _dec_norm
    )

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
        rec_stance=rec_stance,
        decision_matches_recommendation=decision_matches_recommendation,
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
    # T-1262: pass --from-watchtower to exempt the T-1259 CLAUDECODE guard.
    # Flask inherits CLAUDECODE=1 from its parent Claude Code shell; without
    # this flag, Watchtower's decide POST is blocked by the agent-invocation guard.
    stdout, stderr, ok = run_fw_command(
        ["inception", "decide", task_id, decision, "--rationale", rationale, "--from-watchtower"],
        timeout=30,
    )

    # T-1223: log errors for debugging
    if not ok:
        import logging
        logging.getLogger(__name__).error(
            "inception decide %s failed: stdout=%r stderr=%r",
            task_id, stdout[:500], stderr[:500]
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

    # T-1454 (OBS-017): non-htmx form path — surface failure via ?error= query param
    # so the rendered inception_detail page can show a banner. Without this,
    # the user sees a silent redirect and clicks GO repeatedly.
    if not ok:
        err = (stderr or stdout or "Unknown error from fw inception decide")[:300]
        return redirect(url_for("inception.inception_detail", task_id=task_id, error=err))

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
