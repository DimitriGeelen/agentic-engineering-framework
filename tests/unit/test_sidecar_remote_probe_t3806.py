"""T-3806 — `fw sidecar send --hub <remote>` was refused for every remote hub.

probe_hub() told the user to "supply hub credentials" and no code path took
any. The fix reads the hub's version through an authenticated termlink call
(`fleet doctor --json`, which calls `hub.version` with each hubs.toml
profile's own secret and TOFU pin) and checks the floor on the result. A
missing credential is refused by name. All termlink calls go through a fake
runner; hubs.toml is a temp file.
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


def _runner(doctor_rows, calls=None, probe_rc=0):
    def run(argv, **kw):
        if calls is not None:
            calls.append(argv[1:])
        if argv[1:3] == ["hub", "probe"]:
            return _Proc(probe_rc, json.dumps({"fingerprint": "sha256:abc"}))
        if argv[1:3] == ["fleet", "doctor"]:
            return _Proc(0, json.dumps({"hubs": doctor_rows}))
        raise AssertionError(argv)
    return run


def test_remote_hub_passes_on_authenticated_version_at_floor(tt, tmp_path):
    _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{_secret(tmp_path)}"\n')
    calls = []
    v = tt.probe_hub(ADDR, runner=_runner(
        [{"hub": "dash", "status": "ok", "hub_version": "0.12.103"}], calls))
    assert v.ok is True, v.reason
    assert "authenticated" in v.reason and "0.12.103" in v.reason
    assert ["fleet", "doctor", "--json", "--timeout", "5"] in calls


def test_profile_name_resolves_to_its_address_for_the_tls_probe(tt, tmp_path):
    _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{_secret(tmp_path)}"\n')
    calls = []
    v = tt.probe_hub("dash", runner=_runner(
        [{"hub": "dash", "status": "ok", "hub_version": "0.12.103"}], calls))
    assert v.ok is True
    assert ["hub", "probe", ADDR, "--json"] in calls


def test_remote_hub_below_floor_is_refused(tt, tmp_path):
    _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{_secret(tmp_path)}"\n')
    v = tt.probe_hub(ADDR, runner=_runner(
        [{"hub": "dash", "status": "ok", "hub_version": "0.9.1"}]))
    assert v.ok is False and "below the version floor" in v.reason


def test_no_profile_names_hubs_toml_and_the_remedy(tt, tmp_path):
    path = _hubs(tmp_path, '[hubs.other]\naddress = "10.0.0.9:9100"\nsecret_file = "/x"\n')
    v = tt.probe_hub(ADDR, runner=_runner([]))
    assert v.ok is False
    assert str(path) in v.reason and ADDR in v.reason
    assert "termlink remote profile add" in v.reason
    assert "version floor is unestablished" in v.reason and "unreachable" not in v.reason


def test_absent_hubs_toml_is_named(tt, tmp_path):
    v = tt.probe_hub(ADDR, runner=_runner([]))
    assert v.ok is False and "no termlink hub profiles file at" in v.reason


def test_missing_secret_file_names_profile_and_path(tt, tmp_path):
    _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{tmp_path}/gone.hex"\n')
    calls = []
    v = tt.probe_hub(ADDR, runner=_runner([], calls))
    assert v.ok is False
    assert "profile dash" in v.reason and f"{tmp_path}/gone.hex" in v.reason
    assert not [c for c in calls if c[:2] == ["fleet", "doctor"]], "no auth attempt without a credential"


def test_auth_failure_reports_the_secret_source(tt, tmp_path):
    sec = _secret(tmp_path)
    _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{sec}"\n')
    v = tt.probe_hub(ADDR, runner=_runner(
        [{"hub": "dash", "status": "error", "secret_source": str(sec),
          "error": "auth rejected: HMAC mismatch"}]))
    assert v.ok is False
    assert "HMAC mismatch" in v.reason and str(sec) in v.reason


def test_unreachable_still_says_unreachable(tt, tmp_path):
    _hubs(tmp_path, f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{_secret(tmp_path)}"\n')
    v = tt.probe_hub(ADDR, runner=_runner([], probe_rc=1))
    assert v.ok is False and "unreachable" in v.reason


def test_one_good_profile_among_duplicates_suffices(tt, tmp_path):
    sec = _secret(tmp_path)
    _hubs(tmp_path, f'[hubs.a]\naddress = "{ADDR}"\nsecret_file = "{sec}"\n'
                    f'[hubs.b]\naddress = "{ADDR}"\nsecret_file = "{sec}"\n')
    v = tt.probe_hub(ADDR, runner=_runner(
        [{"hub": "a", "status": "error", "error": "stale secret"},
         {"hub": "b", "status": "ok", "hub_version": "0.12.103"}]))
    assert v.ok is True and "profile b" in v.reason
