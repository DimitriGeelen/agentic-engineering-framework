"""T-5054 (010 msg d6e77987): the adapter logs what the meter answered each report — its origin
verdict (`origin_checked`, `basis_checked`) is in the REPLY, not in the status JSON. Fields only,
never prompt text; the file is bounded by one rotation."""
from __future__ import annotations

import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE))

from lib.sidecar import adapter2  # noqa: E402


def _setup(tmp_path, monkeypatch):
    (tmp_path / ".context" / "sidecar").mkdir(parents=True)
    monkeypatch.setattr(adapter2, "_project_root", lambda: tmp_path)
    return tmp_path / ".context" / "sidecar" / "adapter2-replies.jsonl"


def test_reply_fields_are_logged_and_prompt_text_is_not(tmp_path, monkeypatch):
    log = _setup(tmp_path, monkeypatch)
    report = {"event": "prompt_submit", "session_id": "s-1", "prompt": "SECRET PROMPT TEXT",
              "origin": "human", "basis": "inferred"}
    adapter2._log_reply(report, {"ok": True, "origin_checked": "human", "basis_checked": "inferred",
                                 "echo": "SECRET PROMPT TEXT"})
    row = json.loads(log.read_text().splitlines()[-1])
    assert row["event"] == "prompt_submit" and row["session"] == "s-1"
    assert row["ok"] is True and row["origin_checked"] == "human" and row["basis_checked"] == "inferred"
    assert "SECRET" not in log.read_text()


def test_a_refusal_reason_is_kept_short(tmp_path, monkeypatch):
    log = _setup(tmp_path, monkeypatch)
    adapter2._log_reply({"event": "ready", "session_id": "s-1"}, {"ok": False, "ignored": "x" * 500})
    row = json.loads(log.read_text().splitlines()[-1])
    assert row["ok"] is False and len(row["why"]) == 160


def test_no_reply_still_logs_the_event(tmp_path, monkeypatch):
    log = _setup(tmp_path, monkeypatch)
    adapter2._log_reply({"event": "tool_end", "session_id": "s-1"}, None)
    assert json.loads(log.read_text())["event"] == "tool_end"


def test_the_log_rotates_once_past_the_cap(tmp_path, monkeypatch):
    log = _setup(tmp_path, monkeypatch)
    monkeypatch.setattr(adapter2, "_REPLY_LOG_CAP", 200)
    for _ in range(20):
        adapter2._log_reply({"event": "tool_start", "session_id": "s-1"}, {"ok": True})
    assert log.stat().st_size <= 200 + 200
    assert (log.parent / "adapter2-replies.jsonl.1").exists()


def test_a_broken_log_location_never_raises(tmp_path, monkeypatch):
    monkeypatch.setattr(adapter2, "_project_root", lambda: tmp_path / "missing")
    adapter2._log_reply({"event": "ready"}, {"ok": True})   # must not raise
