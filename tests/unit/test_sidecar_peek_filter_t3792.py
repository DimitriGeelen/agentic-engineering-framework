"""T-3792 — the prompt-hook peek must not surface receipts or answered nudges.

055 (2026-10-04): ~24 of 28 entries surfaced at every prompt were delivery
receipts ("no action or reply needed"); a real consult drowned and the hook
output overflowed to a file. 999's own inbox topic holds 114 nudges.
"""

import base64
import importlib
import json

import pytest


@pytest.fixture()
def inbox(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "peek-test")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    for var in ("TERMLINK_SESSION", "FW_FOCUS_SESSION_KEY"):
        monkeypatch.delenv(var, raising=False)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.receipts as receipts
    import lib.sidecar.inbox as inbox_mod
    for m in (outbox, receipts, inbox_mod):
        importlib.reload(m)
    return inbox_mod


def _env(offset, body, *, msg_type="sidecar.consult", meta=None):
    return {"offset": offset, "msg_type": msg_type, "ts": 1,
            "payload_b64": base64.b64encode(body.encode()).decode(),
            "metadata": dict({"client_msg_id": f"m{offset}", "conversation_id": "c",
                              "from_agent": "peer"}, **(meta or {}))}


def _reader(envs):
    return lambda topic, cursor, limit=100, **kw: [e for e in envs if e["offset"] >= cursor] \
        if topic.startswith("inbox:cacc73ea32b121dd/") else []


# ── receipts never reach the peek ────────────────────────────────────────────

@pytest.mark.parametrize("env", [
    _env(1, "[sidecar receipt] RECEIVED for message x from y. no action", msg_type="sidecar.receipt"),
    _env(2, "anything", msg_type="receipt"),
    _env(3, "[sidecar receipt] HANDED_OVER for message x from y."),   # old sender, no kind
    _env(4, "x", meta={"kind": "receipt", "receipt_for": "zz", "receipt_state": "RECEIVED"}),
])
def test_every_receipt_mark_is_excluded_from_pending(inbox, env):
    assert inbox.pending(reader=_reader([env]), advance=False) == []


def test_real_consult_still_surfaces_beside_receipts(inbox):
    envs = [_env(i, "[sidecar receipt] RECEIVED ...", msg_type="sidecar.receipt") for i in range(24)]
    envs.append(_env(30, "please review the RCA"))
    fresh = inbox.pending(reader=_reader(envs), advance=False)
    assert [m["body"] for m in fresh] == ["please review the RCA"]
    assert inbox.unread_summary(reader=_reader(envs))["unread"] == 1


# ── nudges: answered hidden, repeats collapsed, all counted ──────────────────

def _m(offset, cid, body="q"):
    return {"offset": offset, "client_msg_id": cid, "from": "832", "conversation_id": "c",
            "body": body}


def test_answered_nudges_are_held_back_and_counted(inbox):
    msgs = [_m(1, "base-a-nudge-5"), _m(2, "base-a-nudge-6"), _m(3, "real-1")]
    kept, held = inbox.surface_filter(msgs, answered={"base-a"})
    assert [m["client_msg_id"] for m in kept] == ["real-1"]
    assert held == {"receipts": 0, "answered_nudges": 2, "duplicate_nudges": 0}


def test_answered_set_defaults_to_replied_receipts_we_sent(inbox, tmp_path):
    d = tmp_path / ".context" / "sidecar"
    d.mkdir(parents=True, exist_ok=True)
    (d / "receipts-sent.jsonl").write_text(
        json.dumps({"client_msg_id": "base-b", "state": "REPLIED", "ok": True}) + "\n"
        + json.dumps({"client_msg_id": "base-c", "state": "REPLIED", "ok": False}) + "\n")
    kept, held = inbox.surface_filter([_m(1, "base-b-nudge-3"), _m(2, "base-c-nudge-3")])
    assert [m["client_msg_id"] for m in kept] == ["base-c-nudge-3"], "a failed REPLIED did not answer"
    assert held["answered_nudges"] == 1


def test_unanswered_nudges_collapse_to_the_newest_one(inbox):
    msgs = [_m(1, "base-d-nudge-1"), _m(5, "base-d-nudge-3"), _m(3, "base-d-nudge-2")]
    kept, held = inbox.surface_filter(msgs, answered=set())
    assert [m["client_msg_id"] for m in kept] == ["base-d-nudge-3"]
    assert held["duplicate_nudges"] == 2


def test_nudge_beside_its_own_base_consult_collapses_into_it(inbox):
    kept, held = inbox.surface_filter([_m(1, "base-e"), _m(9, "base-e-nudge-4")], answered=set())
    assert [m["client_msg_id"] for m in kept] == ["base-e"]
    assert held["duplicate_nudges"] == 1


def test_receipt_shaped_entry_is_counted_by_the_filter_too(inbox):
    kept, held = inbox.surface_filter(
        [_m(1, "r", body="[sidecar receipt] REPLIED for message x"), _m(2, "real")], answered=set())
    assert [m["client_msg_id"] for m in kept] == ["real"] and held["receipts"] == 1


def test_control_plain_consults_pass_untouched(inbox):
    msgs = [_m(1, "a"), _m(2, "b")]
    kept, held = inbox.surface_filter(msgs, answered={"a"})
    assert {m["client_msg_id"] for m in kept} == {"a", "b"}, "only NUDGES are settled by answered"
    assert not any(held.values())
