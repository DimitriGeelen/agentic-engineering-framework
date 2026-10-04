"""T-3840 — the receiver hook re-surfaced the same messages at every prompt.

Fixture inbox: N messages stored in the receiver and claimed for the session,
then the UserPromptSubmit hook run several times with no finalizer (no
transcript evidence either way), the way an operator's consecutive prompts
run it.
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, hooks, inbox, inject, outbox, receiver, seen  # noqa: E402

SB = {"session_id": "sess-b"}


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t3840-b"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t3840-b\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    inject._publish_injectable(["tl-fleet"])
    return root


def _store(mid, sender: str | None = "peer-a", body=None, **extra):
    env = {"client_msg_id": mid, "from": sender, "conversation_id": "c1",
           "body": body if body is not None else f"body of {mid}"}
    env.update(extra)
    ok, err = receiver.store_message(mid, env)
    assert ok, err
    from datetime import datetime, timezone
    inject._write_claim(mid, datetime.now(timezone.utc),
                        {"session_id": "sess-b", "termlink_session": None})


def _run():
    buf = io.StringIO()
    got = hooks.prompt(SB, out=buf, spawn=False)
    # a later prompt, past the finalize hold: the surfacing markers are gone
    for mid in got:
        hooks._surfacing_marker(mid).unlink(missing_ok=True)
    return got, buf.getvalue()


def test_same_messages_surface_on_run_1_only_and_new_mail_on_run_3(proj):
    ids = [f"m-{i}" for i in range(5)]
    for mid in ids:
        _store(mid)
    run1, out1 = _run()
    assert sorted(run1) == ids
    assert "# Sidecar receiver: 5 message(s)" in out1
    run2, out2 = _run()
    assert run2 == [] and out2 == ""
    _store("m-new")
    run3, _ = _run()
    assert run3 == ["m-new"]
    assert _run()[0] == []


def test_rescued_unknown_sender_keyed_by_msg_id(proj):
    _store("hub-d2d70f67222a6fae", sender=None, via="hub-topic")
    assert _run()[0] == ["hub-d2d70f67222a6fae"]
    assert _run()[0] == []
    assert seen.times_shown({"hub-d2d70f67222a6fae"}) == 1


def test_replied_message_never_surfaces(proj):
    _store("m-ans")
    _store("m-base-nudge-2")
    _store("m-direct")
    # replies we sent: hub path (outbox in_reply_to) and direct path ledger
    outbox.write_message(from_id="me", to="peer-a", body="answer",
                         conversation_id="c1", in_reply_to="m-ans")
    outbox.write_message(from_id="me", to="peer-a", body="answer",
                         conversation_id="c1", in_reply_to="m-base")
    from lib.sidecar import direct
    with open(direct._ledger_path(), "a") as fh:
        fh.write(json.dumps({"client_msg_id": "r1", "state": direct.SENT,
                             "in_reply_to": "m-direct"}) + "\n")
    for _ in range(3):
        assert _run()[0] == []


def test_answered_after_surfacing_is_not_resurfaced_even_if_unconfirmed(proj):
    _store("m-x")
    assert _run()[0] == ["m-x"]
    outbox.write_message(from_id="me", to="peer-a", body="ok",
                         conversation_id="c1", in_reply_to="m-x")
    receiver.record_event("m-x", "HANDOVER_UNCONFIRMED", reason="test")
    assert _run()[0] == []


def test_unconfirmed_resurfaces_at_most_once(proj):
    _store("m-lost")
    assert _run()[0] == ["m-lost"]
    receiver.record_event("m-lost", "HANDOVER_UNCONFIRMED", reason="test")
    assert _run()[0] == ["m-lost"]
    receiver.record_event("m-lost", "HANDOVER_UNCONFIRMED", reason="test")
    assert _run()[0] == []


def test_frame_stays_under_persist_threshold_and_defers_the_rest(proj):
    ids = [f"big-{i}" for i in range(12)]
    for mid in ids:
        _store(mid, body="x" * 3000)
    seen_ids = []
    for _ in range(12):
        got, out = _run()
        if not got:
            break
        ctx = json.loads(out)["hookSpecificOutput"]["additionalContext"]
        assert len(ctx) <= hooks.FRAME_CAP
        seen_ids += got
    assert sorted(seen_ids) == sorted(ids)          # every one, exactly once
    assert len(seen_ids) == len(set(seen_ids))


def test_one_oversized_message_still_fits(proj):
    _store("huge", body="y" * 50000)
    got, out = _run()
    assert got == ["huge"]
    assert len(json.loads(out)["hookSpecificOutput"]["additionalContext"]) <= hooks.FRAME_CAP


def test_inbox_cli_and_hook_share_the_ledger(proj):
    # the hook showed it → the inbox drain does not list it again
    _store("shared-1")
    assert _run()[0] == ["shared-1"]
    env = {"offset": 0, "metadata": {"client_msg_id": "shared-1", "from_agent": "peer-a"},
           "payload_b64": ""}
    assert inbox.pending(reader=lambda t, c, l: [env] if c == 0 else [], advance=True) == []
    # a peek showed it once → may come once more, then never
    seen.mark_shown([("peeked", None)], by="peek")
    assert seen.may_show({"peeked"})
    seen.mark_shown([("peeked", None)], by="peek")
    assert not seen.may_show({"peeked"})
    # a drain showed it → the hook does not surface it
    seen.mark_shown([("drained", {"client_msg_id": "drained"})], by="inbox-cli")
    _store("drained")
    assert _run()[0] == []
