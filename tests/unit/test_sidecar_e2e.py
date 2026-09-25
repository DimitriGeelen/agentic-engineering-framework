"""T-3423 — arc-011 sidecar slice 9: the end-to-end harness state machine.

Every collaborator is a fake here. The live run (`fw sidecar e2e`) is the same
`run()` with the real ones plugged in; what these tests pin is that the
verdict logic is right for every failure shape we can name, and that a failed
hop is recorded, never raised.
"""

import base64
import importlib
import json
from pathlib import Path

import pytest


@pytest.fixture()
def mods(tmp_path, monkeypatch):
    project = tmp_path / "999-Agentic-Engineering-Framework"
    project.mkdir(exist_ok=True)
    monkeypatch.setenv("FRAMEWORK_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.delenv("FW_FOCUS_SESSION_KEY", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION", raising=False)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.circuit as circuit
    import lib.sidecar.delivery as delivery
    import lib.sidecar.inbox as inbox
    import lib.sidecar.e2e as e2e
    for m in (outbox, circuit, delivery, inbox, e2e):
        importlib.reload(m)
    return e2e, outbox, inbox


class Fakes:
    """A scripted hub + worker. Knobs flip individual hops to failure."""

    def __init__(self, e2e, outbox, inbox, cfg, *, ack_after_polls=1, hub_has_consult=True,
                 hub_has_ack=True, worker_reads=True, worker_done=True, wait_rc=0,
                 dispatch_rc=0, send_raises=False):
        self.e2e, self.outbox, self.inbox, self.cfg = e2e, outbox, inbox, cfg
        self.ack_after_polls = ack_after_polls
        self.hub_has_consult = hub_has_consult
        self.hub_has_ack = hub_has_ack
        self.worker_reads = worker_reads
        self.worker_done = worker_done
        self.wait_rc = wait_rc
        self.dispatch_rc = dispatch_rc
        self.send_raises = send_raises
        self.polls = 0
        self.clock = 0.0
        self.cmid = None
        self.dispatched = None

    # collaborators -----------------------------------------------------
    def send(self, sender, responder, body, cid):
        if self.send_raises:
            raise RuntimeError("transport down")
        self.cmid = self.outbox.write_message(from_id=sender, to=responder, body=body,
                                              conversation_id=cid)
        self.outbox.record_ack(self.cmid, responder, None, self.outbox.INJECTED_NOW)
        return self.e2e.delivery.DeliveryResult(self.cmid, self.outbox.INJECTED_NOW, True, "")

    def dispatch(self, name, task, prompt_path, timeout):
        self.dispatched = (name, task, open(prompt_path).read())
        return self.dispatch_rc, "Worker spawned" if self.dispatch_rc == 0 else "boom"

    def wait(self, name, timeout):
        return self.wait_rc, f"Worker {name} finished (exit: {self.wait_rc})"

    def result(self, name):
        return "did the thing\nDONE\n" if self.worker_done else "gave up\n"

    def _env(self, offset, frm, cid, body, cmid):
        return {"offset": offset,
                "metadata": {"client_msg_id": cmid, "conversation_id": cid, "from_agent": frm},
                "payload_b64": base64.b64encode(body.encode()).decode()}

    def hub_messages(self, topic, cursor=0, limit=200):
        cfg = self.cfg
        if topic == self.inbox.inbox_topic(cfg.responder):
            return [self._env(0, cfg.sender, cfg.conversation_id, cfg.nonce, self.cmid)] \
                if self.hub_has_consult else []
        if topic == self.inbox.inbox_topic(cfg.sender):
            return [self._env(0, cfg.responder, cfg.conversation_id, cfg.ack, "ack-1")] \
                if self.hub_has_ack else []
        return []

    def read_inbox(self, sender):
        self.polls += 1
        if self.hub_has_ack and self.polls >= self.ack_after_polls:
            return [{"offset": 0, "client_msg_id": "ack-1", "from": self.cfg.responder,
                     "conversation_id": self.cfg.conversation_id, "body": self.cfg.ack}]
        return []

    def cursor(self, topic):
        return 1 if self.worker_reads else 0

    def sleep(self, s):
        self.clock += s

    def now(self):
        return self.clock

    def run(self, **kw):
        return self.e2e.run(self.cfg, send=self.send, dispatch=self.dispatch, wait=self.wait,
                            result=self.result, hub_messages=self.hub_messages,
                            read_inbox=self.read_inbox, cursor=self.cursor,
                            sleep=self.sleep, now=self.now, **kw)


def _cfg(e2e, **kw):
    return e2e.Config(task="T-0001", timeout=60, poll_interval=5, run_id="abc12345", **kw)


def test_full_pass_all_six_hops(mods, tmp_path):
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e))
    r = f.run(prompt_dir=tmp_path / "p")
    assert [r["hops"][h]["ok"] for h in e2e.HOPS] == [True] * 6
    assert r["verdict"] == "PASS"
    assert r["client_msg_id"] == f.cmid
    # the responder was dispatched with the explicit prompt naming the nonce + ack
    name, task, prompt = f.dispatched
    assert name == "e2e-abc12345-responder" and task == "T-0001"
    assert "SIDECAR-E2E abc12345" in prompt and "SIDECAR-E2E-ACK abc12345" in prompt
    assert "A1" not in r["hops"]
    assert r["timings"]["reply_seen"] >= 0


def test_reply_never_arrives_is_a_recorded_fail_not_an_exception(mods, tmp_path):
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e), hub_has_ack=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert r["hops"]["H1"]["ok"] and r["hops"]["H2"]["ok"]
    assert not r["hops"]["H4"]["ok"] and not r["hops"]["H5"]["ok"]
    assert "no ACK" in r["hops"]["H5"]["detail"]
    assert r["verdict"] == "FAIL"
    assert f.clock >= 60  # the whole window was spent waiting, then it moved on
    assert r["polls"] >= 12


def test_hub_never_shows_our_consult_fails_h2_only(mods, tmp_path):
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e), hub_has_consult=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert not r["hops"]["H2"]["ok"]
    assert r["hops"]["H5"]["ok"]  # the fake still answered; H2 is independent evidence
    assert r["verdict"] == "FAIL"


def test_worker_exits_without_done_fails_h6(mods, tmp_path):
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e), worker_done=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert not r["hops"]["H6"]["ok"] and "DONE=no" in r["hops"]["H6"]["detail"]
    assert r["verdict"] == "FAIL"


def test_dispatch_failure_skips_worker_hops_but_still_asks_the_hub(mods, tmp_path):
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e), dispatch_rc=3)
    r = f.run(prompt_dir=tmp_path / "p")
    assert r["hops"]["H1"]["ok"] and r["hops"]["H2"]["ok"]
    for h in ("H3", "H4", "H5", "H6"):
        assert not r["hops"][h]["ok"] and "not attempted" in r["hops"][h]["detail"]
    assert r["dispatch"]["rc"] == 3
    assert r["verdict"] == "FAIL"


def test_send_raising_records_h1_and_skips_everything(mods, tmp_path):
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e), send_raises=True)
    r = f.run(prompt_dir=tmp_path / "p")
    assert not r["hops"]["H1"]["ok"] and "send raised" in r["hops"]["H1"]["detail"]
    assert f.dispatched is None
    assert r["verdict"] == "FAIL"


def test_ambient_mode_folds_h3_h5_into_a1_and_never_blocks_on_them(mods, tmp_path):
    e2e, outbox, inbox = mods
    # Un-instructed worker did NOT answer: transport still PASS, A1 recorded FAIL.
    f = Fakes(e2e, outbox, inbox, _cfg(e2e, ambient=True), hub_has_ack=False, worker_reads=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert r["blocking_hops"] == ["H1", "H2", "H6"]
    assert r["verdict"] == "PASS"
    assert not r["hops"]["A1"]["ok"]
    # and the ambient prompt says nothing about consults
    assert "inbox" not in f.dispatched[2].lower() and "consult" not in f.dispatched[2].lower()
    # Un-instructed worker DID answer: A1 PASS.
    g = Fakes(e2e, outbox, inbox, _cfg(e2e, ambient=True))
    r2 = g.run(prompt_dir=tmp_path / "q")
    assert r2["hops"]["A1"]["ok"] and r2["verdict"] == "PASS"


def test_free_form_answer_from_the_responder_counts_but_strangers_and_other_threads_do_not(mods):
    e2e, outbox, inbox = mods
    cfg = _cfg(e2e)
    # live run 0153e35a: un-instructed worker phrased its own ack
    assert e2e.is_ack(cfg, sender=cfg.responder, conversation_id=cfg.conversation_id,
                      body="ack SIDECAR-E2E abc12345")
    assert e2e.is_ack(cfg, sender=cfg.responder, conversation_id=cfg.conversation_id, body=cfg.ack)
    # hub envelopes without a from_agent are still accepted on the right thread
    assert e2e.is_ack(cfg, sender=None, conversation_id=cfg.conversation_id, body=cfg.ack)
    # wrong thread, wrong sender, or no run id: not an answer
    assert not e2e.is_ack(cfg, sender=cfg.responder, conversation_id="other", body=cfg.ack)
    assert not e2e.is_ack(cfg, sender="someone-else", conversation_id=cfg.conversation_id, body=cfg.ack)
    assert not e2e.is_ack(cfg, sender=cfg.responder, conversation_id=cfg.conversation_id, body="hello")


def test_peer_mode_consults_a_real_agent_and_never_dispatches(mods, tmp_path):
    e2e, outbox, inbox = mods
    cfg = _cfg(e2e, peer="010-termlink")
    assert cfg.responder == "010-termlink" and cfg.mode == "peer"
    assert cfg.blocking_hops() == ("H1", "H2", "H4", "H5")
    body = cfg.consult_body()
    assert cfg.nonce in body and cfg.ack in body and cfg.sender in body and cfg.conversation_id in body
    f = Fakes(e2e, outbox, inbox, cfg)
    r = f.run(prompt_dir=tmp_path / "p")
    assert f.dispatched is None                      # nothing spawned
    assert r["mode"] == "peer" and r["peer"] == "010-termlink"
    for h in ("H1", "H2", "H4", "H5"):
        assert r["hops"][h]["ok"], h
    assert r["hops"]["H3"]["detail"].startswith("not applicable")
    assert r["hops"]["H6"]["detail"].startswith("not applicable")
    assert r["verdict"] == "PASS"
    assert "n/a " in e2e.render(r)


def test_peer_that_has_not_answered_yet_is_pending_not_fail(mods, tmp_path):
    """T-3476: a peer-mode timeout on H4/H5 alone is "no answer yet", not
    "broken" — live: run ab947312 recorded FAIL at 1800s, then the peer
    answered 73h05m later. H1/H2 passing is what tells them apart."""
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e, peer="010-termlink"), hub_has_ack=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert r["hops"]["H1"]["ok"] and r["hops"]["H2"]["ok"]
    assert not r["hops"]["H4"]["ok"] and not r["hops"]["H5"]["ok"]
    assert r["verdict"] == "PENDING"
    assert f.dispatched is None


def test_peer_mode_h1_or_h2_failure_is_still_fail_not_pending(mods, tmp_path):
    """Control leg: PENDING is reserved for "no answer yet". Real breakage
    (we could not post, or the hub never held it) stays FAIL even in peer
    mode — the two must not collapse into one label."""
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e, peer="010-termlink"), hub_has_consult=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert not r["hops"]["H2"]["ok"]
    assert r["verdict"] == "FAIL"

    g = Fakes(e2e, outbox, inbox, e2e.Config(task="T-0001", timeout=60, poll_interval=5,
                                              run_id="raises1", peer="010-termlink"),
              send_raises=True)
    r2 = g.run(prompt_dir=tmp_path / "q")
    assert not r2["hops"]["H1"]["ok"]
    assert r2["verdict"] == "FAIL"


def test_non_peer_mode_never_produces_pending(mods, tmp_path):
    """PENDING only makes sense in peer mode: a dispatched worker's process
    has already exited by the time run() returns, so there is nothing left
    to settle later. A non-peer timeout stays FAIL."""
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e), hub_has_ack=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert r["verdict"] == "FAIL"


def test_settle_turns_pending_into_pass_when_the_late_ack_lands(mods, tmp_path):
    """AC2: a stored PENDING record re-reads and settles WITHOUT re-sending —
    keyed on its own client_msg_id and conversation_id, not a fresh send."""
    e2e, outbox, inbox = mods
    cfg = _cfg(e2e, peer="010-termlink")
    f = Fakes(e2e, outbox, inbox, cfg, hub_has_ack=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert r["verdict"] == "PENDING"
    sent_cmid = f.cmid

    def hub_with_late_ack(topic, cursor=0, limit=200):
        real = f.hub_messages(topic, cursor, limit)
        if topic == inbox.inbox_topic(cfg.sender):
            return [f._env(1, cfg.responder, cfg.conversation_id, cfg.ack, "late-ack-1")]
        return real

    settled = e2e.settle(r, hub_messages=hub_with_late_ack)
    assert settled is r  # updated in place
    assert settled["verdict"] == "PASS"
    assert settled["hops"]["H4"]["ok"] and settled["hops"]["H5"]["ok"]
    assert "settled from hub evidence" in settled["hops"]["H5"]["detail"]
    assert settled["client_msg_id"] == sent_cmid  # never re-sent
    assert settled["settle_history"][-1]["from_verdict"] == "PENDING"
    assert settled["settle_history"][-1]["to_verdict"] == "PASS"
    assert "settled_at" in settled


def test_settle_stays_pending_when_still_no_ack(mods, tmp_path):
    e2e, outbox, inbox = mods
    cfg = _cfg(e2e, peer="010-termlink")
    f = Fakes(e2e, outbox, inbox, cfg, hub_has_ack=False)
    r = f.run(prompt_dir=tmp_path / "p")
    assert r["verdict"] == "PENDING"
    settled = e2e.settle(r, hub_messages=f.hub_messages)  # hub still has no ACK
    assert settled["verdict"] == "PENDING"
    assert settled["settle_history"][-1] == {
        "at": settled["settled_at"], "from_verdict": "PENDING", "to_verdict": "PENDING"}


def test_settle_refuses_non_peer_records(mods, tmp_path):
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e))
    r = f.run(prompt_dir=tmp_path / "p")
    with pytest.raises(ValueError, match="not peer"):
        e2e.settle(r)


def test_ab947312_regression_settles_to_pass_from_the_real_73h_round_trip(mods):
    """T-3476 origin fixture: T-3426's live run `ab947312` recorded FAIL at
    the 1800s window; the peer's real answer landed on the legacy
    `sidecar:` alias 73h05m later. The stored (pre-T-3433 `topics` field)
    record must still settle correctly via the legacy-topic fallback."""
    e2e, outbox, inbox = mods
    fixture = (Path(__file__).resolve().parents[2] / ".context" / "sidecar" / "e2e"
               / "ab947312.json")
    report = json.loads(fixture.read_text(encoding="utf-8"))
    assert report["verdict"] == "FAIL"
    assert "topics" not in report  # the shape this regression must survive

    def hub_with_late_ack(topic, cursor=0, limit=200):
        if topic == "sidecar:010-termlink":
            return [{"offset": 1,
                     "metadata": {"client_msg_id": report["client_msg_id"],
                                  "conversation_id": report["conversation_id"],
                                  "from_agent": None},
                     "payload_b64": base64.b64encode(b"SIDECAR-E2E ab947312").decode()}]
        if topic == "sidecar:e2e-ab947312-sender":
            return [{"offset": 7,
                     "metadata": {"from_agent": "010-termlink",
                                  "conversation_id": report["conversation_id"]},
                     "payload_b64": base64.b64encode(b"SIDECAR-E2E-ACK ab947312").decode()}]
        return []

    settled = e2e.settle(report, hub_messages=hub_with_late_ack)
    assert settled["verdict"] == "PASS"
    assert settled["hops"]["H4"]["ok"] and settled["hops"]["H5"]["ok"]
    assert settled["settle_history"][-1]["from_verdict"] == "FAIL"
    assert settled["settle_history"][-1]["to_verdict"] == "PASS"


def test_cli_refuses_ambient_with_peer(mods, capsys):
    import lib.sidecar_cli as cli
    importlib.reload(cli)
    rc = cli.main(["e2e", "--peer", "010-termlink", "--ambient", "--task", "T-1"])
    # preflight may refuse first on a host without termlink; either way the
    # combination never reaches run() — exit code 2 and nothing dispatched.
    assert rc == 2


def test_report_round_trips_and_renders(mods, tmp_path):
    e2e, outbox, inbox = mods
    f = Fakes(e2e, outbox, inbox, _cfg(e2e))
    r = f.run(prompt_dir=tmp_path / "p")
    path = e2e.write_report(r, tmp_path / "reports")
    back = json.loads(path.read_text())
    assert back["verdict"] == "PASS" and back["run_id"] == "abc12345"
    text = e2e.render(back)
    assert "[PASS] H1" in text and "[PASS] H6" in text and "verdict: PASS" in text


# ── T-3433: the record names the addresses, and the alias still counts ──────

def test_report_records_every_topic_the_run_touched(mods):
    e2e, outbox, inbox = mods
    cfg = _cfg(e2e)
    report = Fakes(e2e, outbox, inbox, cfg).run()

    topics = report["topics"]
    assert topics["responder"][0] == inbox.inbox_topic(cfg.responder)
    assert topics["responder"][0].startswith("inbox:cacc73ea32b121dd/")
    assert topics["sender"][1] == f"sidecar:{cfg.sender}"   # the read alias
    assert cfg.run_id in topics["sender"][0]


def test_an_answer_on_the_legacy_alias_still_satisfies_h4(mods):
    """A peer that has not switched yet replies on sidecar:<sender>; the
    transition alias is exactly what makes that reply arrive rather than
    vanish, so the hop must see it."""
    e2e, outbox, inbox = mods
    cfg = _cfg(e2e, peer="010-termlink")
    fakes = Fakes(e2e, outbox, inbox, cfg)

    def legacy_only(topic, cursor=0, limit=200):
        if topic == f"sidecar:{cfg.sender}":
            return [fakes._env(0, cfg.responder, cfg.conversation_id, cfg.ack, "ack-1")]
        if topic == inbox.inbox_topic(cfg.responder):
            return [fakes._env(0, cfg.sender, cfg.conversation_id, cfg.nonce, fakes.cmid)]
        return []

    fakes.hub_messages = legacy_only
    report = fakes.run()
    assert report["hops"]["H4"]["ok"]
    assert f"sidecar:{cfg.sender}" in report["hops"]["H4"]["detail"]


def test_peer_consult_body_names_the_new_topic_and_the_alias(mods):
    e2e, outbox, inbox = mods
    cfg = _cfg(e2e, peer="010-termlink")
    body = cfg.consult_body()
    assert inbox.inbox_topic(cfg.sender) in body
    assert f"sidecar:{cfg.sender}" in body
