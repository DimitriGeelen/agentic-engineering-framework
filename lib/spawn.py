#!/usr/bin/env python3
"""
spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome.

T-1773 v1 ships pi-only routing. Other worker kinds (ollama-loop, TermLink,
Task) raise NotImplementedError with explicit deferral messages — premature
unification is the trap T-1700 + T-1701 explicitly avoided. Once a second
worker primitive matures (likely an ollama-loop primitive in `lib/ollama_loop.py`),
extend `_DISPATCHERS` rather than rewriting.

Envelope contract (built by `lib/resolver.py:capture_dispatch`):
  dispatch_id, task_id, task_type, worker_kind, model, effort, prompt,
  allowed_tools, cost_cap_usd, cwd, env, blob_dir, variant_id

`provider` is NOT in the envelope (it's pi-specific). For pi dispatches,
`_spawn_pi` re-loads the workflow YAML to obtain it. This keeps resolver.py
worker-kind-agnostic.

Outcome contract (returned by `spawn_dispatch`):
  {"status": "success"|"error",
   "events_count": int,
   "events_path": str,
   "terminal_event": dict | None}

Side effects:
  - <blob_dir>/events.jsonl is created with one event per line
  - .context/dispatches.jsonl row matching dispatch_id has outcome rewritten

Origin: T-1700 + T-1701 build reports both deferred this driver. T-1773 ships
the pi route to close the orchestrator-rethink arc's headline mechanic.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any, Callable, Dict, Optional

# Sibling-import lib/pi_worker.py without forcing callers to manage sys.path.
_LIB_DIR = Path(__file__).resolve().parent
if str(_LIB_DIR) not in sys.path:
    sys.path.insert(0, str(_LIB_DIR))

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd()))
DISPATCHES_LOG = PROJECT_ROOT / ".context" / "dispatches.jsonl"
WORKFLOWS_DIR = PROJECT_ROOT / ".context" / "project" / "workflows"

# T-1805 / ADR-0004 — dispatch-safety slice 1: substrate recognition for pause.
# Worker emits a `pause_requested` terminal event when severity x likelihood of
# being-wrong crosses the workflow's pause_threshold. Dispatch outcome status
# becomes `paused` (joins `success` and `error`). Resolver-injected envelope
# preamble (slice 2) instructs Workers when to emit; this slice only teaches
# the substrate to *recognize* it.
_PAUSE_EVENT_TYPE = "pause_requested"
_VALID_OUTCOME_STATUSES = frozenset({"success", "error", "paused"})


class SpawnError(Exception):
    """Raised when spawn-side prerequisites fail (workflow not found, pi
    missing, malformed envelope)."""


def _classify_status(terminal: Optional[Dict[str, Any]]) -> str:
    """Map a terminal event to one of {success, error, paused}.

    Pause takes precedence over error/success: a paused Worker has not yet
    attempted the work — the pause is a structured deferral, not an outcome
    of attempted work. See ADR-0004.

    Contract:
      - terminal_event.type == "pause_requested" → "paused"
      - terminal_event.type == "error" → "error"
      - terminal_event.type == "result" and is_error is True → "error"
      - anything else (or no terminal) → "success"
    """
    if not terminal:
        return "success"
    ttype = terminal.get("type")
    if ttype == _PAUSE_EVENT_TYPE:
        return "paused"
    if ttype == "error":
        return "error"
    if ttype == "result" and terminal.get("is_error") is True:
        return "error"
    return "success"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
def spawn_dispatch(
    envelope: Dict[str, Any],
    *,
    on_event: Optional[Callable[[Dict[str, Any]], None]] = None,
) -> Dict[str, Any]:
    """Execute a resolver envelope. Returns final outcome dict.

    Routes by ``envelope["worker_kind"]``. For each event:
      - appended to <blob_dir>/events.jsonl
      - on_event callback called (if provided)
      - prompt() loop terminates on agent.done or error

    The matching dispatches.jsonl row's outcome is updated in-place at the end
    (success / error). If the dispatches.jsonl row is missing (e.g. dry-run
    envelope), the spawn still succeeds and returns the outcome dict; the
    caller can persist if needed.
    """
    wk = envelope.get("worker_kind")
    handler = _DISPATCHERS.get(wk)
    if handler is None:
        if wk == "Task":
            raise NotImplementedError(
                f"spawn driver: worker_kind={wk!r} not yet routed "
                f"(T-1773 v1 ships pi only; T-1775 added ollama-loop; "
                f"T-1797 added TermLink; Task scheduled for follow-up)"
            )
        raise SpawnError(
            f"spawn driver: unknown worker_kind={wk!r}; "
            f"valid set is in lib/resolver.py:VALID_WORKER_KINDS"
        )

    outcome = handler(envelope, on_event)
    extra = {"events_count": outcome["events_count"]}
    # T-1777: persist terminal_event into dispatch row so `fw outcome read`
    # can surface the result without cracking open events.jsonl. Omitted when
    # None (e.g. timeout/crash mid-stream produced no terminal event).
    if outcome.get("terminal_event") is not None:
        extra["terminal_event"] = outcome["terminal_event"]
    update_outcome_row(envelope.get("dispatch_id", ""), outcome["status"],
                       extra=extra)
    return outcome


def update_outcome_row(
    dispatch_id: str,
    outcome: str,
    extra: Optional[Dict[str, Any]] = None,
) -> bool:
    """Find the row in dispatches.jsonl with matching dispatch_id; rewrite
    the file with the updated row's outcome field. Returns True if updated.

    Atomic via tmp + os.replace so a crash mid-rewrite leaves the original
    intact. Returns False (no-op) when dispatch_id missing or log absent.
    """
    if not dispatch_id or not DISPATCHES_LOG.exists():
        return False

    rows = []
    found = False
    with DISPATCHES_LOG.open() as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                rows.append(line)  # preserve malformed lines verbatim
                continue
            if row.get("dispatch_id") == dispatch_id:
                row["outcome"] = outcome
                if extra:
                    row.update(extra)
                found = True
            rows.append(json.dumps(row) if isinstance(row, dict) else row)

    if not found:
        return False

    tmp = DISPATCHES_LOG.with_suffix(DISPATCHES_LOG.suffix + f".tmp.{os.getpid()}")
    tmp.write_text("\n".join(rows) + "\n")
    os.replace(tmp, DISPATCHES_LOG)
    return True


# ---------------------------------------------------------------------------
# Per-worker handlers
# ---------------------------------------------------------------------------
def _spawn_pi(
    envelope: Dict[str, Any],
    on_event: Optional[Callable[[Dict[str, Any]], None]],
) -> Dict[str, Any]:
    """Spawn pi via lib/pi_worker.PiWorker, stream events to blob_dir."""
    import pi_worker  # noqa: PLC0415 — deferred so module imports without pi

    provider = envelope.get("provider") or _provider_from_workflow(envelope)
    if not provider:
        raise SpawnError(
            "pi route requires `provider` field; not in envelope and not in "
            f"workflow file for task_type={envelope.get('task_type')!r}"
        )

    blob_dir = _resolve_blob_dir(envelope)
    blob_dir.mkdir(parents=True, exist_ok=True)
    events_path = blob_dir / "events.jsonl"

    terminal: Optional[Dict[str, Any]] = None
    count = 0
    with events_path.open("a") as ev_f:
        worker = pi_worker.PiWorker(
            provider=provider,
            model=envelope["model"],
            cwd=envelope.get("cwd", str(PROJECT_ROOT)),
        )
        try:
            for event in worker.prompt(envelope["prompt"]):
                ev_f.write(json.dumps(event) + "\n")
                count += 1
                if on_event is not None:
                    on_event(event)
                etype = event.get("type")
                if etype in ("agent.done", "error", _PAUSE_EVENT_TYPE):
                    terminal = event
        finally:
            worker.close()

    status = _classify_status(terminal)
    return {
        "status": status,
        "events_count": count,
        "events_path": str(events_path),
        "terminal_event": terminal,
    }


def _spawn_ollama_loop(
    envelope: Dict[str, Any],
    on_event: Optional[Callable[[Dict[str, Any]], None]],
) -> Dict[str, Any]:
    """Spawn `claude -p` via lib/ollama_loop.OllamaLoopWorker, stream events.

    Env merging: os.environ overlaid by envelope["env"]. The
    ANTHROPIC_BASE_URL / ANTHROPIC_API_KEY redirection is what makes this an
    "ollama-loop" rather than a real Anthropic call — without those env vars
    set in the workflow, `claude -p` would call the real API.

    Terminal event: ``{"type": "result", "is_error": bool}``. Map is_error to
    status="error" (everything else is success).
    """
    import ollama_loop  # noqa: PLC0415 — deferred so module imports without claude

    blob_dir = _resolve_blob_dir(envelope)
    blob_dir.mkdir(parents=True, exist_ok=True)
    events_path = blob_dir / "events.jsonl"

    terminal: Optional[Dict[str, Any]] = None
    count = 0
    with events_path.open("a") as ev_f:
        worker = ollama_loop.OllamaLoopWorker(
            model=envelope["model"],
            cwd=envelope.get("cwd", str(PROJECT_ROOT)),
            env=envelope.get("env") or {},
            allowed_tools=envelope.get("allowed_tools") or [],
        )
        try:
            for event in worker.prompt(envelope["prompt"]):
                ev_f.write(json.dumps(event) + "\n")
                count += 1
                if on_event is not None:
                    on_event(event)
                etype = event.get("type")
                if etype in ("result", _PAUSE_EVENT_TYPE):
                    terminal = event
        finally:
            worker.close()

    status = _classify_status(terminal)
    return {
        "status": status,
        "events_count": count,
        "events_path": str(events_path),
        "terminal_event": terminal,
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _provider_from_workflow(envelope: Dict[str, Any]) -> Optional[str]:
    """Re-load the workflow YAML to fetch the provider field. Pi-specific —
    resolver.py keeps the envelope schema worker-kind-agnostic."""
    import yaml  # local import — yaml is in resolver's deps anyway

    task_type = envelope.get("task_type")
    if not task_type:
        return None
    wf_path = WORKFLOWS_DIR / f"{task_type}.yaml"
    if not wf_path.exists():
        return None
    data = yaml.safe_load(wf_path.read_text()) or {}
    return data.get("provider")


def _resolve_blob_dir(envelope: Dict[str, Any]) -> Path:
    """Envelope's blob_dir may be relative-to-PROJECT_ROOT (resolver builds it
    that way for the row) or absolute (resolver builds it that way for the
    envelope). Handle both."""
    raw = envelope.get("blob_dir")
    if not raw:
        raise SpawnError("envelope missing blob_dir")
    p = Path(raw)
    return p if p.is_absolute() else (PROJECT_ROOT / p)


def _spawn_termlink(
    envelope: Dict[str, Any],
    on_event: Optional[Callable[[Dict[str, Any]], None]],
) -> Dict[str, Any]:
    """Spawn a TermLink worker via lib/termlink_worker.TermLinkWorker.

    Mirrors ``_spawn_ollama_loop``; differs only in which worker class is
    instantiated. The TermLink primitive's ``prompt()`` yields events parsed
    from the on-disk ``result.jsonl`` after the worker exits — same stream-json
    shape (terminal event ``{"type": "result", "is_error": bool}``).

    Origin: T-1776 surfaced the contract gap (default.yaml → worker_kind:
    TermLink → NotImplementedError). T-1797 closes it.
    """
    import termlink_worker  # noqa: PLC0415 — deferred so module imports without fw

    blob_dir = _resolve_blob_dir(envelope)
    blob_dir.mkdir(parents=True, exist_ok=True)
    events_path = blob_dir / "events.jsonl"

    terminal: Optional[Dict[str, Any]] = None
    count = 0
    with events_path.open("a") as ev_f:
        worker = termlink_worker.TermLinkWorker(
            model=envelope["model"],
            cwd=envelope.get("cwd", str(PROJECT_ROOT)),
            task_id=envelope.get("task_id", ""),
            env=envelope.get("env") or {},
            allowed_tools=envelope.get("allowed_tools") or [],
            task_type=envelope.get("task_type"),
        )
        try:
            for event in worker.prompt(envelope["prompt"]):
                ev_f.write(json.dumps(event) + "\n")
                count += 1
                if on_event is not None:
                    on_event(event)
                etype = event.get("type")
                if etype in ("result", _PAUSE_EVENT_TYPE):
                    terminal = event
        finally:
            worker.close()

    status = _classify_status(terminal)
    return {
        "status": status,
        "events_count": count,
        "events_path": str(events_path),
        "terminal_event": terminal,
    }


_DISPATCHERS = {
    "pi": _spawn_pi,
    "ollama-loop": _spawn_ollama_loop,
    "TermLink": _spawn_termlink,
}
