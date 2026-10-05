"""T-3872 — the injector re-announced answered peer mail forever.

Live, 2026-10-05: "[sidecar] 22 peer messages waiting" was typed into the
operator session again and again. All 22 were `<id>-nudge-N` copies of
messages we had already answered. The prompt hook dropped them (answered, per
the T-3840 ledger), so it showed nothing and never recorded HANDED_OVER; the
injector selected by HANDED_OVER alone, so the copies stayed "waiting" and were
typed again every REINJECT_AFTER_S. Both now share seen.withheld().
"""

from __future__ import annotations

import io
import json
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, hooks, inject, outbox, receiver, seen  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t3872"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t3872\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION_ID", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    return root


class Termlink:
    """Answers `discover` with the given sessions; records every inject."""

    def __init__(self, sessions):
        self.sessions, self.injects = sessions, []

    def __call__(self, argv, **_):
        if argv[1] == "discover":
            return subprocess.CompletedProcess(argv, 0, json.dumps({"sessions": self.sessions}), "")
        self.injects.append(argv)
        return subprocess.CompletedProcess(argv, 0, "", "")


def _sessions(*ids):
    tag = inject.project_tag()
    return [{"id": i, "tags": ["claude", tag], "metadata": {}} for i in ids]


def _idle_operator(monkeypatch):
    monkeypatch.setenv("TERMLINK_SESSION_ID", "tl-op")
    try:
        hooks.stop({"session_id": "operator", "transcript_path": "/tr/operator.jsonl"})
    finally:
        monkeypatch.delenv("TERMLINK_SESSION_ID")


def _store(mid):
    env = {"client_msg_id": mid, "from": "832-Workflow-designer",
           "body": f"body-{mid}", "conversation_id": "c"}
    assert receiver.store_message(mid, env)[0]


def _answer(mid):
    outbox.write_message(from_id="me", to="832-Workflow-designer", body="answer",
                         conversation_id="c", in_reply_to=mid)


def test_nudge_copy_of_answered_mail_is_withheld(proj):
    _store("m-base-nudge-7")
    _answer("m-base")
    assert seen.withheld(["m-base-nudge-7"]) == {"m-base-nudge-7": "answered"}


def test_injector_types_nothing_for_answered_nudges(proj, monkeypatch):
    _idle_operator(monkeypatch)
    for n in (5, 6, 7):
        _store(f"m-base-nudge-{n}")
    _answer("m-base")
    tl = Termlink(_sessions("tl-op"))
    rep = inject.deliver_pending("tick", runner=tl)
    assert tl.injects == [], rep
    assert rep["waiting"] == 0
    assert rep["withheld"] == ["m-base-nudge-5", "m-base-nudge-6", "m-base-nudge-7"]
    # recorded once per message, not per tick
    inject.deliver_pending("tick", runner=tl)
    blocked = [e for e in receiver.read_events("m-base-nudge-5")
               if e.get("event") == "INJECT_BLOCKED"]
    assert [e["reason"] for e in blocked] == ["withheld: answered"]


def test_unanswered_mail_is_still_injected_beside_withheld(proj, monkeypatch):
    _idle_operator(monkeypatch)
    _store("m-base-nudge-5")
    _answer("m-base")
    _store("m-new")
    tl = Termlink(_sessions("tl-op"))
    rep = inject.deliver_pending("tick", runner=tl)
    assert rep["injected"] == ["m-new"], rep
    assert len(tl.injects) == 1


def test_hook_and_injector_agree(proj, monkeypatch):
    """Whatever the injector announces, the hook surfaces — and vice versa."""
    _idle_operator(monkeypatch)
    _store("m-base-nudge-5")
    _answer("m-base")
    _store("m-new")
    rep = inject.deliver_pending("tick", runner=Termlink(_sessions("tl-op")))
    monkeypatch.setenv("TERMLINK_SESSION_ID", "tl-op")
    got = hooks.prompt({"session_id": "operator", "transcript_path": "/tr/operator.jsonl"},
                       out=io.StringIO(), spawn=False)
    assert sorted(got) == sorted(rep["injected"]) == ["m-new"]
