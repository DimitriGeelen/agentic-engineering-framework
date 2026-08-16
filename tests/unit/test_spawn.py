"""T-1773: Unit tests for lib/spawn.py.

Pins:
  - pi route streams events to <blob_dir>/events.jsonl
  - terminal agent.done → outcome success
  - terminal error → outcome error
  - other worker_kinds raise NotImplementedError with deferral message
  - update_outcome_row rewrites matching row atomically
  - update_outcome_row returns False when dispatch_id absent

Mocked PiWorker — no live pi binary needed.
"""

from __future__ import annotations

import json
import sys
import os
import tempfile
import threading
import time
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))


@pytest.fixture
def tmp_project(tmp_path, monkeypatch):
    """Set PROJECT_ROOT to a tmp dir and force-reload spawn so the module
    picks up the override (its constants are computed at import time)."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    (tmp_path / ".context").mkdir()
    (tmp_path / ".context" / "project" / "workflows").mkdir(parents=True)
    # Force-reload spawn so PROJECT_ROOT-derived constants reflect the tmp dir
    if "spawn" in sys.modules:
        del sys.modules["spawn"]
    import spawn  # noqa: E402 — force fresh import per fixture
    return tmp_path, spawn


def _envelope(tmp_path, **overrides):
    blob = tmp_path / ".context" / "dispatch-blobs" / "2026-05" / "abc-123"
    base = {
        "dispatch_id": "abc-123",
        "task_id": "T-1773",
        "task_type": "cheap-research",
        "worker_kind": "pi",
        "model": "claude-3-5-sonnet-latest",
        "effort": "medium",
        "prompt": "hello world",
        "allowed_tools": ["Read"],
        "cost_cap_usd": 0.0,
        "cwd": str(tmp_path),
        "env": {},
        "blob_dir": str(blob),
        "variant_id": None,
    }
    base.update(overrides)
    return base


def _fake_pi_worker(events):
    """Return a factory that mimics PiWorker(...) → instance with
    .prompt() yielding events and .close() returning 0."""
    def factory(*a, **kw):  # noqa: ARG001
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m
    return factory


def _write_workflow(tmp_path, task_type="cheap-research", provider="anthropic"):
    wf = tmp_path / ".context" / "project" / "workflows" / f"{task_type}.yaml"
    wf.write_text(
        f"task_type: {task_type}\nworker_kind: pi\n"
        f"provider: {provider}\nmodel: claude-3-5-sonnet-latest\n"
    )


def test_pi_route_success(tmp_project):
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    env = _envelope(tmp_path)
    events = [
        {"type": "response", "id": "req-1"},
        {"type": "tool_use", "tool": "read"},
        {"type": "agent.done"},
    ]
    with patch.object(spawn, "_DISPATCHERS", {"pi": spawn._spawn_pi}):
        with patch("pi_worker.PiWorker", _fake_pi_worker(events)):
            result = spawn.spawn_dispatch(env)

    assert result["status"] == "success"
    assert result["events_count"] == 3
    assert result["terminal_event"]["type"] == "agent.done"
    # events.jsonl exists with all events
    ep = Path(result["events_path"])
    assert ep.exists()
    lines = ep.read_text().strip().splitlines()
    assert len(lines) == 3
    assert json.loads(lines[-1])["type"] == "agent.done"


def test_pi_route_error_terminal(tmp_project):
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    env = _envelope(tmp_path)
    events = [
        {"type": "response", "id": "req-1"},
        {"type": "error", "retryable": True, "message": "429"},
    ]
    with patch("pi_worker.PiWorker", _fake_pi_worker(events)):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "error"
    assert result["terminal_event"]["retryable"] is True


def test_remaining_worker_kinds_raise_notimplemented(tmp_project):
    """T-1775 added ollama-loop, T-1797 added TermLink. Only Task remains deferred."""
    tmp_path, spawn = tmp_project
    env = _envelope(tmp_path, worker_kind="Task")
    with pytest.raises(NotImplementedError) as exc:
        spawn.spawn_dispatch(env)
    msg = str(exc.value)
    assert "Task" in msg
    # Deferral message references the originating task IDs
    assert "T-1773" in msg or "T-1775" in msg or "T-1797" in msg


def test_termlink_route_wired(tmp_project):
    """T-1797: TermLink is registered in _DISPATCHERS and no longer raises
    NotImplementedError. Stream-json result event maps to outcome status."""
    tmp_path, spawn = tmp_project
    assert "TermLink" in spawn._DISPATCHERS

    env = _envelope(tmp_path, worker_kind="TermLink")
    events = [
        {"type": "system", "subtype": "init"},
        {"type": "assistant", "message": {"content": "hi"}},
        {"type": "result", "is_error": False, "result": "done"},
    ]

    def fake_factory(**kwargs):
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    import termlink_worker  # noqa: F401 — ensure module is in sys.modules
    with patch("termlink_worker.TermLinkWorker", side_effect=fake_factory):
        result = spawn.spawn_dispatch(env)

    assert result["status"] == "success"
    assert result["events_count"] == 3
    assert result["terminal_event"]["type"] == "result"
    ep = Path(result["events_path"])
    assert ep.exists()
    lines = ep.read_text().strip().splitlines()
    assert len(lines) == 3


def test_termlink_route_error_terminal(tmp_project):
    """T-1797: type=result is_error=True → status=error (same shape as ollama-loop)."""
    tmp_path, spawn = tmp_project
    env = _envelope(tmp_path, worker_kind="TermLink")
    events = [{"type": "result", "is_error": True, "error": "worker timeout"}]

    def fake_factory(**kwargs):
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    with patch("termlink_worker.TermLinkWorker", side_effect=fake_factory):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "error"
    assert result["terminal_event"]["is_error"] is True


def test_termlink_route_forwards_task_id_and_tools(tmp_project):
    """T-1797: envelope task_id, env, allowed_tools, task_type forwarded to worker."""
    tmp_path, spawn = tmp_project
    env = _envelope(
        tmp_path,
        worker_kind="TermLink",
        env={"ANTHROPIC_BASE_URL": "http://localhost:4000"},
        allowed_tools=["Read", "Bash"],
    )
    captured = {}

    def fake_factory(**kwargs):
        captured.update(kwargs)
        m = MagicMock()
        m.prompt.return_value = iter([{"type": "result", "is_error": False}])
        m.close.return_value = 0
        return m

    with patch("termlink_worker.TermLinkWorker", side_effect=fake_factory):
        spawn.spawn_dispatch(env)

    assert captured["task_id"] == env["task_id"]
    assert captured["env"]["ANTHROPIC_BASE_URL"] == "http://localhost:4000"
    assert captured["allowed_tools"] == ["Read", "Bash"]
    assert captured["task_type"] == env["task_type"]
    assert captured["model"] == env["model"]


def test_ollama_loop_route_success(tmp_project):
    """T-1775: ollama-loop route streams events; type=result is_error=False → success."""
    tmp_path, spawn = tmp_project
    env = _envelope(
        tmp_path,
        worker_kind="ollama-loop",
        env={"ANTHROPIC_BASE_URL": "http://localhost:4000"},
    )
    events = [
        {"type": "system", "subtype": "init"},
        {"type": "assistant", "message": {"content": "hi"}},
        {"type": "result", "is_error": False, "result": "done"},
    ]

    def fake_factory(**kwargs):
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    import ollama_loop  # noqa: F401 — ensure module is in sys.modules
    with patch("ollama_loop.OllamaLoopWorker", side_effect=fake_factory):
        result = spawn.spawn_dispatch(env)

    assert result["status"] == "success"
    assert result["events_count"] == 3
    assert result["terminal_event"]["type"] == "result"
    assert result["terminal_event"]["is_error"] is False
    ep = Path(result["events_path"])
    assert ep.exists()
    lines = ep.read_text().strip().splitlines()
    assert len(lines) == 3


def test_ollama_loop_route_error_terminal(tmp_project):
    """T-1775: type=result is_error=True → status=error."""
    tmp_path, spawn = tmp_project
    env = _envelope(tmp_path, worker_kind="ollama-loop")
    events = [
        {"type": "assistant", "message": {}},
        {"type": "result", "is_error": True, "error": "model timeout"},
    ]

    def fake_factory(**kwargs):
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    with patch("ollama_loop.OllamaLoopWorker", side_effect=fake_factory):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "error"
    assert result["terminal_event"]["is_error"] is True


def test_ollama_loop_route_passes_env_and_tools(tmp_project):
    """T-1775: envelope env + allowed_tools forwarded to OllamaLoopWorker."""
    tmp_path, spawn = tmp_project
    env = _envelope(
        tmp_path,
        worker_kind="ollama-loop",
        env={"ANTHROPIC_BASE_URL": "http://localhost:4000",
             "ANTHROPIC_API_KEY": "sk-litellm-local-dev"},
        allowed_tools=["Read", "Bash", "Grep"],
    )
    captured = {}

    def fake_factory(**kwargs):
        captured.update(kwargs)
        m = MagicMock()
        m.prompt.return_value = iter([{"type": "result", "is_error": False}])
        m.close.return_value = 0
        return m

    with patch("ollama_loop.OllamaLoopWorker", side_effect=fake_factory):
        spawn.spawn_dispatch(env)

    assert captured["env"]["ANTHROPIC_BASE_URL"] == "http://localhost:4000"
    assert captured["env"]["ANTHROPIC_API_KEY"] == "sk-litellm-local-dev"
    assert captured["allowed_tools"] == ["Read", "Bash", "Grep"]
    assert captured["model"] == env["model"]


def test_unknown_worker_kind_raises_spawnerror(tmp_project):
    tmp_path, spawn = tmp_project
    env = _envelope(tmp_path, worker_kind="frobnicate")
    with pytest.raises(spawn.SpawnError):
        spawn.spawn_dispatch(env)


def test_update_outcome_row_rewrites_match(tmp_project):
    tmp_path, spawn = tmp_project
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(
        json.dumps({"dispatch_id": "row-1", "outcome": "pending"}) + "\n"
        + json.dumps({"dispatch_id": "row-2", "outcome": "pending"}) + "\n"
        + json.dumps({"dispatch_id": "row-3", "outcome": "pending"}) + "\n"
    )
    ok = spawn.update_outcome_row("row-2", "success", {"events_count": 7})
    assert ok is True
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    outcomes = {r["dispatch_id"]: r["outcome"] for r in rows}
    assert outcomes == {"row-1": "pending", "row-2": "success", "row-3": "pending"}
    by_id = {r["dispatch_id"]: r for r in rows}
    assert by_id["row-2"]["events_count"] == 7


def test_update_outcome_row_no_match_returns_false(tmp_project):
    tmp_path, spawn = tmp_project
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "row-1", "outcome": "pending"}) + "\n")
    ok = spawn.update_outcome_row("missing-id", "success", None)
    assert ok is False
    # File unchanged
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    assert rows[0]["outcome"] == "pending"


def test_update_outcome_row_no_log_returns_false(tmp_project):
    tmp_path, spawn = tmp_project
    # No dispatches.jsonl at all
    ok = spawn.update_outcome_row("any-id", "success", None)
    assert ok is False


def test_update_outcome_row_empty_dispatch_id_returns_false(tmp_project):
    tmp_path, spawn = tmp_project
    (tmp_path / ".context" / "dispatches.jsonl").write_text("")
    ok = spawn.update_outcome_row("", "success", None)
    assert ok is False


# ---------------------------------------------------------------------------
# T-3042 — concurrent append vs. update_outcome_row's read→os.replace window
# ---------------------------------------------------------------------------
def _fresh_resolver():
    """Import lib/resolver.py against the tmp_project PROJECT_ROOT.

    Its DISPATCHES_LOG is computed at import time, same as spawn's, so it must
    be reloaded inside the fixture's env for the two modules to agree on which
    ledger — and therefore which sidecar lock — they are contending over.
    """
    for mod in ("resolver", "keylock"):
        sys.modules.pop(mod, None)
    import resolver
    return resolver


def _append_row(resolver, row):
    """Drive the real appender, falling back to the pre-fix inline form.

    The fallback exists only so that stashing the fix makes the race test fail
    on the symptom — an erased row — instead of on a missing symbol. A test
    that goes red because `append_dispatch_row` does not exist yet would prove
    nothing about the race it claims to reproduce.
    """
    appender = getattr(resolver, "append_dispatch_row", None)
    if appender is not None:
        appender(row)
        return
    with resolver.DISPATCHES_LOG.open("a") as f:  # pre-fix resolver.py:813
        f.write(json.dumps(row) + "\n")


def test_concurrent_append_survives_update_outcome_row(tmp_project):
    """A row appended while update_outcome_row is mid-rewrite must survive.

    Reproduces the live race: update_outcome_row reads the whole ledger, then
    os.replace()s a rewritten inode over it. Any row appended in between lands
    in the doomed inode and is erased outright. Widening that window with a
    patched os.replace makes a real thread race deterministic.

    Pre-fix this fails: `row-concurrent` is gone from the ledger.
    """
    tmp_path, spawn = tmp_project
    resolver = _fresh_resolver()
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(
        json.dumps({"dispatch_id": "row-1", "outcome": "pending"}) + "\n"
        + json.dumps({"dispatch_id": "row-2", "outcome": "pending"}) + "\n"
    )
    assert resolver.DISPATCHES_LOG == log, "resolver and spawn must share the ledger"

    in_replace = threading.Event()
    appended = threading.Event()
    real_replace = os.replace

    def slow_replace(src, dst):
        # The window the bug lives in: rows are read, the replacement is
        # staged, the swap has not happened yet.
        in_replace.set()
        # Post-fix the appender is parked on the lock and never sets this, so
        # the wait expires — that expiry IS the fix working. Pre-fix it fires
        # in milliseconds and the append is swallowed by the swap below.
        appended.wait(timeout=0.5)
        return real_replace(src, dst)

    errors = []

    def appender():
        try:
            in_replace.wait(timeout=5.0)
            _append_row(resolver, {"dispatch_id": "row-concurrent",
                                   "outcome": "pending"})
            appended.set()
        except Exception as exc:  # surfaced below rather than lost in a thread
            errors.append(exc)

    thread = threading.Thread(target=appender, daemon=True)
    # Patches the shared os module for the duration; scoped to this test.
    with patch.object(spawn.os, "replace", slow_replace):
        thread.start()
        ok = spawn.update_outcome_row("row-2", "success", {"events_count": 3})
    thread.join(timeout=10.0)

    assert not errors, f"appender thread raised: {errors}"
    assert not thread.is_alive(), "appender never completed — lock not released?"
    assert ok is True

    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    ids = [r["dispatch_id"] for r in rows]
    assert "row-concurrent" in ids, (
        "concurrently-appended row was ERASED by update_outcome_row's "
        f"os.replace — ledger holds {ids}"
    )
    outcomes = {r["dispatch_id"]: r["outcome"] for r in rows}
    assert outcomes["row-2"] == "success", "the outcome update itself was lost"
    assert outcomes["row-1"] == "pending"


def test_appender_blocks_while_rewriter_holds_the_ledger_lock(tmp_project):
    """The appender at resolver.py must take the SAME lock as the rewriter.

    Locking only the rewriter leaves the race exactly where it was, so this
    pins the pairing directly rather than inferring it from the race test.
    """
    tmp_path, spawn = tmp_project
    resolver = _fresh_resolver()
    import keylock

    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "row-1", "outcome": "pending"}) + "\n")

    done = threading.Event()

    def appender():
        _append_row(resolver, {"dispatch_id": "row-blocked", "outcome": "pending"})
        done.set()

    with keylock.guarding(log):
        thread = threading.Thread(target=appender, daemon=True)
        thread.start()
        assert not done.wait(timeout=0.5), (
            "appender wrote while the ledger lock was held — resolver.py is "
            "not taking the lock, so the rewriter's lock protects nothing"
        )
    assert done.wait(timeout=10.0), "appender did not proceed after release"
    thread.join(timeout=5.0)
    ids = [json.loads(l)["dispatch_id"] for l in log.read_text().strip().splitlines()]
    assert ids == ["row-1", "row-blocked"]


def test_ledger_lock_is_a_sidecar_not_the_ledger_itself(tmp_project):
    """os.replace swaps the ledger's inode; a lock held on it would be orphaned."""
    tmp_path, spawn = tmp_project
    import keylock

    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "row-1", "outcome": "pending"}) + "\n")
    spawn.update_outcome_row("row-1", "success", None)

    lock = keylock.lock_path_for(log)
    assert lock == tmp_path / ".context" / "locks" / "dispatches.lock"
    assert lock.exists(), "lock file was never created"
    assert lock.resolve() != log.resolve()
    # T-3041 de-rooting: a root cron run must not leave the ledger unlockable
    # for the non-root principal that comes after it.
    assert (lock.stat().st_mode & 0o666) == 0o666, oct(lock.stat().st_mode)


def test_lock_timeout_is_bounded_and_raises_loudly(tmp_project, capfd):
    """Timeout must be bounded and never degrade to a silent skipped write."""
    tmp_path, spawn = tmp_project
    import keylock

    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "row-1", "outcome": "pending"}) + "\n")

    os.environ["FW_LEDGER_LOCK_TIMEOUT"] = "0.2"
    try:
        with keylock.guarding(log):  # hold it; the rewriter cannot get in
            start = time.monotonic()
            with pytest.raises(keylock.LockTimeout):
                spawn.update_outcome_row("row-1", "success", None)
            elapsed = time.monotonic() - start
    finally:
        os.environ.pop("FW_LEDGER_LOCK_TIMEOUT", None)

    assert elapsed < 5.0, f"acquisition was not bounded ({elapsed:.1f}s)"
    err = capfd.readouterr().err
    assert "TIMEOUT" in err and "was NOT performed" in err, err
    # And the row is untouched — not half-written.
    rows = [json.loads(l) for l in log.read_text().strip().splitlines()]
    assert rows[0]["outcome"] == "pending"


def test_module_imports_without_pi_on_path():
    """spawn.py must import without invoking subprocess. PiWorker import is
    deferred to the pi handler."""
    if "spawn" in sys.modules:
        del sys.modules["spawn"]
    import spawn  # noqa: F401
    assert hasattr(spawn, "spawn_dispatch")
    assert hasattr(spawn, "update_outcome_row")
    assert hasattr(spawn, "SpawnError")


def test_pi_route_uses_envelope_provider_when_present(tmp_project):
    tmp_path, spawn = tmp_project
    # No workflow file — must fall back to envelope.provider
    env = _envelope(tmp_path, provider="openai")
    captured = {}
    def factory(*a, **kw):
        captured["provider"] = kw.get("provider") or (a[0] if a else None)
        m = MagicMock()
        m.prompt.return_value = iter([{"type": "agent.done"}])
        m.close.return_value = 0
        return m
    with patch("pi_worker.PiWorker", factory):
        spawn.spawn_dispatch(env)
    assert captured["provider"] == "openai"


def test_pi_route_falls_back_to_workflow_provider(tmp_project):
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path, provider="anthropic")
    env = _envelope(tmp_path)  # no provider in envelope
    captured = {}
    def factory(*a, **kw):
        captured["provider"] = kw.get("provider") or (a[0] if a else None)
        m = MagicMock()
        m.prompt.return_value = iter([{"type": "agent.done"}])
        m.close.return_value = 0
        return m
    with patch("pi_worker.PiWorker", factory):
        spawn.spawn_dispatch(env)
    assert captured["provider"] == "anthropic"


def test_pi_route_missing_provider_raises_spawnerror(tmp_project):
    tmp_path, spawn = tmp_project
    # No workflow file, no envelope provider → must error
    env = _envelope(tmp_path)
    with patch("pi_worker.PiWorker", _fake_pi_worker([{"type": "agent.done"}])):
        with pytest.raises(spawn.SpawnError) as exc:
            spawn.spawn_dispatch(env)
    assert "provider" in str(exc.value)


def test_spawn_dispatch_finalises_outcome_row(tmp_project):
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "abc-123", "outcome": "pending"}) + "\n")
    env = _envelope(tmp_path)
    with patch("pi_worker.PiWorker", _fake_pi_worker([{"type": "agent.done"}])):
        spawn.spawn_dispatch(env)
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    assert rows[0]["outcome"] == "success"
    assert rows[0]["events_count"] == 1


def test_spawn_persists_terminal_event_pi(tmp_project):
    """T-1777: pi route persists terminal `agent.done` event into dispatches row."""
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "abc-123", "outcome": "pending"}) + "\n")
    env = _envelope(tmp_path)
    with patch("pi_worker.PiWorker", _fake_pi_worker([{"type": "agent.done", "id": "req-1"}])):
        spawn.spawn_dispatch(env)
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    assert rows[0]["terminal_event"]["type"] == "agent.done"
    assert rows[0]["terminal_event"]["id"] == "req-1"


def test_spawn_persists_terminal_event_ollama_loop(tmp_project):
    """T-1777: ollama-loop route persists `result` event with is_error flag."""
    tmp_path, spawn = tmp_project
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "abc-123", "outcome": "pending"}) + "\n")
    env = _envelope(tmp_path, worker_kind="ollama-loop")
    events = [
        {"type": "assistant"},
        {"type": "result", "is_error": False, "result": "ok"},
    ]

    def fake_factory(**kwargs):
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    with patch("ollama_loop.OllamaLoopWorker", side_effect=fake_factory):
        spawn.spawn_dispatch(env)
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    te = rows[0]["terminal_event"]
    assert te["type"] == "result"
    assert te["is_error"] is False
    assert te["result"] == "ok"


def test_spawn_omits_terminal_event_when_none(tmp_project):
    """T-1777: when no terminal event arrives (early stream end), the row
    should NOT carry a null terminal_event field."""
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "abc-123", "outcome": "pending"}) + "\n")
    env = _envelope(tmp_path)
    # No agent.done, no error — generator just ends
    with patch("pi_worker.PiWorker", _fake_pi_worker([{"type": "response"}])):
        spawn.spawn_dispatch(env)
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    assert "terminal_event" not in rows[0]


# ---------------------------------------------------------------------------
# T-1805 / ADR-0004 — dispatch-safety slice 1: pause_requested terminal class
# ---------------------------------------------------------------------------


def test_pause_event_type_constant(tmp_project):
    """The constant referenced by AC verification is `pause_requested` and
    `paused` is in the valid-status set."""
    _, spawn = tmp_project
    assert spawn._PAUSE_EVENT_TYPE == "pause_requested"
    assert spawn._VALID_OUTCOME_STATUSES == frozenset({"success", "error", "paused"})


def test_classify_status_pause_takes_precedence(tmp_project):
    """A pause_requested terminal classifies as `paused`, not success/error.
    Pause is a structured deferral — Worker hasn't attempted, so success vs
    error don't apply yet."""
    _, spawn = tmp_project
    pause = {"type": "pause_requested", "question": "which pattern?",
             "assessment": {"severity": "high", "likelihood": "medium"}}
    assert spawn._classify_status(pause) == "paused"
    # Sanity: no terminal → success
    assert spawn._classify_status(None) == "success"
    # Existing classifications still hold
    assert spawn._classify_status({"type": "agent.done"}) == "success"
    assert spawn._classify_status({"type": "error"}) == "error"
    assert spawn._classify_status({"type": "result", "is_error": True}) == "error"
    assert spawn._classify_status({"type": "result", "is_error": False}) == "success"


def test_pi_route_pause_terminal(tmp_project):
    """pi dispatcher recognizes pause_requested as terminal; outcome status
    is `paused`; terminal_event dict preserved."""
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    env = _envelope(tmp_path)
    events = [
        {"type": "response", "id": "req-1"},
        {"type": "pause_requested", "question": "Pattern A or B?",
         "assessment": {"severity": "high", "likelihood": "medium"},
         "state_ref": "blob_dir/state-1"},
    ]
    with patch("pi_worker.PiWorker", _fake_pi_worker(events)):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "paused"
    assert result["terminal_event"]["type"] == "pause_requested"
    assert result["terminal_event"]["question"] == "Pattern A or B?"
    assert result["terminal_event"]["assessment"]["severity"] == "high"


def test_ollama_loop_route_pause_terminal(tmp_project):
    """ollama-loop dispatcher recognizes pause_requested as terminal."""
    tmp_path, spawn = tmp_project
    env = _envelope(tmp_path, worker_kind="ollama-loop")
    events = [
        {"type": "system", "subtype": "init"},
        {"type": "pause_requested", "question": "Schema migration ambiguous?",
         "assessment": {"severity": "high", "likelihood": "high"}},
    ]

    def fake_factory(**kwargs):  # noqa: ARG001
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    import ollama_loop  # noqa: F401 — ensure module in sys.modules
    with patch("ollama_loop.OllamaLoopWorker", side_effect=fake_factory):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "paused"
    assert result["terminal_event"]["type"] == "pause_requested"


def test_termlink_route_pause_terminal(tmp_project):
    """TermLink dispatcher recognizes pause_requested as terminal."""
    tmp_path, spawn = tmp_project
    env = _envelope(tmp_path, worker_kind="TermLink")
    events = [
        {"type": "system", "subtype": "init"},
        {"type": "pause_requested", "question": "Tool selection ambiguous?",
         "assessment": {"severity": "medium", "likelihood": "high"}},
    ]

    def fake_factory(**kwargs):  # noqa: ARG001
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    import termlink_worker  # noqa: F401
    with patch("termlink_worker.TermLinkWorker", side_effect=fake_factory):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "paused"
    assert result["terminal_event"]["type"] == "pause_requested"


def test_spawn_pause_persists_into_dispatch_row(tmp_project):
    """Pause event persists into dispatches.jsonl row with status=paused."""
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "abc-123", "outcome": "pending"}) + "\n")
    env = _envelope(tmp_path)
    events = [
        {"type": "pause_requested", "question": "Which file pattern?",
         "assessment": {"severity": "high", "likelihood": "medium"}},
    ]
    with patch("pi_worker.PiWorker", _fake_pi_worker(events)):
        spawn.spawn_dispatch(env)
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    assert rows[0]["outcome"] == "paused"
    assert rows[0]["terminal_event"]["type"] == "pause_requested"
    assert rows[0]["terminal_event"]["question"] == "Which file pattern?"


def test_pause_does_not_break_existing_success_path(tmp_project):
    """Regression guard: an agent.done after a non-terminal event still maps
    to success — pause recognition must not steal terminal status from
    non-pause events earlier in the stream."""
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    env = _envelope(tmp_path)
    events = [
        {"type": "response", "id": "req-1"},
        {"type": "agent.done"},
    ]
    with patch("pi_worker.PiWorker", _fake_pi_worker(events)):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "success"
    assert result["terminal_event"]["type"] == "agent.done"
