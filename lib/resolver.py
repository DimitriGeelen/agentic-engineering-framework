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
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import yaml


PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd()))
WORKFLOWS_DIR = PROJECT_ROOT / ".context" / "project" / "workflows"
DISPATCHES_LOG = PROJECT_ROOT / ".context" / "dispatches.jsonl"
BLOBS_ROOT = PROJECT_ROOT / ".context" / "dispatch-blobs"
PATTERNS_YAML = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
EXAMPLES_ROOT = PROJECT_ROOT / "prompts" / "examples"
TASKS_ACTIVE = PROJECT_ROOT / ".tasks" / "active"
TASKS_COMPLETED = PROJECT_ROOT / ".tasks" / "completed"

DISPATCH_SCHEMA_VERSION = 1
VAR_PAT = re.compile(r"\$([A-Z][A-Z0-9_]*)")

# NOTE: keep in sync with bin/fw:1804 (T-1734). Two tables drifted before: bin/fw
# accepted "ollama-loop" while this one didn't, so workflows listed cleanly but
# failed at dispatch. If you add a worker_kind here, add it there too (and vice versa).
VALID_WORKER_KINDS = {"Task", "TermLink", "pi", "ollama-loop"}
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
# Telemetry capture (dispatches.jsonl + blob dir)
# ---------------------------------------------------------------------------
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
        "dry_run": (not write) or None,
    }
    if row["dry_run"] is None:
        del row["dry_run"]
    if extra:
        row.update(extra)

    if write:
        DISPATCHES_LOG.parent.mkdir(parents=True, exist_ok=True)
        # O_APPEND is atomic for small writes (<= PIPE_BUF, ~4KB) on POSIX.
        # Per-line JSON keeps each dispatch self-contained.
        with DISPATCHES_LOG.open("a") as f:
            f.write(json.dumps(row) + "\n")

    cwd_template = workflow.get("cwd", "$PROJECT_ROOT")
    cwd_resolved = cwd_template.replace("$PROJECT_ROOT", str(PROJECT_ROOT))

    envelope = {
        "dispatch_id": dispatch_id,
        "task_id": task_id,
        "task_type": row["task_type"],
        "worker_kind": workflow.get("worker_kind"),
        "model": workflow.get("model"),
        "effort": workflow.get("effort"),
        "prompt": rendered_prompt,
        "allowed_tools": workflow.get("allowed_tools", []),
        "cost_cap_usd": workflow.get("cost_cap_usd"),
        "cwd": cwd_resolved,
        "env": workflow.get("env", {}),
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

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
