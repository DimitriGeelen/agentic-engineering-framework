"""T-5141 — probe_hub named every failed `termlink hub probe` "TLS handshake failed".

010 T-3797 / 1409-sprind: a sender with no hubs.toml profile for the hub had its
bare hub name handed to `hub probe` as an address; the non-zero exit was reported
as a TLS failure and 1409 debugged TLS for hours. The probe now names its real
reason: the missing profile, or termlink's own stderr. All termlink calls go
through a stub runner; hubs.toml is a temp file. No network traffic.
"""

import importlib
import json

import pytest

ADDR = "192.168.10.121:9100"


class _Proc:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode, self.stdout, self.stderr = returncode, stdout, stderr


@pytest.fixture()
def tt(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    import lib.sidecar.termlink_transport as mod
    importlib.reload(mod)
    return mod


def _hubs(tmp_path, body):
    d = tmp_path / ".termlink"
    d.mkdir(exist_ok=True)
    (d / "hubs.toml").write_text(body)
    return d / "hubs.toml"


def _secret(tmp_path):
    p = tmp_path / "dash.hex"
    p.write_text("ab" * 32)
    return p


def _runner(*, probe_rc=0, probe_err="", doctor_rows=None, calls=None):
    def run(argv, **kw):
        if calls is not None:
            calls.append(argv[1:])
        if argv[1:3] == ["hub", "probe"]:
            return _Proc(probe_rc, "" if probe_rc else json.dumps({"fingerprint": "x"}), probe_err)
        if argv[1:3] == ["fleet", "doctor"]:
            return _Proc(0, json.dumps({"hubs": doctor_rows or []}))
        raise AssertionError(argv)
    return run


# ── criterion 1: no profile says so ──────────────────────────────────────────

def test_no_profile_and_failed_probe_names_the_missing_profile(tt, tmp_path):
    """The 010/1409 case: only a local-hub profile; the remote name is unknown."""
    path = _hubs(tmp_path, '[hubs.local-hub]\naddress = "127.0.0.1:9100"\nsecret_file = "/x"\n')
    v = tt.probe_hub("ring20-management", hubs_file=path, runner=_runner(
        probe_rc=1, probe_err="Error: failed to resolve address ring20-management"))
    assert v.ok is False
    assert ("no hubs.toml profile for ring20-management: no address or credential "
            "for this user") in v.reason
    assert "TLS handshake failed" not in v.reason
    assert "failed to resolve address ring20-management" in v.reason
    assert v.credential_refused is False   # unchanged: this path was never final


def test_absent_hubs_toml_and_failed_probe_names_the_missing_profile(tt, tmp_path):
    v = tt.probe_hub("ring20-management", runner=_runner(probe_rc=1, probe_err="boom"))
    assert v.ok is False and "no hubs.toml profile for ring20-management" in v.reason
    assert "TLS handshake failed" not in v.reason


def test_no_profile_with_reachable_address_also_says_so(tt, tmp_path):
    path = _hubs(tmp_path, '[hubs.other]\naddress = "10.0.0.9:9100"\nsecret_file = "/x"\n')
    v = tt.probe_hub(ADDR, hubs_file=path, runner=_runner())
    assert v.ok is False
    assert f"no hubs.toml profile for {ADDR}: no address or credential for this user" in v.reason
    assert "termlink remote profile add" in v.reason   # the remedy is kept


# ── criterion 2: a failed probe carries termlink's own stderr ────────────────

def test_failed_probe_with_profile_carries_termlink_stderr_one_line(tt, tmp_path):
    path = _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{_secret(tmp_path)}"\n')
    stderr = "warning: retrying\nError: connection refused (os error 111)\n"
    v = tt.probe_hub("dash", hubs_file=path, runner=_runner(
        probe_rc=1, probe_err=stderr,
        doctor_rows=[{"hub": "dash", "status": "error", "error": "connect timeout"}]))
    assert v.ok is False
    assert "connection refused (os error 111)" in v.reason
    assert "\n" not in v.reason and "warning: retrying" not in v.reason
    assert "TLS handshake failed" not in v.reason


def test_failed_probe_never_uses_a_fixed_tls_phrase(tt, tmp_path):
    for err in ("Error: certificate pin mismatch", "Error: no route to host", ""):
        v = tt.probe_hub("ring20-management", runner=_runner(probe_rc=2, probe_err=err))
        assert "TLS handshake failed" not in v.reason
        assert (err or "no output") in v.reason


def test_runner_exception_carries_its_own_text(tt, tmp_path):
    def run(argv, **kw):
        raise OSError("termlink: permission denied")
    v = tt.probe_hub("ring20-management", runner=run)
    assert v.ok is False and "permission denied" in v.reason
    assert "TLS handshake failed" not in v.reason


def test_failed_probe_but_authenticated_read_clears_floor_is_ok_with_note(tt, tmp_path):
    """The weaker rung failing does not refuse a hub the stronger rung cleared."""
    path = _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{_secret(tmp_path)}"\n')
    v = tt.probe_hub("dash", hubs_file=path, runner=_runner(
        probe_rc=1, probe_err="Error: handshake eof",
        doctor_rows=[{"hub": "dash", "status": "ok", "hub_version": "0.12.103"}]))
    assert v.ok is True, v.reason
    assert "handshake eof" in v.note and "authenticated version read succeeded" in v.note


def test_failed_probe_below_floor_still_refused(tt, tmp_path):
    path = _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{_secret(tmp_path)}"\n')
    v = tt.probe_hub("dash", hubs_file=path, runner=_runner(
        probe_rc=1, probe_err="Error: eof",
        doctor_rows=[{"hub": "dash", "status": "ok", "hub_version": "0.9.1"}]))
    assert v.ok is False and "below the version floor" in v.reason and "Error: eof" in v.reason


def test_passing_probe_has_no_note(tt, tmp_path):
    path = _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{_secret(tmp_path)}"\n')
    v = tt.probe_hub("dash", hubs_file=path, runner=_runner(
        doctor_rows=[{"hub": "dash", "status": "ok", "hub_version": "0.12.103"}]))
    assert v.ok is True and v.note == ""
