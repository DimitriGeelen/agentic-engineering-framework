"""T-4207 — a receiver started with --no-inject held peer mail with no delivery path.

inject.deliver_pending returns before recording an injectable decision when
injection is off, so injector_found_no_session() stayed False and the
UserPromptSubmit hook never took the mail either: 58 messages sat 51 h on
050-email-archive, silently. With injection off the prompt hook is the only
delivery path, so it must surface unclaimed mail for an interactive session.
"""

from __future__ import annotations

import io
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, hooks, inject, lifecycle, receiver, seen  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t4207"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t4207\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION_ID", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    return root


def _store(mid, stored_at=None):
    env = {"client_msg_id": mid, "from": "050-email-archive",
           "body": f"body-{mid}", "conversation_id": "c"}
    assert receiver.store_message(mid, env)[0]
    if stored_at is not None:
        path = receiver._message_path(mid)
        msg = json.loads(path.read_text(encoding="utf-8"))
        msg["_stored_at"] = stored_at.isoformat()
        path.write_text(json.dumps(msg), encoding="utf-8")


def _prompt(session_id="interactive-1"):
    out = io.StringIO()
    surfaced = hooks.prompt({"session_id": session_id, "transcript_path": "/tr/x.jsonl"},
                            out=out, spawn=False)
    return surfaced, out.getvalue()


def test_inject_off_prompt_hook_surfaces_held_mail(proj):
    lifecycle.write_config(inject=False)   # receiver started with --no-inject
    _store("m-held-1")
    surfaced, frame = _prompt()
    assert surfaced == ["m-held-1"], "held mail with injection off must reach the prompt hook"
    assert "body-m-held-1" in frame


def test_inject_on_no_decision_still_surfaces_nothing(proj):
    # T-3745 is unchanged: with injection ON and no injector decision on record,
    # an interactive prompt must not take mail that was never claimed for it.
    lifecycle.write_config(inject=True)
    _store("m-unclaimed-1")
    surfaced, _ = _prompt()
    assert surfaced == []


def test_held_unsurfaced_reports_old_mail_never_shown(proj):
    old = datetime.now(timezone.utc) - timedelta(hours=30)
    _store("m-old-1", stored_at=old)
    _store("m-fresh-1", stored_at=datetime.now(timezone.utc))
    rows = inject.held_unsurfaced(threshold_hours=24)
    assert [r["msg_id"] for r in rows] == ["m-old-1"]
    assert rows[0]["age_hours"] >= 29


def test_held_unsurfaced_silent_once_shown(proj):
    old = datetime.now(timezone.utc) - timedelta(hours=30)
    _store("m-old-2", stored_at=old)
    seen.mark_shown([("m-old-2", receiver.read_message("m-old-2"))], by="hook")
    assert inject.held_unsurfaced(threshold_hours=24) == []
