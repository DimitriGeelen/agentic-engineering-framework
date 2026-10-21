"""T-3762: a send that falls back to the hub because the target has no receiver
must say so.

Origin: 055 @135 — none of its consults reached RECEIVED because 999 and 010 had
no receiver in the host registry, and the sender saw only `delivered:
HUB_ACCEPTED`. `_cmd_send` computed "no receiver registered" to choose the hub
path, then reported only the hub's acceptance.

Nothing reaches a real hub: addressing.resolve and delivery.deliver are faked,
and the receiver registry is an empty temp dir.
"""
from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))


@pytest.fixture()
def cli(tmp_path, monkeypatch):
    proj = tmp_path / "proj"
    (proj / ".context" / "sidecar").mkdir(parents=True)
    (proj / ".framework.yaml").write_text("project: x\n")
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "sender-t3762")
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    from lib import sidecar_cli as cli
    importlib.reload(cli)
    monkeypatch.setattr(cli.addressing, "resolve", lambda to, **k: {
        "circuit": f"cacc73ea32b121dd/{to}", "hub": k.get("hub"),
        "how": "peer directory"})

    class R:
        client_msg_id, state, delivered, reason = "m1", "HUB_ACCEPTED", True, None
    monkeypatch.setattr(cli.delivery, "deliver", lambda *a, **k: R())
    return cli


def test_no_registered_receiver_is_reported(cli, capsys):
    rc = cli.main(["send", "--to", "010-termlink", "--body", "consult"])
    out = capsys.readouterr().out
    assert rc == 0
    line = [ln for ln in out.splitlines() if ln.startswith("receiver:")]
    assert line, out
    assert "no receiver registered for 010-termlink" in line[0]
    assert "HUB_ACCEPTED" in line[0]


def test_no_registered_receiver_json(cli, capsys):
    cli.main(["send", "--to", "010-termlink", "--body", "consult", "--json"])
    payload = json.loads(capsys.readouterr().out.strip().splitlines()[-1])
    assert payload["receiver"] == "none-registered"


def test_explicit_hub_does_not_claim_a_registry_check(cli, capsys):
    cli.main(["send", "--to", "010-termlink", "--hub", "local", "--body", "consult"])
    assert "receiver:" not in capsys.readouterr().out
    cli.main(["send", "--to", "010-termlink", "--hub", "local", "--body", "c", "--json"])
    payload = json.loads(capsys.readouterr().out.strip().splitlines()[-1])
    assert payload["receiver"] is None
