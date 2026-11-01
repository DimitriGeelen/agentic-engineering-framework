"""T-4941: the host-shared check compared two readings of `termlink whoami`'s session
block, which a pid walk selects whatever the identity env says. Inside a session
registered with the project key both readings matched, so every agent session read
as host-shared (false T-4892 WARN). The host default is now the key termlink SIGNS
with when no selector is set (`termlink identity sign --json`, source host_default)."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.sidecar import dm  # noqa: E402

OWN, HOST = "ownfp000000000000", "hostfp00000000000"
SEL = ("TERMLINK_IDENTITY_FILE", "TERMLINK_AGENT_ID", "TERMLINK_IDENTITY_DIR")


def _termlink(*, session_fp=OWN, sign_ok=True):
    """Real-world shape: whoami reports the registered SESSION's key no matter the env;
    `identity sign` follows the env passed to it."""
    def run(argv, **kw):
        if argv[1:3] == ["identity", "sign"]:
            if not sign_ok:
                return subprocess.CompletedProcess(argv, 2, stdout="", stderr="unknown command")
            env = kw.get("env") or {}
            own = any(env.get(k) for k in SEL)
            out = {"fingerprint": OWN if own else HOST, "ok": True,
                   "source": "identity_file" if own else "host_default"}
            return subprocess.CompletedProcess(argv, 0, stdout=json.dumps(out), stderr="")
        out = {"session": {"identity_fingerprint": session_fp}}
        return subprocess.CompletedProcess(argv, 0, stdout=json.dumps(out), stderr="")
    return run


@pytest.fixture
def selected(monkeypatch):
    monkeypatch.delenv("FW_SIDECAR_IDENTITY_FP", raising=False)
    monkeypatch.setenv("TERMLINK_IDENTITY_FILE", "/x/project.key")


def test_host_default_is_the_signing_key_not_the_session(selected):
    assert dm._host_fingerprint(runner=_termlink()) == HOST


def test_session_with_project_key_is_not_host_shared(selected):
    assert dm.identity_is_host_shared(runner=_termlink(session_fp=OWN)) is False


def test_session_on_the_host_key_is_still_host_shared(selected):
    assert dm.identity_is_host_shared(runner=_termlink(session_fp=HOST)) is True


def test_sign_unavailable_means_host_key_unknown(selected):
    # T-4970: no whoami fallback. whoami reports the session's key (OWN) whatever the
    # env, so falling back made every project-keyed session look host-shared.
    assert dm._host_fingerprint(runner=_termlink(sign_ok=False)) is None


def test_sign_unavailable_with_a_selector_is_not_host_shared(selected):
    assert dm.identity_is_host_shared(runner=_termlink(sign_ok=False)) is False


def test_sign_unavailable_without_a_selector_is_still_host_shared(monkeypatch):
    # the drain protection does not depend on the probe: no selector means the host key
    monkeypatch.delenv("FW_SIDECAR_IDENTITY_FP", raising=False)
    for k in SEL:
        monkeypatch.delenv(k, raising=False)
    assert dm.identity_is_host_shared(runner=_termlink(sign_ok=False)) is True


def test_sign_answer_without_host_default_source_is_not_trusted(selected):
    def run(argv, **kw):
        if argv[1:3] == ["identity", "sign"]:
            out = {"fingerprint": OWN, "source": "identity_file"}
            return subprocess.CompletedProcess(argv, 0, stdout=json.dumps(out), stderr="")
        out = {"session": {"identity_fingerprint": HOST}}
        return subprocess.CompletedProcess(argv, 0, stdout=json.dumps(out), stderr="")
    assert dm._signing_host_fingerprint(runner=run) is None


# ── T-4945 (010-termlink msg 18dbaffb): a per_agent identity, not identity_file ──

def _per_agent_termlink(session_fp=OWN):
    """termlink resolves FILE > AGENT_ID > IDENTITY_DIR > host default; AGENT_ID and
    IDENTITY_DIR report source per_agent."""
    def run(argv, **kw):
        if argv[1:3] == ["identity", "sign"]:
            env = kw.get("env") or {}
            if env.get("TERMLINK_IDENTITY_FILE"):
                out = {"fingerprint": OWN, "source": "identity_file"}
            elif env.get("TERMLINK_AGENT_ID") or env.get("TERMLINK_IDENTITY_DIR"):
                out = {"fingerprint": OWN, "source": "per_agent"}
            else:
                out = {"fingerprint": HOST, "source": "host_default"}
            return subprocess.CompletedProcess(argv, 0, stdout=json.dumps(out), stderr="")
        out = {"session": {"identity_fingerprint": session_fp}}
        return subprocess.CompletedProcess(argv, 0, stdout=json.dumps(out), stderr="")
    return run


@pytest.mark.parametrize("var", ["TERMLINK_AGENT_ID", "TERMLINK_IDENTITY_DIR"])
def test_per_agent_identity_is_own_key(monkeypatch, var):
    monkeypatch.delenv("FW_SIDECAR_IDENTITY_FP", raising=False)
    for k in SEL:
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setenv(var, "some-agent" if var == "TERMLINK_AGENT_ID" else "/x/agents")
    assert dm._host_fingerprint(runner=_per_agent_termlink()) == HOST
    assert dm.identity_is_host_shared(runner=_per_agent_termlink()) is False
