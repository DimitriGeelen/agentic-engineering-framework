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

import keylock  # noqa: E402 — after the sys.path insert above

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
# Worker write provenance (T-3030, G-083)
# ---------------------------------------------------------------------------
# A dispatched worker writes into the same checkout as any live session and
# leaves no mark saying so. `git status` afterwards shows a merged result with
# no indication two authors produced it, which is how a worker's unreviewed
# edit to a completion gate nearly got committed under a human's authorship on
# 2026-08-16.
#
# The oracle is git state, NOT the worker's own tool calls. That distinction is
# load-bearing: in the origin incident the worker CREATED
# tests/unit/ac_structure_close_gate.bats with zero Write tool calls — 40 Bash,
# 8 Edit, 0 Write — so scanning tool_use blocks for file_path would have
# reported the file as untouched by anyone. Redirections, heredocs, `sed -i`,
# `rm` and `git mv` are all invisible to tool-name extraction and all visible
# to git.
#
# Soundness comes from the picker's clean-tree guard (resolver.py
# `_dirty_paths`): dispatch is refused while the tree carries hand-edited
# changes, so paths that turn dirty across the dispatch window are the
# worker's. Without that guard this would be correlation; with it, it is
# attribution. If an operator sets FW_DISPATCH_REQUIRE_CLEAN_TREE=0 they trade
# exactly that property away, which is why the field records the flag's state
# alongside the paths rather than presenting the list as unconditional truth.


def _git_state() -> Optional[Dict[str, str]]:
    """path -> porcelain status code. None if git is unreadable (never guess)."""
    import subprocess  # noqa: PLC0415 — only needed on the dispatch path

    try:
        proc = subprocess.run(
            ["git", "-C", str(PROJECT_ROOT), "status", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    state: Dict[str, str] = {}
    for line in proc.stdout.splitlines():
        if len(line) < 4:
            continue
        code, path = line[:2], line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        state[path.strip('"')] = code
    return state


def _writes_between(
    before: Optional[Dict[str, str]], after: Optional[Dict[str, str]]
) -> Optional[Dict[str, Any]]:
    """Paths whose git state changed across the dispatch window.

    Returns None when either snapshot is missing — an empty list would read as
    "the worker wrote nothing", and a provenance record that cannot tell
    "nothing happened" from "I could not look" is worse than none at all."""
    if before is None or after is None:
        return None
    changed = sorted(
        path for path, code in after.items() if before.get(path) != code
    )
    vanished = sorted(path for path in before if path not in after)
    return {
        "paths": changed,
        "reverted_paths": vanished,
        "clean_tree_guard": os.environ.get(
            "FW_DISPATCH_REQUIRE_CLEAN_TREE", "1"
        ).strip() != "0",
    }


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

    # T-3030: bracket the worker so its writes are attributable after the fact.
    tree_before = _git_state()
    outcome = handler(envelope, on_event)
    extra = {"events_count": outcome["events_count"]}
    writes = _writes_between(tree_before, _git_state())
    if writes is not None:
        extra["worker_writes"] = writes
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

    T-3042 — CRASH-atomic is not CONCURRENCY-safe. The tmp + os.replace pattern
    guarantees a reader never sees a half-written file; it guarantees nothing
    about a *writer* that appended between this function's read loop and its
    replace. That row lands in the old inode and os.replace discards it — the
    dispatch is erased outright, not merely left un-updated, and the pass-rate
    table agents consult before dispatching is computed from what survives.
    So the whole read→replace window is held under the ledger's sidecar lock,
    which lib/resolver.py's appender takes too. Locking one side would have
    left the race exactly where it was.
    """
    if not dispatch_id or not DISPATCHES_LOG.exists():
        return False

    # Bounded; raises keylock.LockTimeout (loudly, on stderr) rather than
    # returning False on expiry. False here means "no such dispatch_id", and a
    # caller cannot distinguish that from "lock lost" — silently dropping the
    # outcome would recreate this bug's signature: a ledger that under-reports
    # without saying so.
    with keylock.guarding(DISPATCHES_LOG):
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
            env=envelope.get("env") or {},
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
            # T-2592 (OBS-096): forward the T-2488 lean-worker contract —
            # _spawn_termlink honours these; ollama-loop was the missed sibling.
            strict_mcp_config=bool(envelope.get("strict_mcp_config", True)),
            mcp_config=envelope.get("mcp_config"),
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


def _spawn_ollama_thin_loop(
    envelope: Dict[str, Any],
    on_event: Optional[Callable[[Dict[str, Any]], None]],
) -> Dict[str, Any]:
    """Run the direct-API tool loop in-process (no claude subprocess).

    T-2592: `claude -p` (worker_kind=ollama-loop) drowns 8B local models in its
    injected system prompt — hermes3 0/9 real tool_use (T-1704) vs 100% on the
    thin direct loop (T-1706). This dispatcher routes to the validated
    primitive. No strict_mcp_config forwarding: the thin loop has no MCP
    surface at all — the curated 3-tool catalogue IS the whole tool set.
    """
    import ollama_thin_loop  # noqa: PLC0415 — deferred like the siblings

    blob_dir = _resolve_blob_dir(envelope)
    blob_dir.mkdir(parents=True, exist_ok=True)
    events_path = blob_dir / "events.jsonl"

    terminal: Optional[Dict[str, Any]] = None
    count = 0
    with events_path.open("a") as ev_f:
        worker = ollama_thin_loop.OllamaThinLoopWorker(
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
            # T-2488/OBS-088: default strict so a bare worker does not inherit
            # the parent .mcp.json (~175K tokens of tool schemas → context blowout).
            strict_mcp_config=bool(envelope.get("strict_mcp_config", True)),
            mcp_config=envelope.get("mcp_config"),
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
    "ollama-thin-loop": _spawn_ollama_thin_loop,
    "TermLink": _spawn_termlink,
}
