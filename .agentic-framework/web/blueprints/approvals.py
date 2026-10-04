"""Approvals blueprint — Unified approval surface (T-611, T-639).

Shows four urgency-ordered sections:
  A. Tier 0 approvals (agent blocked)
  B. Pending GO/NO-GO inception decisions
  C. Paused dispatches (T-1808 / dispatch-safety slice 4)
  D. Tasks with unchecked Human ACs
"""

import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint, request

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page, render_markdown_safe, parse_frontmatter, task_id_sort_key, get_all_task_metadata, extract_recommendation_verdict, extract_recommendation_state, extract_reviewer_verdict, count_unchecked_human_acs, needs_human_review, mtime_cached_get, has_unchecked_review_ac, request_task_metadata, is_ready_for_batch_completion

# T-1808: paused-dispatch surface — needs lib/ on the path so the helper imports cleanly.
# T-2645 (832 G-004 sibling): lib/ is FRAMEWORK-owned — PROJECT_ROOT resolution broke
# split-root consumers (masked here by the try/except fallback, feature silently dead).
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))
try:
    from dispatch_pause import list_paused_dispatches, format_age, truncate as _trunc_q
except Exception:  # pragma: no cover - fallback for consumer projects without lib/
    def list_paused_dispatches(_=None):
        return []
    def format_age(_):
        return "?"
    def _trunc_q(s, w):
        return s

bp = Blueprint("approvals", __name__)

APPROVALS_DIR = PROJECT_ROOT / ".context" / "approvals"
APPROVAL_FILE = PROJECT_ROOT / ".context" / "working" / ".tier0-approval"

# T-3200: the continuous-run brake. Resolution MIRRORS agents/context/stop-driver.sh:60
#   HALT_FILE="${FW_CONTINUOUS_HALT:-${WORKING_DIR}/.continuous-halt}"
# and must stay mirrored: a button that writes a path the driver does not read is
# worse than no button, because it reports success while the loop keeps running.
#
# Deliberately the SAME file, not a parallel mechanism. The driver checks it as
# Brake 1 ahead of every other vote, and its trustworthiness comes from being a
# file written outside the model's mediation. Watchtower is a second WRITER of
# that file, never a second brake — so there is no new precedence question for
# stop-driver.sh to resolve.
def _halt_file() -> Path:
    override = os.environ.get("FW_CONTINUOUS_HALT", "").strip()
    if override:
        return Path(override)
    return PROJECT_ROOT / ".context" / "working" / ".continuous-halt"


def _halt_state() -> dict:
    """Current brake state, for the /approvals card."""
    hf = _halt_file()
    halted = hf.exists()
    since = None
    if halted:
        try:
            since = datetime.fromtimestamp(hf.stat().st_mtime, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        except OSError:
            since = None
    return {"halted": halted, "path": str(hf), "since": since}

# Approvals older than this are considered expired (seconds)
EXPIRY_SECONDS = 3600  # 1 hour

# T-2102: per-file body cache keyed on path -> (mtime_ns, body).
# /approvals scans ~170 active task bodies per request through three hot loaders
# (_load_pending_go_decisions, _load_pending_human_acs, _load_close_ready_arcs).
# Profile (S-2026-0529): disk read all = 9ms; parse_frontmatter all = 571ms;
# section extracts on already-parsed body = 48-85ms. The yaml.safe_load on the
# frontmatter chunk is the dominant cost. Caching the body (after frontmatter
# strip) keyed by (path, mtime_ns) eliminates the repeat yaml parse and brings
# /approvals from 14.8s → <3s on warm cache. Memory cost: ~170 body strings
# (a few MB) in the long-running Flask process — amortises across requests.
# Same shape as T-1954 _FM_CACHE in web/blueprints/bvp.py.
_BODY_CACHE: dict[str, tuple[int, str]] = {}


def _parse_body_from_path(p: Path) -> str:
    """Read file, strip frontmatter, return body. Empty string on read failure."""
    try:
        content = p.read_text()
    except OSError:
        return ""
    _, body = parse_frontmatter(content)
    return body


def _get_body_cached(path: Path | str) -> str:
    """Return task body (after frontmatter strip), mtime-invalidated.

    Returns "" on any read or parse failure (matches existing callers'
    behaviour of skipping the task on continue).

    T-2109: migrated to shared.mtime_cached_get; semantics unchanged.
    """
    return mtime_cached_get(Path(path), _parse_body_from_path, _BODY_CACHE, default="")


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


# T-3078: how a Tier 0 origin is described to the operator. Keyed by the `kind`
# derived in agents/context/check-tier0.sh; anything unrecognised — including a
# card written before provenance existed — falls through to "unknown origin"
# rather than being presented as an agent request.
_ORIGIN_LABELS = {
    "agent": ("agent request", "agent requests"),
    "test": ("test artefact", "test artefacts"),
    "human": ("shell command", "shell commands"),
    "unknown": ("unknown origin", "unknown origin"),
}


def _tier0_origin_summary(approvals) -> str:
    """Describe what is actually pending, instead of asserting an agent asked.

    The section subtitle used to read "Agent blocked — requires your decision"
    unconditionally. That was a literal in the template, and it was false for
    every card T-3077's governance suite filed against the live queue — the
    operator saw `rm -rf /` attributed to a blocked agent that never existed.
    Returns "" when nothing is pending, so the caller can omit the clause.
    """
    counts: dict[str, int] = {}
    for a in approvals:
        if a.get("status") != "pending":
            continue
        origin = a.get("origin")
        kind = (origin or {}).get("kind") or "unknown"
        if kind not in _ORIGIN_LABELS:
            kind = "unknown"
        counts[kind] = counts.get(kind, 0) + 1
    if not counts:
        return ""
    parts = []
    for kind in ("agent", "test", "human", "unknown"):
        n = counts.get(kind)
        if not n:
            continue
        singular, plural = _ORIGIN_LABELS[kind]
        parts.append(f"{n} {singular if n == 1 else plural}")
    return ", ".join(parts)


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


# T-1415 (T-1388 B5 / F2): Count inline `- A\d+:` assumption bullets in task body.
# Most inception tasks list assumptions inline under ## Assumptions rather than
# registering via `fw assumption add`, so the /approvals badge read "0" even
# when the body clearly showed several. Fall back to the body count and mark
# source=body so the template can render the provenance.
_INLINE_ASSUMPTION_RE = re.compile(r"^- A\d+:", re.MULTILINE)


def _count_body_assumptions(body: str) -> int:
    """Count inline `- A\\d+:` assumption bullets under the ## Assumptions section."""
    from web.blueprints.inception import _extract_section

    section = _extract_section(body, "Assumptions")
    if not section:
        return 0
    return len(_INLINE_ASSUMPTION_RE.findall(section))


def _task_meta():
    """Task frontmatter rows, fetched once per request (T-3600).

    Passes this module's `get_all_task_metadata` binding so tests that
    substitute it here keep working.
    """
    return request_task_metadata(get_all_task_metadata)


def _active_task_fms() -> dict:
    """{task_id: frontmatter} for tasks in .tasks/active/, from the shared cache."""
    out = {}
    for fm in _task_meta():
        tid = fm.get("id")
        if tid and fm.get("_location") == "active":
            out.setdefault(tid, fm)
    return out


def _load_pending_go_decisions():
    """Scan active inception tasks where decision is still pending.

    Returns list of dicts with: task_id, name, status, problem_excerpt,
    assumption_counts, artifacts.
    """
    from web.blueprints.inception import _extract_decision, _extract_section, _load_assumptions

    assumptions = _load_assumptions()
    results = []

    # T-1244: Use shared task metadata cache to filter to active+inception tasks
    # before reading bodies. Avoids re-globbing 100+ active tasks per request.
    candidates = [
        fm for fm in _task_meta()
        if fm.get("_location") == "active" and fm.get("workflow_type") == "inception"
    ]
    candidates.sort(key=lambda fm: task_id_sort_key(fm.get("_path", "")))

    for fm in candidates:
        path = fm.get("_path")
        if not path:
            continue
        # T-2102: use mtime-keyed body cache (was: re-read + parse_frontmatter per request).
        body = _get_body_cached(path)
        if not body:
            continue
        if _extract_decision(body) != "pending":
            continue

        # T-1123 / T-1570 (F4): Only drop captured/unexplored inceptions when the
        # Recommendation is missing. Started-work inceptions without a Recommendation
        # are exactly the cases where the human needs to see "agent is stuck — write
        # recommendation or escalate" — keep them, the template fallback handles
        # rendering (T-1214). Aligns display gate with the completion gate (T-1529).
        rec_section = _extract_section(body, "Recommendation")
        rec_substantive = bool(rec_section and len(rec_section.strip()) >= 20)
        if not rec_substantive and fm.get("status", "") != "started-work":
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
        if rec_raw and len(rec_raw) > 10:
            rec_display = rec_raw.strip()
        # T-1537: use canonical helper for the verdict so inception + partial-complete
        # sections share extraction logic. Returns "GO"/"DEFER"/"NO-GO"/"?".
        verdict = extract_recommendation_verdict(body)
        # rec_decision retained for backward compat with the existing collapsible
        # summary (T-1119 contract); blank string preserved when no recommendation.
        rec_decision = verdict if verdict in ("GO", "DEFER", "NO-GO") else ""

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

        # T-1415 (T-1388 B5 / F2): Fall back to body-inline assumptions when none registered.
        if linked:
            assumption_counts = {
                "total": len(linked),
                "validated": sum(1 for a in linked if a.get("status") == "validated"),
                "source": "ledger",
            }
        else:
            body_count = _count_body_assumptions(body)
            assumption_counts = {
                "total": body_count,
                "validated": 0,
                "source": "body" if body_count else "ledger",
            }

        # T-1569 / F3: surface reviewer agent's mechanical verdict at decision time.
        reviewer = extract_reviewer_verdict(body)

        # T-100188: compact evidence badge from the claims-validator verdict
        # (T-100187). None overall = no badge rendered.
        from web.shared import extract_recommendation_claims_verdict
        claims = extract_recommendation_claims_verdict(body)

        results.append({
            "task_id": task_id,
            "name": fm.get("name", ""),
            "status": fm.get("status", ""),
            "problem_excerpt": problem_excerpt,
            "problem_full": problem,
            "assumption_counts": assumption_counts,
            "artifacts": artifacts,
            "rationale_hint": rationale_hint,
            "recommendation": rec_display,
            # T-3587: rendered through the shared pipeline so Evidence refs are
            # links (or visibly dead) here too, not raw Markdown in a pre-wrap div.
            "recommendation_html": render_markdown_safe(rec_display),
            "rec_decision": rec_decision,
            "verdict": verdict,
            "go_nogo_criteria": go_nogo_raw,
            "reviewer": reviewer,
            "claims": claims,
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

    results = []
    now = time.time()

    # T-1244: Pull active-task frontmatter from shared cache instead of
    # re-globbing per request. Body still required for AC parse.
    candidates = [
        fm for fm in _task_meta()
        if fm.get("_location") == "active"
    ]
    candidates.sort(key=lambda fm: task_id_sort_key(fm.get("_path", "")))

    for fm in candidates:
        path = fm.get("_path")
        if not path:
            continue
        # T-2102: use mtime-keyed body cache (was: re-read + parse_frontmatter per request).
        body = _get_body_cached(path)
        if not body:
            continue

        # T-2075 (T-2064 GO): canonical predicate — shared with `fw review-queue`.
        # Gate FIRST on the cheap predicate, then run the full per-AC parse for
        # display detail. Previously this used `_parse_acceptance_criteria` →
        # filter on `section == "human"` → filter on `not checked` — which
        # drifted from the CLI's inline regex on tasks with HTML-commented
        # template stubs. Centralising the predicate kills the drift class.
        if not needs_human_review(body):
            continue

        # DISPLAY ONLY (T-3590): the per-criterion detail rendered in the card.
        # No decision on this page reads it — `_parse_acceptance_criteria` stops
        # at an intervening `## ` heading and so can see zero Human criteria on a
        # task that has an unticked one (T-2200/T-2202). Admission, sort priority
        # and batch readiness use the web.shared predicates instead.
        all_acs = _parse_acceptance_criteria(body)
        human_acs = [ac for ac in all_acs if ac.get("section") == "human"]

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
        has_review = has_unchecked_review_ac(body)  # T-3590: canonical scoping
        sort_priority = 0 if has_review else (1 if is_stale else 2)

        # T-1531: extract agent recommendation verdict (GO/DEFER/NO-GO/?)
        # T-1533: helper now lives in web.shared (third call site arrived)
        # T-1576: also expose `state` so template can distinguish NO-REC
        # (agent owes a recommendation) from '?' (verdict unparseable).
        verdict = extract_recommendation_verdict(body)
        state = extract_recommendation_state(body)
        # T-1569 / F3: parallel surface for the reviewer's mechanical scan.
        reviewer = extract_reviewer_verdict(body)

        results.append({
            "task_id": fm.get("id", ""),
            "name": fm.get("name", ""),
            "status": fm.get("status", ""),
            "human_acs": human_acs,
            # T-3590: canonical count (every `### Human` block) — the badge and the
            # card's Complete button read this, never the display list above.
            "unchecked_count": count_unchecked_human_acs(body),
            "age_days": age_days,
            "is_stale": is_stale,
            "sort_priority": sort_priority,
            "verdict": verdict,
            "state": state,
            "reviewer": reviewer,
        })

    # Sort: priority ascending, then age descending (oldest first within group)
    results.sort(key=lambda t: (t["sort_priority"], -t["age_days"]))
    return results


_TASK_ID_RE = re.compile(r"^T-\d+$")


def _read_active_task(task_id: str):
    """(frontmatter, body) for an active task, read fresh from disk; None if the
    id is malformed or no active task carries it. T-3590: complete_batch judges
    readiness at POST time on this, never on the list the page rendered."""
    if not _TASK_ID_RE.match(task_id or ""):
        return None
    for p in sorted((PROJECT_ROOT / ".tasks" / "active").glob(f"{task_id}-*.md")):
        try:
            fm, body = parse_frontmatter(p.read_text())
        except OSError:
            continue
        if str(fm.get("id", "")) == task_id:
            return fm, body
    return None


def _load_batch_ready_tasks():
    """Active tasks `is_ready_for_batch_completion` accepts (T-3590).

    Returns list of {task_id, name}, id-sorted. The batch form posts exactly
    these ids; complete_batch re-checks each against the same predicate.
    """
    out = []
    candidates = [fm for fm in _task_meta() if fm.get("_location") == "active"]
    candidates.sort(key=lambda fm: task_id_sort_key(fm.get("_path", "")))
    for fm in candidates:
        path = fm.get("_path")
        if not path:
            continue
        body = _get_body_cached(path)
        if is_ready_for_batch_completion(fm.get("status", ""), body):
            out.append({"task_id": fm.get("id", ""), "name": fm.get("name", "")})
    return out


def _count_deferred_inceptions():
    """Count active inceptions with a recorded DEFER decision (T-1518).

    DEFER'd inceptions are excluded from /approvals (decision != pending) but
    remain visible on /inception?decision=defer. This count powers an exit-ramp
    hint when /approvals has no pending decisions.
    """
    count = 0
    for fm in _task_meta():
        if fm.get("_location") != "active" or fm.get("workflow_type") != "inception":
            continue
        path = fm.get("_path")
        if not path:
            continue
        try:
            body = Path(path).read_text()
        except OSError:
            continue
        # Match the canonical block emitted by do_inception_decide
        if re.search(r"^\*\*Decision\*\*:\s*DEFER\b", body, re.M):
            count += 1
    return count


def _load_paused_dispatches():
    """T-1808: load paused dispatches and decorate for template rendering."""
    rows = list_paused_dispatches(PROJECT_ROOT)
    out = []
    for r in rows:
        out.append({
            **r,
            "dispatch_id_short": (r["dispatch_id"][:8] + "..") if len(r["dispatch_id"]) > 8 else r["dispatch_id"],
            "age_label": format_age(r["age_seconds"]),
            "question_short": _trunc_q(r["question"] or "(no question)", 120),
        })
    return out


# ---------------------------------------------------------------------------
# T-3782: peer messages waiting for a recipient (lib/sidecar/waiting.py).
#
# Read through `fw sidecar waiting --json` in a subprocess (the sidecar modules
# resolve the project from PROJECT_ROOT in their environment; mutating this
# process's environment under threaded Flask is not safe). Cached on the
# mtimes of every ledger the listing reads, plus a one-minute bucket because
# an item can become listed by age alone. A failure is shown as an error card,
# never as an empty list: "could not look" must not read as "nothing waiting".
# ---------------------------------------------------------------------------

_WAITING_CACHE: dict = {}
_SIDECAR_ID_RE = re.compile(r"[A-Za-z0-9_:-]{1,128}")


def _waiting_signature():
    sc = PROJECT_ROOT / ".context" / "sidecar"
    paths = [sc / "receiver" / "events.jsonl", sc / "receiver" / "messages",
             sc / "direct-ack.jsonl", sc / "receipts.jsonl", sc / "receipts-sent.jsonl",
             sc / "outbox", sc / "waiting", sc / "waiting" / "closures.jsonl",
             sc / "waiting" / "escalations.jsonl", sc / "waiting" / "recover.jsonl"]
    sig = []
    for p in paths:
        try:
            sig.append(p.stat().st_mtime_ns)
        except OSError:
            sig.append(None)
    return (tuple(sig), int(time.time() // 60))


def _sidecar_cli_env() -> dict:
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    env["PROJECT_ROOT"] = str(PROJECT_ROOT)
    env["FRAMEWORK_ROOT"] = str(FRAMEWORK_ROOT)
    return env


def _load_waiting_messages() -> dict:
    import json
    import subprocess

    sig = _waiting_signature()
    if _WAITING_CACHE.get("sig") == sig:
        return _WAITING_CACHE["value"]
    value = {"items": [], "error": None, "warn_hours": None}
    if not (PROJECT_ROOT / ".context" / "sidecar").is_dir():
        _WAITING_CACHE.update(sig=sig, value=value)
        return value   # no sidecar in this project: genuinely nothing held
    try:
        proc = subprocess.run(
            [sys.executable, str(FRAMEWORK_ROOT / "lib" / "sidecar_cli.py"), "waiting", "--json"],
            capture_output=True, text=True, timeout=20, cwd=str(PROJECT_ROOT),
            env=_sidecar_cli_env())
        if proc.returncode != 0:
            raise RuntimeError(f"exit {proc.returncode}: {(proc.stderr or '').strip()[-300:]}")
        data = json.loads(proc.stdout)
        items = []
        for it in data.get("items", []):
            hours = (it.get("age_s") or 0) / 3600
            it["age_label"] = f"{hours:.1f} h" if hours >= 1 else f"{int((it.get('age_s') or 0) // 60)} min"
            items.append(it)
        value = {"items": items, "error": None, "warn_hours": data.get("warn_hours")}
    except Exception as e:
        from web.shared import operator_facing_stderr
        value = {"items": [], "error": operator_facing_stderr(str(e))[:300] or type(e).__name__,
                 "warn_hours": None}
        _WAITING_CACHE.clear()   # retry on the next render rather than caching a failure
        return value
    _WAITING_CACHE.update(sig=sig, value=value)
    return value


def _sidecar_operator_action(verb: str, msg_id: str, reason: str = "") -> tuple[bool, str]:
    import json
    import subprocess

    argv = [sys.executable, str(FRAMEWORK_ROOT / "lib" / "sidecar_cli.py"), verb, msg_id,
            "--from-watchtower", "--json"]
    if verb == "drop":
        argv += ["--reason", reason]
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=60,
                              cwd=str(PROJECT_ROOT), env=_sidecar_cli_env())
    except (OSError, subprocess.SubprocessError) as e:
        return False, str(e)[:300]
    _WAITING_CACHE.clear()
    if proc.returncode != 0:
        from web.shared import operator_facing_stderr
        return False, operator_facing_stderr((proc.stderr or proc.stdout or "")[-1500:])[:400] \
            or f"exit {proc.returncode}"
    try:
        return True, json.loads(proc.stdout)
    except json.JSONDecodeError:
        return True, {}


@bp.route("/api/sidecar/recover", methods=["POST"])
def sidecar_recover():
    """T-3782: the operator's Recover button — start this project's agent with
    the waiting message (fw sidecar recover --from-watchtower). CSRF-checked
    like every mutating route (web/app.py before_request)."""
    from markupsafe import escape

    msg_id = (request.form.get("msg_id") or "").strip()
    if not _SIDECAR_ID_RE.fullmatch(msg_id):
        return '<p style="color:var(--pico-del-color);">Refused: invalid message id.</p>', 400
    ok, out = _sidecar_operator_action("recover", msg_id)
    if not ok:
        return f'<p style="color:var(--pico-del-color);">Recover refused: {escape(out)}</p>'
    return (f'<p style="color:var(--pico-ins-color);">Started <code>{escape(out.get("termlink_session", "?"))}</code> '
            f'for message <code>{escape(msg_id[:12])}</code>. Watch: '
            f'<code>termlink attach {escape(out.get("termlink_session", "?"))}</code>. '
            'It stays listed until the new session shows the message (HANDED_OVER) or answers it.</p>')


@bp.route("/api/sidecar/drop", methods=["POST"])
def sidecar_drop():
    """T-3782: the operator's Drop button — close a waiting message with a reason;
    the sender is told."""
    from markupsafe import escape

    msg_id = (request.form.get("msg_id") or "").strip()
    reason = (request.form.get("reason") or "").strip()
    if not _SIDECAR_ID_RE.fullmatch(msg_id):
        return '<p style="color:var(--pico-del-color);">Refused: invalid message id.</p>', 400
    if not reason:
        return '<p style="color:var(--pico-del-color);">Refused: a reason is required to drop a message.</p>'
    ok, out = _sidecar_operator_action("drop", msg_id, reason)
    if not ok:
        return f'<p style="color:var(--pico-del-color);">Drop refused: {escape(out)}</p>'
    told = ""
    if out.get("side") == "inbound":
        told = " Sender told." if out.get("sender_told") else f" Sender NOT told: {escape(str(out.get('sender_told_via')))}"
    return (f'<p style="color:var(--pico-ins-color);">Dropped <code>{escape(msg_id[:12])}</code>: '
            f'{escape(reason)}.{told}</p>')


def _load_close_ready_arcs(threshold: float = 0.80) -> list[dict]:
    """T-1961: arcs ready for closure review on /approvals.

    Filters: status=='in-progress' AND completion_ratio >= threshold AND
    anchor-task `## Recommendation` block present. Returns one dict per
    qualifying arc with the fields the template needs to render a row.

    T-2986: the third condition no longer drops the arc silently. An arc that
    meets the threshold but whose anchor carries no `## Recommendation` is
    returned with ``blocked_reason`` set, and the template renders it without a
    verdict badge. Close-ready rows are unchanged and carry ``blocked_reason``
    as an empty string.

    The motivating instance was arc-015 (onboarding-shape-detection): 2/2
    complete, demo evidence captured and verified under T-2910, and absent from
    the queue because its anchor closed without a Recommendation block. A bare
    ``continue`` made "finished but blocked" look exactly like "not ready yet",
    which is the one state an approvals queue exists to distinguish. Widening by
    this single condition is deliberate — the queue stays bounded by the
    threshold (T-2038 unbounded-list class).
    """
    import glob
    import yaml as _yaml
    from web.blueprints.arcs import (
        _resolve_constituents,
        _completion_stats,
        _anchor_recommendation,
    )
    out: list[dict] = []
    for f in sorted(glob.glob(str(PROJECT_ROOT / ".context" / "arcs" / "*.yaml"))):
        try:
            arc = _yaml.safe_load(open(f).read()) or {}
        except (OSError, _yaml.YAMLError):
            continue
        if str(arc.get("status") or "").strip() != "in-progress":
            continue
        constituents = _resolve_constituents(arc)
        stats = _completion_stats(constituents)

        # T-3552 (T-3548 Slice A): surface on quadrant exhaustion, not on a
        # completion ratio. `completed / total` describes the LIST; closure is a
        # claim about what is LEFT. Measured on this corpus at the swap: the 80%
        # ratio surfaced 8 arcs, 6 of which still had high-value open members —
        # orchestrator-rethink read "close-ready" at 85% with 18 open members, 8
        # of them Q1/Q2.
        #
        # `threshold` is kept in the signature and still applied as a CEILING on
        # nothing — it is retained only so existing callers and tests that pass it
        # do not break. The ratio itself is still reported in the row, because it
        # is useful information; it is simply no longer the predicate.
        legs = _arc_readiness_legs(arc, constituents)
        if legs is not None and not (legs["l1"]["passed"] and legs["l2"]["passed"]):
            continue
        if legs is None and stats["ratio"] < threshold:
            # Readiness could not be computed (helper unavailable). Fall back to
            # the old ratio rather than surfacing everything or nothing — a
            # degraded queue is recoverable, a silently empty one is not.
            continue

        rec = _anchor_recommendation(arc)
        # T-3843: expected_task is the arc's close_task when set, else its anchor.
        anchor_id = (rec.get("anchor_id", "") or rec.get("expected_task", "")
                     or str(arc.get("anchor_task") or "").strip())
        _rec_role = "close-out task" if str(arc.get("close_task") or "").strip() else "anchor"
        blocked_reason = ""
        if not rec.get("present"):
            blocked_reason = (
                f"{_rec_role} {anchor_id or '(none set)'} has no Recommendation section — the agent "
                f"advisory that closure review reads. Until it is written the arc cannot be "
                f"judged, only counted."
            ) if anchor_id else (
                "no anchor_task is set on the arc, so there is nowhere for the closure "
                "advisory to live."
            )
        out.append({
            "slug": str(arc.get("slug") or "").strip(),
            "id": str(arc.get("id") or "").strip(),
            "name": str(arc.get("name") or arc.get("slug") or ""),
            "anchor": anchor_id,
            # Blocked rows carry no verdict: showing GO/CLOSE here would invite a close
            # on evidence nobody has written down yet.
            "verdict": rec.get("verdict", "?") if not blocked_reason else "",
            "blocked_reason": blocked_reason,
            "completion_ratio": stats["ratio"],
            "completed": stats["completed"],
            "total": stats["total"],
            "headline_mechanic": str(arc.get("headline_mechanic") or ""),
            # T-3552: the legs that produced this row. Carried so a surface can
            # say WHY an arc is here without recomputing and risking a second,
            # disagreeing answer.
            "readiness": legs,
        })
    return out


# Cached across requests: the medians are a corpus-wide property, and recomputing
# them per arc would re-read every active task 18 times on one page load.
_READINESS_MEDIANS: dict = {}


def _arc_readiness_legs(arc: dict, constituents) -> dict | None:
    """L1/L2/L3 for one arc, or None when readiness cannot be computed.

    Returning None rather than a failed verdict is deliberate: "the predicate
    could not run" and "the predicate says no" are different facts, and the
    caller degrades to the old ratio on the first while honouring the second.
    Collapsing them would make a broken import look like an arc that is not
    ready — the same false-negative class this task removes from the ratio.
    """
    import sys as _sys

    lib_dir = str(Path(__file__).resolve().parents[2] / "lib")
    if lib_dir not in _sys.path:
        _sys.path.insert(0, lib_dir)
    try:
        import arc_close_readiness as _acr
        from web.blueprints.arcs import _anchor_recommendation as _anchor
    except Exception:
        return None

    try:
        # T-3600: frontmatter comes from the shared task cache. Both the medians
        # and the per-member reads used to re-parse the files with pure-Python
        # yaml.safe_load — 9.5s cold for the medians, 3.8s on every build for
        # the members.
        active = _active_task_fms()
        if not _READINESS_MEDIANS:
            _READINESS_MEDIANS.update(
                _acr.corpus_medians(PROJECT_ROOT, open_fms=list(active.values())))

        open_members: list[tuple[str, dict]] = []
        for c in constituents or []:
            # A constituent still in active/ is open work — including
            # partial-complete, which is most of them. See the module docstring
            # in lib/arc_close_readiness.py for why that population is right.
            tid = c.get("id") if isinstance(c, dict) else str(c)
            if not tid or tid not in active:
                continue
            open_members.append((tid, active[tid]))

        rec = _anchor(arc) or {}
        legs = _acr.evaluate(
            open_members,
            _READINESS_MEDIANS,
            {
                "present": bool(rec.get("present")),
                "verdict": rec.get("verdict", ""),
                "has_rationale": True,  # `_anchor_recommendation` has no rationale probe
            },
        )

        # T-3553: L4 costs a subprocess, so it runs only for arcs that already
        # cleared L1+L2 — the set the operator is actually being offered. Adding
        # it for all 18 in-progress arcs would put 18 `fw arc demo-check` calls on
        # every /approvals render to answer a question about 2 of them.
        if legs["l1"]["passed"] and legs["l2"]["passed"]:
            demo = _arc_demo_state(arc)
            legs = _acr.evaluate(
                open_members,
                _READINESS_MEDIANS,
                {
                    "present": bool(rec.get("present")),
                    "verdict": rec.get("verdict", ""),
                    "has_rationale": True,
                },
                demo=demo,
            )
        return legs
    except Exception:
        return None


def _arc_demo_state(arc: dict) -> dict:
    """Run `fw arc demo-check` for one arc. T-3553.

    Shells out on purpose. `_arc_validate_demo_path` (lib/arc.sh) already encodes
    every rule — existence, minimum size, extension allowlist, traceability to the
    arc or one of its member tasks — and re-expressing those in python would be a
    second opinion about the same question. The exit code carries the three states
    a boolean would flatten.
    """
    import subprocess

    slug = str(arc.get("slug") or arc.get("id") or "").strip()
    if not slug:
        return {"state": "absent", "detail": "arc has no slug or id"}
    fw = Path(__file__).resolve().parents[2] / "bin" / "fw"
    try:
        p = subprocess.run([str(fw), "arc", "demo-check", slug],
                           capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        # Could not ask. Not the same as "no demo" — say so.
        return {"state": "indeterminate", "detail": "demo-check could not be run"}

    out = ((p.stdout or "") + (p.stderr or "")).strip().splitlines()
    first = out[0] if out else ""
    if p.returncode == 0:
        return {"state": "valid", "detail": first.replace("valid: ", "", 1)}
    if p.returncode == 2:
        return {"state": "indeterminate", "detail": first}
    if first.startswith("absent:"):
        return {"state": "absent", "detail": first}
    return {"state": "invalid", "detail": first}


def _load_decided_unclosed():
    """T-3175: inceptions the operator has DECIDED that are still open.

    Sibling of `_load_pending_go_decisions` and its exact complement: that one
    keeps `decision == "pending"`, this one keeps the concluding decisions. A
    task leaving the first section used to arrive nowhere, so the single
    remaining action — the operator closing it — was on no surface at all.

    Predicate lives in `lib/decided_unclosed.py` so `fw review-queue` can import
    the same one. Two surfaces disagreeing about what is outstanding is how this
    class of gap survives; a second copy here would guarantee it.
    """
    import sys

    lib_dir = str(Path(__file__).resolve().parents[2] / "lib")
    if lib_dir not in sys.path:
        sys.path.insert(0, lib_dir)
    try:
        import decided_unclosed
    except Exception:
        # Never take the page down for a missing helper — an approvals page that
        # 500s hides EVERY section, which is worse than the gap being closed.
        return []

    candidates = [
        fm for fm in _task_meta()
        if fm.get("_location") == "active" and fm.get("workflow_type") == "inception"
    ]
    try:
        return decided_unclosed.scan(candidates, _get_body_cached)
    except Exception:
        return []


def _load_stale_keystones():
    """T-3694 (T-3691 item 5): captured keystones older than 3 days.

    A captured task that owns an unbuilt design-register row, or is named as an
    arc's keystone / slice 1, and has stayed captured for more than 3 days. The
    predicate is lib/design_register.py, the same one `fw audit` WARNs from, so
    the page and the audit cannot disagree. T-3397/T-3561 sat captured while the
    sidecar arc read healthy; this puts that on the operator's surface.
    """
    lib_dir = str(Path(__file__).resolve().parents[2] / "lib")
    if lib_dir not in sys.path:
        sys.path.insert(0, lib_dir)
    try:
        import design_register
        return design_register.stale_keystones(PROJECT_ROOT, days=3.0)
    except Exception:
        # Never take the page down for a helper — a 500 hides every section.
        return []


def _approval_counts(pending_tier0, pending_go, ac_task_count, paused_dispatches,
                     arcs_close_ready, bvp_proposals, decided_unclosed,
                     waiting_messages=()) -> dict:
    """The badge arithmetic, shared by the page and the dashboard tile (T-3600).

    One function so the two cannot drift. A ripe DEFER revisit is deliberately
    not counted. T-3175: a decided-but-unclosed inception is one outstanding
    operator action, so it counts toward the badge like every other section.
    Omitting it from the total was how the queue read "complete" while three of
    these sat open.
    """
    tier0_count = sum(1 for a in pending_tier0 if a.get("status") == "pending")
    go_count = len(pending_go)
    # T-3782: a peer message waiting for a recipient is an outstanding operator
    # action (recover or drop) like every other section.
    total = (tier0_count + go_count + ac_task_count + len(paused_dispatches)
             + len(arcs_close_ready) + len(bvp_proposals) + len(decided_unclosed)
             + len(waiting_messages))
    return {"total_count": total, "tier0_count": tier0_count,
            "go_count": go_count, "ac_task_count": ac_task_count}


def _count_pending_human_ac_tasks() -> int:
    """How many cards `_load_pending_human_acs()` would render, without rendering them.

    Same candidates and the same admission predicate; skips the per-criterion
    parse and markdown render, which is display-only (T-3600).
    """
    count = 0
    for fm in _task_meta():
        if fm.get("_location") != "active" or not fm.get("_path"):
            continue
        body = _get_body_cached(fm["_path"])
        if body and needs_human_review(body):
            count += 1
    return count


def approval_summary() -> dict:
    """Counts-only view of /approvals for the dashboard tile (T-3600)."""
    from web.blueprints.bvp import _load_proposals

    return _approval_counts(
        _load_pending_approvals(),
        _load_pending_go_decisions(),
        _count_pending_human_ac_tasks(),
        _load_paused_dispatches(),
        _load_close_ready_arcs(),
        _load_proposals(),
        _load_decided_unclosed(),
        _load_waiting_messages()["items"],
    )


def _build_approvals_context(expand_overflow: bool = False):
    """Build template context for approvals page.

    T-2406: expand_overflow controls whether the Verifications overflow
    <details class="ac-overflow"> renders open. Default closed preserves the
    T-2103 page-height cap (T-2038 unbounded-list class prevention); operator
    opts in via ?expand=verifications when their workflow needs the full list
    (e.g. arc-003 closure burst walking all partial-completes).
    """
    pending_tier0 = _load_pending_approvals()
    resolved_tier0 = _load_resolved_approvals()
    pending_go = _load_pending_go_decisions()
    pending_acs = _load_pending_human_acs()
    decided_unclosed = _load_decided_unclosed()  # T-3175
    stale_keystones = _load_stale_keystones()  # T-3694
    deferred_count = _count_deferred_inceptions()
    paused_dispatches = _load_paused_dispatches()  # T-1808
    arcs_close_ready = _load_close_ready_arcs()  # T-1961
    # T-2335: BVP driver proposals pending the operator's Sovereign decision.
    # Same reader the /bvp page uses (T-2332); Approve/Reject proxy to its
    # /api/bvp/driver/* endpoints, so state machine + audit trail stay single.
    from web.blueprints.bvp import _load_proposals

    bvp_proposals = _load_proposals()
    waiting = _load_waiting_messages()  # T-3782

    counts = _approval_counts(pending_tier0, pending_go, len(pending_acs),
                              paused_dispatches, arcs_close_ready, bvp_proposals,
                              decided_unclosed, waiting["items"])
    tier0_count = counts["tier0_count"]
    tier0_origin_summary = _tier0_origin_summary(pending_tier0)  # T-3078
    go_count = counts["go_count"]
    ac_count = sum(t["unchecked_count"] for t in pending_acs)  # T-3590: canonical
    paused_count = len(paused_dispatches)  # T-1808
    arc_close_count = len(arcs_close_ready)  # T-1961
    bvp_proposal_count = len(bvp_proposals)  # T-2335
    decided_unclosed_count = len(decided_unclosed)
    total = counts["total_count"]

    # T-3590: tasks the batch button may close, by the ONE canonical predicate.
    # Disjoint from pending_acs by construction (admission requires an unchecked
    # Human criterion); the old count filtered pending_acs with a second parser
    # and so could only ever be non-zero when that parser was wrong.
    batch_ready = _load_batch_ready_tasks()
    ready_count = len(batch_ready)

    return dict(
        pending_tier0=pending_tier0,
        resolved_tier0=resolved_tier0,
        pending_go=pending_go,
        decided_unclosed=decided_unclosed,          # T-3175
        decided_unclosed_count=decided_unclosed_count,  # T-3175
        stale_keystones=stale_keystones,            # T-3694
        pending_acs=pending_acs,
        paused_dispatches=paused_dispatches,
        arcs_close_ready=arcs_close_ready,
        bvp_proposals=bvp_proposals,
        bvp_proposal_count=bvp_proposal_count,
        tier0_count=tier0_count,
        tier0_origin_summary=tier0_origin_summary,  # T-3078
        go_count=go_count,
        ac_count=ac_count,
        ac_task_count=len(pending_acs),
        paused_count=paused_count,
        arc_close_count=arc_close_count,
        total_count=total,
        active_count=tier0_count,
        ready_count=ready_count,
        batch_ready=batch_ready,                    # T-3590
        deferred_count=deferred_count,
        expand_overflow=expand_overflow,
        continuous=_halt_state(),          # T-3200
        waiting_messages=waiting["items"],  # T-3782
        waiting_error=waiting["error"],     # T-3782
        waiting_warn_hours=waiting["warn_hours"],
    )


def _read_expand_overflow():
    """T-2406: parse ?expand=verifications query param."""
    return (request.args.get("expand", "").strip().lower() == "verifications")


@bp.route("/approvals")
def approvals():
    ctx = _build_approvals_context(expand_overflow=_read_expand_overflow())
    return render_page("approvals.html", page_title="Approvals", **ctx)


@bp.route("/approvals/content")
def approvals_content():
    """htmx polling fragment — returns approvals content without page wrapper (T-669)."""
    from flask import render_template

    ctx = _build_approvals_context(expand_overflow=_read_expand_overflow())
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

    exec_result = None
    if decision == "approved":
        # Write the approval token that check-tier0.sh expects
        # Format: <command_hash> <unix_timestamp>
        APPROVAL_FILE.parent.mkdir(parents=True, exist_ok=True)
        APPROVAL_FILE.write_text(f"{command_hash} {int(time.time())}\n")

        # Self-consuming execution for idempotent bookkeeping commands that
        # would otherwise be orphaned if no agent retries (T-1192 structural
        # fix). Scope: `fw inception decide T-XXX go|no-go --rationale "..."`.
        command_preview = data.get("command_preview", "")
        if _is_inception_decide(command_preview):
            exec_result = _execute_inception_decide(command_preview)

    # Move pending → resolved
    data["status"] = decision
    response_dict = {
        "decision": decision,
        "feedback": feedback or None,
        "responded_at": now_ts,
        "mechanism": "watchtower",
    }
    if exec_result is not None:
        response_dict["auto_executed"] = exec_result
    data["response"] = response_dict

    resolved_file = APPROVALS_DIR / f"resolved-{command_hash[:12]}.yaml"
    with open(resolved_file, "w") as fh:
        yaml.dump(data, fh, default_flow_style=False, sort_keys=False)

    # Remove pending file
    pending_file.unlink(missing_ok=True)

    status_color = "var(--pico-ins-color)" if decision == "approved" else "var(--pico-del-color)"
    status_icon = "Approved" if decision == "approved" else "Rejected"
    msg = f'{status_icon}.'
    if exec_result is not None:
        if exec_result.get("ok"):
            msg += f' Auto-executed — {exec_result.get("summary", "decision recorded")}.'
        else:
            msg += f' Auto-execute failed: {exec_result.get("error", "unknown")}. Agent can retry.'
    else:
        msg += ' Agent can retry the command.'
    return f'<p style="color:{status_color};">{msg}</p>'


def _is_inception_decide(command_preview: str) -> bool:
    """Detect `fw inception decide T-XXX go|no-go --rationale ...` shape."""
    # T-1567 / F1: raw-string + double-escape produced literal `\d`/`\s`/`\b`
    # that never matched. Auto-exec on Watchtower-approved Tier-0 inception
    # decisions was dead code from T-1192 until this fix.
    return bool(re.search(r"(?:^|/|\s)fw inception decide T-\d+ (?:go|no-go)\b", command_preview))


def _execute_inception_decide(command_preview: str) -> dict:
    """Run the approved `fw inception decide` command and return a status dict."""
    import shlex
    import subprocess

    cmd_str = " ".join(command_preview.split())
    # T-1567 / F1: same dead-code regex bug as _is_inception_decide above.
    m = re.search(r"fw inception decide (T-\d+) (go|no-go)", cmd_str)
    if not m:
        return {"ok": False, "error": "could not parse command", "summary": "", "stdout_tail": ""}
    task_id, verdict = m.group(1), m.group(2)
    rat_m = re.search(r'--rationale\s+"(.*)"(?:\s|$)', cmd_str, re.DOTALL)
    rationale = rat_m.group(1) if rat_m else "Approved via Watchtower (no rationale captured)"

    fw_bin = str(PROJECT_ROOT / ".agentic-framework" / "bin" / "fw")
    if not Path(fw_bin).exists():
        fw_bin = "fw"

    argv = [fw_bin, "inception", "decide", task_id, verdict, "--rationale", rationale]
    try:
        # T-1193: strip CLAUDECODE so the inner gate (T-679/T-1259) treats this as a
        # human action routed through Watchtower, not an agent invocation. TIER0_AUTOEXEC
        # signals the outer hook that this subprocess was authorized via approvals.
        subproc_env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
        subproc_env["TIER0_AUTOEXEC"] = "1"
        proc = subprocess.run(
            argv, cwd=str(PROJECT_ROOT),
            env=subproc_env,
            capture_output=True, text=True, timeout=30,
        )
        stdout_tail = (proc.stdout or "")[-400:]
        if proc.returncode == 0:
            return {"ok": True, "summary": f"{task_id} decided {verdict}", "error": None, "stdout_tail": stdout_tail}
        # T-3284: operator-facing translation (G-102 defect B) — this error is
        # rendered on /approvals; raw gate stderr carries agent-audience bypass
        # instructions the operator must not be handed as the remedy.
        from web.shared import operator_facing_stderr
        return {"ok": False, "error": operator_facing_stderr((proc.stderr or "")[:3000]).strip()[:400] or f"exit {proc.returncode}", "summary": "", "stdout_tail": stdout_tail}
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout (30s)", "summary": "", "stdout_tail": ""}
    except Exception as e:
        return {"ok": False, "error": f"{type(e).__name__}: {e}", "summary": "", "stdout_tail": ""}


@bp.route("/api/approvals/complete-batch", methods=["POST"])
def complete_batch():
    """Complete the tasks the operator saw listed as ready (T-846, T-3590).

    This is a human-initiated batch action from the Watchtower UI. The form posts
    the task ids the page displayed (``task_id``, repeated). Each id is re-read
    from disk and re-judged by `is_ready_for_batch_completion` NOW; any id that
    is not ready is refused and named. Nothing outside the posted list is ever
    touched — there is no "complete everything that happens to be ready".
    """
    import subprocess
    from markupsafe import escape

    requested = []
    for tid in request.form.getlist("task_id"):
        tid = (tid or "").strip()
        if tid and tid not in requested:
            requested.append(tid)
    if not requested:
        return '<p style="color:var(--pico-del-color);">Refused: no task ids posted. Reload /approvals and use the batch button.</p>'

    ready_tasks = []
    errors = []
    for tid in requested:
        found = _read_active_task(tid)
        if found is None:
            errors.append(f"{escape(tid)}: refused — not an active task")
            continue
        fm, body = found
        if not is_ready_for_batch_completion(fm.get("status", ""), body):
            errors.append(f"{escape(tid)}: refused — not ready (needs status work-completed and every Human criterion ticked)")
            continue
        ready_tasks.append(tid)

    completed = []
    fw_path = str(FRAMEWORK_ROOT / "bin" / "fw")

    for task_id in ready_tasks:
        try:
            # T-1568 / F2: narrow flags instead of --force. Batch operates on
            # partial-complete tasks (already work-completed in active/) where
            # the human is authorising closure regardless of unchecked Human
            # ACs — same auth-flag semantics T-1559 fixed for the recheck
            # branch. Recommendation + RCA gates do not re-fire on the
            # partial-complete recheck path so no skip needed for those.
            result = subprocess.run(
                [fw_path, "task", "update", task_id, "--status", "work-completed",
                 "--skip-sovereignty", "--skip-verification", "--skip-acceptance-criteria",
                 "--reason", "Batch completed via Watchtower UI (human action)"],
                capture_output=True, text=True, timeout=30,
                cwd=str(PROJECT_ROOT),
                # T-3586: strip the CLAUDECODE Flask inherits from an agent shell (same
                # defence as T-1193 above) — update-task.sh refuses these --skip-* flags
                # under CLAUDECODE=1, and this is the operator's own click.
                env={k: v for k, v in os.environ.items() if k != "CLAUDECODE"},
            )
            if result.returncode == 0:
                completed.append(task_id)
            else:
                # T-3284: sanitize before rendering to the operator (G-102 defect B)
                from web.shared import operator_facing_stderr
                errors.append(f"{task_id}: {operator_facing_stderr((result.stderr or '')[:3000])[:100] or f'exit {result.returncode}'}")
        except Exception as e:
            errors.append(f"{task_id}: {str(e)[:100]}")

    parts = []
    if completed:
        parts.append(f'<p style="color:var(--pico-ins-color);">Completed {len(completed)} task(s): {", ".join(completed)}</p>')
    if errors:
        parts.append(f'<p style="color:var(--pico-del-color);">Errors ({len(errors)}): {"<br>".join(errors)}</p>')

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# T-3200: continuous-run brake, reachable without shell access.
#
# Sovereignty says the human can override anything. Before this, the only
# override was `touch .context/working/.continuous-halt` — which means an
# operator watching a runaway loop from a phone had no brake at all.
#
# Both routes are state-changing POSTs and so pass through Watchtower's global
# CSRF check (web/app.py before_request, T-1343) like every other mutating
# route here. No bespoke auth: a one-off auth story for one endpoint is how
# surfaces drift apart.
#
# On the DoS shape flagged when this was filed: the halt endpoint is fail-safe
# in the direction that matters — the worst an unauthorised caller achieves is
# STOPPING your agent, never starting one or approving anything. It is strictly
# less dangerous than /api/approvals/decide, which already sits on this posture.
# ---------------------------------------------------------------------------

@bp.route("/api/continuous/halt", methods=["POST"])
def continuous_halt():
    """Engage the brake by writing the file stop-driver.sh reads as Brake 1."""
    hf = _halt_file()
    try:
        hf.parent.mkdir(parents=True, exist_ok=True)
        hf.write_text(
            "halted via Watchtower /approvals at %s\n"
            % datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        )
    except OSError as exc:
        return '<p style="color:var(--pico-del-color);">Could not write halt file: %s</p>' % exc, 500
    return _halt_fragment()


@bp.route("/api/continuous/resume", methods=["POST"])
def continuous_resume():
    """Release the brake. A brake with no release is a brake nobody dares use."""
    hf = _halt_file()
    try:
        hf.unlink(missing_ok=True)
    except OSError as exc:
        return '<p style="color:var(--pico-del-color);">Could not remove halt file: %s</p>' % exc, 500
    return _halt_fragment()


@bp.route("/approvals/continuous-state")
def continuous_state_fragment():
    """Read-only fragment, so the card can refresh without a full page load."""
    return _halt_fragment()


def _halt_fragment():
    from flask import render_template
    return render_template("_continuous_halt.html", continuous=_halt_state())
