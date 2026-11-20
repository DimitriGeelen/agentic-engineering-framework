"""T-5262: a project's CSRF (form-safety) exemptions, `csrf-exemption` entries.

Each entry names endpoints or a whole blueprint, the credential they check and the
proving test. Watchtower probes every listed endpoint at startup and applies the
exemption only when it refuses requests without a valid credential. Fixture project
in a temp dir; the real `.framework-extensions.yaml` is never touched.
"""
import json
import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("PROJECT_ROOT", str(FRAMEWORK_ROOT))

import web.app as web_app  # noqa: E402

FIXTURE = FRAMEWORK_ROOT / "tests" / "fixtures" / "project_ext"
STATE = Path(".context") / "working" / "watchtower-extensions.json"
EXT = FRAMEWORK_ROOT / "lib" / "extensions.py"
TOKEN, KEY = "fixture-good-token", "fixture-good-key"

API = textwrap.dedent('''
    from flask import Blueprint, abort, request
    bp = Blueprint("csrf_api", __name__)

    @bp.route("/csrf-api/tap", methods=["POST"])
    def tap():
        if request.headers.get("Authorization") != "Bearer %s":
            abort(401)
        return "tapped"

    @bp.route("/csrf-api/presence", methods=["POST"])
    def presence():
        if "X-Fixture-Key" not in request.headers:   # header presence only
            abort(403)
        return "let through"

    @bp.route("/csrf-api/open", methods=["POST"])
    def unlisted():
        return "no exemption listed"
''') % TOKEN

VPN = textwrap.dedent('''
    from flask import Blueprint, abort, request
    bp = Blueprint("csrf_vpn", __name__)

    @bp.route("/csrf-vpn/<int:n>/up", methods=["POST", "PUT"])
    def up(n):
        if request.headers.get("X-Fixture-Key") != "%s":
            abort(403)
        return "up %%d" %% n

    @bp.route("/csrf-vpn/state", methods=["GET"])
    def state():
        return "read only"
''') % KEY


def _entry(eid, kind, *paths, **extra):
    e = {"id": eid, "kind": kind, "paths": list(paths), "words": "fixture decision",
         "decided_by": "operator", "date": "2026-11-20"}
    e.update(extra)
    return e


PAGES = [_entry("api", "page", "web_ext/csrf_api.py"), _entry("vpn", "page", "web_ext/csrf_vpn.py")]
TAP = _entry("tap", "csrf-exemption", "csrf_api.tap", auth="bearer", test="tests/test_tap_auth.py")
WEAK = _entry("weak", "csrf-exemption", "csrf_api.presence", auth="header:X-Fixture-Key",
              test="tests/test_tap_auth.py")
VPNX = _entry("vpnx", "csrf-exemption", "blueprint:csrf_vpn", auth="header:X-Fixture-Key",
              test="tests/test_tap_auth.py")
GONE = _entry("gone", "csrf-exemption", "csrf_api.nope", "blueprint:nobp", auth="bearer",
              test="tests/missing_test.py")


def _project(tmp_path, entries):
    root = tmp_path / "proj"
    shutil.copytree(FIXTURE, root)
    (root / "web_ext" / "csrf_api.py").write_text(API)
    (root / "web_ext" / "csrf_vpn.py").write_text(VPN)
    (root / "tests").mkdir()
    (root / "tests" / "test_tap_auth.py").write_text("# fixture proving test\n")
    (root / ".framework-extensions.yaml").write_text(json.dumps({"extensions": entries}))
    return root


@pytest.fixture
def clean_modules():
    before, path_before = set(sys.modules), list(sys.path)
    yield
    for name in set(sys.modules) - before:
        if name.startswith("fw_project_page_"):
            sys.modules.pop(name, None)
    sys.path[:] = path_before


@pytest.fixture
def built(tmp_path, monkeypatch, clean_modules):
    root = _project(tmp_path, PAGES + [TAP, WEAK, VPNX, GONE])
    monkeypatch.setattr(web_app, "PROJECT_ROOT", root)
    app = web_app.create_app()
    st = json.loads((root / STATE).read_text())
    return root, app, {r["id"]: r for r in st["csrf"]["entries"]}


def test_proper_bearer_check_is_applied(built):
    _, app, rec = built
    assert rec["tap"]["applied"] == ["csrf_api.tap"] and not rec["tap"]["refused"]
    c = app.test_client()
    assert c.post("/csrf-api/tap", headers={"Authorization": f"Bearer {TOKEN}"}).status_code == 200
    assert c.post("/csrf-api/tap").status_code == 401        # own auth still applies


def test_header_presence_only_endpoint_is_refused_and_stays_protected(built):
    _, app, rec = built
    assert rec["weak"]["applied"] == []
    reason = rec["weak"]["refused"][0]["reason"]
    assert rec["weak"]["refused"][0]["endpoint"] == "csrf_api.presence"
    assert "answered 200" in reason and "wrong credential" in reason and "presence only" in reason
    resp = app.test_client().post("/csrf-api/presence", headers={"X-Fixture-Key": KEY})
    assert resp.status_code == 403 and b"CSRF" in resp.data


def test_blueprint_form_covers_its_state_changing_endpoints(built):
    _, app, rec = built
    assert rec["vpnx"]["applied"] == ["csrf_vpn.up"] and not rec["vpnx"]["refused"]
    c = app.test_client()
    assert c.put("/csrf-vpn/7/up", headers={"X-Fixture-Key": KEY}).data == b"up 7"
    assert c.post("/csrf-vpn/7/up", headers={"X-Fixture-Key": "wrong"}).status_code == 403


def test_missing_endpoint_and_blueprint_are_recorded(built):
    _, _, rec = built
    assert rec["gone"]["missing"] == ["csrf_api.nope", "blueprint:nobp"]
    assert rec["gone"]["applied"] == []


def test_unlisted_endpoint_still_needs_a_csrf_token(built):
    _, app, _ = built
    assert app.test_client().post("/csrf-api/open").status_code == 403
    assert app.test_client().post("/csrf-api/open",
                                  headers={"Authorization": f"Bearer {TOKEN}"}).status_code == 403


def test_probe_bypass_is_gone_after_startup(built):
    from web import project_extensions as pext
    _, app, _ = built
    resp = app.test_client().post("/csrf-api/open", environ_base={pext.PROBE_ENVIRON_KEY: "guess"})
    assert resp.status_code == 403


def _audit_rows(root):
    out = subprocess.run([sys.executable, str(EXT), "--project", str(root), "audit"],
                         capture_output=True, text=True, check=True).stdout
    return [ln.split("\t") for ln in out.splitlines()]


def test_audit_info_fail_rows(built):
    root, _, _ = built
    rows = _audit_rows(root)
    titles = {(r[0], r[1]) for r in rows}
    assert any(lv == "INFO" and "tap applied" in t and "decided by operator" in t for lv, t in titles)
    assert any(lv == "FAIL" and "weak" in t and "csrf_api.presence refused" in t for lv, t in titles)
    assert any(lv == "FAIL" and "gone" in t and "csrf_api.nope does not exist" in t for lv, t in titles)
    assert any(lv == "FAIL" and "gone" in t and "blueprint:nobp does not exist" in t for lv, t in titles)
    assert any(lv == "FAIL" and "gone" in t and "missing_test.py does not exist" in t for lv, t in titles)
    assert not any(lv == "WARN" and "csrf" in t.lower() for lv, t in titles)
    # fw doctor's surface carries the same rows, FAIL shown as WARN (doctor reads INFO/WARN).
    doc = subprocess.run([sys.executable, str(EXT), "--project", str(root), "web-status"],
                         capture_output=True, text=True, check=True).stdout
    assert "\nFAIL\t" not in "\n" + doc and "csrf_api.presence refused" in doc


def test_audit_warns_until_watchtower_checks_the_entry(built):
    root, _, _ = built
    reg = json.loads((root / ".framework-extensions.yaml").read_text())
    reg["extensions"].append(_entry("later", "csrf-exemption", "csrf_api.open", auth="bearer",
                                    test="tests/test_tap_auth.py"))
    reg["extensions"][2]["auth"] = "header:X-Other"   # tap edited since the probe
    (root / ".framework-extensions.yaml").write_text(json.dumps(reg))
    rows = _audit_rows(root)
    warns = [r[1] for r in rows if r[0] == "WARN"]
    assert any("later: not checked yet" in w for w in warns)
    assert any("tap: changed since it was checked" in w for w in warns)


def test_fw_audit_emits_fail_rows(built):
    root, _, _ = built
    env = dict(os.environ, PROJECT_ROOT=str(root), FRAMEWORK_ROOT=str(FRAMEWORK_ROOT))
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    out = subprocess.run([str(FRAMEWORK_ROOT / "agents" / "audit" / "audit.sh"), "--section", "enforcement"],
                         cwd=root, env=env, capture_output=True, text=True, timeout=300).stdout
    assert "[FAIL]" in out and "csrf_api.presence refused" in out
    assert "CSRF exemption tap applied" in out
