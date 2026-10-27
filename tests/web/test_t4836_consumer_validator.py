"""T-4836: POST /api/validate in a CONSUMER layout.

T-4830's tests ran in the framework repo, where FRAMEWORK_ROOT == PROJECT_ROOT and the
validator `fw designer sync` wrote is present, so they could not see that no consumer ever
received it. Here the consumer is built for real: `fw vendor` into a scratch project (the
vendored copy is a separate directory), then `fw designer install` from that copy, then the
blueprint is pointed at the two roots the way a consumer's Watchtower sees them.
"""
import hashlib
import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

import web.blueprints.designer_api as designer_api
from web.shared import FRAMEWORK_ROOT

BROKEN = '<a xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"/>'
PIN = yaml.safe_load((FRAMEWORK_ROOT / "policy/designer-pin.yaml").read_text())
VREL = PIN["validator_path"]


def _env():
    env = {k: v for k, v in os.environ.items() if k not in ("PROJECT_ROOT", "FRAMEWORK_ROOT")}
    env["NO_COLOR"] = "1"
    return env


@pytest.fixture(scope="module")
def consumer(tmp_path_factory):
    root = tmp_path_factory.mktemp("t4836")
    proj = root / "proj"
    proj.mkdir()
    subprocess.run(["git", "init", "-q", str(proj)], check=True)
    r = subprocess.run([str(FRAMEWORK_ROOT / "bin/fw"), "vendor", "--target", str(proj)],
                       env=_env(), capture_output=True, text=True, timeout=300)
    assert r.returncode == 0, r.stdout[-2000:] + r.stderr[-2000:]
    vend = proj / ".agentic-framework"
    assert (vend / VREL).is_file(), "fw vendor did not ship validator_path"
    assert not (proj / VREL).exists()
    yield proj, vend
    for p in (root,):
        subprocess.run(["chmod", "-R", "u+w", str(p)], check=False)
        shutil.rmtree(p, ignore_errors=True)


def _install(proj, vend):
    env = _env() | {"PROJECT_ROOT": str(proj), "FRAMEWORK_ROOT": str(vend)}
    return subprocess.run(["bash", str(vend / "agents/designer/designer.sh"), "install"],
                          env=env, capture_output=True, text=True, timeout=120)


@pytest.fixture()
def point_at(monkeypatch):
    def _point(proj, vend):
        monkeypatch.setattr(designer_api, "PROJECT_ROOT", Path(proj))
        monkeypatch.setattr(designer_api, "FRAMEWORK_ROOT", Path(vend))
        monkeypatch.setattr(designer_api, "_PIN_FILE", Path(vend) / "policy/designer-pin.yaml")
        designer_api._VALIDATOR_CACHE.clear()
    yield _point
    designer_api._VALIDATOR_CACHE.clear()


@pytest.fixture()
def client():
    from web.app import app
    app.config["TESTING"] = True
    return app.test_client()


def _pycaches(*dirs):
    return [p for d in dirs for p in Path(d).rglob("__pycache__")]


def test_consumer_after_vendor_and_install_gets_findings(consumer, point_at, client):
    proj, vend = consumer
    r = _install(proj, vend)
    assert r.returncode == 0, r.stdout + r.stderr
    assert hashlib.sha256((proj / VREL).read_bytes()).hexdigest() == PIN["validator_sha256"]
    point_at(proj, vend)
    resp = client.post("/api/validate", json={"bpmn": BROKEN})
    assert resp.status_code == 200, resp.get_json()
    d = resp.get_json()
    assert d["ok"] is False and "E-XML-STRUCTURE" in [f["rule"] for f in d["findings"]]
    assert _pycaches(proj / "vendor", vend / "vendor") == []


def test_vendored_validator_sha_mismatch_is_503(consumer, point_at, client, tmp_path):
    proj, vend = consumer
    # a consumer with no installed copy and a vendored file that does not match the pin
    bare = tmp_path / "bare"
    bad = tmp_path / "vend"
    (bad / "policy").mkdir(parents=True)
    shutil.copy(vend / "policy/designer-pin.yaml", bad / "policy/designer-pin.yaml")
    (bad / VREL).parent.mkdir(parents=True)
    (bad / VREL).write_bytes((vend / VREL).read_bytes() + b"\n# tampered\n")
    bare.mkdir()
    point_at(bare, bad)
    resp = client.post("/api/validate", json={"bpmn": BROKEN})
    assert resp.status_code == 503
    assert "sha256 mismatch" in resp.get_json()["error"]


def test_absent_everywhere_is_503_naming_install(consumer, point_at, client, tmp_path):
    proj, vend = consumer
    point_at(tmp_path, vend.parent / "no-such-vendored-copy")
    designer_api._PIN_FILE = vend / "policy/designer-pin.yaml"
    resp = client.post("/api/validate", json={"bpmn": BROKEN})
    assert resp.status_code == 503
    assert "fw designer install" in resp.get_json()["error"]


def test_project_root_copy_is_read_before_the_vendored_one(consumer, point_at, client, tmp_path):
    proj, vend = consumer
    # vendored copy corrupt, installed copy good: PROJECT_ROOT wins, so 200
    bad = tmp_path / "vend"
    (bad / VREL).parent.mkdir(parents=True)
    (bad / VREL).write_text("raise SystemExit('vendored copy must not be read')\n")
    good = tmp_path / "proj"
    (good / VREL).parent.mkdir(parents=True)
    (good / VREL).write_bytes((vend / VREL).read_bytes())
    point_at(good, bad)
    designer_api._PIN_FILE = vend / "policy/designer-pin.yaml"
    assert client.post("/api/validate", json={"bpmn": BROKEN}).status_code == 200
    assert _pycaches(good, bad) == []
