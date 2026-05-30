"""Review blueprint — Mobile-first task review page for QR scan (T-667).

Lightweight approval card at /review/T-XXX:
- Standalone template (no base.html chrome)
- Human ACs only with large touch targets
- Pending Tier 0 approvals with approve/reject
- htmx polling for live updates
"""

import re
import sys

from flask import Blueprint, abort, redirect, render_template, request, url_for

from web.shared import PROJECT_ROOT, parse_frontmatter

# T-1810: paused-dispatch helpers live in lib/ (CLI parity with `fw pause list`).
sys.path.insert(0, str(PROJECT_ROOT / "lib"))

bp = Blueprint("review", __name__)


def _load_paused_for_task(task_id):
    """Decorate paused-for-task rows with short id, age label, truncated question."""
    from dispatch_pause import format_age, list_paused_dispatches_for_task, truncate

    rows = list_paused_dispatches_for_task(task_id, PROJECT_ROOT)
    out = []
    for r in rows:
        rr = dict(r)
        did = rr.get("dispatch_id") or ""
        rr["dispatch_id_short"] = (did[:10] + "...") if len(did) > 10 else did
        rr["age_label"] = format_age(int(rr.get("age_seconds") or 0))
        rr["question_display"] = truncate(rr.get("question") or "(no question)", 240)
        out.append(rr)
    return out


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


# T-1575: _parse_recommendation removed — see web.shared.extract_recommendation
# (returns structured {verdict, rationale, evidence, raw} dict). Three parsers
# drifted apart and /review surface ended up dumping `raw` into a `<pre>` block,
# showing literal markdown to humans. Now unified.


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

    # T-2131 (T-2125 slice A): render-side forgiveness for the class-mismatched
    # handoff URL the agent kept typing for inceptions. If the target task is
    # an inception, redirect to /inception/<id> — the class-correct surface
    # that exposes the GO/NO-GO/DEFER decide form. /review/<id> is the
    # partial-complete task-review surface; routing inceptions through it
    # showed the wrong form. Pairs with the codification in T-2129 and the
    # CLI hint emitted by `fw task review` (lib/review.sh).
    if fm.get("workflow_type") == "inception":
        return redirect(url_for("inception.inception_detail", task_id=task_id), code=302)

    human_acs = _parse_human_acs(body)
    checked_count = sum(1 for ac in human_acs if ac["checked"])
    total_count = len(human_acs)
    all_checked = total_count > 0 and checked_count == total_count

    pending_tier0 = _load_pending_approvals()
    active_tier0 = [a for a in pending_tier0 if a.get("status") == "pending"]

    artifacts = _find_research_artifacts(task_id)
    # T-1575: structured extraction (verdict, rationale, evidence) — replaces
    # the verdict-only path + raw-pre-dump that ate the markdown formatting.
    # T-1583: also surface the reviewer agent's mechanical verdict (cross-surface
    # parity with /approvals F3 / T-1569).
    from web.shared import extract_recommendation, render_markdown_safe, extract_reviewer_verdict
    rec = extract_recommendation(body)
    reviewer = extract_reviewer_verdict(body)
    rec_complete = rec["verdict"] != "?" and bool(rec["rationale"].strip())
    rec_rationale_html = render_markdown_safe(rec["rationale"])
    rec_evidence_html = render_markdown_safe(rec["evidence"])
    # T-1578: state distinguishes "no Recommendation block at all" (NO-REC)
    # from "block exists but verdict unparseable" (?). Same convention as
    # cockpit / approvals / review-queue / handover (T-1576, T-1577).
    rec_state = "NO-REC" if not rec["raw"].strip() else rec["verdict"]

    # T-1575: detect already-recorded decision so we don't re-prompt the human.
    from web.blueprints.inception import _extract_decision
    decision_state = _extract_decision(body)
    decision_recorded = decision_state.lower() not in ("pending", "")

    # T-1810: paused-dispatch panel — web parity for `fw pause resolve`.
    paused_dispatches = _load_paused_for_task(task_id)

    # Optional flash banner forwarded from POST handler (?resolved=<short_id>).
    resolved_flash = request.args.get("resolved") or ""
    resolve_error = request.args.get("resolve_error") or ""

    return render_template(
        "review.html",
        task_id=task_id,
        task_name=fm.get("name", ""),
        task_status=fm.get("status", ""),
        task_owner=fm.get("owner", ""),
        workflow_type=fm.get("workflow_type", ""),
        human_acs=human_acs,
        checked_count=checked_count,
        total_count=total_count,
        all_checked=all_checked,
        verdict=rec["verdict"],
        state=rec_state,
        rec_rationale_html=rec_rationale_html,
        rec_evidence_html=rec_evidence_html,
        rec_rationale_text=rec["rationale"],
        rec_complete=rec_complete,
        decision_recorded=decision_recorded,
        decision_value=decision_state,
        pending_tier0=active_tier0,
        artifacts=artifacts,
        reviewer=reviewer,
        paused_dispatches=paused_dispatches,
        resolved_flash=resolved_flash,
        resolve_error=resolve_error,
    )


@bp.route("/review/<task_id>/pause/<dispatch_id>/resolve", methods=["POST"])
def review_pause_resolve(task_id, dispatch_id):
    """T-1810: web parity for `fw pause resolve`.

    Form fields:
      answer  (required, non-empty)

    Success: redirects back to `/review/<task_id>?resolved=<new_short_id>`.
    Error:   redirects back to `/review/<task_id>?resolve_error=<message>` with
             a 4xx status code so htmx error handlers can surface a toast if
             the form is ever fetched via XHR. PauseResolveError → 400, anything
             else → 500.
    """
    if not re.match(r"^T-\d{3,}$", task_id):
        abort(404)
    answer = (request.form.get("answer") or "").strip()
    if not answer:
        return redirect(
            url_for("review.review", task_id=task_id, resolve_error="answer is required")
        ), 303

    from pause_resolve import PauseResolveError, resolve_pause

    try:
        envelope, _row = resolve_pause(
            dispatch_id, answer, project_root=PROJECT_ROOT
        )
    except PauseResolveError as e:
        return redirect(
            url_for("review.review", task_id=task_id, resolve_error=str(e))
        ), 303

    new_did = (envelope.get("dispatch_id") or "")[:10] + "..."
    return redirect(
        url_for("review.review", task_id=task_id, resolved=new_did)
    ), 303


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

    # T-1575: htmx polling fragment must also pre-fill the rationale textarea —
    # otherwise the 5-second poll wipes the user's not-yet-submitted rationale OR
    # replaces the pre-filled one with an empty box.
    from web.shared import extract_recommendation
    rec = extract_recommendation(body)

    # T-1575: don't re-render the decide form after a decision was recorded.
    # The page polls /review/<id>/acs every 5s; without this guard, the success
    # message ("Decision recorded — GO") flashes for 5s then gets wiped by the
    # poll re-rendering the form. Detect recorded decisions and surface them.
    from web.blueprints.inception import _extract_decision
    decision_state = _extract_decision(body)
    decision_recorded = decision_state.lower() not in ("pending", "")

    # T-2081 / T-2082 (L-441 sibling of T-1575): the same poll wipes the Complete
    # button's POST-swap response on non-inception build tasks. The template falls
    # through to the Complete-button branch whenever all_checked + total_count > 0
    # + workflow_type != 'inception', regardless of completion status. Empirical:
    # GET /review/T-2079/acs (T-2079 in completed/ with status: work-completed)
    # returned the Complete button. This guard short-circuits the branch so the
    # poll renders a "✓ Task completed" panel instead.
    status = (fm.get("status") or "").strip().lower()
    task_completed = status in ("work-completed", "completed")

    return render_template(
        "_review_acs.html",
        task_id=task_id,
        workflow_type=fm.get("workflow_type", ""),
        human_acs=human_acs,
        checked_count=checked_count,
        total_count=total_count,
        all_checked=all_checked,
        verdict=rec["verdict"],
        rec_rationale_text=rec["rationale"],
        decision_recorded=decision_recorded,
        decision_value=decision_state,
        task_completed=task_completed,
    )
