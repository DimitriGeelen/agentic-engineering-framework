"""Approvals blueprint — Unified approval surface (T-611, T-639).

Shows three urgency-ordered sections:
  A. Tier 0 approvals (agent blocked)
  B. Pending GO/NO-GO inception decisions
  C. Tasks with unchecked Human ACs
"""

import os
import time
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint, request

from web.shared import PROJECT_ROOT, render_page, parse_frontmatter

bp = Blueprint("approvals", __name__)

APPROVALS_DIR = PROJECT_ROOT / ".context" / "approvals"
APPROVAL_FILE = PROJECT_ROOT / ".context" / "working" / ".tier0-approval"

# Approvals older than this are considered expired (seconds)
EXPIRY_SECONDS = 3600  # 1 hour


def _load_pending_approvals():
    """Load all pending approval YAML files. Returns list of dicts."""
    approvals = []
    if not APPROVALS_DIR.exists():
        return approvals

    now = time.time()
    for f in sorted(APPROVALS_DIR.glob("pending-*.yaml"), reverse=True):
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh)
            if not isinstance(data, dict):
                continue
            data["_file"] = f.name

            # Check expiry
            ts = data.get("timestamp", "")
            if ts:
                try:
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    age = now - dt.timestamp()
                    if age > EXPIRY_SECONDS:
                        data["status"] = "expired"
                except (ValueError, OSError):
                    pass

            approvals.append(data)
        except yaml.YAMLError:
            continue
    return approvals


def _load_resolved_approvals():
    """Load recently resolved (approved/rejected) approvals."""
    resolved = []
    if not APPROVALS_DIR.exists():
        return resolved

    for f in sorted(APPROVALS_DIR.glob("resolved-*.yaml"), reverse=True):
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh)
            if isinstance(data, dict):
                resolved.append(data)
        except yaml.YAMLError:
            continue
    return resolved[:20]  # Last 20


def _load_pending_go_decisions():
    """Scan active inception tasks where decision is still pending.

    Returns list of dicts with: task_id, name, status, problem_excerpt,
    assumption_counts, artifacts.
    """
    from web.blueprints.inception import _extract_decision, _extract_section, _load_assumptions

    task_dir = PROJECT_ROOT / ".tasks" / "active"
    if not task_dir.exists():
        return []

    assumptions = _load_assumptions()
    results = []

    for f in sorted(task_dir.glob("T-*.md")):
        try:
            content = f.read_text()
        except OSError:
            continue
        fm, body = parse_frontmatter(content)
        if not fm or fm.get("workflow_type") != "inception":
            continue
        if _extract_decision(body) != "pending":
            continue

        # T-1123: Only show inception tasks with a recommendation (skip captured/unexplored)
        rec_section = _extract_section(body, "Recommendation")
        if not rec_section or len(rec_section.strip()) < 20:
            continue

        task_id = fm.get("id", "")
        linked = [a for a in assumptions if a.get("linked_task") == task_id]

        # Find research artifacts
        artifacts = []
        reports_dir = PROJECT_ROOT / "docs" / "reports"
        if reports_dir.exists():
            tid_lower = task_id.lower().replace("-", "")
            for rpt in sorted(reports_dir.iterdir()):
                if rpt.suffix == ".md" and tid_lower in rpt.name.lower().replace("-", ""):
                    artifacts.append({"name": rpt.name, "path": f"docs/reports/{rpt.name}"})

        problem = _extract_section(body, "Problem Statement")
        # Truncate to first 2 lines
        problem_lines = problem.split("\n")[:2]
        problem_excerpt = " ".join(line.strip() for line in problem_lines if line.strip())
        if len(problem_excerpt) > 200:
            problem_excerpt = problem_excerpt[:197] + "..."

        # Extract recommendation for display (T-1119: show full recommendation)
        rec_raw = _extract_section(body, "Recommendation")
        rec_display = ""  # Full recommendation for visible display
        rec_decision = ""  # GO/NO-GO/DEFER extracted
        if rec_raw and len(rec_raw) > 10:
            rec_display = rec_raw.strip()
            # Extract the recommendation decision
            for line in rec_raw.split("\n"):
                stripped = line.strip().replace("**", "").replace("*", "")
                if stripped.lower().startswith("recommendation:"):
                    rec_decision = stripped.split(":", 1)[1].strip().split()[0].upper()
                    break

        # Fallback to GO criteria for rationale hint
        # T-1150: NO truncation — the textarea pre-fill becomes the permanent decision
        # rationale when the human clicks approve. Truncating here = truncating the decision.
        # (Previous 200-char cap caused data loss in recorded decisions.)
        rationale_hint = ""
        if rec_raw and len(rec_raw) > 10:
            rationale_hint = rec_raw.replace("**", "").replace("*", "").strip()
        else:
            gonogo = _extract_section(body, "Go/No-Go Criteria")
            if gonogo:
                go_lines = []
                in_go = False
                for line in gonogo.split("\n"):
                    stripped = line.strip()
                    if stripped.startswith("**GO if:**"):
                        in_go = True
                        continue
                    if stripped.startswith("**NO-GO if:**"):
                        break
                    if in_go and stripped.startswith("- "):
                        go_lines.append(stripped[2:].strip())
                rationale_hint = "; ".join(go_lines) if go_lines else ""

        # T-1214: Extract Go/No-Go Criteria for fallback display when recommendation missing
        go_nogo_raw = _extract_section(body, "Go/No-Go Criteria")

        results.append({
            "task_id": task_id,
            "name": fm.get("name", ""),
            "status": fm.get("status", ""),
            "problem_excerpt": problem_excerpt,
            "problem_full": problem,
            "assumption_counts": {
                "total": len(linked),
                "validated": sum(1 for a in linked if a.get("status") == "validated"),
            },
            "artifacts": artifacts,
            "rationale_hint": rationale_hint,
            "recommendation": rec_display,
            "rec_decision": rec_decision,
            "go_nogo_criteria": go_nogo_raw,
        })

    return results


def _load_pending_human_acs():
    """Scan active tasks for unchecked Human ACs.

    Returns list of dicts with: task_id, name, status, human_acs list, age_days, is_stale, sort_priority.
    Sorted by priority: REVIEW first, then stale (>7d), then RUBBER-STAMP.
    """
    import time
    from datetime import datetime

    from web.blueprints.tasks import _parse_acceptance_criteria

    task_dir = PROJECT_ROOT / ".tasks" / "active"
    if not task_dir.exists():
        return []

    results = []
    now = time.time()

    for f in sorted(task_dir.glob("T-*.md")):
        try:
            content = f.read_text()
        except OSError:
            continue
        fm, body = parse_frontmatter(content)
        if not fm:
            continue

        all_acs = _parse_acceptance_criteria(body)
        human_acs = [ac for ac in all_acs if ac.get("section") == "human"]
        unchecked = [ac for ac in human_acs if not ac["checked"]]

        if not unchecked:
            continue

        # Calculate age from date_finished or last_update
        age_days = 0
        for date_field in ("date_finished", "last_update", "created"):
            ts = fm.get(date_field, "")
            if ts:
                try:
                    dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
                    age_days = int((now - dt.timestamp()) / 86400)
                    break
                except (ValueError, OSError):
                    pass

        is_stale = age_days > 7

        # Priority: has REVIEW AC unchecked → 0, stale → 1, RUBBER-STAMP only → 2
        has_review = any(ac.get("confidence") == "review" and not ac["checked"]
                        for ac in human_acs)
        sort_priority = 0 if has_review else (1 if is_stale else 2)

        results.append({
            "task_id": fm.get("id", ""),
            "name": fm.get("name", ""),
            "status": fm.get("status", ""),
            "human_acs": human_acs,
            "age_days": age_days,
            "is_stale": is_stale,
            "sort_priority": sort_priority,
        })

    # Sort: priority ascending, then age descending (oldest first within group)
    results.sort(key=lambda t: (t["sort_priority"], -t["age_days"]))
    return results


def _build_approvals_context():
    """Build template context for approvals page."""
    pending_tier0 = _load_pending_approvals()
    resolved_tier0 = _load_resolved_approvals()
    pending_go = _load_pending_go_decisions()
    pending_acs = _load_pending_human_acs()

    tier0_count = sum(1 for a in pending_tier0 if a.get("status") == "pending")
    go_count = len(pending_go)
    ac_count = sum(
        sum(1 for ac in t["human_acs"] if not ac["checked"])
        for t in pending_acs
    )
    total = tier0_count + go_count + len(pending_acs)

    # Count tasks ready for batch completion (all human ACs checked)
    ready_count = sum(
        1 for t in pending_acs
        if all(ac["checked"] for ac in t["human_acs"])
    )

    return dict(
        pending_tier0=pending_tier0,
        resolved_tier0=resolved_tier0,
        pending_go=pending_go,
        pending_acs=pending_acs,
        tier0_count=tier0_count,
        go_count=go_count,
        ac_count=ac_count,
        ac_task_count=len(pending_acs),
        total_count=total,
        active_count=tier0_count,
        ready_count=ready_count,
    )


@bp.route("/approvals")
def approvals():
    ctx = _build_approvals_context()
    return render_page("approvals.html", page_title="Approvals", **ctx)


@bp.route("/approvals/content")
def approvals_content():
    """htmx polling fragment — returns approvals content without page wrapper (T-669)."""
    from flask import render_template

    ctx = _build_approvals_context()
    return render_template("_approvals_content.html", **ctx)


@bp.route("/api/approvals/decide", methods=["POST"])
def decide_approval():
    """Approve or reject a pending Tier 0 request.

    This endpoint is the unfakeable surface — only the web UI (human) can POST here.
    It writes the approval token that check-tier0.sh reads on retry.
    """
    command_hash = request.form.get("command_hash", "").strip()
    decision = request.form.get("decision", "").strip()
    feedback = request.form.get("feedback", "").strip()

    if not command_hash:
        return '<p style="color:var(--pico-del-color);">Missing command hash</p>', 400
    if decision not in ("approved", "rejected"):
        return '<p style="color:var(--pico-del-color);">Invalid decision</p>', 400

    # Find the pending request
    pending_file = APPROVALS_DIR / f"pending-{command_hash[:12]}.yaml"
    if not pending_file.exists():
        return '<p style="color:var(--pico-del-color);">No pending request found</p>', 404

    try:
        with open(pending_file) as fh:
            data = yaml.safe_load(fh)
    except yaml.YAMLError:
        return '<p style="color:var(--pico-del-color);">Cannot read request</p>', 500

    now_ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    if decision == "approved":
        # Write the approval token that check-tier0.sh expects
        # Format: <command_hash> <unix_timestamp>
        APPROVAL_FILE.parent.mkdir(parents=True, exist_ok=True)
        APPROVAL_FILE.write_text(f"{command_hash} {int(time.time())}\n")

    # Move pending → resolved
    data["status"] = decision
    data["response"] = {
        "decision": decision,
        "feedback": feedback or None,
        "responded_at": now_ts,
        "mechanism": "watchtower",
    }

    resolved_file = APPROVALS_DIR / f"resolved-{command_hash[:12]}.yaml"
    with open(resolved_file, "w") as fh:
        yaml.dump(data, fh, default_flow_style=False, sort_keys=False)

    # Remove pending file
    pending_file.unlink(missing_ok=True)

    status_color = "var(--pico-ins-color)" if decision == "approved" else "var(--pico-del-color)"
    status_icon = "Approved" if decision == "approved" else "Rejected"
    return f'<p style="color:{status_color};">{status_icon}. Agent can retry the command.</p>'


@bp.route("/api/approvals/complete-batch", methods=["POST"])
def complete_batch():
    """Complete all tasks where ALL Human ACs are checked (T-846).

    This is a human-initiated batch action from the Watchtower UI.
    Only completes tasks that are fully ready (no unchecked ACs).
    """
    import subprocess

    pending_acs = _load_pending_human_acs()

    # Find tasks where ALL human ACs are checked
    ready_tasks = []
    for t in pending_acs:
        unchecked = [ac for ac in t["human_acs"] if not ac["checked"]]
        if not unchecked:
            ready_tasks.append(t["task_id"])

    if not ready_tasks:
        return '<p style="color:var(--pico-muted-color);">No tasks ready for completion (all have unchecked ACs).</p>'

    completed = []
    errors = []
    fw_path = str(PROJECT_ROOT / "bin" / "fw")

    for task_id in ready_tasks:
        try:
            result = subprocess.run(
                [fw_path, "task", "update", task_id, "--status", "work-completed",
                 "--force", "--reason", "Batch completed via Watchtower UI (human action)"],
                capture_output=True, text=True, timeout=30,
                cwd=str(PROJECT_ROOT)
            )
            if result.returncode == 0:
                completed.append(task_id)
            else:
                errors.append(f"{task_id}: {result.stderr[:100]}")
        except Exception as e:
            errors.append(f"{task_id}: {str(e)[:100]}")

    parts = []
    if completed:
        parts.append(f'<p style="color:var(--pico-ins-color);">Completed {len(completed)} task(s): {", ".join(completed)}</p>')
    if errors:
        parts.append(f'<p style="color:var(--pico-del-color);">Errors ({len(errors)}): {"<br>".join(errors)}</p>')

    return "\n".join(parts)
