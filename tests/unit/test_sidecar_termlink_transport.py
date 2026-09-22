"""T-3405 — arc-011 sidecar real TermLink transport + hub probe (Amendment 5, slice 3)."""

import importlib
import json
import subprocess

import pytest


@pytest.fixture()
def mod(tmp_path, monkeypatch):
    project = tmp_path / "999-Agentic-Engineering-Framework"
    project.mkdir(exist_ok=True)
    monkeypatch.setenv("FRAMEWORK_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "agentA")
    monkeypatch.setenv("FW_FOCUS_SESSION_KEY", "agentA")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.circuit as circuit
    import lib.sidecar.delivery as delivery
    import lib.sidecar.termlink_transport as tt
    importlib.reload(outbox)
    importlib.reload(circuit)
    importlib.reload(delivery)
    importlib.reload(tt)
    return tt, delivery, outbox


class _Proc:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def _msg(hub=None):
    return {
        "client_msg_id": "cmid-live-1",
        "from": "agentA",
        "to": "agentB",
        "hub": hub,
        "conversation_id": "conv-7",
        "body": "ping",
    }


def test_command_carries_identity_and_conversation(mod):
    tt, _, _ = mod
    argv = tt.build_post_command(_msg(), binary="termlink")

    assert argv[:4] == ["termlink", "channel", "post",
                        "inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework/agentB"]
    assert "--client-msg-id" in argv
    assert argv[argv.index("--client-msg-id") + 1] == "cmid-live-1"
    assert "client_msg_id=cmid-live-1" in argv  # observable on the envelope too
    assert "cv_key=cmid-live-1" in argv         # T-3426: hub-indexed O(1) lookup key
    assert "conversation_id=conv-7" in argv
    assert "--hub" not in argv  # same-host names no hub


def test_hub_is_appended_only_when_the_message_names_one(mod):
    """Same command shape both ways — --hub is data, not a separate branch."""
    tt, _, _ = mod
    same = tt.build_post_command(_msg(), binary="termlink")
    cross = tt.build_post_command(_msg(hub="10.0.0.5:9100"), binary="termlink")

    assert cross[:len(same)] == same  # cross-host is same-host plus --hub
    assert cross[len(same):] == ["--hub", "10.0.0.5:9100"]


def test_nonzero_exit_raises_transport_error(mod):
    tt, delivery, _ = mod

    def runner(argv, **kw):
        return _Proc(returncode=1, stderr="-32013 unknown topic")

    with pytest.raises(delivery.TransportError) as exc:
        tt.termlink_transport(_msg(), runner=runner)
    assert "exit 1" in str(exc.value)
    assert "unknown topic" in str(exc.value)


def test_timeout_raises_transport_error(mod):
    tt, delivery, _ = mod

    def runner(argv, **kw):
        raise subprocess.TimeoutExpired(cmd=argv, timeout=15)

    with pytest.raises(delivery.TransportError) as exc:
        tt.termlink_transport(_msg(), runner=runner)
    assert "timed out" in str(exc.value)


def test_successful_post_returns_offset(mod):
    tt, _, _ = mod

    def runner(argv, **kw):
        # Shape observed live against termlink 0.11.1766 (T-3405).
        return _Proc(stdout=json.dumps(
            {"confirmed": False, "delivered": {"offset": 42, "ts": 1}}))

    assert tt.termlink_transport(_msg(), runner=runner) == 42


def test_local_hub_passes_when_version_meets_floor(mod):
    tt, _, _ = mod

    def runner(argv, **kw):
        return _Proc(stdout="termlink 0.11.1766 (5eff27ece) [x86_64]")

    verdict = tt.probe_hub(None, runner=runner)
    assert verdict.ok is True
    assert "0.11.1766" in verdict.reason


def test_local_hub_refused_below_version_floor(mod):
    tt, _, _ = mod

    def runner(argv, **kw):
        return _Proc(stdout="termlink 0.9.2104 (deadbeef) [x86_64]")

    verdict = tt.probe_hub(None, runner=runner)
    assert verdict.ok is False
    assert "below the version floor" in verdict.reason


def test_reachable_remote_is_refused_naming_the_version_floor(mod):
    """Reachability must not be allowed to stand in for capability (T-2415)."""
    tt, _, _ = mod

    def runner(argv, **kw):
        # `hub probe` succeeds: TLS handshake fine, cert presented.
        return _Proc(stdout=json.dumps(
            {"address": "10.0.0.5:9100", "fingerprint": "sha256:abc"}))

    verdict = tt.probe_hub("10.0.0.5:9100", runner=runner)
    assert verdict.ok is False
    assert "version floor is unestablished" in verdict.reason
    assert "unreachable" not in verdict.reason  # the two must stay distinct


def test_unreachable_remote_says_unreachable(mod):
    tt, _, _ = mod

    def runner(argv, **kw):
        return _Proc(returncode=1, stderr="connection refused")

    verdict = tt.probe_hub("10.0.0.5:9100", runner=runner)
    assert verdict.ok is False
    assert "unreachable" in verdict.reason
    assert "version floor" not in verdict.reason  # distinct diagnosis


def test_refused_hub_blocks_delivery_end_to_end(mod):
    """The probe is an acceptance gate: a refused hub never reaches the post."""
    tt, delivery, outbox = mod
    cmid = outbox.write_message(from_id="a", to="b", body="x",
                                conversation_id="c1", hub="10.0.0.5:9100")
    posted = []

    def probe(hub):
        return tt.probe_hub(hub, runner=lambda argv, **kw: _Proc(
            stdout=json.dumps({"fingerprint": "sha256:abc"})))

    result = delivery.deliver(cmid, lambda m: posted.append(m), probe)

    assert result.delivered is False
    assert posted == []
    assert "version floor is unestablished" in outbox.latest_ack_state(cmid)["error"]


# ── T-3433: inbox:<circuit-id> addressing ───────────────────────────────────

HUB = "cacc73ea32b121dd"
PROJ = "999-Agentic-Engineering-Framework"


def test_bare_project_id_posts_to_the_durable_role_address(mod):
    tt, _, _ = mod
    msg = dict(_msg(), to="010-termlink")
    assert tt.topic_for(msg) == f"inbox:{HUB}/010-termlink"


def test_bare_agent_name_posts_to_an_agent_under_our_project(mod):
    tt, _, _ = mod
    msg = dict(_msg(), to="e2e-ab947312-responder")
    assert tt.topic_for(msg) == f"inbox:{HUB}/{PROJ}/e2e-ab947312-responder"


def test_a_full_circuit_to_is_posted_verbatim(mod):
    tt, _, _ = mod
    cid = f"{HUB}/003-NTB-ATC-Plugin/tl-9/reviewer"
    assert tt.topic_for(dict(_msg(), to=cid)) == f"inbox:{cid}"


def test_address_level_overrides_the_heuristic(mod):
    tt, _, _ = mod
    msg = dict(_msg(), to="010-termlink", address_level="agent")
    assert tt.topic_for(msg) == f"inbox:{HUB}/{PROJ}/010-termlink"


def test_post_carries_the_senders_full_host_qualified_circuit(mod):
    tt, _, _ = mod
    argv = tt.build_post_command(_msg(), binary="termlink")
    assert f"from_circuit=//host107.ring20.lan/{HUB}/{PROJ}/agentA" in argv
    assert "from_agent=agentA" in argv   # compatibility field kept


def test_explicit_from_circuit_on_the_message_wins(mod):
    tt, _, _ = mod
    msg = dict(_msg(), from_circuit=f"//other.host/{HUB}/005-Yellowtwig/worker")
    argv = tt.build_post_command(msg, binary="termlink")
    assert f"from_circuit=//other.host/{HUB}/005-Yellowtwig/worker" in argv


def test_no_sender_writes_the_legacy_prefix(mod):
    tt, _, _ = mod
    for to in ("010-termlink", "e2e-x-responder", f"{HUB}/{PROJ}/w"):
        argv = tt.build_post_command(dict(_msg(), to=to), binary="termlink")
        assert not argv[3].startswith("sidecar:")
        assert argv[3].startswith("inbox:")
