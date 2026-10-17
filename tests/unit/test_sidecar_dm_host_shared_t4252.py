"""T-4252: a plain `fw sidecar inbox` must not drain dm rails under the host-shared identity.

Origin: the 0909 greenfield run — a worker in a project with no identity of its own ran the
preamble's `fw sidecar inbox`, resolved to the host-shared fingerprint and marked 198 DMs
addressed to other projects as read. The hub is faked throughout.
"""
import json
import subprocess
import sys
from argparse import Namespace
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import sidecar_cli  # noqa: E402
from lib.sidecar import dm, inbox  # noqa: E402

RAIL = {"name": "dm:aaaa:hostfp", "count": 5, "latest_offset": 4}
HOST_FP = "hostfp"
IDENT_ENV = ("TERMLINK_IDENTITY_FILE", "TERMLINK_AGENT_ID", "TERMLINK_IDENTITY_DIR",
             "FW_SIDECAR_IDENTITY_FP")


def _whoami(host_fp, own_fp=None):
    """Fake `termlink whoami`: own_fp when an identity env var selects one, else the host's."""
    import os

    def run(argv, **kw):
        fp = own_fp if own_fp and any(os.environ.get(k) for k in IDENT_ENV[:3]) else host_fp
        out = json.dumps({"session": {"identity_fingerprint": fp}})
        return subprocess.CompletedProcess(argv, 0, stdout=out, stderr="")
    return run


@pytest.fixture
def project(tmp_path, monkeypatch):
    """A fresh project dir with its own (empty) sidecar state."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    for k in IDENT_ENV:
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setattr(inbox.outbox, "_root", lambda: tmp_path)
    return tmp_path


def _reader(name, cursor, limit=100):
    return [{"offset": o, "msg_type": "post", "sender_id": "peer", "payload_b64": ""}
            for o in range(cursor, 5)]


def test_shared_identity_is_detected(project):
    assert dm.identity_is_host_shared(runner=_whoami(HOST_FP)) is True


def test_own_identity_is_not_shared(project, monkeypatch):
    monkeypatch.setenv("TERMLINK_IDENTITY_FILE", "/x/own.key")
    assert dm.identity_is_host_shared(runner=_whoami(HOST_FP, own_fp="ownfp")) is False


def test_configured_but_same_as_host_is_shared(project, monkeypatch):
    monkeypatch.setenv("TERMLINK_IDENTITY_FILE", "/x/own.key")
    assert dm.identity_is_host_shared(runner=_whoami(HOST_FP, own_fp=HOST_FP)) is True


def test_pending_leaves_dms_unread_under_shared_identity(project, monkeypatch):
    monkeypatch.setattr(dm, "identity_is_host_shared", lambda *a, **k: True)
    monkeypatch.setattr(dm, "identity_fingerprint", lambda *a, **k: HOST_FP)
    got = dm.pending(reader=_reader, lister=lambda: [RAIL], advance=True)
    assert got == []
    assert inbox.load_state()["topics"] == {}          # no cursor written


def test_pending_still_drains_under_own_identity(project, monkeypatch):
    monkeypatch.setattr(dm, "identity_is_host_shared", lambda *a, **k: False)
    monkeypatch.setattr(dm, "identity_fingerprint", lambda *a, **k: HOST_FP)
    got = dm.pending(reader=_reader, lister=lambda: [RAIL], advance=True)
    assert len(got) == 5
    assert inbox.load_state()["topics"][RAIL["name"]]["cursor"] == 5


def test_cli_plain_inbox_leaves_unread(project, monkeypatch, capsys):
    """The regression: shared identity + unread DMs, plain (non-peek) inbox moves nothing."""
    monkeypatch.setattr(dm, "identity_is_host_shared", lambda *a, **k: True)
    monkeypatch.setattr(dm, "identity_fingerprint", lambda *a, **k: HOST_FP)
    monkeypatch.setattr(dm, "default_lister", lambda **k: [RAIL])
    monkeypatch.setattr(dm, "rails_for_key",
                        lambda key=None, *, lister=None: [RAIL])
    monkeypatch.setattr(inbox, "inbox_topic", lambda *a, **k: "inbox:x")
    rc = sidecar_cli._print_inbox(Namespace(peek=False, json=True), [])
    assert rc == 0
    data = json.loads(capsys.readouterr().out)
    assert "dm_posts" not in data and data["dm_rails"][0]["unread"] == 5
    assert "no TermLink identity of its own" in data["dm_drain_refused"]
    assert inbox.load_state()["topics"] == {}
