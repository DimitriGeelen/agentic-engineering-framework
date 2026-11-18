"""T-5142 — every `fw sidecar send` ends with ONE verdict line.

010 T-3797 / 1409-sprind: one send printed both `HUB_ACCEPTED` and
`hub-refused: … TLS handshake failed`, the message had in fact arrived, and the
sender re-sent the same consult six times. The send now prints one verdict line
(`delivered: …` / `NOT delivered: …`) with every other state as detail beneath
it, and `--json` carries the same single `verdict` field.

Nothing reaches a hub: addressing.resolve, the transport and the probe are
stubs; the outbox lives in a temp project; hubs.toml is a temp file.
"""
from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

OWN = "cacc73ea32b121dd"
REMOTE = "d1993c2c3ec44c94"
VERDICTS = ("delivered:", "NOT delivered:")


@pytest.fixture()
def cli(tmp_path, monkeypatch):
    proj = tmp_path / "proj"
    (proj / ".context" / "sidecar").mkdir(parents=True)
    (proj / ".framework.yaml").write_text("project: x\n")
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", OWN)
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "sender-t5142")
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    from lib import sidecar_cli as mod
    importlib.reload(mod)

    def resolve(to, **k):
        hub = k.get("hub")
        hid = REMOTE if hub and hub != "local" else OWN
        return {"circuit": f"{hid}/{to}", "hub": hub if hid == REMOTE else None,
                "how": "peer directory" if not hub else f"--hub {hub}"}
    monkeypatch.setattr(mod.addressing, "resolve", resolve)
    posted = []
    monkeypatch.setattr(mod.transport, "termlink_transport",
                        lambda msg, **k: posted.append(msg) or 7)
    mod._posted = posted
    return mod


def _probe(cli, monkeypatch, result):
    monkeypatch.setattr(cli.transport, "probe_hub", lambda hub, **k: result)


def _run(cli, capsys, argv):
    rc = cli.main(["send", *argv])
    return rc, capsys.readouterr()


def _one_verdict(out: str) -> str:
    lines = out.splitlines()
    verdicts = [ln for ln in lines if ln.startswith(VERDICTS)]
    assert len(verdicts) == 1, out
    assert lines[0] == verdicts[0], "the verdict comes first; everything else is detail"
    return verdicts[0]


# ── accepted with a failed probe (the 010/1409 case) ─────────────────────────

def test_accepted_with_failed_probe_reads_delivered(cli, capsys, monkeypatch):
    note = ("reachability probe failed (termlink hub probe ring20-management exit 1: "
            "Error: handshake eof); the authenticated version read succeeded")
    _probe(cli, monkeypatch, cli.delivery.ProbeResult(True, "authenticated", note=note))
    rc, cap = _run(cli, capsys, ["--to", "ring20-manager", "--hub", "ring20-management",
                                 "--body", "consult"])
    assert rc == 0 and len(cli._posted) == 1
    v = _one_verdict(cap.out)
    assert v.startswith("delivered: HUB_ACCEPTED")
    assert f"probe note: {note}" in cap.out.splitlines()
    assert "hub-refused" not in cap.out and "NOT delivered" not in cap.out


def test_real_probe_with_failed_tls_probe_still_delivers(cli, capsys, monkeypatch, tmp_path):
    """End to end through the real probe_hub: profile present, `hub probe` fails,
    authenticated read clears the floor -> post goes out -> delivered + note."""
    sec = tmp_path / "s.hex"
    sec.write_text("ab" * 32)
    hubs = tmp_path / "hubs.toml"
    hubs.write_text(f'[hubs.ring20-management]\naddress = "192.168.10.122:9100"\n'
                    f'secret_file = "{sec}"\n')

    class P:
        def __init__(self, rc, out="", err=""):
            self.returncode, self.stdout, self.stderr = rc, out, err

    def runner(argv, **kw):
        if argv[1:3] == ["hub", "probe"]:
            return P(1, err="Error: handshake eof")
        if argv[1:3] == ["fleet", "doctor"]:
            return P(0, json.dumps({"hubs": [{"hub": "ring20-management", "status": "ok",
                                              "hub_version": "0.12.103"}]}))
        raise AssertionError(argv)

    real = importlib.import_module("lib.sidecar.termlink_transport").probe_hub
    monkeypatch.setattr(cli.transport, "probe_hub",
                        lambda hub, **k: real(hub, runner=runner, hubs_file=hubs))
    rc, cap = _run(cli, capsys, ["--to", "ring20-manager", "--hub", "ring20-management",
                                 "--body", "consult"])
    assert rc == 0
    assert _one_verdict(cap.out).startswith("delivered: HUB_ACCEPTED")
    assert "handshake eof" in cap.out and "TLS handshake failed" not in cap.out


# ── refused ──────────────────────────────────────────────────────────────────

def test_refused_is_one_not_delivered_verdict_and_never_claims_acceptance(cli, capsys, monkeypatch):
    _probe(cli, monkeypatch, cli.delivery.ProbeResult(
        False, "hub ring20-management unreachable: no hubs.toml profile for ring20-management: "
               "no address or credential for this user"))
    rc, cap = _run(cli, capsys, ["--to", "ring20-manager", "--body", "consult"])
    assert rc == 1 and cli._posted == []
    v = _one_verdict(cap.out)
    assert v.startswith("NOT delivered: STORED (kept in the outbox; retried)")
    assert "HUB_ACCEPTED" not in cap.out          # the competing state of the 010 report
    assert any(ln.startswith("reason: hub-refused:") for ln in cap.out.splitlines())
    receiver = [ln for ln in cap.out.splitlines() if ln.startswith("receiver:")]
    assert receiver and "the hub path was tried" in receiver[0]


def test_credential_refused_says_final(cli, capsys, monkeypatch):
    _probe(cli, monkeypatch, cli.delivery.ProbeResult(False, "no secret", credential_refused=True))
    rc, cap = _run(cli, capsys, ["--to", "x", "--hub", "ring20-management", "--body", "c"])
    assert rc == 1
    assert _one_verdict(cap.out).startswith("NOT delivered: UNKNOWN (final; not retried)")


# ── no receiver ──────────────────────────────────────────────────────────────

def test_no_receiver_is_detail_under_delivered(cli, capsys, monkeypatch):
    _probe(cli, monkeypatch, cli.delivery.ProbeResult(True, "local hub"))
    rc, cap = _run(cli, capsys, ["--to", "010-termlink", "--body", "consult"])
    assert rc == 0
    lines = cap.out.splitlines()
    assert _one_verdict(cap.out).startswith("delivered: HUB_ACCEPTED")
    rec = [i for i, ln in enumerate(lines) if ln.startswith("receiver:")]
    assert rec and rec[0] > 0 and "no receiver registered for 010-termlink" in lines[rec[0]]


# ── cross-hub route ──────────────────────────────────────────────────────────

def test_cross_hub_route_one_verdict_naming_the_hub(cli, capsys, monkeypatch):
    _probe(cli, monkeypatch, cli.delivery.ProbeResult(True, "authenticated"))
    rc, cap = _run(cli, capsys, ["--to", "ring20-manager", "--hub", "ring20-management",
                                 "--body", "consult"])
    assert rc == 0
    v = _one_verdict(cap.out)
    assert f"inbox:{REMOTE}/ring20-manager" in v and "on hub ring20-management" in v
    assert cli._posted[0]["hub"] == "ring20-management"
    assert "probe note" not in cap.out


# ── --json: one verdict field ────────────────────────────────────────────────

@pytest.mark.parametrize("probe,verdict,delivered", [
    ({"ok": True, "reason": "ok", "note": "reachability probe failed (x)"}, "delivered", True),
    ({"ok": False, "reason": "refused"}, "NOT delivered", False),
])
def test_json_carries_one_verdict_field(cli, capsys, monkeypatch, probe, verdict, delivered):
    _probe(cli, monkeypatch, cli.delivery.ProbeResult(**probe))
    rc, cap = _run(cli, capsys, ["--to", "x", "--hub", "ring20-management", "--body", "c", "--json"])
    lines = cap.out.strip().splitlines()
    assert len(lines) == 1
    payload = json.loads(lines[0])
    assert payload["verdict"] == verdict and payload["delivered"] is delivered
    if delivered:
        assert payload["note"] == "reachability probe failed (x)"


def test_json_refusal_before_posting_carries_the_verdict(cli, capsys):
    rc, cap = _run(cli, capsys, ["--to", "x", "--body", "  ", "--json"])
    assert rc == 2
    assert json.loads(cap.out.strip())["verdict"] == "NOT delivered"


def test_direct_path_one_verdict_and_json_field(cli, capsys, monkeypatch):
    monkeypatch.setattr(cli.lifecycle, "lookup", lambda to: {"url": "http://127.0.0.1:1/"})
    monkeypatch.setattr(cli.direct, "send", lambda entry, **k: {
        "client_msg_id": "m9", "state": cli.direct.RECEIVED, "error": None, "deadline": None})
    rc, cap = _run(cli, capsys, ["--to", "peer", "--body", "c"])
    assert rc == 0 and _one_verdict(cap.out).startswith("delivered: RECEIVED")
    rc, cap = _run(cli, capsys, ["--to", "peer", "--body", "c", "--json"])
    assert json.loads(cap.out.strip())["verdict"] == "delivered"
