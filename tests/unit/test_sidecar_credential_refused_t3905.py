"""T-3905 (G-109) — a send the hub refused on CREDENTIALS is final.

ring20 s6 joint test step 6 (2026-10-05): a deliberately wrong-secret send was
refused by the hub (-32010 invalid signature), stored in the PROJECT outbox as
retryable, and the project watcher — which holds the correct secret — retried
it. The message marked "must NOT arrive" was RECEIVED and HANDED_OVER at the
peer minutes later. A refusal of the sender's authority is an answer, not a
delay: terminal, flag consumed, never re-posted by a sweep.
"""

import importlib
import json
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 10, 5, 20, 0, 0, tzinfo=timezone.utc)
AUTH_ERR = ("Authentication failed: -32010 Token validation failed: invalid signature "
            "— termlink fleet reauth <profile>")


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "sender-test")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    import lib.sidecar.retry as retry
    import lib.sidecar.termlink_transport as tt
    for m in (outbox, delivery, retry, tt):
        importlib.reload(m)
    return outbox, delivery, retry, tt


class _Proc:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode, self.stdout, self.stderr = returncode, stdout, stderr


def _ok_probe(_hub):
    import lib.sidecar.delivery as delivery
    return delivery.ProbeResult(True)


def _empty_reader(_topic, _cursor, _limit=None):
    return []


def _write(outbox):
    return outbox.write_message(from_id="sender-test", to="22c19fedafd73da2/proxmox-ring20-management",
                                body="must NOT arrive", conversation_id="t2459-s6",
                                hub="ring20-manager")


def test_credential_refused_probe_is_terminal_and_never_swept(sc):
    outbox, delivery, retry, _tt = sc
    cmid = _write(outbox)

    def refused(_hub):
        return delivery.ProbeResult(False, f"hub ring20-manager: {AUTH_ERR}",
                                    credential_refused=True)

    posted = []
    res = delivery.deliver(cmid, posted.append, refused, now=T0)
    assert res.delivered is False and res.state == outbox.UNKNOWN
    assert res.reason.startswith("credential-refused (final, not retried)")
    assert "fw sidecar send --to 22c19fedafd73da2/proxmox-ring20-management --hub ring20-manager" in res.reason
    assert cmid not in outbox.list_pending()

    # The watcher's sweep runs later with a WORKING credential — it must not post.
    for minutes in (1, 5, 60, 24 * 60):
        retry.sweep(now=T0 + timedelta(minutes=minutes), transport=posted.append,
                    probe=_ok_probe, reader=_empty_reader)
    assert posted == []


def test_transport_auth_error_is_terminal_too(sc):
    outbox, delivery, retry, _tt = sc
    cmid = _write(outbox)

    def post(_msg):
        raise delivery.TransportError(AUTH_ERR)

    res = delivery.deliver(cmid, post, _ok_probe, now=T0)
    assert res.state == outbox.UNKNOWN and "credential-refused" in res.reason
    posted = []
    retry.sweep(now=T0 + timedelta(hours=2), transport=posted.append,
                probe=_ok_probe, reader=_empty_reader)
    assert posted == []


def test_control_unreachable_hub_stays_retryable(sc):
    """Narrowing must not turn the ladder off: a hub that is merely down is retried."""
    outbox, delivery, retry, _tt = sc
    cmid = _write(outbox)

    def down(_hub):
        return delivery.ProbeResult(False, "hub ring20-manager is unreachable: connection refused")

    res = delivery.deliver(cmid, lambda m: None, down, now=T0)
    assert res.state == outbox.STORED and cmid in outbox.list_pending()
    posted = []
    retry.sweep(now=T0 + timedelta(minutes=2), transport=posted.append,
                probe=_ok_probe, reader=_empty_reader)
    assert [m["client_msg_id"] for m in posted] == [cmid]


def test_is_auth_failure_matches_termlink_and_not_reachability(sc):
    _o, delivery, _r, _tt = sc
    assert delivery.is_auth_failure(AUTH_ERR)
    assert not delivery.is_auth_failure("connection refused (os error 111)")
    assert not delivery.is_auth_failure("hub runs termlink 0.10.0, below the version floor 0.11.0")


def _hubs(tmp_path, secret=True):
    sf = tmp_path / "r20.hex"
    if secret:
        sf.write_text("ab" * 32)
    (tmp_path / ".termlink").mkdir(exist_ok=True)
    (tmp_path / ".termlink" / "hubs.toml").write_text(
        f'[hubs.ring20-manager]\naddress = "192.168.10.122:9100"\nsecret_file = "{sf}"\n')


def test_probe_marks_a_rejected_secret_as_credential_refused(sc, tmp_path):
    _o, _d, _r, tt = sc
    _hubs(tmp_path)
    doctor = {"hubs": [{"hub": "ring20-manager", "status": "error", "error": AUTH_ERR,
                        "secret_source": "file"}]}
    r = tt._authenticated_floor("ring20-manager", runner=lambda argv, **kw: _Proc(
        stdout=json.dumps(doctor)), binary="termlink", floor=(0, 11, 0), hubs_file=None)
    assert r.ok is False and r.credential_refused is True


def test_probe_marks_a_missing_secret_as_credential_refused(sc, tmp_path):
    _o, _d, _r, tt = sc
    _hubs(tmp_path, secret=False)
    r = tt._authenticated_floor("ring20-manager", runner=lambda argv, **kw: _Proc(),
                                binary="termlink", floor=(0, 11, 0), hubs_file=None)
    assert r.ok is False and r.credential_refused is True


def test_probe_does_not_mark_a_timeout_as_credential_refused(sc, tmp_path):
    _o, _d, _r, tt = sc
    _hubs(tmp_path)
    doctor = {"hubs": [{"hub": "ring20-manager", "status": "error",
                        "error": "timed out after 5s", "secret_source": "file"}]}
    r = tt._authenticated_floor("ring20-manager", runner=lambda argv, **kw: _Proc(
        stdout=json.dumps(doctor)), binary="termlink", floor=(0, 11, 0), hubs_file=None)
    assert r.ok is False and r.credential_refused is False


def test_cli_send_exits_nonzero_when_not_delivered():
    """The exit code says so (ring20 saw 0 on 1.8.2): pinned at the source."""
    import pathlib
    src = (pathlib.Path(__file__).resolve().parents[2] / "lib" / "sidecar_cli.py").read_text()
    assert "return 0 if result.delivered else 1" in src
