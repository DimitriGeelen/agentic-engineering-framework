"""Unit tests for lib/peer.py — v2 peer-consult subscriber + responder spawn.

T-1818 (framework-half) pairs with TermLink T-1636 (inbox.queued emitter).
Pins event parsing, addressee resolution (success + miss), spawn invocation
(mocked TermLink), and long-poll loop continuation past one event.
"""

from __future__ import annotations

import importlib
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


def _load_peer_module(tmp_path: Path):
    """Import lib/peer.py with PROJECT_ROOT pointed at a tmp dir.

    The module captures PROJECT_ROOT at import time, so we re-import per
    test against an isolated tmp tree to keep cursor/miss-log writes scoped.
    """
    os.environ["PROJECT_ROOT"] = str(tmp_path)
    (tmp_path / ".context" / "working").mkdir(parents=True, exist_ok=True)
    spec = importlib.util.spec_from_file_location(
        f"peer_test_{tmp_path.name}", REPO_ROOT / "lib" / "peer.py",
    )
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def _make_runner(plan):
    """Build a subprocess.run stand-in that returns canned CompletedProcess
    objects based on which CLI is being invoked (matched by first argv token).

    `plan` is a dict: cli-token → list of (stdout, returncode) pairs popped
    in order, or a single tuple reused indefinitely.
    """
    calls = []

    def runner(cmd, capture_output=False, text=False, timeout=None):
        calls.append(list(cmd))
        head = cmd[0]
        # Match argv head — for "bin/fw" inspect cmd[1] (e.g. termlink).
        key = head if head != "bin/fw" else f"{cmd[0]} {cmd[1]}"
        slot = plan.get(key)
        if slot is None:
            return subprocess.CompletedProcess(cmd, 0, "", "")
        if isinstance(slot, list):
            out, rc = slot.pop(0) if slot else ("", 0)
        else:
            out, rc = slot
        return subprocess.CompletedProcess(cmd, rc, out, "")

    return runner, calls


def test_resolve_addressee_by_session_id(tmp_path):
    peer = _load_peer_module(tmp_path)
    prompts = {
        "code-review": {
            "addressee": "tl-abc",
            "workflow": "workflows/code-review.yaml",
            "name": "code-review",
        },
    }
    ev = {"addressee_session_id": "tl-abc", "channel": "dm:code-review"}
    workflow, name = peer.resolve_addressee(ev, prompts)
    assert workflow == "workflows/code-review.yaml"
    assert name == "code-review"


def test_resolve_addressee_by_channel_prefix(tmp_path):
    peer = _load_peer_module(tmp_path)
    prompts = {
        "consult-design": {
            "channel": "dm:design-",
            "workflow": "workflows/design-consult.yaml",
            "name": "design-consult",
        },
    }
    ev = {"addressee_session_id": "tl-xyz", "channel": "dm:design-auth"}
    workflow, name = peer.resolve_addressee(ev, prompts)
    assert workflow == "workflows/design-consult.yaml"
    assert name == "design-consult"


def test_resolve_addressee_miss_returns_none(tmp_path):
    peer = _load_peer_module(tmp_path)
    prompts = {
        "code-review": {
            "addressee": "tl-zzz",
            "channel": "dm:code-review",
            "workflow": "workflows/code-review.yaml",
        },
    }
    ev = {"addressee_session_id": "tl-other", "channel": "dm:random"}
    workflow, name = peer.resolve_addressee(ev, prompts)
    assert workflow is None
    assert name is None


def test_log_miss_appends_line(tmp_path):
    peer = _load_peer_module(tmp_path)
    ev = {"addressee_session_id": "tl-ghost", "channel": "dm:no-handler"}
    peer.log_miss(ev)
    peer.log_miss({"addressee_session_id": "tl-ghost2", "channel": "x"})
    contents = peer.MISS_LOG.read_text()
    lines = [l for l in contents.splitlines() if l.strip()]
    assert len(lines) == 2
    # Each line: timestamp + JSON
    parts = lines[0].split(" ", 1)
    assert len(parts) == 2
    assert json.loads(parts[1])["addressee_session_id"] == "tl-ghost"


def test_spawn_responder_invokes_fw_termlink_dispatch(tmp_path):
    peer = _load_peer_module(tmp_path)
    runner, calls = _make_runner({"bin/fw termlink": ("ok", 0)})
    ev = {
        "addressee_session_id": "tl-abc",
        "channel": "dm:review",
        "message_offset": 7,
        "enqueued_at": "2026-05-14T00:00:00Z",
    }
    result = peer.spawn_responder(
        "workflows/code-review.yaml", "code-review", ev, runner=runner,
    )
    assert result is not None
    assert result.returncode == 0
    # Verify exactly one dispatch call with the right shape
    dispatch_calls = [c for c in calls if c[:3] == ["bin/fw", "termlink", "dispatch"]]
    assert len(dispatch_calls) == 1
    args = dispatch_calls[0]
    assert "--name" in args
    name_idx = args.index("--name")
    assert args[name_idx + 1] == "peer-code-review"
    assert "--prompt" in args
    prompt_idx = args.index("--prompt")
    preamble = args[prompt_idx + 1]
    assert "tl-abc" in preamble
    assert "workflows/code-review.yaml" in preamble
    assert "T-1818" in args  # task tag


def test_poll_once_parses_event_list(tmp_path):
    peer = _load_peer_module(tmp_path)
    events_json = json.dumps([
        {"addressee_session_id": "tl-a", "channel": "dm:x", "message_offset": 5},
        {"addressee_session_id": "tl-b", "channel": "dm:y", "message_offset": 6},
    ])
    runner, _ = _make_runner({"termlink": (events_json, 0)})
    events = peer.poll_once("tl-hub", since=0, timeout=1, runner=runner)
    assert len(events) == 2
    assert events[0]["addressee_session_id"] == "tl-a"


def test_poll_once_handles_dict_envelope(tmp_path):
    """Some TermLink responses wrap events in {events: [...]} — accept both."""
    peer = _load_peer_module(tmp_path)
    payload = json.dumps({"events": [{"addressee_session_id": "tl-c", "channel": "z"}]})
    runner, _ = _make_runner({"termlink": (payload, 0)})
    events = peer.poll_once("tl-hub", since=0, runner=runner)
    assert len(events) == 1
    assert events[0]["addressee_session_id"] == "tl-c"


def test_subscribe_loop_continuation_past_miss(tmp_path):
    """After one inbox.queued event is processed, the loop must not stall.

    One event resolves (spawn fires), another misses (logged), cursor advances
    to the highest seen message_offset. With once=True the subscriber returns
    after exactly one poll batch.
    """
    peer = _load_peer_module(tmp_path)
    # Configure prompts: only tl-known resolves
    prompts = tmp_path / ".context" / "peer-consult-prompts.yaml"
    prompts.write_text(
        "code-review:\n"
        "  addressee: tl-known\n"
        "  workflow: workflows/code-review.yaml\n"
        "  name: code-review\n"
    )
    # Plan three CLI calls: list (one ready session), event poll (batch), dispatch (spawn)
    list_payload = json.dumps({"sessions": [
        {"display_name": "tl-hub", "state": "ready"},
    ]})
    events_payload = json.dumps([
        {"addressee_session_id": "tl-known", "channel": "dm:r",
         "message_offset": 11, "enqueued_at": "t1"},
        {"addressee_session_id": "tl-unknown", "channel": "dm:r",
         "message_offset": 12, "enqueued_at": "t2"},
    ])
    runner, calls = _make_runner({
        "termlink": [(list_payload, 0), (events_payload, 0)],
        "bin/fw termlink": ("dispatched", 0),
    })
    iters = peer.subscribe(once=True, runner=runner, sleep=lambda *_: None)
    assert iters == 1
    # Exactly one spawn (the resolving event)
    dispatches = [c for c in calls if c[:3] == ["bin/fw", "termlink", "dispatch"]]
    assert len(dispatches) == 1
    # The miss logged
    misses = peer.MISS_LOG.read_text().splitlines()
    assert len(misses) == 1
    assert "tl-unknown" in misses[0]
    # Cursor advanced to highest seen offset
    saved_target, saved_since = peer._read_cursor()
    assert saved_target == "tl-hub"
    assert saved_since == 12


def test_subscribe_no_ready_sessions_returns_zero(tmp_path):
    peer = _load_peer_module(tmp_path)
    runner, _ = _make_runner({"termlink": (json.dumps({"sessions": []}), 0)})
    iters = peer.subscribe(once=True, runner=runner, sleep=lambda *_: None)
    assert iters == 0


def test_load_prompts_handles_missing_file(tmp_path):
    peer = _load_peer_module(tmp_path)
    assert peer._load_prompts() == {}


def test_cursor_persists_across_runs(tmp_path):
    peer = _load_peer_module(tmp_path)
    peer._write_cursor("tl-hub", 42)
    target, since = peer._read_cursor()
    assert target == "tl-hub"
    assert since == 42
