"""T-3855 — cross-hub sidecar: addressing, receipts, attribution, wake.

Every termlink call goes through a fake runner; hubs.toml is a temp file;
nothing reaches a real hub. Measured origin (2026-10-05): `fw sidecar send
--to ring20-dashboard --hub ring20-dashboard` posted to
`inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework/ring20-dashboard`
— the SENDER's namespace — and reported delivered. The recipient reads
`inbox:1389a831016c4bf1/ring20-dashboard`.
"""

import importlib
import json
import os
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)

OWN = "cacc73ea32b121dd"
THEIRS = "1389a831016c4bf1"
THEIR_FP = "sha256:" + THEIRS + "50587879af620b227df9bdb27dfabc66d2673827cecd7c5b"
ADDR = "192.168.10.121:9100"
PROJECT = "999-Agentic-Engineering-Framework"


class _Proc:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode, self.stdout, self.stderr = returncode, stdout, stderr


@pytest.fixture()
def env(tmp_path, monkeypatch):
    proj = tmp_path / PROJECT
    (proj / ".context" / "sidecar").mkdir(parents=True)
    (proj / ".framework.yaml").write_text("project: x\n")
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", OWN)
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION", raising=False)
    monkeypatch.delenv("FW_FOCUS_SESSION_KEY", raising=False)
    secret = tmp_path / "dash.hex"
    secret.write_text("ab" * 32)
    (tmp_path / ".termlink").mkdir()
    (tmp_path / ".termlink" / "hubs.toml").write_text(
        f'[hubs.ring20-dashboard]\naddress = "{ADDR}"\nsecret_file = "{secret}"\n')
    import lib.sidecar.addressing as addressing
    importlib.reload(addressing)
    return addressing


def _runner(calls=None, fp=THEIR_FP, pin=THEIR_FP, topics=(), auth=THEIRS, inst=THEIR_FP):
    def run(argv, **kw):
        if calls is not None:
            calls.append(argv[1:])
        if argv[1:3] == ["remote", "ping"]:
            # T-3873: the authenticated hub.version answer (TermLink T-3345)
            return _Proc(0, json.dumps({"ok": True, "hub_id": auth, "hub_instance_id": inst}))
        if argv[1:3] == ["hub", "probe"]:
            return _Proc(0, json.dumps({"address": argv[3], "fingerprint": fp, "ok": True}))
        if argv[1:3] == ["tofu", "list"]:
            entries = [{"host": ADDR, "fingerprint": pin}] if pin else []
            return _Proc(0, json.dumps({"entries": entries}))
        if argv[1:3] == ["channel", "list"]:
            return _Proc(0, json.dumps({"topics": [{"name": t} for t in topics]}))
        raise AssertionError(argv)
    return run


def _outbox():
    from lib.sidecar import outbox
    return outbox._outbox_dir()


# ── leg 1: addressing ───────────────────────────────────────────────────────

def test_bare_name_with_remote_hub_lands_in_the_recipients_namespace(env):
    w = env.resolve("ring20-dashboard", hub="ring20-dashboard", runner=_runner())
    assert w["topic"] == f"inbox:{THEIRS}/ring20-dashboard"
    assert w["hub"] == "ring20-dashboard"
    assert OWN not in w["topic"] and PROJECT not in w["topic"]


def test_the_measured_bug_shape_is_never_produced(env):
    w = env.resolve("ring20-dashboard", hub=ADDR, runner=_runner())
    assert w["topic"] != f"inbox:{OWN}/{PROJECT}/ring20-dashboard"


def test_unknown_bare_name_without_hub_is_refused_by_name(env):
    with pytest.raises(env.AddressError) as e:
        env.resolve("dimitri-mint-dev", runner=_runner())
    assert "dimitri-mint-dev" in str(e.value) and "not resolvable" in str(e.value)


def test_cli_refusal_posts_nothing_and_never_says_delivered(env, capsys, monkeypatch):
    from lib import sidecar_cli as cli
    importlib.reload(cli)
    monkeypatch.setattr(cli.addressing, "_subagent_evidence", lambda name, runner: None)
    posted = []
    monkeypatch.setattr(cli.delivery, "deliver", lambda *a, **k: posted.append(a))
    rc = cli.main(["send", "--to", "claude-shared-toolkit", "--body", "x"])
    err = capsys.readouterr()
    assert rc == 2 and posted == []
    assert "REFUSED" in err.err and "delivered" not in err.out
    assert not list((_outbox()).glob("*.json"))


def test_sub_agent_with_its_own_inbox_is_addressed_under_us(env):
    topic = f"inbox:{OWN}/{PROJECT}/w-t9999"
    w = env.resolve("w-t9999", runner=_runner(topics=(topic,)))
    assert w["topic"] == topic and w["hub"] is None


def test_explicit_circuit_is_verbatim_and_must_match_the_hub(env):
    w = env.resolve(f"{THEIRS}/ring20-dashboard", hub="ring20-dashboard", runner=_runner())
    assert w["topic"] == f"inbox:{THEIRS}/ring20-dashboard"
    with pytest.raises(env.AddressError):
        env.resolve(f"{OWN}/ring20-dashboard", hub="ring20-dashboard", runner=_runner())


def test_explicit_remote_circuit_without_hub_finds_the_profile(env):
    w = env.resolve(f"{THEIRS}/ring20-dashboard", runner=_runner())
    assert w["hub"] == "ring20-dashboard"


def test_explicit_circuit_on_an_unreachable_hub_is_refused(env):
    with pytest.raises(env.AddressError) as e:
        env.resolve("ffffffffffffffff/someone", runner=_runner())
    assert "no termlink hub profile reaches hub ffffffffffffffff" in str(e.value)


def test_tofu_mismatch_is_refused(env):
    with pytest.raises(env.AddressError) as e:
        env.resolve("ring20-dashboard", hub="ring20-dashboard",
                    runner=_runner(pin="sha256:" + "0" * 64))
    assert "TOFU" in str(e.value)


def test_hub_without_a_credential_is_refused(env):
    with pytest.raises(env.AddressError) as e:
        env.resolve("x", hub="10.0.0.9:9100", runner=_runner())
    assert "credential" in str(e.value)


def test_peer_directory_learned_from_from_circuit_routes_a_bare_reply(env):
    assert env.learn("ring20-dashboard", f"//host121/{THEIRS}/ring20-dashboard")
    w = env.resolve("ring20-dashboard", runner=_runner())
    assert w["topic"] == f"inbox:{THEIRS}/ring20-dashboard"
    assert w["hub"] == "ring20-dashboard"


def test_t3873_hub_id_comes_from_the_authenticated_call(env):
    calls = []
    hid, _ = env.remote_hub_id("ring20-dashboard", runner=_runner(calls), use_cache=False)
    assert hid == THEIRS
    assert ["remote", "ping", "ring20-dashboard", "--json"] in calls
    assert env.load_peers()["hubs"]["ring20-dashboard"]["source"] == "authenticated"


def test_t3873_authenticated_id_is_read_not_derived(env):
    """Once canonical-id minting lands, hub_id is NOT the fingerprint prefix;
    the authenticated value must win (010: 'read hub_id, never derive it')."""
    minted = "0123456789abcdef"
    hid, _ = env.remote_hub_id("ring20-dashboard", runner=_runner(auth=minted), use_cache=False)
    assert hid == minted


def test_t3873_null_hub_id_falls_back_to_fingerprint_with_a_warning(env, capsys):
    hid, _ = env.remote_hub_id("ring20-dashboard", runner=_runner(auth=None, inst=None),
                               use_cache=False)
    assert hid == THEIRS
    assert "no authenticated hub_id" in capsys.readouterr().err
    assert env.load_peers()["hubs"]["ring20-dashboard"]["source"] == "fingerprint"


def test_t3873_instance_and_certificate_disagree_refuses(env):
    other = "sha256:" + "ff" * 32
    with pytest.raises(env.AddressError, match="does not match the certificate"):
        env.remote_hub_id("ring20-dashboard", runner=_runner(inst=other), use_cache=False)


ATTACKER = "deadbeefdeadbeef"


def test_t3880_spoofed_from_agent_cannot_redirect_a_known_peer(env):
    """The ring20-dashboard report: one envelope claiming to be ring20-manager,
    carrying the attacker's circuit, must not move where --to goes."""
    real = f"{THEIRS}/ring20-manager"
    assert env.learn("ring20-manager", real)
    assert not env.learn("ring20-manager", f"//evil/{ATTACKER}/ring20-manager")
    assert env.peer("ring20-manager")["circuit"] == real
    c = env.load_peers()["conflicts"][-1]
    assert (c["name"], c["known"], c["claimed"], c["action"]) == (
        "ring20-manager", real, f"{ATTACKER}/ring20-manager", "refused")


def test_t3880_from_agent_naming_someone_else_learns_nothing(env):
    """from_agent=ring20-manager on a circuit whose own name is 'x' writes no
    entry for ring20-manager (nor for 'x': the envelope contradicts itself)."""
    assert not env.learn("ring20-manager", f"{ATTACKER}/x")
    assert env.peer("ring20-manager") is None and env.peer("x") is None


def test_t3880_relearning_the_same_circuit_is_a_no_op(env):
    assert env.learn("ring20-dashboard", f"{THEIRS}/ring20-dashboard")
    assert not env.learn("ring20-dashboard", f"//h/{THEIRS}/ring20-dashboard")
    assert "conflicts" not in env.load_peers()


def test_hub_id_read_is_cached(env):
    calls = []
    env.resolve("a-peer", hub="ring20-dashboard", runner=_runner(calls))
    n = len(calls)
    env.resolve("a-peer", hub="ring20-dashboard", runner=_runner(calls))
    assert len(calls) == n


def test_cli_delivered_line_names_topic_and_hub(env, capsys, monkeypatch):
    from lib import sidecar_cli as cli
    importlib.reload(cli)
    monkeypatch.setattr(cli.addressing, "remote_hub_id",
                        lambda hub, **k: (THEIRS, ADDR))

    class R:
        state, delivered, reason = "HUB_ACCEPTED", True, None

    def deliver(cid, *_):
        r = R()
        r.client_msg_id = cid
        return r
    monkeypatch.setattr(cli.delivery, "deliver", deliver)
    rc = cli.main(["send", "--to", "ring20-dashboard", "--hub", "ring20-dashboard", "--body", "x"])
    out = capsys.readouterr().out
    assert rc == 0
    assert f"inbox:{THEIRS}/ring20-dashboard" in out and "on hub ring20-dashboard" in out
    msgs = [json.loads(p.read_text()) for p in _outbox().glob("*.json")]
    assert msgs and msgs[0]["hub"] == "ring20-dashboard"
    assert msgs[0]["to"] == f"{THEIRS}/ring20-dashboard"


# ── leg 2: receipts travel back to the sender's hub ─────────────────────────

def _receipt_runner(posts, **kw):
    base = _runner(**kw)

    def run(argv, **k):
        if argv[1:3] == ["channel", "post"]:
            posts.append(argv)
            return _Proc(0, json.dumps({"delivered": {"offset": 1}}))
        return base(argv, **k)
    return run


def test_receipt_for_a_remote_sender_posts_to_the_senders_hub(env):
    from lib.sidecar import receipts
    importlib.reload(receipts)
    posts = []
    row = receipts.send({"client_msg_id": "m-1", "from": "ring20-dashboard",
                         "from_circuit": f"//dash.host/{THEIRS}/ring20-dashboard",
                         "conversation_id": "c1"},
                        receipts.RECEIVED, by="t", runner=_receipt_runner(posts))
    assert row["ok"], row
    argv = posts[0]
    assert argv[3] == f"inbox:{THEIRS}/ring20-dashboard"
    assert argv[argv.index("--hub") + 1] == "ring20-dashboard"
    assert row["via"] == f"hub:inbox:{THEIRS}/ring20-dashboard@ring20-dashboard"
    assert any(a.startswith("from_circuit=//") for a in argv)


def test_all_three_states_reach_the_remote_sender(env):
    from lib.sidecar import receipts
    importlib.reload(receipts)
    posts = []
    envl = {"client_msg_id": "m-2", "from": "ring20-dashboard",
            "from_circuit": f"{THEIRS}/ring20-dashboard", "conversation_id": "c"}
    for st in (receipts.RECEIVED, receipts.HANDED_OVER, receipts.REPLIED):
        assert receipts.send(envl, st, by="t", runner=_receipt_runner(posts))["ok"]
    assert [p[p.index("--hub") + 1] for p in posts] == ["ring20-dashboard"] * 3
    assert [a for p in posts for a in p if a.startswith("receipt_state=")] == [
        "receipt_state=RECEIVED", "receipt_state=HANDED_OVER", "receipt_state=REPLIED"]


def test_receipt_to_an_unreachable_sender_hub_fails_loudly_not_locally(env):
    from lib.sidecar import receipts
    importlib.reload(receipts)
    posts = []
    row = receipts.send({"client_msg_id": "m-3", "from": "far",
                         "from_circuit": "ffffffffffffffff/far", "conversation_id": "c"},
                        receipts.RECEIVED, by="t", runner=_receipt_runner(posts))
    assert not row["ok"] and posts == []
    assert "ffffffffffffffff" in row["error"]


def test_receipt_for_a_local_sender_has_no_hub_flag(env):
    from lib.sidecar import receipts
    importlib.reload(receipts)
    posts = []
    row = receipts.send({"client_msg_id": "m-4", "from": "peer",
                         "from_circuit": f"{OWN}/010-termlink", "conversation_id": "c"},
                        receipts.RECEIVED, by="t", runner=_receipt_runner(posts))
    assert row["ok"] and "--hub" not in posts[0]


# ── leg 3: attribution ──────────────────────────────────────────────────────

def _env(offset, meta, body=b"hello"):
    import base64
    return {"offset": offset, "ts": 1, "payload_b64": base64.b64encode(body).decode(),
            "metadata": meta}


def test_sender_named_from_circuit_when_from_agent_is_missing_and_raw_is_labelled(env, monkeypatch):
    from lib.sidecar import inbox
    importlib.reload(inbox)
    monkeypatch.setattr(inbox, "read_topics", lambda agent=None: ["inbox:t"])
    envs = [_env(0, {"client_msg_id": "a1", "from_circuit": f"//h/{THEIRS}/ring20-dashboard"}),
            _env(1, {"client_msg_id": "a2", "from_agent": "peer-x"}),
            _env(2, {})]
    msgs = inbox.pending(reader=lambda t, c, limit=100: [e for e in envs if e["offset"] >= c])
    labels = [inbox.sender_label(m) for m in msgs]
    assert labels == ["ring20-dashboard", "peer-x", "unattributed (raw post)"]
    assert "unknown" not in " ".join(labels)


def test_hook_header_never_says_unknown_and_raw_post_gets_no_reply_line(env):
    from lib.sidecar import hooks
    importlib.reload(hooks)
    attributed = hooks._block({"from_circuit": f"{THEIRS}/ring20-dashboard",
                               "client_msg_id": "m", "conversation_id": "c", "body": "b"},
                              "tok", "fw")
    assert attributed[0].startswith("## from ring20-dashboard ")
    # remote sender: the reply goes to ITS circuit, so it lands in its namespace
    assert f"--to {THEIRS}/ring20-dashboard " in attributed[4]
    raw = hooks._block({"client_msg_id": "m", "body": "b"}, "tok", "fw")
    assert raw[0].startswith("## from unattributed (raw post) ")
    assert "--to" not in raw[4] and "raw post" in raw[4]


def test_received_envelope_teaches_the_peer_directory(env, monkeypatch):
    from lib.sidecar import inbox
    importlib.reload(inbox)
    monkeypatch.setattr(inbox, "read_topics", lambda agent=None: ["inbox:t"])
    envs = [_env(0, {"client_msg_id": "p1", "from_agent": "ring20-dashboard",
                     "from_circuit": f"//dash/{THEIRS}/ring20-dashboard"})]
    inbox.pending(reader=lambda t, c, limit=100: [e for e in envs if e["offset"] >= c])
    assert env.peer("ring20-dashboard")["circuit"] == f"{THEIRS}/ring20-dashboard"


def test_cli_inbox_print_labels_raw_posts(env, monkeypatch, capsys):
    from lib import sidecar_cli as cli
    importlib.reload(cli)
    monkeypatch.setattr(cli.dm, "pending", lambda advance=True: [])
    args = type("A", (), {"peek": False, "json": False})()
    cli._print_inbox(args, [{"offset": 3, "conversation_id": "c", "body": "x"}])
    assert "from unattributed (raw post)" in capsys.readouterr().out


# ── leg 4: wake without claude-fw ───────────────────────────────────────────

MY_TOPIC = f"inbox:{OWN}/{PROJECT}"


def test_queued_frame_parsing_push_line_and_bare_json(env):
    from lib.sidecar import watcher
    importlib.reload(watcher)
    push = ('[push] inbox.queued seq=7: {"addressee_session_id": "x", '
            f'"channel": "{MY_TOPIC}", "message_offset": 3}}')
    assert watcher.queued_channel(push) == MY_TOPIC
    assert watcher.queued_channel(json.dumps({"addressee_session_id": f"{OWN}/{PROJECT}"})) == MY_TOPIC
    assert watcher.queued_channel('[push] dm.queued seq=1: {"channel": "dm:a:b"}') is None
    assert watcher.queued_channel("garbage") is None


class _FakeProc:
    """One subscribe stream; `stop` is set once it is exhausted (the follower
    would otherwise re-subscribe)."""
    def __init__(self, lines, stop=None):
        def gen():
            yield from lines
            if stop is not None:
                stop.set()
        self.stdout = gen()
        self.pid = 4242

    def terminate(self):
        pass


def test_follower_wakes_only_for_our_inbox(env, monkeypatch):
    import threading
    from lib.sidecar import watcher
    importlib.reload(watcher)
    monkeypatch.setattr(watcher, "follow_argv",
                        lambda runner=None: (["termlink", "channel", "subscribe", "inbox.queued",
                                              "--push", "--hub", "h:1"], "profile p (h:1)"))
    wake, stop = threading.Event(), threading.Event()
    seen = []

    def popen(argv, **kw):
        seen.append(argv)
        return _FakeProc([
            '[push] inbox.queued seq=1: {"channel": "inbox:someone-else"}\n',
            f'[push] inbox.queued seq=2: {{"channel": "{MY_TOPIC}", "message_offset": 0}}\n'], stop)
    watcher.follow(wake, stop, topics=[MY_TOPIC], popen=popen)
    assert wake.is_set()
    assert seen[0][3:5] == ["inbox.queued", "--push"]
    fol = watcher.read_follower()
    assert fol["frames"] == 1 and fol["last_channel"] == MY_TOPIC


def test_follower_ignores_other_inboxes(env, monkeypatch):
    import threading
    from lib.sidecar import watcher
    importlib.reload(watcher)
    monkeypatch.setattr(watcher, "follow_argv", lambda runner=None: (["termlink"], "p"))
    wake, stop = threading.Event(), threading.Event()

    def popen(argv, **kw):
        return _FakeProc(['[push] inbox.queued seq=1: {"channel": "inbox:other/x"}\n'], stop)
    watcher.follow(wake, stop, topics=[MY_TOPIC], popen=popen)
    assert not wake.is_set()


def test_follow_argv_uses_the_profile_of_our_own_hub(env, monkeypatch):
    from lib.sidecar import watcher
    importlib.reload(watcher)
    monkeypatch.setattr(watcher.shutil, "which", lambda b: "/usr/bin/termlink")
    own_fp = "sha256:" + OWN + "206a6ce20278a319e8dda6b6b4d6d5872105acccdc546d66"
    argv, why = watcher.follow_argv(runner=_runner(fp=own_fp, pin=own_fp, auth=OWN, inst=own_fp))
    assert argv == ["termlink", "channel", "subscribe", "inbox.queued", "--push", "--hub", ADDR]
    # a profile that is NOT our hub cannot carry our wake frames
    env.load_peers()  # cache was written for OWN; clear it to test the refusal
    (env.peers_path()).unlink()
    argv, why = watcher.follow_argv(runner=_runner())
    assert argv is None and "own hub" in why


def test_watcher_tick_wait_is_cut_short_by_a_wake(env, monkeypatch):
    import threading
    import time
    from lib.sidecar import watcher
    importlib.reload(watcher)
    ticks, handlers = [], {}
    monkeypatch.setattr(watcher, "run_tick", lambda seq, tick: ticks.append(time.monotonic()))
    monkeypatch.setattr(watcher, "_single_instance", lambda which: object())
    monkeypatch.setattr(watcher.signal, "signal", lambda sig, h: handlers.setdefault("term", h))

    def fake_start(wake, stop):
        threading.Timer(0.3, wake.set).start()      # an inbox.queued frame arrives
    monkeypatch.setattr(watcher, "_start_follower", fake_start)

    t = threading.Thread(target=watcher.run_forever, kwargs={"tick_s": 60}, daemon=True)
    t.start()
    deadline = time.monotonic() + 5
    while len(ticks) < 2 and time.monotonic() < deadline:
        time.sleep(0.05)
    handlers["term"]()                              # SIGTERM: stop the loop
    t.join(5)
    assert len(ticks) >= 2, "a wake must trigger a tick long before the 60 s tick"
    assert ticks[1] - ticks[0] < 5
    assert not t.is_alive()


def test_inbox_with_no_live_watcher_means_nothing_wakes(env):
    from lib.sidecar import watcher
    importlib.reload(watcher)
    v = watcher.wake_verdict({"state": "absent", "liveness": None})
    assert v["has_inbox"] is False and v["nothing_wakes"] is False
    from lib.sidecar import inbox
    inbox.save_state({"topics": {}})
    v = watcher.wake_verdict({"state": "absent", "liveness": None})
    assert v["has_inbox"] and v["nothing_wakes"]
    live = watcher.wake_verdict({"state": "live", "liveness": {"tick_s": 30}})
    assert not live["nothing_wakes"] and live["wakes"]


def test_audit_facts_report_wake_none_for_an_inbox_with_no_watcher(env, tmp_path):
    """The one fact function doctor and audit read: WAKE column = none."""
    import subprocess
    proj = tmp_path / PROJECT
    (proj / ".context" / "sidecar" / "inbox-state.json").write_text('{"topics": {}}')
    out = subprocess.run(
        ["bash", "-c", f'source "{ROOT}/lib/sidecar-audit.sh"; fw_sidecar_watcher_facts "{proj}"'],
        capture_output=True, text=True, timeout=120, env=dict(os.environ, PROJECT_ROOT=str(proj)))
    assert out.returncode == 0, out.stderr
    cols = out.stdout.rstrip("\n").split("\t")
    assert cols[0] == "absent" and cols[6] == "none", cols


def test_doctor_and_audit_fail_on_wake_none(env):
    """Both consumers turn WAKE=none into a FAIL (static: the branch exists)."""
    for rel in ("bin/fw", "agents/audit/audit.sh"):
        text = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        assert '"$_sw_wake" = "none"' in text, rel
    audit = open(os.path.join(ROOT, "agents/audit/audit.sh"), encoding="utf-8").read()
    assert 'fail "Sidecar inbox with nothing to wake it"' in audit
