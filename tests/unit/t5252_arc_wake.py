"""T-5252: arc owner wake-up (notice | worker), daily per-arc wake limit, deadline sweep,
update-task.sh trigger.

Every test uses a temporary project root. No real notice is sent and no real worker
is spawned: in-process tests replace the channel functions, subprocess tests point
FW_ARC_WAKE_FW_BIN at a stub `fw` that only records its arguments.
Run: python3 -m pytest tests/unit/t5252_arc_wake.py -q
"""

from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
import types
from pathlib import Path

import pytest

FW = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW))

from lib import arc_journal as aj  # noqa: E402
from lib import arc_owner as ao  # noqa: E402
from lib import arc_wake as aw  # noqa: E402

CLI = [sys.executable, str(FW / "lib" / "arc_wake.py")]
REC = types.SimpleNamespace(sent=[], dispatched=[], pushed=[])  # what the stubbed channels saw
NOW = dt.datetime(2026, 11, 19, 12, 0, tzinfo=dt.timezone.utc)


def _arc(root: Path, slug: str, numeric: str, anchor: str | None = None) -> Path:
    d = root / ".context" / "arcs"
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{slug}.yaml"
    p.write_text(f"id: {numeric}\nslug: {slug}\nname: \"fixture\"\nstatus: in-progress\n"
                 + (f"anchor_task: {anchor}\n" if anchor else ""))
    return p


def _stub_fw(tmp: Path) -> Path:
    log = tmp / "stub-calls.jsonl"
    s = tmp / "stub-fw"
    s.write_text("#!/usr/bin/env python3\nimport json, sys\n"
                 f"open({str(log)!r}, 'a').write(json.dumps(sys.argv[1:]) + '\\n')\n")
    s.chmod(0o755)
    return s


def _calls(tmp: Path) -> list[list[str]]:
    p = tmp / "stub-calls.jsonl"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


@pytest.fixture
def root(tmp_path, monkeypatch):
    proj = tmp_path / "proj"
    proj.mkdir()
    _arc(proj, "demo-arc", "arc-901", anchor="T-9100")
    _arc(proj, "plain-arc", "arc-902")
    ao.set_owner("demo-arc", True, "notice", proj)
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    monkeypatch.setenv("FW_ARC_WAKE_FW_BIN", str(_stub_fw(tmp_path)))
    monkeypatch.delenv("FW_ARC_WAKE", raising=False)
    monkeypatch.delenv("FW_ARC_WAKE_OPERATOR_CMD", raising=False)
    sent, dispatched, pushed = [], [], []
    monkeypatch.setattr(aw, "_send_notice", lambda body, r: (sent.append(body), (True, "sent"))[1])
    monkeypatch.setattr(aw, "_dispatch",
                        lambda task, name, prompt, r: (dispatched.append((task, name, prompt)), (True, "ok"))[1])
    monkeypatch.setattr(aw, "_notify_operator",
                        lambda title, msg, r: (pushed.append((title, msg)), (True, "pushed"))[1])
    REC.sent, REC.dispatched, REC.pushed = sent, dispatched, pushed
    return proj


def _ledger(root, slug="demo-arc"):
    p = root / ".context" / "arcs" / f"{slug}.wakes.jsonl"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


# ---------------------------------------------------------------- notice / worker

def test_notice_wake_sends_one_notice_and_records(root):
    row = aw.wake("demo-arc", "T-1 captured → started-work", "status", now=NOW)
    assert row["outcome"] == "sent" and row["channel"] == "notice"
    assert REC.sent == ["arc demo-arc: T-1 captured → started-work; run: fw arc resume demo-arc"]
    assert REC.dispatched == []
    led = _ledger(root)
    assert len(led) == 1 and led[0]["trigger"] == "status" and led[0]["ts"].startswith("2026-11-19")
    assert {"ts", "trigger", "reason", "channel", "outcome", "detail"} <= set(led[0])


def test_worker_wake_dispatches_under_anchor_with_resume_prompt(root):
    ao.set_owner("demo-arc", True, "worker", root)
    row = aw.wake("demo-arc", "deadline passed", "deadline", now=NOW)
    assert row["outcome"] == "sent" and row["channel"] == "worker" and row["task"] == "T-9100"
    (task, name, prompt), = REC.dispatched
    assert task == "T-9100" and name.startswith("arc-wake-demo-arc-")
    assert prompt.startswith("fw arc resume demo-arc")
    assert REC.sent == []


def test_worker_wake_prefers_active_next_step_task(root):
    ao.set_owner("demo-arc", True, "worker", root)
    (root / ".tasks" / "active").mkdir(parents=True)
    (root / ".tasks" / "active" / "T-9200-x.md").write_text("---\nid: T-9200\nstatus: started-work\n---\n")
    aj.append("demo-arc", "next", "me", root, step="do it", owner="agent", task="T-9200")
    aw.wake("demo-arc", "x", "status", now=NOW)
    assert REC.dispatched[0][0] == "T-9200"


def test_refused_dispatch_is_recorded_not_retried(root, monkeypatch):
    ao.set_owner("demo-arc", True, "worker", root)
    calls = []
    monkeypatch.setattr(aw, "_dispatch", lambda *a: (calls.append(a), (False, "exit 1: REFUSED cap"))[1])
    row = aw.wake("demo-arc", "x", "status", now=NOW)
    assert row["outcome"] == "dispatch-refused" and "REFUSED" in row["detail"]
    assert len(calls) == 1
    assert [r["outcome"] for r in _ledger(root)] == ["dispatch-refused"]


def test_dispatch_cli_shape_through_stub_fw(root, tmp_path, monkeypatch):
    """The real _dispatch builds `fw termlink dispatch --task --name --prompt` (stub fw)."""
    import importlib
    real = importlib.reload(aw)
    try:
        ok, _d = real._dispatch("T-9100", "arc-wake-demo-arc-120000", "fw arc resume demo-arc\n...", root)
        assert ok
        args = _calls(tmp_path)[-1]
        assert args[:2] == ["termlink", "dispatch"]
        assert args[args.index("--task") + 1] == "T-9100"
        assert args[args.index("--prompt") + 1].startswith("fw arc resume demo-arc")
    finally:
        importlib.reload(aw)


def test_arc_not_switched_on_never_wakes(root):
    assert aw.wake("plain-arc", "x", "status", now=NOW) is None
    ao.set_owner("demo-arc", False, None, root)
    assert aw.wake("demo-arc", "x", "status", now=NOW) is None
    assert REC.sent == [] and REC.dispatched == []
    assert not (root / ".context" / "arcs" / "plain-arc.wakes.jsonl").exists()


def test_disabled_records_skipped_and_does_not_count(root, monkeypatch):
    monkeypatch.setenv("FW_ARC_WAKE", "0")
    row = aw.wake("demo-arc", "x", "status", now=NOW)
    assert row["outcome"] == "skipped" and REC.sent == []
    assert aw.today("demo-arc", now=NOW)["count"] == 0


# ---------------------------------------------------------------- limit

def test_limit_reached_no_wake_one_operator_notice(root):
    p = root / ".context" / "arcs" / "demo-arc.yaml"
    p.write_text(p.read_text().replace("  wake: notice\n", "  wake: notice\n  wake_limit: 3\n"))
    assert aw.owner_config("demo-arc")["limit"] == 3
    rows = [aw.wake("demo-arc", f"e{i}", "status", now=NOW) for i in range(6)]
    assert [r["outcome"] for r in rows] == ["sent"] * 3 + ["refused-limit"] * 3
    assert len(REC.sent) == 3
    assert len(REC.pushed) == 1 and "wake limit" in REC.pushed[0][0]
    assert [bool(r.get("operator_notified")) for r in rows[3:]] == [True, False, False]
    t = aw.today("demo-arc", now=NOW)
    assert (t["count"], t["limit"], t["refused"]) == (3, 3, 3)
    # next UTC day: wakes again
    row = aw.wake("demo-arc", "new day", "status", now=NOW + dt.timedelta(days=1))
    assert row["outcome"] == "sent"


def test_default_limit_is_12_and_survives_owner_toggle(root):
    assert aw.owner_config("demo-arc")["limit"] == 12
    p = root / ".context" / "arcs" / "demo-arc.yaml"
    p.write_text(p.read_text().replace("  wake: notice\n", "  wake: notice\n  wake_limit: 5\n"))
    ao.set_owner("demo-arc", True, "worker", root)
    assert aw.owner_config("demo-arc")["limit"] == 5


def test_operator_pending_lists_arc_at_limit(root, monkeypatch):
    import importlib
    from lib import operator_pending as op
    for i in range(13):
        aw.wake("demo-arc", f"e{i}", "status")  # real now: pending reads today's UTC rows
    monkeypatch.setattr(op, "PROJECT", root)
    assert op.arc_wake_limits() == [{"arc": "demo-arc", "refused": 1}]
    importlib.reload(op)


# ---------------------------------------------------------------- deadline sweep

def test_sweep_wakes_once_per_passed_deadline(root):
    aj.append("demo-arc", "next", "me", root, step="ship it", owner="agent", deadline="2026-11-18")
    aj.append("plain-arc", "next", "me", root, step="x", owner="agent", deadline="2026-11-01")
    first = aw.sweep(now=NOW)
    assert [(r["arc"], r["outcome"], r["trigger"]) for r in first] == [("demo-arc", "sent", "deadline")]
    assert "ship it" in REC.sent[0]
    assert aw.sweep(now=NOW) == []
    assert aw.sweep(now=NOW + dt.timedelta(hours=3)) == []
    assert len(REC.sent) == 1
    # a new next step with its own passed deadline wakes once more
    aj.append("demo-arc", "next", "me", root, step="ship v2", owner="agent", deadline="2026-11-18")
    assert len(aw.sweep(now=NOW)) == 1 and len(REC.sent) == 2


def test_sweep_ignores_future_or_today_deadline(root):
    aj.append("demo-arc", "next", "me", root, step="later", owner="agent", deadline="2026-11-19")
    assert aw.sweep(now=NOW) == [] and REC.sent == []


def test_sweep_skipped_wake_does_not_use_up_deadline(root, monkeypatch):
    aj.append("demo-arc", "next", "me", root, step="s", owner="agent", deadline="2026-11-10")
    monkeypatch.setenv("FW_ARC_WAKE", "0")
    assert aw.sweep(now=NOW)[0]["outcome"] == "skipped"
    monkeypatch.delenv("FW_ARC_WAKE")
    assert aw.sweep(now=NOW)[0]["outcome"] == "sent"


# ---------------------------------------------------------------- CLI / test guard

def test_cli_today_line_and_test_guard(root, tmp_path):
    env = {**os.environ, "PROJECT_ROOT": str(root), "BATS_RUN_TMPDIR": "x"}
    env.pop("FW_ARC_WAKE_FW_BIN", None)
    r = subprocess.run(CLI + ["wake", "demo-arc", "--reason", "x", "--json"], env=env,
                       capture_output=True, text=True, cwd=root)
    assert r.returncode == 0 and json.loads(r.stdout)["outcome"] == "skipped"
    assert _calls(tmp_path) == []
    r = subprocess.run(CLI + ["today", "demo-arc"], env=env, capture_output=True, text=True, cwd=root)
    assert "Wakes today (UTC): 0 of 12" in r.stdout


# ---------------------------------------------------------------- update-task.sh trigger

def _task(root: Path, tid: str, arc: str) -> Path:
    d = root / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    (root / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
    p = d / f"{tid}-fixture.md"
    p.write_text(f"""---
id: {tid}
name: "fixture"
description: fixture
status: captured
workflow_type: build
owner: agent
horizon: now
arc_id: {arc}
created: 2026-11-19T00:00:00Z
last_update: 2026-11-19T00:00:00Z
---

# {tid}: fixture

## Context

**Background / trigger:** test. **Problem / hypothesis:** test. **Goal:** test. **Expected outcome:** test.

## Acceptance Criteria

### Agent
- [ ] Real criterion for the fixture task

## Verification

true

## Updates
""")
    return p


def _update(root: Path, tid: str, status: str):
    for sub in ("working", "episodic", "project"):
        (root / ".context" / sub).mkdir(parents=True, exist_ok=True)
    fy = root / ".framework.yaml"
    if not fy.exists():
        fy.write_text("id: TEST\n")
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "PYTEST_CURRENT_TEST")}
    env.update({
        "PROJECT_ROOT": str(root), "FRAMEWORK_ROOT": str(FW), "AGENTS_DIR": str(FW / "agents"),
        "FW_LIB_DIR": str(FW / "lib"), "TASKS_DIR": str(root / ".tasks"),
        "CONTEXT_DIR": str(root / ".context"), "NO_COLOR": "1", "FW_ISSUES_LIFECYCLE": "0",
        "FW_REVIEWER_DISABLED": "1", "WATCHTOWER_URL": "http://test.invalid:3000",
    })
    return subprocess.run(["bash", str(FW / "agents" / "task-create" / "update-task.sh"), tid,
                           "--status", status], capture_output=True, text=True, env=env, cwd=root,
                          timeout=240)


def test_update_task_status_change_sends_notice_via_stub(root, tmp_path):
    t = _task(root, "T-9001", "arc-901")
    r = _update(root, "T-9001", "started-work")
    assert "status: started-work" in t.read_text(), r.stdout + r.stderr
    sends = [c for c in _calls(tmp_path) if c[:2] == ["sidecar", "send"]]
    assert len(sends) == 1, r.stderr
    assert sends[0][sends[0].index("--to") + 1] == "proj"
    assert "--notice" in sends[0]
    assert sends[0][sends[0].index("--body") + 1] == \
        "arc demo-arc: T-9001 captured → started-work; run: fw arc resume demo-arc"
    led = _ledger(root)
    assert [(x["trigger"], x["outcome"]) for x in led] == [("status", "sent")]


def test_update_task_arc_not_on_no_wake(root, tmp_path):
    t = _task(root, "T-9002", "plain-arc")
    _update(root, "T-9002", "started-work")
    assert "status: started-work" in t.read_text()
    assert _calls(tmp_path) == []
    assert not (root / ".context" / "arcs" / "plain-arc.wakes.jsonl").exists()


def test_update_task_failing_wake_never_blocks(root, tmp_path):
    bad = tmp_path / "bad-fw"
    bad.write_text("#!/bin/sh\necho boom >&2\nexit 7\n")
    bad.chmod(0o755)
    os.environ["FW_ARC_WAKE_FW_BIN"] = str(bad)
    try:
        t = _task(root, "T-9003", "demo-arc")
        r = _update(root, "T-9003", "started-work")
    finally:
        os.environ["FW_ARC_WAKE_FW_BIN"] = str(tmp_path / "stub-fw")
    assert r.returncode == 0 and "status: started-work" in t.read_text()
    assert _ledger(root)[-1]["outcome"] == "error"
    assert sum("arc wake error" in ln for ln in r.stderr.splitlines()) == 1
