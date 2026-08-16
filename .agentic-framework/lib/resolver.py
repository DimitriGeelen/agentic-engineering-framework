#!/usr/bin/env python3
"""
Resolver — workflow lookup, prompt assembly, variant selection, telemetry.

Spawn-side primitive consumed by:
  - `bin/fw resolver` (CLI: dispatch dry-run, explain forensics)
  - T-1697 (outcome enrichment back-prop)
  - T-1698 (litellm proxy adapter)
  - T-1699 (pi backend adapter)

Three prompt tiers:
  - static       — prompt_template loaded verbatim
  - assembled    — $VAR substitution from task context + resolver-injected context (default)
  - meta-prompted — substrate for v2; runtime LLM call deferred unless explicitly enabled

Workflow lookup (Q12 fallback): <task_type>.yaml → default.yaml → ResolverError.
ADR-0002: workflows declaring `inline: true` must NOT reach the dispatcher.

Origin: T-1689 inception spike at docs/reports/T-1689-spikes/resolver_spike.py.
Build task: T-1696. Decisions: D-073 (single module + shell shim), D-074 (atomic
per-call tmp pattern for any modify-in-place callers).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import subprocess
import sys
import threading
import time
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import yaml

import keylock
import worker_identity

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd()))
WORKFLOWS_DIR = PROJECT_ROOT / ".context" / "project" / "workflows"
DISPATCHES_LOG = PROJECT_ROOT / ".context" / "dispatches.jsonl"
DISPATCH_OUTCOMES_LOG = PROJECT_ROOT / ".context" / "dispatch-outcomes.jsonl"
BLOBS_ROOT = PROJECT_ROOT / ".context" / "dispatch-blobs"
PATTERNS_YAML = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
EXAMPLES_ROOT = PROJECT_ROOT / "prompts" / "examples"
TASKS_ACTIVE = PROJECT_ROOT / ".tasks" / "active"
TASKS_COMPLETED = PROJECT_ROOT / ".tasks" / "completed"

DISPATCH_SCHEMA_VERSION = 1
VAR_PAT = re.compile(r"\$([A-Z][A-Z0-9_]*)")

# T-2914: default non-convergence threshold for `resolver loop`/`pick`/`stalled`
# — a task dispatched this many times in a row with no measurable advancement
# (status change, AC tick, or a landed commit referencing it) stops being
# picked. Origin: T-2862 hit 57 dispatches / 0 outcomes before this existed.
_DEFAULT_STALL_AFTER = 5

# T-2915: default age bound (minutes) for the in-flight latch. A dispatch row
# with no terminal_event is presumed "worker still running" — but nothing
# ever bounded that presumption, so a worker that died mid-run (crash, OOM,
# host reboot) latched its task out of the loop forever. Observed worst-case
# legitimate runtime is well under an hour (TermLinkWorker default timeout
# 1800s/30min + 30s grace; pi/ollama-loop dispatches complete inside a single
# 30-min systemd tick in every measured row). 240min (4h) is a wide safety
# margin above that ceiling while still being far short of "weeks" — the
# failure mode this fixes (nine tasks latched five weeks, T-2915 origin).
# Override via FW_RESOLVER_INFLIGHT_MAX_AGE_MIN (not yet in FW_CONFIG_REGISTRY
# — env-only, consistent with FW_RESOLVER_BVP_RANK/FW_DISPATCH_ORIGIN above).
_INFLIGHT_MAX_AGE_MIN_DEFAULT = 240


def _inflight_max_age_min() -> int:
    """Resolve the in-flight age bound: FW_RESOLVER_INFLIGHT_MAX_AGE_MIN env
    var, falling back to the documented default on missing/invalid input."""
    raw = os.environ.get("FW_RESOLVER_INFLIGHT_MAX_AGE_MIN", "")
    try:
        val = int(raw)
        if val > 0:
            return val
    except ValueError:
        pass
    return _INFLIGHT_MAX_AGE_MIN_DEFAULT

# NOTE: keep in sync with bin/fw:1804 (T-1734). Two tables drifted before: bin/fw
# accepted "ollama-loop" while this one didn't, so workflows listed cleanly but
# failed at dispatch. If you add a worker_kind here, add it there too (and vice versa).
# "ollama-direct" (T-1719 A3) is the one kind that spawns nothing: `fw ask`
# runs a synchronous RAG+chat call in the caller's own process. See
# .context/project/workflows/ask.yaml for why it is not ollama-thin-loop.
VALID_WORKER_KINDS = {"Task", "TermLink", "pi", "ollama-loop", "ollama-thin-loop", "ollama-direct"}
VALID_PROMPT_STRATEGIES = {"static", "assembled", "meta-prompted"}


class ResolverError(Exception):
    """Raised for unrecoverable resolver-side errors (missing default.yaml,
    inline workflow at dispatch time, missing template, etc.)."""


# ---------------------------------------------------------------------------
# Workflow lookup (Q12 fallback)
# ---------------------------------------------------------------------------
def load_workflow(task_type: str) -> Dict[str, Any]:
    """Q12 fallback: <task_type>.yaml → default.yaml → ResolverError.

    Annotates the returned dict with synthetic fields:
      _source_path     — relative path of file that was loaded
      _resolved_via    — 'primary' | 'default-fallback'
      _original_task_type — set only on fallback (preserves caller's request)
    """
    primary = WORKFLOWS_DIR / f"{task_type}.yaml"
    fallback = WORKFLOWS_DIR / "default.yaml"

    if primary.exists():
        wf = yaml.safe_load(primary.read_text()) or {}
        wf["_source_path"] = str(primary.relative_to(PROJECT_ROOT))
        wf["_resolved_via"] = "primary"
        return wf
    if fallback.exists():
        wf = yaml.safe_load(fallback.read_text()) or {}
        wf["_source_path"] = str(fallback.relative_to(PROJECT_ROOT))
        wf["_resolved_via"] = "default-fallback"
        wf["_original_task_type"] = task_type
        return wf
    raise ResolverError(
        f"No workflow for task_type '{task_type}' and no default.yaml at "
        f"{fallback.relative_to(PROJECT_ROOT) if fallback.parent.exists() else fallback}. "
        "default.yaml is the Q12 contract — its absence is unrecoverable."
    )


# ---------------------------------------------------------------------------
# Prompt assembly (Tier 2 default; Tier 1 + Tier 3 substrate)
# ---------------------------------------------------------------------------
# T-1806 / ADR-0004 — dispatch-safety slice 2: risk-policy preamble.
# Workers spawn --bare (no CLAUDE.md, no hooks); the dispatch envelope is the
# only governance channel they see. When a workflow opts in via
# `allow_pause: true`, the Resolver prepends a baseline risk-policy preamble
# telling the Worker how and when to emit a `pause_requested` terminal event.
# Per-workflow override via `pause_preamble: <path>` swaps the baseline for
# custom text. Without opt-in, no preamble is injected — cheap workflows stay
# unmodified.
_BASELINE_RISK_PREAMBLE = """\
[RISK POLICY — read before any irreversible action]

You MAY emit a pause_requested terminal event INSTEAD of completing the task
when you encounter an ambiguity that meets BOTH of these conditions:

  1. SEVERITY — a wrong choice here would produce output that is hard to
     detect as wrong (verification might pass) AND expensive to undo
     (existing code, downstream dependencies, or external state would
     need to be reverted).
  2. LIKELIHOOD — given the evidence currently available to you, your
     confidence in the right choice is meaningfully below the workflow's
     pause_threshold.

This workflow's pause_threshold is: $PAUSE_THRESHOLD

To pause, emit a terminal event with this exact JSON shape:

  {"type": "pause_requested",
   "question": "<the specific question you want answered>",
   "assessment": {"severity": "<low|medium|high>",
                  "likelihood": "<low|medium|high>"},
   "state_ref": "<optional: file/path/identifier of any partial work>"}

Then exit cleanly. The orchestrator will surface your question to the
operator, capture the resolution, and re-dispatch you with the answer in
context. DO NOT timeout-assume-default — silence is not consent. If you
asked "is this safe?" and got no answer, the safe action is to wait.

DO NOT pause for:
  - Stylistic preferences (pick the existing pattern)
  - Low-stakes ambiguities you can recover from with a single revert
  - Anything you can answer by reading the codebase or running a test
  - Anything that does not meet BOTH severity AND likelihood thresholds

Pause is structured deferral, not "I'm not sure." Use it sparingly.
"""


def _risk_policy_preamble(workflow: Dict[str, Any]) -> str:
    """Return the risk-policy preamble for this workflow.

    Resolution order:
      1. If workflow.pause_preamble is set: read that file (PROJECT_ROOT-relative).
         Missing/unreadable → warn on stderr, fall back to baseline.
      2. Else: use _BASELINE_RISK_PREAMBLE.

    In all cases, substitute $PAUSE_THRESHOLD from the workflow (default "high")
    so the rendered preamble is self-contained.
    """
    threshold = str(workflow.get("pause_threshold", "high"))

    custom_path = workflow.get("pause_preamble")
    text = _BASELINE_RISK_PREAMBLE
    if custom_path:
        custom_full = PROJECT_ROOT / custom_path
        try:
            text = custom_full.read_text()
        except OSError as e:
            sys.stderr.write(
                f"resolver: pause_preamble {custom_path!r} unreadable ({e}); "
                f"falling back to baseline\n"
            )

    # $PAUSE_THRESHOLD substitution is the only variable supported in preambles
    # in v1 — other resolver-injected vars (RECENT_DISPATCHES etc.) are for the
    # body, not the preamble. Keep the surface small.
    return text.replace("$PAUSE_THRESHOLD", threshold)


def _redispatch_preamble(pause_resolution: Dict[str, str]) -> str:
    """T-1809 — build the RE-DISPATCH block prepended to a retry prompt.

    Workers come back fresh on a retry (claude --bare). The only signal they
    have that they previously paused on this exact dispatch is what we write
    at the top of their prompt. Be explicit, terse, and put the answer in a
    distinct visual block.
    """
    question = (pause_resolution.get("question") or "").strip() or "(question text was not captured)"
    answer = (pause_resolution.get("answer") or "").strip() or "(operator provided no answer text)"
    return (
        "[RE-DISPATCH — operator answered your pause]\n"
        "\n"
        "On a previous attempt at this task you paused with this question:\n"
        f"  Q: {question}\n"
        "\n"
        "The operator's answer is:\n"
        f"  A: {answer}\n"
        "\n"
        "Treat this answer as authoritative. Proceed with the task using it as\n"
        "guidance. Do NOT re-pause on the same question. If a different ambiguity\n"
        "arises that meets the severity × likelihood threshold, you may pause\n"
        "again — but on the new question, not this one.\n"
    )


def assemble_prompt(
    workflow: Dict[str, Any],
    task_context: Dict[str, str],
    pause_resolution: Optional[Dict[str, str]] = None,
) -> str:
    """Render the prompt per workflow.prompt_strategy.

    static       — load template, return verbatim (no $VAR expansion)
    assembled    — load template, substitute $VAR (default)
    meta-prompted — substrate stub: builds the meta-prompt envelope but does
                    NOT call the meta-model unless workflow.meta_model_enabled
                    is True (deferred to v2 per A-4 caveat in T-1689).

    T-1806: If workflow.allow_pause is True, prepend the risk-policy preamble
    to the rendered output regardless of strategy. The preamble lives at the
    front so Workers read it before any task-specific instructions.

    T-1809: If pause_resolution is provided ({question, answer}), prepend a
    RE-DISPATCH block ABOVE the risk-policy preamble. The retry block must
    come first because it answers a question the Worker explicitly asked —
    it's higher-priority context than the generic risk policy.
    """
    template_path = workflow.get("prompt_template")
    if not template_path:
        raise ResolverError(
            f"Workflow {workflow.get('task_type')} has no prompt_template "
            "(inline workflows must not reach the resolver — see ADR-0002)"
        )
    template_full = PROJECT_ROOT / template_path
    if not template_full.exists():
        raise ResolverError(f"prompt_template missing: {template_full}")
    template = template_full.read_text()

    strategy = workflow.get("prompt_strategy", "assembled")
    if strategy not in VALID_PROMPT_STRATEGIES:
        raise ResolverError(
            f"Invalid prompt_strategy '{strategy}' (valid: {sorted(VALID_PROMPT_STRATEGIES)})"
        )

    if strategy == "static":
        body = template
    elif strategy == "meta-prompted":
        body = _meta_prompted_assemble(workflow, task_context, template)
    else:
        # default: assembled
        body = _assembled_substitute(workflow, task_context, template)

    # T-1806: prepend the risk-policy preamble when the workflow opts in.
    if workflow.get("allow_pause") is True:
        body = _risk_policy_preamble(workflow) + "\n" + body
    # T-1809: prepend the re-dispatch block ABOVE the risk-policy preamble.
    if pause_resolution:
        body = _redispatch_preamble(pause_resolution) + "\n" + body
    return body


def _assembled_substitute(
    workflow: Dict[str, Any], task_context: Dict[str, str], template: str
) -> str:
    """Tier-2 default: $VAR substitution.

    Resolution precedence (high → low):
      1. task_context (caller-supplied: TASK_ID, TASK_NAME, TASK_DESCRIPTION, ACCEPTANCE_CRITERIA, …)
      2. resolver-injected (PROJECT_ROOT, RECENT_DISPATCHES, HEALING_PATTERNS, FEW_SHOT_EXAMPLES)
      3. unresolved → empty + footer comment
    """
    task_type = workflow.get("_original_task_type") or workflow.get("task_type", "default")
    injected = {
        "PROJECT_ROOT": str(PROJECT_ROOT),
        "RECENT_DISPATCHES": _recent_dispatches_summary(task_type),
        "HEALING_PATTERNS": _healing_patterns_summary(task_type),
        "FEW_SHOT_EXAMPLES": _few_shot_examples(task_type),
    }
    context = {**injected, **task_context}  # task_context wins

    unresolved: List[str] = []

    def repl(match: "re.Match[str]") -> str:
        var = match.group(1)
        if var in context:
            return str(context[var])
        unresolved.append(var)
        return ""

    rendered = VAR_PAT.sub(repl, template)
    if unresolved:
        rendered += f"\n\n<!-- resolver: unresolved $VARs: {sorted(set(unresolved))} -->\n"
    return rendered


def _meta_prompted_assemble(
    workflow: Dict[str, Any], task_context: Dict[str, str], template: str
) -> str:
    """Tier-3 substrate. Builds a meta-prompt envelope.

    If workflow.meta_model_enabled is True, the runtime call is left to the
    spawn-side worker (which holds the LLM credentials). The resolver only
    constructs the meta-prompt; the actual LLM call is out of scope for v1.

    For v1, the rendered prompt is the meta-prompt envelope itself, marked
    with a sentinel header. T-1697/T-1698 read the sentinel and route
    accordingly. If meta_model_enabled is False, fall through to assembled.
    """
    if not workflow.get("meta_model_enabled", False):
        # Substrate-only: behaves as assembled
        return _assembled_substitute(workflow, task_context, template)

    meta_model = workflow.get("meta_model")
    if not meta_model:
        raise ResolverError(
            f"Workflow {workflow.get('task_type')} has prompt_strategy=meta-prompted "
            "and meta_model_enabled=true but no meta_model configured"
        )
    rendered_seed = _assembled_substitute(workflow, task_context, template)
    envelope = (
        f"<!-- META-PROMPT v1: model={meta_model} -->\n"
        f"<!-- SEED-PROMPT START -->\n"
        f"{rendered_seed}\n"
        f"<!-- SEED-PROMPT END -->\n"
        f"<!-- The worker should call meta_model with the seed prompt to produce "
        f"the final task prompt, then run the task with that. -->"
    )
    return envelope


# ---------------------------------------------------------------------------
# Resolver-injected context sources
# ---------------------------------------------------------------------------
def _recent_dispatches_summary(task_type: str, n: int = 5) -> str:
    """Tail dispatches.jsonl for last-N matching task_type."""
    if not DISPATCHES_LOG.exists():
        return "(no prior dispatches)"
    matches: List[Dict[str, Any]] = []
    try:
        with DISPATCHES_LOG.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if row.get("task_type") == task_type:
                    matches.append(row)
    except OSError:
        return "(dispatches.jsonl unreadable)"
    if not matches:
        return f"(no prior {task_type} dispatches)"
    tail = matches[-n:]
    lines = []
    for r in tail:
        ts = r.get("ts", "?")
        did = r.get("dispatch_id", "?")[:8]
        outcome = r.get("outcome", "pending")
        lines.append(f"- {ts} [{did}] outcome={outcome}")
    return "\n".join(lines)


def _healing_patterns_summary(task_type: str, max_patterns: int = 3) -> str:
    """Pull failure_patterns from patterns.yaml. v1: include top-3 by recency.

    Future: tag patterns with applicable task_types and filter. v1 uses
    'most recently learned' as a proxy — broadly applicable patterns
    surface naturally as they're added.
    """
    if not PATTERNS_YAML.exists():
        return "(no patterns.yaml — none matched)"
    try:
        data = yaml.safe_load(PATTERNS_YAML.read_text()) or {}
    except yaml.YAMLError:
        return "(patterns.yaml unparseable)"
    patterns = data.get("failure_patterns", []) or []
    if not patterns:
        return "(no failure patterns recorded)"
    # Sort by date_learned desc; missing dates sink to bottom
    def _sort_key(p: Dict[str, Any]) -> str:
        return str(p.get("date_learned", ""))

    patterns_sorted = sorted(patterns, key=_sort_key, reverse=True)[:max_patterns]
    lines = []
    for p in patterns_sorted:
        pid = p.get("id", "?")
        name = p.get("pattern", "?")
        mit = p.get("mitigation", "(no mitigation recorded)")
        lines.append(f"- {pid} [{name}]: {mit}")
    return "\n".join(lines)


def _few_shot_examples(task_type: str) -> str:
    """Load prompts/examples/<task_type>/*.md if present."""
    examples_dir = EXAMPLES_ROOT / task_type
    if not examples_dir.is_dir():
        return "(no few-shot examples for this task_type)"
    files = sorted(p for p in examples_dir.glob("*.md") if p.is_file())
    if not files:
        return f"(no .md files in {examples_dir.relative_to(PROJECT_ROOT)})"
    chunks = []
    for f in files:
        try:
            chunks.append(f"### Example: {f.stem}\n{f.read_text()}")
        except OSError:
            chunks.append(f"### Example: {f.stem} (unreadable)")
    return "\n\n".join(chunks)


# ---------------------------------------------------------------------------
# SHA capture (for telemetry parity with the substrate)
# ---------------------------------------------------------------------------
def git_sha(path: str) -> Optional[str]:
    """git rev-parse HEAD:<path> with mtime-hash fallback if uncommitted."""
    if not path:
        return None
    full = PROJECT_ROOT / path
    if not full.exists():
        return None
    try:
        result = subprocess.run(
            ["git", "rev-parse", f"HEAD:{path}"],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    mt = full.stat().st_mtime
    return f"mtime:{hashlib.sha1(f'{path}:{mt}'.encode()).hexdigest()[:12]}"


# ---------------------------------------------------------------------------
# Variant selection
# ---------------------------------------------------------------------------
def select_variant(workflow: Dict[str, Any]) -> Optional[str]:
    """Weighted-random variant pick. Returns None if no variants declared."""
    variants = workflow.get("variants")
    if not variants:
        return None
    ids = list(variants.keys())
    weights = [float(variants[v].get("weight", 1.0)) for v in ids]
    return random.choices(ids, weights=weights, k=1)[0]


# ---------------------------------------------------------------------------
# Provenance + non-convergence guard (T-2914)
# ---------------------------------------------------------------------------
def _dispatch_origin() -> str:
    """Identify what invoked this dispatch — never None (defect 3, T-2914).

    Resolution order: explicit `FW_DISPATCH_ORIGIN` env var (set by the
    systemd unit / cron command that fired this run) → systemd-detected
    (INVOCATION_ID is set by systemd for every unit it starts, even when the
    unit doesn't set FW_DISPATCH_ORIGIN) → interactive session (tagged with
    the current session id from session.yaml, if resolvable) → 'unknown'.
    'unknown' is still non-null — it says "not attributable", not nothing.
    """
    env_origin = os.environ.get("FW_DISPATCH_ORIGIN", "").strip()
    if env_origin:
        return env_origin
    if os.environ.get("INVOCATION_ID"):
        return "systemd:unlabeled-unit"
    try:
        interactive = sys.stdin.isatty() or sys.stdout.isatty()
    except Exception:
        interactive = False
    if interactive:
        session = ""
        session_file = PROJECT_ROOT / ".context" / "working" / "session.yaml"
        if session_file.exists():
            try:
                sdata = yaml.safe_load(session_file.read_text()) or {}
                session = str(sdata.get("session_id") or "").strip()
            except (yaml.YAMLError, OSError):
                pass
        return f"interactive:{session}" if session else "interactive:unknown-session"
    return "unknown"


def _ac_ticked_count(ac_block: str) -> int:
    """Count of ticked `- [x]` checkboxes in an Acceptance Criteria block
    (case-insensitive). Used as one of the three stall-detector advancement
    signals — a worker cannot trivially satisfy this without doing the work,
    since ticking is gated by the reviewer/completion machinery, not free text."""
    return len(re.findall(r"^\s*-\s*\[x\]", ac_block, re.IGNORECASE | re.MULTILINE))


def _task_current_snapshot(task_id: str) -> Optional[Dict[str, Any]]:
    """Read {status, ac_ticked} for `task_id` from .tasks/active/ right now.
    Returns None if the task is no longer in active/ (completed, removed —
    not the stall detector's concern; it only guards the autonomous loop)."""
    if not TASKS_ACTIVE.is_dir():
        return None
    candidates = list(TASKS_ACTIVE.glob(f"{task_id}-*.md"))
    if not candidates:
        return None
    meta = _read_task_meta(candidates[0])
    return {"status": meta["status"], "ac_ticked": _ac_ticked_count(meta["ac_block"])}


def _task_touched_since(task_id: str, since_iso: str) -> bool:
    """True if the task's own `last_update` has moved past `since_iso`
    (T-2916). Used only on the degraded path, where no dispatch-time snapshot
    exists to diff against. Unparseable/missing timestamps return True —
    fail-open, so an unreadable task is never reported stalled on evidence
    the function could not actually read."""
    if not TASKS_ACTIVE.is_dir():
        return True
    candidates = list(TASKS_ACTIVE.glob(f"{task_id}-*.md"))
    if not candidates:
        return True
    # last_update lives in the raw frontmatter dict, not the flattened meta —
    # `_read_task_meta` surfaces only {id,name,status,owner,horizon,
    # workflow_type,ac_block,fm,path}. Reading it off the top level silently
    # yields None, which fails open and reports every task as advanced.
    fm = _read_task_meta(candidates[0]).get("fm")
    raw = str((fm or {}).get("last_update") or "").strip().strip("'\"")
    if not raw:
        return True
    try:
        last = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        since = datetime.fromisoformat(str(since_iso).replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return True
    if last.tzinfo is None:
        last = last.replace(tzinfo=timezone.utc)
    if since.tzinfo is None:
        since = since.replace(tzinfo=timezone.utc)
    return last > since


def _git_commit_count_since(task_id: str, since_iso: str) -> int:
    """Count commits landed after `since_iso` whose SUBJECT LINE references
    `task_id`. P-002 requires every commit reference a task id in the form
    `T-XXXX: ...`, so the subject is where a commit declares what it advances.

    T-2916: this deliberately does NOT match the body. Matching anywhere in
    the message conflates "this commit advanced the task" with "this commit
    mentioned the task" — and the second is exactly what an RCA does. Measured
    on the origin case: T-2862 (60 dispatches, 0 outcomes, `last_update`
    unmoved since 2026-08-08) was cleared from the stalled set by commits
    387a1465b and e7cce384b — the T-2914 and T-2916 commits, which cite T-2862
    in their bodies *as the example of a stalled task*. Writing the RCA about a
    stall was enough to make the stall undetectable.
    """
    try:
        result = subprocess.run(
            ["git", "log", f"--since={since_iso}", "--format=%s"],
            cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return 0
        pat = re.compile(rf"\b{re.escape(task_id)}\b")
        return sum(1 for line in result.stdout.splitlines() if pat.search(line))
    except (OSError, subprocess.SubprocessError):
        return 0


def _outcome_count(task_id: str) -> int:
    """Rows in dispatch-outcomes.jsonl for `task_id` — the zero-outcome
    signal from defect 6 (T-2914: 57 dispatches of T-2862, 0 outcome rows)."""
    if not DISPATCH_OUTCOMES_LOG.exists():
        return 0
    n = 0
    with DISPATCH_OUTCOMES_LOG.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("task_id") == task_id:
                n += 1
    return n


def _stalled_task_ids(stall_after: int) -> Dict[str, Dict[str, Any]]:
    """Task IDs that have not advanced across the last `stall_after`
    dispatches (T-2914 defect 1). 'Advanced' means at least one of: status
    changed, AC-ticked count increased, or a commit referencing the task
    landed — all measured against the `task_snapshot` captured AT dispatch
    time, which a worker cannot retroactively edit (a dispatch row is
    append-only history, not a self-report).

    Rows without a `task_snapshot` (pre-T-2914 history) are skipped —
    fail-open, matching `_recently_dispatched_ids`'s convention: never
    wrongly exclude on data this function can't interpret.

    Returns {task_id: {"dispatch_count", "since", "outcome_count"}} for
    tasks that should stop being picked and be surfaced instead.
    """
    if stall_after <= 0 or not DISPATCHES_LOG.exists():
        return {}
    per_task: Dict[str, List[Tuple[str, Optional[Dict[str, Any]]]]] = defaultdict(list)
    with DISPATCHES_LOG.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            tid = row.get("task_id")
            ts = row.get("ts")
            if not tid or not ts:
                continue
            snap = row.get("task_snapshot")
            # T-2916: rows WITHOUT a task_snapshot are kept, not dropped. The
            # original predicate required one on every row — but task_snapshot
            # was introduced by T-2914 itself, so on day one the evaluable
            # history was empty and the guard abstained on 100% of its input
            # while printing the same line as a guard that had cleared it.
            # Measured at the time of this fix: 11/1325 rows carry a snapshot
            # (0.8%). A predicate that can only read 0.8% of the record cannot
            # guard the record.
            per_task[tid].append((str(ts), snap if isinstance(snap, dict) else None))

    stalled: Dict[str, Dict[str, Any]] = {}
    for tid, rows in per_task.items():
        rows.sort(key=lambda r: r[0])
        if len(rows) < stall_after:
            continue
        window = rows[-stall_after:]
        earliest_ts, earliest_snap = window[0]
        current = _task_current_snapshot(tid)
        if current is None:
            continue  # not active anymore — outside the loop's concern

        commits = _git_commit_count_since(tid, earliest_ts)
        if earliest_snap is not None:
            # Full evidence: compare against the snapshot captured AT dispatch,
            # which a worker cannot retroactively edit.
            evidence = "snapshot"
            status_changed = current["status"] != earliest_snap.get("status")
            ac_grew = current["ac_ticked"] > int(earliest_snap.get("ac_ticked", -1))
            advanced = status_changed or ac_grew or commits > 0
        else:
            # Degraded evidence (T-2916): no "then" state to diff against, but
            # advancement is still observable without one. A commit referencing
            # the task after the window opened is advancement under P-002; so is
            # a `last_update` that has moved past the window's start. Both are
            # strictly weaker than the snapshot diff — they cannot see an AC
            # ticked with no commit and no last_update bump — so this path can
            # MISS a stall, never invent one. That asymmetry is deliberate: the
            # cost of a missed stall is one extra dispatch, the cost of a false
            # stall is a task silently locked out (the T-2915 failure).
            evidence = "degraded"
            advanced = commits > 0 or _task_touched_since(tid, earliest_ts)

        if advanced:
            continue
        stalled[tid] = {
            "dispatch_count": len(rows),
            "since": earliest_ts,
            "outcome_count": _outcome_count(tid),
            "evidence": evidence,
        }
    return stalled


def _stall_coverage(stall_after: int) -> Dict[str, int]:
    """What `_stalled_task_ids` was actually able to look at (T-2916).

    A verdict without coverage is unreadable: "no tasks stalled" is the same
    sentence whether the guard cleared 300 tasks or examined none. This
    returns the denominator so the verdict can never again be printed alone.
    """
    if not DISPATCHES_LOG.exists():
        return {"tasks_seen": 0, "evaluated": 0, "below_threshold": 0, "inactive": 0}
    per_task: Dict[str, int] = defaultdict(int)
    with DISPATCHES_LOG.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("task_id") and row.get("ts"):
                per_task[row["task_id"]] += 1
    below = sum(1 for n in per_task.values() if n < stall_after)
    inactive = sum(
        1 for tid, n in per_task.items()
        if n >= stall_after and _task_current_snapshot(tid) is None
    )
    return {
        "tasks_seen": len(per_task),
        "evaluated": len(per_task) - below - inactive,
        "below_threshold": below,
        "inactive": inactive,
    }


# ---------------------------------------------------------------------------
# Telemetry capture (dispatches.jsonl + blob dir)
# ---------------------------------------------------------------------------
def append_dispatch_row(row: Dict[str, Any]) -> None:
    """Append one dispatch row to dispatches.jsonl under the ledger lock.

    T-3042 — O_APPEND alone is atomic against other *appenders*, and that was
    the only writer this site was written to expect. It is not atomic against
    lib/spawn.py:update_outcome_row, which reads the whole ledger and swaps a
    rewritten inode in over it: a row appended after that read lands in the
    inode os.replace is about to discard, and is erased. So this side takes the
    same sidecar lock the rewriter takes. Locking only the rewriter closes
    nothing — that is the whole point of the pairing, and the reason this
    two-line append is a named function: so the pairing is greppable and so
    the regression test can drive the real appender rather than a stand-in.
    """
    DISPATCHES_LOG.parent.mkdir(parents=True, exist_ok=True)
    with keylock.guarding(DISPATCHES_LOG):
        # Per-line JSON keeps each dispatch self-contained.
        with DISPATCHES_LOG.open("a") as f:
            f.write(json.dumps(row) + "\n")


def capture_dispatch(
    *,
    task_id: str,
    workflow: Dict[str, Any],
    rendered_prompt: str,
    variant_id: Optional[str] = None,
    parent_dispatch_id: Optional[str] = None,
    extra: Optional[Dict[str, Any]] = None,
    write: bool = True,
) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    """Persist a dispatch row + blob, return (envelope, row).

    write=False: dry-run mode — no files written, no IDs minted? Actually
    we DO mint a UUID and compute SHAs (those are read-only) so the dry-run
    output is faithful, but we skip the JSONL append + blob mkdir.
    """
    dispatch_id = str(uuid.uuid4())
    ts = datetime.now(timezone.utc).isoformat()
    yyyy_mm = ts[:7]
    blob_dir = BLOBS_ROOT / yyyy_mm / dispatch_id

    if write:
        blob_dir.mkdir(parents=True, exist_ok=True)
        (blob_dir / "prompt.txt").write_text(rendered_prompt)

    workflow_path = workflow.get("_source_path", "")
    workflow_sha = git_sha(workflow_path) if workflow_path else None
    template_path = workflow.get("prompt_template", "")
    template_sha = git_sha(template_path) if template_path else None

    # T-2914 defect 3: provenance must be non-null on every row. defect 1:
    # task_snapshot is the pre-dispatch state a worker cannot retroactively
    # edit, which _stalled_task_ids compares against N dispatches later.
    task_snapshot = _task_current_snapshot(task_id)

    row: Dict[str, Any] = {
        "schema_version": DISPATCH_SCHEMA_VERSION,
        "ts": ts,
        "dispatch_id": dispatch_id,
        "task_id": task_id,
        "parent_dispatch_id": parent_dispatch_id,
        "task_type": workflow.get("_original_task_type") or workflow.get("task_type"),
        "workflow_id": workflow.get("task_type"),
        "workflow_sha": workflow_sha,
        "workflow_resolved_via": workflow.get("_resolved_via"),
        "prompt_strategy": workflow.get("prompt_strategy", "assembled"),
        "prompt_template": template_path,
        "template_sha": template_sha,
        "worker_kind": workflow.get("worker_kind"),
        "model": workflow.get("model"),
        "effort": workflow.get("effort"),
        "variant_id": variant_id,
        "blob_dir": str(blob_dir.relative_to(PROJECT_ROOT)),
        "outcome": "pending",
        "origin": _dispatch_origin(),
        "task_snapshot": task_snapshot,
        "dry_run": (not write) or None,
    }
    if row["dry_run"] is None:
        del row["dry_run"]
    if extra:
        row.update(extra)

    if write:
        append_dispatch_row(row)

    cwd_template = workflow.get("cwd", "$PROJECT_ROOT")
    cwd_resolved = cwd_template.replace("$PROJECT_ROOT", str(PROJECT_ROOT))

    # T-2917: give the worker a git identity distinct from the operator's,
    # named for the mechanism that spawned it (row["origin"]) and carrying
    # this dispatch_id in the email local-part so a worker's commit joins
    # back to this row without depending on the worker to write a trailer.
    # Workflow-declared `env:` is layered on top — it can override if a
    # workflow ever needs to (none do today), never the other way round.
    mechanism = worker_identity.mechanism_from_origin(row["origin"])
    env = worker_identity.worker_git_env(mechanism, dispatch_id)
    env.update(workflow.get("env", {}))

    envelope = {
        "dispatch_id": dispatch_id,
        "task_id": task_id,
        "task_type": row["task_type"],
        "worker_kind": workflow.get("worker_kind"),
        "model": workflow.get("model"),
        "effort": workflow.get("effort"),
        "prompt": rendered_prompt,
        "allowed_tools": workflow.get("allowed_tools", []),
        # T-2488/OBS-088: strict-mcp defaults ON so resolver-dispatched
        # claude -p workers stay lean (no inherited .mcp.json schema injection,
        # ~175K tokens). A workflow that needs MCP sets strict_mcp_config: false
        # and supplies mcp_config: <path>.
        "strict_mcp_config": workflow.get("strict_mcp_config", True),
        "mcp_config": workflow.get("mcp_config"),
        "cost_cap_usd": workflow.get("cost_cap_usd"),
        "cwd": cwd_resolved,
        "env": env,
        "blob_dir": str(blob_dir),
        "variant_id": variant_id,
    }
    return envelope, row


# ---------------------------------------------------------------------------
# Atomic write helper (D-074 — for any modify-in-place paths added later)
# ---------------------------------------------------------------------------
def atomic_write_text(target: Path, content: str) -> None:
    """Per-call unique tmp filename to avoid concurrent-writer overwrites.

    Pattern:  <target>.tmp.<pid>.<tid>  →  os.replace → <target>
    Spike A-5 caught a shared-tmp race; this is the production fix.
    """
    tmp = target.with_suffix(target.suffix + f".tmp.{os.getpid()}.{threading.get_ident()}")
    tmp.write_text(content)
    os.replace(tmp, target)


# ---------------------------------------------------------------------------
# End-to-end resolve
# ---------------------------------------------------------------------------
def resolve(
    task_id: str,
    task_type: str,
    task_context: Dict[str, str],
    *,
    dry_run: bool = False,
    retry_of_dispatch_id: Optional[str] = None,
    pause_resolution: Optional[Dict[str, str]] = None,
) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    """Main entry: workflow → assemble → capture → return (envelope, row).

    T-1809: pause re-dispatch chain. When `retry_of_dispatch_id` is set, the
    new dispatch row carries the link back to the paused dispatch so slice 4's
    `list_paused_dispatches` deflates the awaiting list automatically. When
    `pause_resolution` is set, `assemble_prompt` prepends the RE-DISPATCH block
    with the operator's answer.
    """
    workflow = load_workflow(task_type)
    if workflow.get("inline") is True:
        raise ResolverError(
            f"Workflow {task_type} is marked inline:true — Agent must do this "
            "work directly, not dispatch it (ADR-0002)"
        )
    # Validate worker_kind (defensive — fw doctor lints this, but resolver is
    # also called outside of doctor's audit window).
    wk = workflow.get("worker_kind")
    if wk and wk not in VALID_WORKER_KINDS:
        raise ResolverError(
            f"Workflow {task_type} has invalid worker_kind '{wk}' "
            f"(valid: {sorted(VALID_WORKER_KINDS)})"
        )
    rendered = assemble_prompt(workflow, task_context, pause_resolution=pause_resolution)
    variant_id = select_variant(workflow)
    extra: Optional[Dict[str, Any]] = None
    if retry_of_dispatch_id:
        extra = {"retry_of_dispatch_id": retry_of_dispatch_id}
    return capture_dispatch(
        task_id=task_id,
        workflow=workflow,
        rendered_prompt=rendered,
        variant_id=variant_id,
        write=not dry_run,
        extra=extra,
    )


# ---------------------------------------------------------------------------
# Task frontmatter loader (so CLI can build task_context from a real task)
# ---------------------------------------------------------------------------
def load_task_frontmatter(task_id: str) -> Dict[str, str]:
    """Read T-XXX-*.md from active/ then completed/. Extract YAML frontmatter
    + Acceptance Criteria block. Returns flat dict for $VAR substitution."""
    candidates = []
    for d in (TASKS_ACTIVE, TASKS_COMPLETED):
        if d.is_dir():
            candidates += list(d.glob(f"{task_id}-*.md"))
    if not candidates:
        return {}
    path = candidates[0]
    text = path.read_text()
    fm: Dict[str, Any] = {}
    body = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end > 0:
            try:
                fm = yaml.safe_load(text[4:end]) or {}
            except yaml.YAMLError:
                fm = {}
            body = text[end + 5 :]
    ac_block = _extract_section(body, "Acceptance Criteria")
    return {
        "TASK_ID": str(fm.get("id", task_id)),
        "TASK_NAME": str(fm.get("name", "")),
        "TASK_DESCRIPTION": str(fm.get("description", "")).strip(),
        "TASK_TYPE": str(fm.get("workflow_type", "")),
        "ACCEPTANCE_CRITERIA": ac_block.strip() or "(none)",
    }


def _extract_section(body: str, heading: str) -> str:
    """Extract a Markdown section by heading name. Returns body until next ##."""
    pattern = re.compile(
        rf"^##\s+{re.escape(heading)}\s*$(.*?)(?=^##\s|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    m = pattern.search(body)
    return m.group(1) if m else ""


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def cmd_dispatch(args: argparse.Namespace) -> int:
    """fw resolver dispatch <task_id> <task_type> [--dry-run]"""
    task_context = load_task_frontmatter(args.task_id)
    # Always provide minimum keys even when frontmatter loader returns {}
    task_context.setdefault("TASK_ID", args.task_id)
    task_context.setdefault("TASK_TYPE", args.task_type)
    task_context.setdefault("TASK_NAME", "")
    task_context.setdefault("TASK_DESCRIPTION", "")
    task_context.setdefault("ACCEPTANCE_CRITERIA", "(none)")

    # T-1737: caller-supplied --var KEY=VALUE entries extend task_context
    # so workflows like prompt-triage can reference custom $VARs in their
    # prompt template (e.g. $PROMPT_UNDER_TRIAGE).
    for kv in getattr(args, "var", []) or []:
        if "=" not in kv:
            print(f"resolver: --var must be KEY=VALUE, got {kv!r}", file=sys.stderr)
            return 1
        key, _, value = kv.partition("=")
        if not key or not VAR_PAT.fullmatch("$" + key):
            print(
                f"resolver: --var KEY must be UPPERCASE [A-Z][A-Z0-9_]*, "
                f"got {key!r}",
                file=sys.stderr,
            )
            return 1
        task_context[key] = value

    try:
        envelope, row = resolve(
            args.task_id, args.task_type, task_context, dry_run=args.dry_run
        )
    except ResolverError as e:
        print(f"resolver: error: {e}", file=sys.stderr)
        return 1
    except FileNotFoundError as e:
        print(f"resolver: file missing: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(envelope, indent=2))
    else:
        print(f"dispatch_id:    {envelope['dispatch_id']}")
        print(f"task_id:        {envelope['task_id']}")
        print(f"task_type:      {envelope['task_type']}")
        print(f"worker_kind:    {envelope['worker_kind']}")
        print(f"model:          {envelope['model']}")
        print(f"effort:         {envelope['effort']}")
        print(f"variant_id:     {envelope.get('variant_id')}")
        print(f"workflow_via:   {row['workflow_resolved_via']}")
        print(f"workflow_sha:   {row['workflow_sha']}")
        print(f"template_sha:   {row['template_sha']}")
        print(f"blob_dir:       {row['blob_dir']}")
        print(f"prompt:         {len(envelope['prompt'])} chars")
        if args.dry_run:
            print("dry-run:        no JSONL append, no blob written")
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    """fw resolver run <task_id> <task_type> — build envelope + spawn worker.

    Convenience CLI on top of `dispatch` + `lib/spawn.spawn_dispatch`. T-1774.

    Returns 0 on success, 1 on resolver/spawn errors, 2 on a worker terminal
    error (e.g. agent.done with type=error). The third exit code lets shell
    callers distinguish "infrastructure broke" from "worker reported error".
    """
    task_context = load_task_frontmatter(args.task_id)
    task_context.setdefault("TASK_ID", args.task_id)
    task_context.setdefault("TASK_TYPE", args.task_type)
    task_context.setdefault("TASK_NAME", "")
    task_context.setdefault("TASK_DESCRIPTION", "")
    task_context.setdefault("ACCEPTANCE_CRITERIA", "(none)")
    for kv in getattr(args, "var", []) or []:
        if "=" not in kv:
            print(f"resolver run: --var must be KEY=VALUE, got {kv!r}", file=sys.stderr)
            return 1
        key, _, value = kv.partition("=")
        task_context[key] = value

    try:
        envelope, _row = resolve(args.task_id, args.task_type, task_context, dry_run=False)
    except ResolverError as e:
        print(f"resolver run: error: {e}", file=sys.stderr)
        return 1

    # Lazy-import spawn so `fw resolver dispatch|workflows|explain` don't pay
    # for it (and so spawn's PiWorker import path stays cold for non-pi flows).
    try:
        import spawn  # noqa: PLC0415
    except ImportError as e:
        print(f"resolver run: cannot import lib/spawn.py: {e}", file=sys.stderr)
        return 1

    try:
        outcome = spawn.spawn_dispatch(envelope)
    except NotImplementedError as e:
        print(f"resolver run: {e}", file=sys.stderr)
        return 1
    except spawn.SpawnError as e:
        print(f"resolver run: spawn error: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(outcome, indent=2))
    else:
        print(f"dispatch_id:    {envelope['dispatch_id']}")
        print(f"task_type:      {envelope['task_type']}")
        print(f"worker_kind:    {envelope['worker_kind']}")
        print(f"status:         {outcome['status']}")
        print(f"events_count:   {outcome['events_count']}")
        print(f"events_path:    {outcome['events_path']}")
        if outcome.get("terminal_event"):
            te = outcome["terminal_event"]
            print(f"terminal:       {te.get('type')}")
            # T-1778: surface sub-fields that drive retry/error semantics
            if te.get("type") == "error" and "retryable" in te:
                print(f"retryable:      {te['retryable']}")
            elif te.get("type") == "result" and "is_error" in te:
                print(f"is_error:       {te['is_error']}")
            elif te.get("type") == "pause_requested":
                # T-1805 / ADR-0004: pause-specific fields
                if te.get("question"):
                    print(f"question:       {te['question']}")
                a = te.get("assessment")
                if isinstance(a, dict):
                    if "severity" in a:
                        print(f"severity:       {a['severity']}")
                    if "likelihood" in a:
                        print(f"likelihood:     {a['likelihood']}")
                if te.get("state_ref"):
                    print(f"state_ref:      {te['state_ref']}")

    return 2 if outcome["status"] == "error" else 0


def cmd_explain(args: argparse.Namespace) -> int:
    """fw resolver explain <dispatch_id>"""
    if not DISPATCHES_LOG.exists():
        print(f"resolver: no dispatches log at {DISPATCHES_LOG}", file=sys.stderr)
        return 1
    found = None
    with DISPATCHES_LOG.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("dispatch_id", "").startswith(args.dispatch_id):
                found = row
                # Don't break — last match wins (back-prop may have updated)
    if not found:
        print(f"resolver: no dispatch matching '{args.dispatch_id}'", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(found, indent=2))
        return 0
    print(f"dispatch_id:    {found.get('dispatch_id')}")
    print(f"ts:             {found.get('ts')}")
    print(f"task_id:        {found.get('task_id')}")
    print(f"task_type:      {found.get('task_type')}")
    print(f"workflow_id:    {found.get('workflow_id')}")
    print(f"workflow_sha:   {found.get('workflow_sha')}")
    print(f"template_sha:   {found.get('template_sha')}")
    print(f"worker_kind:    {found.get('worker_kind')}")
    print(f"model:          {found.get('model')}")
    print(f"variant_id:     {found.get('variant_id')}")
    print(f"outcome:        {found.get('outcome')}")
    # T-1778: surface terminal_event detail when persisted (T-1777+)
    te = found.get("terminal_event")
    if te:
        print(f"terminal:       {te.get('type')}")
        if te.get("type") == "error" and "retryable" in te:
            print(f"retryable:      {te['retryable']}")
        elif te.get("type") == "result" and "is_error" in te:
            print(f"is_error:       {te['is_error']}")
    # T-3030: what this worker actually wrote. Absent on rows predating the
    # field, and absent (rather than empty) when git was unreadable — see
    # spawn._writes_between on why "nothing" and "could not look" must not
    # render the same.
    writes = found.get("worker_writes")
    if writes is None:
        print("worker_writes:  (not recorded — dispatch predates T-3030)")
    else:
        paths = writes.get("paths") or []
        reverted = writes.get("reverted_paths") or []
        guarded = writes.get("clean_tree_guard", True)
        print(f"worker_writes:  {len(paths)} path(s) changed during the dispatch")
        for path in paths:
            print(f"  wrote:       {path}")
        for path in reverted:
            print(f"  reverted:    {path}")
        if not guarded:
            print(
                "  NOTE:        FW_DISPATCH_REQUIRE_CLEAN_TREE was 0 for this "
                "dispatch, so another writer may have been active in the same "
                "tree; treat these paths as correlated, not attributed."
            )
    print(f"blob_dir:       {found.get('blob_dir')}")
    blob_dir = PROJECT_ROOT / found.get("blob_dir", "")
    if blob_dir.is_dir():
        for p in sorted(blob_dir.iterdir()):
            print(f"  blob:        {p.relative_to(PROJECT_ROOT)} ({p.stat().st_size}B)")
    return 0


def cmd_list_workflows(args: argparse.Namespace) -> int:
    """fw resolver workflows — list discovered workflow files."""
    if not WORKFLOWS_DIR.is_dir():
        print(f"resolver: no workflows dir at {WORKFLOWS_DIR}", file=sys.stderr)
        return 1
    files = sorted(WORKFLOWS_DIR.glob("*.yaml"))
    if not files:
        print(f"resolver: {WORKFLOWS_DIR.relative_to(PROJECT_ROOT)} is empty")
        return 0
    for f in files:
        try:
            wf = yaml.safe_load(f.read_text()) or {}
        except yaml.YAMLError:
            print(f"  {f.name:30s}  (parse error)")
            continue
        inline = " inline" if wf.get("inline") else ""
        wk = wf.get("worker_kind", "?")
        model = wf.get("model", "?")
        print(f"  {f.name:30s}  worker={wk:10s} model={model}{inline}")
    return 0


# ---------------------------------------------------------------------------
# Autonomous task selection (T-2489) — fw resolver pick
#
# The picker is the "selection" lever off single-agent execution (T-2484 IW-4):
# enumerate active tasks, keep only those SAFE for autonomous dispatch, rank, and
# surface the top pick (dry-run by default; --dispatch fires it through the same
# resolve()+spawn path as `run`). Authority model: selection is initiative (the
# default dry-run only *proposes*); execution stays explicit (--dispatch). The
# eligibility filter is the structural guard — the picker can only ever fire
# agent-owned, scoped, non-inception work.
# ---------------------------------------------------------------------------
_DISPATCHABLE_TYPES = {"build", "test", "refactor", "decommission"}
_NON_DISPATCHABLE_TYPES = {"inception", "specification", "design"}
_ELIGIBLE_STATUS = {"started-work", "captured"}


# ---------------------------------------------------------------- BVP ranking
# T-2497: value-aware picker. The live resolver loop (resolver-loop.timer)
# dispatches the picker's top pick every tick; ranking by BVP quadrant makes the
# loop clear the HV/LC backlog by value instead of in id-order — the enabler for
# autonomous HV/LC clearance.
#
# These formulas REPLICATE lib/bvp.sh's python engine (F8-stable, documented in
# CLAUDE.md §BVP). bvp.sh embeds its math in a `python3 - <<PYEOF` heredoc and so
# is not importable; the math is mirrored here and pinned to `fw bvp` output by a
# parity test (tests/unit/t2497_resolver_bvp_rank.bats). If the F8 cost formula or
# the driver-weight model changes in bvp.sh, update here too — the parity test is
# the tripwire.
# PROJECT_ROOT deliberate (T-2648/OBS-097 allowlist): per-project policy
# instance (T-2229 --init model), parity with bvp.sh's own PROJECT_ROOT read.
_BVP_POLICY = PROJECT_ROOT / "policy" / "value-drivers.yaml"
_TSHIRT_COST = {"S": 2, "M": 4, "L": 6, "XL": 8}
# Quadrant priority for the picker: HV-LC first, then value-leaning (HV-HC before
# LV-LC), LV-HC last. Tasks with no usable BVP signal get the neutral no-data
# bucket so ranking falls back to FIFO.
_QUADRANT_RANK = {"hv-lc": 0, "hv-hc": 1, "lv-lc": 2, "lv-hc": 3}
_NO_BVP_RANK = 4
_COST_SENTINEL = 1e9


def _bvp_driver_weights() -> Dict[str, int]:
    """{driver_id: weight} from policy/value-drivers.yaml (protected + free).
    Empty when the policy file is absent/unreadable — ranking then degrades to
    FIFO (fail-open; the picker must never crash on a missing policy)."""
    if not _BVP_POLICY.is_file():
        return {}
    try:
        policy = yaml.safe_load(_BVP_POLICY.read_text()) or {}
    except yaml.YAMLError:
        return {}
    out: Dict[str, int] = {}
    for group in ("protected_drivers", "free_drivers"):
        for d in (policy.get(group) or []):
            try:
                out[d["id"]] = int(d["weight"])
            except (KeyError, TypeError, ValueError):
                continue
    return out


def _bvp_norm(scores: Any, weights: Dict[str, int]) -> Optional[float]:
    """Normalised BVP in [0,1] against 5×sum(weights-in-use). None when no driver
    overlaps (mirrors bvp.sh compute_bvp; None means 'no value signal')."""
    if not isinstance(scores, dict) or not weights:
        return None
    raw = 0
    weight_sum = 0
    for driver_id, weight in weights.items():
        if driver_id in scores:
            try:
                raw += int(scores[driver_id]) * weight
                weight_sum += weight
            except (TypeError, ValueError):
                continue
    if weight_sum == 0:
        return None
    return raw / (5 * weight_sum)


def _bvp_cost(cost_estimate: Any) -> Optional[float]:
    """F8 composite 0.6×br+0.3×tier+0.1×effort, or the T-shirt fallback. None
    when absent (mirrors bvp.sh compute_cost)."""
    if not isinstance(cost_estimate, dict):
        return None
    br, tier, effort = (cost_estimate.get(k) for k in ("blast_radius", "tier", "effort"))
    if br is not None and tier is not None and effort is not None:
        try:
            return 0.6 * float(br) + 0.3 * float(tier) + 0.1 * float(effort)
        except (TypeError, ValueError):
            pass
    size = cost_estimate.get("size")
    if size and str(size).upper() in _TSHIRT_COST:
        return float(_TSHIRT_COST[str(size).upper()])
    return None


def _bvp_latest_proposed(fm: Dict[str, Any], key: str, inner: str) -> Optional[dict]:
    """Newest entry's `inner` dict from a list-of-timestamped-entries field
    (bvp_scores_proposed / cost_estimate_proposed)."""
    lst = fm.get(key)
    if not isinstance(lst, list) or not lst:
        return None
    latest = lst[-1] if isinstance(lst[-1], dict) else None
    if not latest:
        return None
    val = latest.get(inner)
    return val if isinstance(val, dict) else None


def _bvp_value_cost(fm: Dict[str, Any], weights: Dict[str, int]) -> Tuple[Optional[float], Optional[float]]:
    """(bvp_norm, cost) for a task's frontmatter. Confirmed `bvp_scores:` first;
    falls back to the latest estimator-proposed scores/cost (advisory — matches
    `fw bvp --include-proposed`, the realistic corpus state). This is
    ordering-only and never writes, so consuming advisory inputs does not cross
    the `bvp_scores:` sovereignty boundary (T-1924)."""
    scores = fm.get("bvp_scores") or _bvp_latest_proposed(fm, "bvp_scores_proposed", "scores")
    norm = _bvp_norm(scores, weights)
    cost = _bvp_cost(fm.get("cost_estimate"))
    if cost is None:
        cost = _bvp_cost(_bvp_latest_proposed(fm, "cost_estimate_proposed", "cost_estimate"))
    return norm, cost


def _annotate_bvp_rank(metas: List[Dict[str, Any]]) -> None:
    """T-2497: attach bvp_norm / bvp_cost / _quadrant / _quadrant_rank in place.

    Quadrant boundaries use the median value/cost over the SCORED eligible tasks
    (mirroring bvp.sh cmd_rank, including its 0.5/4.0 empty-set fallbacks). Off
    when FW_RESOLVER_BVP_RANK=0 or policy/value-drivers.yaml is absent — every
    task then sits in the neutral no-data bucket and ranking is pure FIFO."""
    for m in metas:
        m["bvp_norm"] = None
        m["bvp_cost"] = None
        m["_quadrant"] = "-"
        m["_quadrant_rank"] = _NO_BVP_RANK
    if os.environ.get("FW_RESOLVER_BVP_RANK", "1") == "0":
        return
    weights = _bvp_driver_weights()
    if not weights:
        return
    scored: List[Dict[str, Any]] = []
    for m in metas:
        norm, cost = _bvp_value_cost(m.get("fm") or {}, weights)
        m["bvp_norm"] = norm
        m["bvp_cost"] = cost
        if norm is not None:
            scored.append(m)
    if not scored:
        return
    import statistics  # noqa: PLC0415

    norms = [m["bvp_norm"] for m in scored]
    costs = [m["bvp_cost"] for m in scored if m["bvp_cost"] is not None]
    bvp_median = statistics.median(norms) if norms else 0.5
    cost_median = statistics.median(costs) if costs else 4.0
    for m in scored:
        # A scored task with no cost signal can't claim to be cheap — place it on
        # the cost median (neutral) so it still lands in a defined quadrant.
        cost = m["bvp_cost"] if m["bvp_cost"] is not None else cost_median
        quad = ("hv" if m["bvp_norm"] >= bvp_median else "lv") + "-" + (
            "lc" if cost <= cost_median else "hc"
        )
        m["_quadrant"] = quad
        m["_quadrant_rank"] = _QUADRANT_RANK[quad]


def _bvp_summary(meta: Dict[str, Any]) -> Dict[str, Any]:
    """T-2497: observability payload for a pick — value/cost/quadrant as ranked.
    null fields mean the task carried no BVP signal (ranked FIFO)."""
    norm = meta.get("bvp_norm")
    cost = meta.get("bvp_cost")
    return {
        "bvp_norm": round(norm, 4) if isinstance(norm, (int, float)) else None,
        "cost": round(cost, 2) if isinstance(cost, (int, float)) else None,
        "quadrant": meta.get("_quadrant", "-"),
    }


def _read_task_meta(path: Path) -> Dict[str, Any]:
    """Parse a task .md → eligibility-relevant fields."""
    text = path.read_text()
    fm: Dict[str, Any] = {}
    body = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end > 0:
            try:
                fm = yaml.safe_load(text[4:end]) or {}
            except yaml.YAMLError:
                fm = {}
            body = text[end + 5 :]
    m = re.match(r"(T-\d+)", path.name)
    tid = str(fm.get("id") or (m.group(1) if m else path.stem))
    return {
        "id": tid,
        "name": str(fm.get("name", "")),
        "workflow_type": str(fm.get("workflow_type", "")).strip().lower(),
        "owner": str(fm.get("owner", "")).strip().lower(),
        "horizon": str(fm.get("horizon", "now")).strip().lower(),
        "status": str(fm.get("status", "")).strip().lower(),
        "ac_block": _extract_section(body, "Acceptance Criteria"),
        "path": str(path),
        "fm": fm if isinstance(fm, dict) else {},  # T-2497: BVP ranking source
    }


def _inflight_dispatch_status(max_age_min: Optional[int] = None) -> Dict[str, Dict[str, Any]]:
    """Task IDs whose most-recent dispatch row has no terminal_event, split by
    age against `max_age_min` (T-2915, default `_inflight_max_age_min()`).

    Absence of terminal_event is produced by two situations a raw predicate
    cannot distinguish: a worker still running, and a worker that died
    without ever writing one. Age is the only signal that separates them —
    a dispatch older than the bound is presumed abandoned, not running.

    Returns {task_id: {"ts", "age_min", "stale"}} for EVERY task with an
    open (terminal_event-less) latest dispatch — "stale": False is still
    in-flight (excludes from picking), "stale": True has aged out (no
    longer excludes, but is worth surfacing as an anomaly — see
    `_stale_inflight_ids`). Unparseable/missing timestamps fail OPEN (not
    in-flight) — mirrors `_recently_dispatched_ids`'s convention of never
    wrongly excluding on data this function can't interpret; a row this
    corrupt cannot be verified as recent, so it must not block forever."""
    if not DISPATCHES_LOG.exists():
        return {}
    if max_age_min is None:
        max_age_min = _inflight_max_age_min()
    latest: Dict[str, tuple] = {}  # task_id -> (ts, terminal_event)
    with DISPATCHES_LOG.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            tid = row.get("task_id")
            if not tid:
                continue
            ts = str(row.get("ts", ""))
            if tid not in latest or ts >= latest[tid][0]:
                latest[tid] = (ts, row.get("terminal_event"))

    now = datetime.now(timezone.utc)
    status: Dict[str, Dict[str, Any]] = {}
    for tid, (ts, te) in latest.items():
        if te:
            continue  # has a terminal_event — not in-flight at all
        try:
            parsed = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
        except (ValueError, TypeError):
            continue  # unparseable ts — fail open, not in-flight
        age_min = (now - parsed).total_seconds() / 60.0
        status[tid] = {
            "ts": ts,
            "age_min": round(age_min, 1),
            "stale": age_min > max_age_min,
        }
    return status


def _inflight_task_ids(max_age_min: Optional[int] = None) -> set:
    """Task IDs currently in-flight — most-recent dispatch has no
    terminal_event AND is within the age bound (T-2915). A worker cannot be
    in flight indefinitely: once a dispatch ages past `max_age_min` it is
    presumed abandoned and stops excluding its task (see
    `_stale_inflight_ids` for the surfaced-anomaly half)."""
    status = _inflight_dispatch_status(max_age_min)
    return {tid for tid, info in status.items() if not info["stale"]}


def _stale_inflight_ids(max_age_min: Optional[int] = None) -> Dict[str, Dict[str, Any]]:
    """Dispatch rows that WOULD have latched their task forever pre-T-2915 —
    no terminal_event, older than the age bound. No longer excludes from
    picking, but a nonzero/growing count means workers are dying without
    writing a terminal event, which is an operational anomaly worth
    surfacing (`fw resolver latched`, `fw doctor` Autonomous Dispatch)."""
    status = _inflight_dispatch_status(max_age_min)
    return {tid: info for tid, info in status.items() if info["stale"]}


def _recently_dispatched_ids(cooldown_min: int) -> set:
    """Task IDs whose most-recent dispatch ts is within `cooldown_min` minutes.

    Anti-thrash guard for the loop/cron (T-2491): a dispatched worker does not
    auto-advance the task's frontmatter status, and a *completed* dispatch row
    carries a terminal_event (so it is NOT in-flight). Without a cooldown the
    cron would re-dispatch the same non-advancing task every tick. Parse
    failures are skipped (fail-open — never wrongly exclude)."""
    if cooldown_min <= 0 or not DISPATCHES_LOG.exists():
        return set()
    import datetime as _dt  # noqa: PLC0415

    latest: Dict[str, str] = {}  # task_id -> max ts seen
    with DISPATCHES_LOG.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            tid = row.get("task_id")
            ts = str(row.get("ts", ""))
            if not tid or not ts:
                continue
            if tid not in latest or ts > latest[tid]:
                latest[tid] = ts

    now = _dt.datetime.now(_dt.timezone.utc)
    cooling: set = set()
    for tid, ts in latest.items():
        try:
            parsed = _dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=_dt.timezone.utc)
        except (ValueError, TypeError):
            continue
        if (now - parsed).total_seconds() < cooldown_min * 60:
            cooling.add(tid)
    return cooling


# ── Two-writer guard (T-3030, G-083) ────────────────────────────────────────
#
# The loop's worker runs `claude -p` with WorkingDirectory pinned to the MAIN
# checkout (deploy/resolver-loop.service:39), so it writes the same files, at
# the same paths, as whatever interactive session is running — no lock, no
# worktree. Until T-3030 the only separation was `_focused_task_id()` below,
# and a single advisory slot cannot carry that load: it names ONE task when a
# session holds several, `update-task.sh:2044-2055` nulls it on every full
# completion, and it is read once at pick time and never re-checked.
#
# On 2026-08-16 a worker was dispatched onto T-3028 four seconds after a tick
# that found focus null — nulled by the close path itself — while the session
# was mid-reconciliation on that very task. Both wrote update-task.sh.
#
# So the guard here is EVIDENCE, not declaration: a dirty working tree is
# proof someone is mid-edit, and it cannot be nulled by a code path that
# thinks the work is done. In the origin incident T-3028's task file was an
# uncommitted rename back into active/ at pick time (deducible from
# `_select_eligible`'s glob of TASKS_ACTIVE plus b0f6091cc landing that rename
# 35 minutes later), so this guard would have excluded it.

# Machine-written churn. These are dirty on essentially every tick — counters,
# session metrics, generated docs, vendored mirror — and say nothing about
# whether anyone is mid-edit. Without this list the guard would read the tree
# as permanently busy and silently disable autonomy, which is a worse failure
# than the one it prevents because it looks like "nothing to do".
_CHURN_PREFIXES = (
    ".context/working/",
    ".context/audits/",
    ".context/monitors/",
    ".context/handovers/",
    ".context/episodic/",
    ".context/inbox.yaml",
    ".context/dispatches.jsonl",
    ".context/dispatch-outcomes.jsonl",
    ".context/project/metrics-history.yaml",
    ".agentic-framework/",
    "docs/generated/",
    "VERSION",
)


def _dirty_paths() -> List[str]:
    """Tracked files with uncommitted changes, minus the machine-churn set.

    Fails OPEN on any git error: a guard that cannot read the tree must not
    latch the loop off, because a permanently-excluded task is indistinguishable
    from an empty backlog in the journal."""
    try:
        proc = subprocess.run(
            [
                "git", "-C", str(PROJECT_ROOT), "status",
                "--porcelain", "--untracked-files=no",
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.SubprocessError):
        return []
    if proc.returncode != 0:
        return []
    out: List[str] = []
    for line in proc.stdout.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].strip()
        if " -> " in path:  # rename: the destination is the live path
            path = path.split(" -> ", 1)[1]
        path = path.strip('"')
        if path.startswith(_CHURN_PREFIXES):
            continue
        out.append(path)
    return out


def _dirty_task_ids(paths: List[str]) -> set:
    """Task IDs whose own .tasks/ file is uncommitted — someone is editing it."""
    ids = set()
    for path in paths:
        match = re.search(r"\.tasks/(?:active|completed)/(T-\d+)", path)
        if match:
            ids.add(match.group(1))
    return ids


def _focused_task_id() -> str:
    """The task currently in focus.yaml — excluded from picking so the picker
    never dispatches the task the main agent is actively working.

    Retained as a first line of defence, but see the T-3030 comment above: it
    is advisory and the completion path nulls it. `_dirty_paths()` is the guard
    that holds when this one does not."""
    focus = PROJECT_ROOT / ".context" / "working" / "focus.yaml"
    if not focus.exists():
        return ""
    try:
        data = yaml.safe_load(focus.read_text()) or {}
    except yaml.YAMLError:
        return ""
    return str(data.get("current_task") or "").strip()


def _ac_is_placeholder(ac_block: str) -> bool:
    """True when the Acceptance Criteria block is template-only / unscoped —
    mirrors the G-020 readiness gate's intent (don't dispatch unscoped work)."""
    s = ac_block.strip()
    if not s:
        return True
    if "[First criterion]" in s or "[Second criterion]" in s:
        return True
    # Must have at least one real unchecked item to be worth dispatching.
    if not re.search(r"-\s*\[\s*\]\s+\S", s):
        return True
    return False


def _pick_eligibility(meta: Dict[str, Any], inflight: set, focused: str = "") -> Optional[str]:
    """Return None if the task is eligible for autonomous dispatch, else a
    one-line exclusion reason."""
    if focused and meta["id"] == focused:
        return "in focus (main agent working it)"
    wt = meta["workflow_type"]
    if wt in _NON_DISPATCHABLE_TYPES:
        return f"workflow_type={wt} (needs human decision)"
    if not wt:
        return "no workflow_type"
    if wt not in _DISPATCHABLE_TYPES:
        return f"workflow_type={wt} (not auto-dispatchable)"
    if meta["owner"] == "human":
        return "owner=human"
    if meta["horizon"] == "later":
        return "horizon=later"
    if meta["status"] not in _ELIGIBLE_STATUS:
        return f"status={meta['status']}"
    if _ac_is_placeholder(meta["ac_block"]):
        return "placeholder/unscoped ACs"
    if meta["id"] in inflight:
        return "in-flight dispatch"
    return None


def _pick_rank_key(meta: Dict[str, Any]) -> tuple:
    """Deterministic ranking (T-2497 BVP-aware).

    WIP-reduction and horizon lead — finish started-work, prefer horizon=now —
    so the picker never abandons in-flight work for a shinier new task. WITHIN a
    (status, horizon) tier it ranks by BVP quadrant (HV-LC first), then value
    descending and cost ascending, so the live loop grinds the HV/LC backlog by
    value. FIFO oldest-id is the final tiebreak. When no BVP data is present every
    task shares the neutral no-data bucket and value/cost are constant, so this
    reduces exactly to the original status→horizon→id FIFO order."""
    status_rank = 0 if meta["status"] == "started-work" else 1
    horizon_rank = 0 if meta["horizon"] == "now" else 1
    quad_rank = meta.get("_quadrant_rank", _NO_BVP_RANK)
    norm = meta.get("bvp_norm")
    value_key = -norm if norm is not None else 0.0  # higher value first
    cost = meta.get("bvp_cost")
    cost_key = cost if cost is not None else _COST_SENTINEL  # lower cost first
    m = re.search(r"T-(\d+)", meta["id"])
    idnum = int(m.group(1)) if m else 0
    return (status_rank, horizon_rank, quad_rank, value_key, cost_key, idnum)


def _require_clean_tree() -> bool:
    """Whether a hand-edited working tree blocks ALL dispatch (T-3030).

    Per-task dirtiness always excludes that task — that is not negotiable and
    has no switch. This controls the wider claim: that ANY uncommitted source
    change means an interactive session is mid-work in the shared tree, so the
    worker has no safe file to write. Default on. An operator running fully
    unattended with a permanently dirty checkout can set
    FW_DISPATCH_REQUIRE_CLEAN_TREE=0, and the loop reports what it skipped
    either way — a guard that silently declines is the failure mode of the one
    it replaces."""
    return os.environ.get("FW_DISPATCH_REQUIRE_CLEAN_TREE", "1").strip() != "0"


def _select_eligible(
    claimed: Optional[set] = None, cooldown_min: int = 0, stall_after: int = 0
) -> tuple:
    """Return (eligible_sorted, excluded) — excluded is list of (id, reason).

    `claimed` (T-2491): task ids already picked earlier in the SAME loop run —
    excluded so a single invocation never re-picks the same task (a completed
    dispatch leaves frontmatter status unchanged, so the eligibility filter
    alone would re-select it). `cooldown_min` (T-2491): exclude tasks dispatched
    within the window — cross-tick anti-thrash. `stall_after` (T-2914): exclude
    tasks that have not advanced across the last N dispatches (defect 1 —
    without this, cooldown alone cannot bound a task no worker can finish; it
    just delays the next of an unbounded number of retries). All three default
    off, so the single-shot `cmd_pick` caller with no flags is unchanged."""
    inflight = _inflight_task_ids()
    if claimed:
        inflight = inflight | set(claimed)
    focused = _focused_task_id()
    cooling = _recently_dispatched_ids(cooldown_min) if cooldown_min > 0 else set()
    stalled = _stalled_task_ids(stall_after) if stall_after > 0 else {}
    # T-3030 / G-083: evidence-based two-writer guard. See _dirty_paths().
    dirty = _dirty_paths()
    dirty_ids = _dirty_task_ids(dirty)
    busy_paths = [p for p in dirty if not p.startswith(".tasks/")]
    tree_busy = bool(busy_paths) and _require_clean_tree()
    eligible: List[Dict[str, Any]] = []
    excluded: List[tuple] = []
    for path in sorted(TASKS_ACTIVE.glob("T-*.md")):
        meta = _read_task_meta(path)
        reason = _pick_eligibility(meta, inflight, focused)
        # T-3030: dirtiness before cooldown/stall — it is the strongest signal
        # of a live second writer, and naming it first makes the journal say
        # WHY a busy tick found nothing.
        if reason is None and meta["id"] in dirty_ids:
            reason = "task file uncommitted (a session is editing it)"
        if reason is None and tree_busy:
            shown = ", ".join(sorted(busy_paths)[:3])
            more = f" +{len(busy_paths) - 3} more" if len(busy_paths) > 3 else ""
            reason = (
                f"working tree has uncommitted changes ({shown}{more}) — a worker "
                f"would write the same tree; set FW_DISPATCH_REQUIRE_CLEAN_TREE=0 "
                f"to dispatch anyway"
            )
        if reason is None and meta["id"] in cooling:
            reason = f"cooldown (<{cooldown_min}m since last dispatch)"
        if reason is None and meta["id"] in stalled:
            info = stalled[meta["id"]]
            reason = (
                f"stalled ({info['dispatch_count']} dispatches since "
                f"{info['since']}, {info['outcome_count']} outcomes, no advancement)"
            )
        if reason is None:
            eligible.append(meta)
        else:
            excluded.append((meta["id"], reason))
    _annotate_bvp_rank(eligible)  # T-2497: attach bvp_norm/cost/quadrant in place
    eligible.sort(key=_pick_rank_key)
    return eligible, excluded


def _pick_workflow_type(meta: Dict[str, Any]) -> str:
    """Use a per-type workflow file if one exists, else the default workflow."""
    wt = meta["workflow_type"]
    if wt and (WORKFLOWS_DIR / f"{wt}.yaml").exists():
        return wt
    return "default"


def cmd_pick(args: argparse.Namespace) -> int:
    """fw resolver pick [--dispatch] [--stall-after N] [--json] — autonomous task selection."""
    if not TASKS_ACTIVE.is_dir():
        print(f"resolver pick: no active tasks dir at {TASKS_ACTIVE}", file=sys.stderr)
        return 1
    eligible, excluded = _select_eligible(stall_after=max(0, int(getattr(args, "stall_after", 0))))
    pick = eligible[0] if eligible else None
    chosen_type = _pick_workflow_type(pick) if pick else None

    if not pick:
        if args.json:
            print(json.dumps({
                "eligible": [], "pick": None, "reason": "no eligible tasks",
                "excluded": dict(excluded), "dispatched": False,
            }, indent=2))
        else:
            print("resolver pick: no eligible tasks for autonomous dispatch")
            if excluded:
                print(f"  ({len(excluded)} active task(s) excluded — --json for reasons)")
        return 0

    if not args.dispatch:
        if args.json:
            print(json.dumps({
                "eligible": [m["id"] for m in eligible],
                "pick": pick["id"], "workflow": chosen_type,
                "reason": f"status={pick['status']}, horizon={pick['horizon']}, "
                          f"quadrant={pick.get('_quadrant', '-')}",
                "bvp": _bvp_summary(pick),
                "excluded": dict(excluded), "dispatched": False,
            }, indent=2))
        else:
            print(f"Eligible for autonomous dispatch ({len(eligible)}):")
            for m in eligible:
                marker = "→" if m["id"] == pick["id"] else " "
                quad = m.get("_quadrant", "-")
                print(f"  {marker} {m['id']:8s} [{m['status']}/{m['horizon']}] "
                      f"{quad:>5s} {m['name'][:54]}")
            print()
            print(f"Top pick:  {pick['id']}  →  workflow '{chosen_type}'")
            print(f"Dispatch:  bin/fw resolver pick --dispatch")
        return 0

    # --dispatch: fire the top pick via resolve + spawn (parity with cmd_run).
    task_id, task_type = pick["id"], chosen_type
    task_context = load_task_frontmatter(task_id)
    task_context.setdefault("TASK_ID", task_id)
    task_context.setdefault("TASK_TYPE", task_type)
    task_context.setdefault("TASK_NAME", "")
    task_context.setdefault("TASK_DESCRIPTION", "")
    task_context.setdefault("ACCEPTANCE_CRITERIA", "(none)")
    try:
        envelope, _row = resolve(task_id, task_type, task_context, dry_run=False)
    except ResolverError as e:
        print(f"resolver pick: error: {e}", file=sys.stderr)
        return 1
    try:
        import spawn  # noqa: PLC0415
    except ImportError as e:
        print(f"resolver pick: cannot import lib/spawn.py: {e}", file=sys.stderr)
        return 1
    try:
        outcome = spawn.spawn_dispatch(envelope)
    except NotImplementedError as e:
        print(f"resolver pick: {e}", file=sys.stderr)
        return 1
    except spawn.SpawnError as e:
        print(f"resolver pick: spawn error: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps({
            "eligible": [m["id"] for m in eligible],
            "pick": task_id, "workflow": task_type,
            "bvp": _bvp_summary(pick),
            "excluded": dict(excluded), "dispatched": True, "outcome": outcome,
        }, indent=2, default=str))
    else:
        print(f"Picked + dispatched: {task_id} (workflow '{task_type}')")
        print(f"dispatch_id:    {envelope['dispatch_id']}")
        print(f"status:         {outcome['status']}")
        print(f"events_count:   {outcome['events_count']}")
        if outcome.get("terminal_event"):
            te = outcome["terminal_event"]
            print(f"terminal:       {te.get('type')}")
            if te.get("type") == "result" and "is_error" in te:
                print(f"is_error:       {te['is_error']}")
    return 2 if outcome["status"] == "error" else 0


def _dispatch_one(pick: Dict[str, Any], chosen_type: str) -> tuple:
    """Resolve + spawn a single pick. Returns (envelope, outcome). Raises
    ResolverError / spawn.SpawnError / NotImplementedError / ImportError on
    failure — caller decides whether to stop the loop. Mirrors cmd_pick's
    --dispatch path so loop and single-shot share one dispatch contract."""
    task_id, task_type = pick["id"], chosen_type
    task_context = load_task_frontmatter(task_id)
    task_context.setdefault("TASK_ID", task_id)
    task_context.setdefault("TASK_TYPE", task_type)
    task_context.setdefault("TASK_NAME", "")
    task_context.setdefault("TASK_DESCRIPTION", "")
    task_context.setdefault("ACCEPTANCE_CRITERIA", "(none)")
    envelope, _row = resolve(task_id, task_type, task_context, dry_run=False)
    import spawn  # noqa: PLC0415

    outcome = spawn.spawn_dispatch(envelope)
    return envelope, outcome


def cmd_loop(args: argparse.Namespace) -> int:
    """fw resolver loop — bounded autonomous dispatch driver (T-2491).

    Calls the picker up to --max times. Dry-run by default (surfaces the plan);
    --dispatch fires each pick through resolve+spawn. An in-run `claimed` set
    keeps a single invocation from re-picking the same task; --cooldown-min
    blocks cross-tick re-dispatch within a short window (single-invocation
    anti-thrash — NOT a bound on repeat count, see T-2914 defect 1/3);
    --stall-after (T-2914) is the actual non-convergence guard — it excludes a
    task once N consecutive dispatches produced no measurable advancement,
    regardless of how much time has passed. Stops early on no eligible work
    or a dispatch error."""
    if not TASKS_ACTIVE.is_dir():
        print(f"resolver loop: no active tasks dir at {TASKS_ACTIVE}", file=sys.stderr)
        return 1
    max_iter = max(1, int(args.max))
    cooldown = max(0, int(args.cooldown_min))
    stall_after = max(0, int(getattr(args, "stall_after", 0)))
    claimed: set = set()
    results: List[Dict[str, Any]] = []
    stop_reason = f"reached --max ({max_iter})"
    in_flight_n = 0  # T-2915 AC3: last-observed in-flight exclusion count

    for i in range(max_iter):
        eligible, _excluded = _select_eligible(
            claimed=claimed, cooldown_min=cooldown, stall_after=stall_after
        )
        pick = eligible[0] if eligible else None
        if not pick:
            in_flight_n = sum(1 for _id, r in _excluded if r == "in-flight dispatch")
            if i > 0:
                stop_reason = "no more eligible tasks"
            elif in_flight_n:
                # T-2915: name the cause instead of a silence identical to
                # "everything is done" — the exact ambiguity that let nine
                # tasks sit unpicked for five weeks with no distinguishing
                # signal in `dispatched 0`.
                stop_reason = (
                    f"no eligible tasks — {in_flight_n} in-flight "
                    f"(worker presumed still running; frees on completion "
                    f"or after {_inflight_max_age_min()}m)"
                )
            elif _excluded:
                stop_reason = (
                    f"no eligible tasks — {len(_excluded)} excluded, none "
                    f"in-flight (see --json excluded reasons or `fw resolver "
                    f"pick --json`)"
                )
            else:
                stop_reason = "no eligible tasks — nothing to do (no active tasks match)"
            break
        chosen_type = _pick_workflow_type(pick)
        claimed.add(pick["id"])  # never re-pick within this run, dispatched or not

        if not args.dispatch:
            results.append({"id": pick["id"], "workflow": chosen_type, "dispatched": False})
            continue

        try:
            envelope, outcome = _dispatch_one(pick, chosen_type)
        except ResolverError as e:
            results.append({"id": pick["id"], "dispatched": False, "error": f"resolve: {e}"})
            stop_reason = "resolve error (stopping loop)"
            break
        except NotImplementedError as e:
            results.append({"id": pick["id"], "dispatched": False, "error": str(e)})
            stop_reason = "spawn not implemented (stopping loop)"
            break
        except Exception as e:  # spawn.SpawnError / ImportError / unexpected
            results.append({"id": pick["id"], "dispatched": False, "error": f"spawn: {e}"})
            stop_reason = "spawn error (stopping loop)"
            break

        results.append({
            "id": pick["id"], "workflow": chosen_type,
            "dispatch_id": envelope["dispatch_id"],
            "dispatched": True, "status": outcome["status"],
        })
        if outcome["status"] == "error":
            stop_reason = "dispatch returned error (stopping loop)"
            break

    dispatched_n = sum(1 for r in results if r.get("dispatched"))
    had_error = any(r.get("status") == "error" or "error" in r for r in results)

    if args.json:
        print(json.dumps({
            "max": max_iter, "dispatch": bool(args.dispatch), "cooldown_min": cooldown,
            "stall_after": stall_after,
            "picked": results, "dispatched_count": dispatched_n,
            "stop_reason": stop_reason,
            "in_flight_count": in_flight_n,  # T-2915 AC3
        }, indent=2, default=str))
    else:
        mode = "DISPATCH" if args.dispatch else "DRY-RUN"
        print(f"resolver loop [{mode}]  max={max_iter}  cooldown={cooldown}m  stall-after={stall_after}")
        if not results:
            print(f"  nothing to do — {stop_reason}")
        for r in results:
            if r.get("dispatched"):
                did = str(r.get("dispatch_id", ""))[:12]
                print(f"  ✓ {r['id']:8s} → {r['workflow']:10s} dispatch={did} status={r.get('status')}")
            elif "error" in r:
                print(f"  ✗ {r['id']:8s} error: {r['error']}")
            else:
                print(f"  • {r['id']:8s} → {r['workflow']:10s} (would dispatch)")
        print(f"  stop: {stop_reason}; dispatched {dispatched_n}")
    return 2 if had_error else 0


def cmd_stalled(args: argparse.Namespace) -> int:
    """fw resolver stalled [--stall-after N] [--json] — surface (T-2914 defect
    1 + 6) the non-advancing/zero-outcome tasks the loop is refusing to
    re-dispatch. This is the "surfaced instead" half of AC1: exclusion alone
    is silent unless something prints it."""
    stall_after = max(1, int(args.stall_after))
    stalled = _stalled_task_ids(stall_after)
    cov = _stall_coverage(stall_after)
    if args.json:
        print(json.dumps(
            {"stall_after": stall_after, "coverage": cov, "stalled": stalled},
            indent=2, default=str,
        ))
        return 0
    # T-2916: coverage prints on BOTH paths, verdict-first or not. The whole
    # defect was a verdict with no denominator — "no tasks stalled" read as
    # success while the guard had abstained on every task it was given.
    cov_line = (
        f"  evaluated {cov['evaluated']}/{cov['tasks_seen']} task(s) "
        f"({cov['below_threshold']} below threshold, {cov['inactive']} not active)"
    )
    if not stalled:
        print(f"resolver stalled: no tasks stalled at threshold {stall_after}")
        print(cov_line)
        return 0
    print(f"Stalled tasks (>= {stall_after} dispatches, no advancement):")
    for tid, info in sorted(stalled.items()):
        print(
            f"  {tid:8s} dispatches={info['dispatch_count']:<4d} "
            f"outcomes={info['outcome_count']:<3d} evidence={info.get('evidence','?'):<8s} "
            f"since={info['since']}"
        )
    print(cov_line)
    return 0


def cmd_latched(args: argparse.Namespace) -> int:
    """fw resolver latched [--max-age-min N] [--json] — surface (T-2915 AC5)
    dispatch rows with no terminal_event older than the in-flight age bound.
    These no longer exclude their task from picking (see
    `_inflight_task_ids`), but a nonzero/growing count means a worker died
    without writing a terminal event — an operational anomaly, distinct from
    a worker that is still genuinely running."""
    max_age = max(1, int(args.max_age_min)) if args.max_age_min else _inflight_max_age_min()
    stale = _stale_inflight_ids(max_age)
    if args.json:
        print(json.dumps({"max_age_min": max_age, "latched": stale}, indent=2, default=str))
        return 0
    if not stale:
        print(f"resolver latched: no stale in-flight dispatches (threshold {max_age}m)")
        return 0
    print(f"Stale in-flight dispatches (no terminal_event, older than {max_age}m):")
    for tid, info in sorted(stale.items()):
        print(f"  {tid:8s} age={info['age_min']:>8.1f}m  last_dispatch={info['ts']}")
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="fw resolver",
        description="Workflow lookup + prompt assembly + telemetry capture.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sp_d = sub.add_parser("dispatch", help="Build a dispatch envelope (read task frontmatter)")
    sp_d.add_argument("task_id", help="Task ID (e.g. T-1696)")
    sp_d.add_argument("task_type", help="Workflow task_type (or 'default')")
    sp_d.add_argument("--dry-run", action="store_true", help="Skip JSONL append and blob write")
    sp_d.add_argument("--json", action="store_true", help="Emit envelope as JSON")
    sp_d.add_argument(
        "--var",
        action="append",
        default=[],
        metavar="KEY=VALUE",
        help=(
            "Inject a custom $VAR into the prompt template. KEY must be "
            "UPPERCASE (e.g. --var PROMPT_UNDER_TRIAGE='hello'). May be "
            "repeated. Required for workflows that reference template-"
            "specific vars beyond TASK_ID/TASK_NAME/TASK_DESCRIPTION/"
            "TASK_TYPE/ACCEPTANCE_CRITERIA. (T-1737)"
        ),
    )
    sp_d.set_defaults(func=cmd_dispatch)

    sp_r = sub.add_parser("run", help="Build envelope + spawn worker (T-1774)")
    sp_r.add_argument("task_id", help="Task ID (e.g. T-1773)")
    sp_r.add_argument("task_type", help="Workflow task_type (or 'default')")
    sp_r.add_argument("--json", action="store_true", help="Emit outcome dict as JSON")
    sp_r.add_argument(
        "--var",
        action="append",
        default=[],
        metavar="KEY=VALUE",
        help="Inject custom $VAR into the prompt template (same as `dispatch`).",
    )
    sp_r.set_defaults(func=cmd_run)

    sp_e = sub.add_parser("explain", help="Print a dispatch row by ID prefix")
    sp_e.add_argument("dispatch_id", help="Dispatch UUID (or prefix)")
    sp_e.add_argument("--json", action="store_true", help="Emit row as JSON")
    sp_e.set_defaults(func=cmd_explain)

    sp_w = sub.add_parser("workflows", help="List configured workflows")
    sp_w.set_defaults(func=cmd_list_workflows)

    sp_p = sub.add_parser(
        "pick",
        help="Autonomously select an eligible task; dry-run surface or --dispatch (T-2489)",
    )
    sp_p.add_argument(
        "--dispatch",
        action="store_true",
        help="Fire the top pick through resolve+spawn (default: dry-run surface only)",
    )
    sp_p.add_argument(
        "--stall-after",
        type=int,
        default=0,
        dest="stall_after",
        help="Exclude a task once it has N consecutive non-advancing dispatches "
             "(default 0 = off, T-2914)",
    )
    sp_p.add_argument("--json", action="store_true", help="Emit selection (and outcome) as JSON")
    sp_p.set_defaults(func=cmd_pick)

    sp_l = sub.add_parser(
        "loop",
        help="Bounded autonomous dispatch driver — pick up to --max times (T-2491)",
    )
    sp_l.add_argument("--max", type=int, default=3, help="Max distinct tasks to pick/dispatch (default 3)")
    sp_l.add_argument(
        "--dispatch",
        action="store_true",
        help="Fire each pick through resolve+spawn (default: dry-run plan only)",
    )
    sp_l.add_argument(
        "--cooldown-min",
        type=int,
        default=0,
        dest="cooldown_min",
        help="Exclude tasks dispatched within N minutes — single-invocation "
             "anti-thrash only, NOT a repeat-count bound (default 0 = off; "
             "see --stall-after for the non-convergence guard, T-2914)",
    )
    sp_l.add_argument(
        "--stall-after",
        type=int,
        default=_DEFAULT_STALL_AFTER,
        dest="stall_after",
        help=f"Exclude a task once it has N consecutive non-advancing dispatches "
             f"(default {_DEFAULT_STALL_AFTER}, T-2914). 0 disables the guard.",
    )
    sp_l.add_argument("--json", action="store_true", help="Emit loop plan/outcome as JSON")
    sp_l.set_defaults(func=cmd_loop)

    sp_s = sub.add_parser(
        "stalled",
        help="List tasks excluded by the non-convergence guard (T-2914)",
    )
    sp_s.add_argument(
        "--stall-after",
        type=int,
        default=_DEFAULT_STALL_AFTER,
        dest="stall_after",
        help=f"Threshold to check against (default {_DEFAULT_STALL_AFTER})",
    )
    sp_s.add_argument("--json", action="store_true", help="Emit as JSON")
    sp_s.set_defaults(func=cmd_stalled)

    sp_lt = sub.add_parser(
        "latched",
        help="List tasks whose in-flight latch has aged out — abandoned "
             "dispatches with no terminal_event (T-2915)",
    )
    sp_lt.add_argument(
        "--max-age-min",
        type=int,
        default=0,
        dest="max_age_min",
        help=f"Age bound in minutes (default {_INFLIGHT_MAX_AGE_MIN_DEFAULT}, "
             f"or FW_RESOLVER_INFLIGHT_MAX_AGE_MIN)",
    )
    sp_lt.add_argument("--json", action="store_true", help="Emit as JSON")
    sp_lt.set_defaults(func=cmd_latched)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
