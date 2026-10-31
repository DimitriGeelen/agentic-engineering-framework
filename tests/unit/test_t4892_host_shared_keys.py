"""T-4892: dm rails keyed by the host-shared TermLink key carry every project's mail.

832 (msg 1e2df855) set SIDECAR_DM_ADDRESS_KEYS to the .107 host key and `fw sidecar alerts`
adopted other agents' old mail; TermLink (msg 467742fb) saw the same when a project's own
identity is the host default. Both now produce a WARN line.
"""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.sidecar import dm  # noqa: E402
import lib.sidecar_cli as cli  # noqa: E402


def _env(monkeypatch, keys):
    monkeypatch.setenv("FW_SIDECAR_DM_ADDRESS_KEYS", keys)


def test_configured_host_key_is_named(monkeypatch):
    _env(monkeypatch, "aaaa111122223333, d1993c2c3ec44c94")
    monkeypatch.setattr(dm, "_host_fingerprint", lambda **kw: "d1993c2c3ec44c94")
    assert dm.host_shared_address_keys() == {"d1993c2c3ec44c94"}


def test_other_keys_and_unmeasurable_host_name_nothing(monkeypatch):
    _env(monkeypatch, "aaaa111122223333")
    monkeypatch.setattr(dm, "_host_fingerprint", lambda **kw: "d1993c2c3ec44c94")
    assert dm.host_shared_address_keys() == set()
    _env(monkeypatch, "d1993c2c3ec44c94")
    monkeypatch.setattr(dm, "_host_fingerprint", lambda **kw: None)
    assert dm.host_shared_address_keys() == set()


def test_no_configured_keys_never_measures_the_host(monkeypatch):
    _env(monkeypatch, "")
    called = []
    monkeypatch.setattr(dm, "_host_fingerprint", lambda **kw: called.append(1) or "x")
    assert dm.host_shared_address_keys() == set()
    assert called == []


def test_alerts_warns_for_shared_identity_and_shared_key(monkeypatch):
    monkeypatch.setattr(dm, "identity_is_host_shared", lambda **kw: True)
    monkeypatch.setattr(dm, "host_shared_address_keys", lambda **kw: {"d1993c2c3ec44c94"})
    lines = cli._host_shared_lines()
    assert len(lines) == 2
    assert lines[0].startswith("WARN  this project signs with the host-shared TermLink key")
    assert dm.HANDLED_FILE in lines[0]
    assert "SIDECAR_DM_ADDRESS_KEYS lists the host-shared key d1993c2c3ec44c94" in lines[1]


def test_alerts_silent_when_nothing_is_shared(monkeypatch):
    monkeypatch.setattr(dm, "identity_is_host_shared", lambda **kw: False)
    monkeypatch.setattr(dm, "host_shared_address_keys", lambda **kw: set())
    assert cli._host_shared_lines() == []


def test_alerts_check_that_cannot_run_says_nothing(monkeypatch):
    def boom(**kw):
        raise RuntimeError("termlink missing")
    monkeypatch.setattr(dm, "identity_is_host_shared", boom)
    assert cli._host_shared_lines() == []
