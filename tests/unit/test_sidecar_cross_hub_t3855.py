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


def _runner(calls=None, fp=THEIR_FP, pin=THEIR_FP, topics=()):
    def run(argv, **kw):
        if calls is not None:
            calls.append(argv[1:])
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
