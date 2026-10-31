"""T-4880 — DM mail is judged per addressee, not by the signing identity's cursor.

Origin (TermLink f37f3c3f, their T-3618): 055's 2026-10-20 report sat on
dm:3bba…:d1993c… (3bba = an AEF agent key we no longer sign with) and 1023's
~2026-10-15 report on the host root key's self-DM rail dm:d1993c…:d1993c…
(posts tagged to_project). Nothing on the session-start path read DM rails,
auto-confirming sidecars posted "delivered" receipts for us, and a drain had
moved the shared rail's cursor past the 1023 post. Both arrived 8 and 13 days
late, by forward. The contract pinned here: addressed mail stays OPEN until
this project posts on that rail; receipts, notices and our own posts are
never mail and never an answer; mail for another project is never ours.
"""

from __future__ import annotations

import base64
import io
import sys
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import alerts, dm, inbox  # noqa: E402
import lib.sidecar_cli as cli  # noqa: E402

US = "999-Agentic-Engineering-Framework"
OUR_KEY = "bdd184bd89f318e4"
OLD_AGENT_KEY = "3bba15e681b3a078"
ROOT_KEY = "d1993c2c3ec44c94"
NOW = datetime(2026, 10, 28, 18, 0, tzinfo=timezone.utc)


def _ts(hours_ago: float) -> int:
    return int((NOW - timedelta(hours=hours_ago)).timestamp() * 1000)


def _post(offset, hours_ago, body, *, sender=ROOT_KEY, msg_type="chat", **meta):
    return {"offset": offset, "ts": _ts(hours_ago), "msg_type": msg_type,
            "sender_id": sender, "metadata": meta,
            "payload_b64": base64.b64encode(body.encode()).decode()}


def _receipt(offset, hours_ago, up_to, *, as_chat=False, sender=OLD_AGENT_KEY):
    return _post(offset, hours_ago, "", sender=sender,
                 msg_type="chat" if as_chat else "receipt",
                 from_project="010-termlink", stage="delivered", up_to=str(up_to))


def _hub(rails: dict[str, list[dict]]):
    def lister(**_):
        return [{"name": n, "count": len(p), "latest_offset": len(p) - 1} for n, p in rails.items()]

    def reader(topic, cursor, limit=50, **_):
        return [e for e in rails.get(topic, []) if e["offset"] >= cursor][:limit]
    return lister, reader


def _unacted(rails, *, keys=(OUR_KEY, OLD_AGENT_KEY), handled=frozenset()):
    lister, reader = _hub(rails)
    return dm.unacted(US, keys=set(keys), lister=lister, reader=reader,
                      handled=set(handled), now=NOW)


AGENT_RAIL = f"dm:{OLD_AGENT_KEY}:{ROOT_KEY}"
SELF_RAIL = f"dm:{ROOT_KEY}:{ROOT_KEY}"


def test_addressed_mail_with_only_auto_confirm_receipts_after_it_is_open():
    rails = {AGENT_RAIL: [
        _post(0, 200, "Finding from 055", from_project="055-agentic-fleet-cockpit"),
        _receipt(1, 200, 0, sender=ROOT_KEY),
        _receipt(2, 200, 0, as_chat=True),  # receipt posted as chat: still not an answer
    ]}
    rows = _unacted(rails)
    assert [(r["topic"], r["offset"]) for r in rows] == [(AGENT_RAIL, 0)]
    assert rows[0]["from"] == "055-agentic-fleet-cockpit"


def test_mail_we_answered_on_the_rail_is_closed():
    rails = {AGENT_RAIL: [
        _post(0, 200, "question", from_project="055-agentic-fleet-cockpit"),
        _post(1, 190, "answer", from_project=US),
    ]}
    assert _unacted(rails) == []


def test_our_own_post_is_not_mail():
    rails = {AGENT_RAIL: [
        _post(0, 100, "our note", from_project=US),
        _post(1, 99, "smoke probe", sender=OUR_KEY),  # signed with our key, no from_project
    ]}
    assert _unacted(rails) == []


def test_mail_to_another_project_on_a_shared_rail_is_not_ours():
    rails = {SELF_RAIL: [
        _post(0, 300, "handover", from_project="050-email-archive", to_project="2105-Rasmus-Schule"),
    ], AGENT_RAIL: [
        # even on a rail carrying our key, a to_project naming someone else wins
        _post(0, 300, "for 832", from_project="010-termlink", to_project="832-Workflow-designer"),
    ]}
    assert _unacted(rails) == []


def test_untagged_mail_on_a_rail_without_our_key_is_not_ours():
    rails = {f"dm:{ROOT_KEY}:deadbeefdeadbeef": [_post(0, 50, "smoke", from_project="010-termlink")]}
    assert _unacted(rails) == []


def test_real_case_1023_on_the_host_self_dm_rail():
    """1023's report: signed with the root key, no from_project, tagged
    to_project = us; only a 'delivered' receipt after it; the shared rail's
    cursor had been drained past it. Still OPEN."""
    rails = {SELF_RAIL: [
        _post(19, 316, "[050 T-2390] Handover", from_project="050-email-archive",
              to_project="2105-Rasmus-Schule"),
        _post(20, 307, "From the 1023-portable-encrypted-chromium-vault session (consumer, "
              "vendored AEF v1.6.15), ...", to_project=US),
        _receipt(21, 220, 20, sender=ROOT_KEY),
    ]}
    rows = _unacted(rails)
    assert [(r["topic"], r["offset"], r["to_project"]) for r in rows] == [(SELF_RAIL, 20, US)]
    assert rows[0]["age_hours"] == pytest.approx(307, abs=0.1)


def test_real_case_055_on_an_old_agent_key_rail():
    """055's report: on dm:3bba…:d1993c…, a rail keyed by an AEF agent key we
    no longer sign with. Visible only because SIDECAR_DM_ADDRESS_KEYS names it."""
    rails = {AGENT_RAIL: [
        _post(136, 198, "Finding from 055-agentic-fleet-cockpit (reply to agent id ...)",
              from_project="055-agentic-fleet-cockpit"),
        _receipt(137, 198, 136, sender=ROOT_KEY),
        _receipt(138, 198, 136),
    ]}
    assert [r["offset"] for r in _unacted(rails)] == [136]
    assert _unacted(rails, keys=(OUR_KEY,)) == []  # the key gap that hid it


def test_handled_and_age_window():
    rails = {AGENT_RAIL: [
        _post(0, 200, "answered elsewhere", from_project="055-agentic-fleet-cockpit"),
        _post(1, 2, "fresh, not yet stale", from_project="055-agentic-fleet-cockpit"),
        _post(2, 24 * 40, "older than the window", from_project="055-agentic-fleet-cockpit"),
    ]}
    assert _unacted(rails, handled={(AGENT_RAIL, 0)}) == []


def test_handled_file_parse(tmp_path):
    f = tmp_path / dm.HANDLED_FILE
    f.parent.mkdir(parents=True)
    f.write_text(f"# comment\n{AGENT_RAIL} 136  # T-4714\n{SELF_RAIL} 20\nbad line\n")
    assert dm._handled(tmp_path) == {(AGENT_RAIL, 136), (SELF_RAIL, 20)}


def test_address_keys_reads_config(monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_IDENTITY_FP", OUR_KEY)
    monkeypatch.setenv("FW_SIDECAR_DM_ADDRESS_KEYS", f"{OLD_AGENT_KEY}, ")
    assert dm.address_keys() == {OUR_KEY, OLD_AGENT_KEY}


def test_stale_ignores_receipts_posted_as_chat_and_own_posts(monkeypatch, tmp_path):
    """TermLink's false positive: 2 'unread' for 43 h on a rail holding only
    our own smoke posts and receipts."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    (tmp_path / ".context").mkdir()
    rail = f"dm:{OUR_KEY}:deadbeefdeadbeef"
    lister, reader = _hub({rail: [_post(0, 43, "smoke", sender=OUR_KEY),
                                  _receipt(1, 43, 0, as_chat=True, sender="deadbeefdeadbeef")]})
    assert dm.stale(24, key=OUR_KEY, lister=lister, reader=reader, now=NOW) == []


def test_alerts_lists_unacted_dm_by_sender_and_age_and_never_hides_it(monkeypatch, tmp_path):
    root = tmp_path / "p"
    (root / ".context").mkdir(parents=True)
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setattr(cli.addressing, "orphan_inboxes", lambda **_: [])
    monkeypatch.setattr(alerts.inbox, "pending", lambda **_: [])
    monkeypatch.setattr(alerts.receiver, "awaiting_handover", lambda: [])
    rails = {AGENT_RAIL: [_post(136, 198, "Finding from 055", from_project="055-agentic-fleet-cockpit")]}
    lister, reader = _hub(rails)
    real = dm.unacted
    unacted = lambda: real(US, keys={OLD_AGENT_KEY}, lister=lister, reader=reader,
                                 handled=set(), now=NOW)
    monkeypatch.setattr(alerts.dm, "unacted", lambda **_: unacted())

    out = io.StringIO()
    with redirect_stdout(out):
        rc = cli.cmd_alerts(SimpleNamespace(limit=10, json=False, mark_seen=True))
    text = out.getvalue()
    assert rc == 0, text
    assert "055-agentic-fleet-cockpit" in text and "unanswered 198.0h" in text
    assert f"{AGENT_RAIL}@136" in text
    # --mark-seen does not make unacted mail disappear: it is listed again
    assert [r["route"] for r in alerts.collect()] == ["dm"]


def test_alerts_failed_dm_listing_is_not_checked(monkeypatch):
    monkeypatch.setattr(alerts.inbox, "pending", lambda **_: [])
    monkeypatch.setattr(alerts.receiver, "awaiting_handover", lambda: [])

    def boom(**_):
        raise RuntimeError("hub down")
    monkeypatch.setattr(alerts.dm, "unacted", boom)
    # by name: another test file may reload lib.sidecar.inbox, giving a new class
    with pytest.raises(Exception, match="dm rails") as ei:
        alerts.collect()
    assert type(ei.value).__name__ == "Unreadable"


# T-4893 (ring20 be.50, msgs 90ae5b45 / 5a3aa616): 7 of 9 "unanswered" DMs from 050 were
# its own 'Got it, on it now...' auto-acks. ring20 read the envelopes: msg_type chat,
# metadata only client_msg_id/from_project/observed_addr — no marker tells an ack from
# mail, so the fix is on the sending side. This pins what a sender can rely on.
def test_a_peer_ack_marked_as_notice_is_never_mail_nor_an_answer():
    for marker in ({"notice": True}, {"kind": "notice"}):
        rails = {AGENT_RAIL: [
            _post(0, 50, "real request", from_project="050-email-archive"),
            _post(1, 49, "[bridge-ref:x] Got it, on it now", from_project="050-email-archive", **marker),
        ]}
        rows = _unacted(rails)
        assert [r["offset"] for r in rows] == [0], marker  # the request stays open; the ack is not listed


def test_an_unmarked_peer_ack_is_still_mail():
    # The limitation T-4893 documents: without a marker an ack is indistinguishable from mail.
    rails = {AGENT_RAIL: [
        _post(0, 49, "[bridge-ref:x] Got it, on it now", from_project="050-email-archive"),
    ]}
    assert [r["offset"] for r in _unacted(rails)] == [0]
