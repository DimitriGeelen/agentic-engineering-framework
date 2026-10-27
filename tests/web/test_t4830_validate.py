"""T-4830 (T-4737 GO): POST /api/validate, a thin wrapper over 832's pinned validate-workflow.py.

Both directions: a clean map gives zero findings AND a broken one gives the specific rule id
back (an endpoint only ever seen returning [] is indistinguishable from one that finds nothing).
Unavailability is 503, never an empty list.
"""
import hashlib
from pathlib import Path

import pytest
import yaml

import web.blueprints.designer_api as designer_api
from web.shared import FRAMEWORK_ROOT

CLEAN = (FRAMEWORK_ROOT / "tests/fixtures/832/s4-exemplar.bpmn").read_text()
WARNS = (FRAMEWORK_ROOT / "tests/fixtures/832-outbound/t406-incidental-leading-boilerplate.bpmn").read_text()
BROKEN = '<a xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"/>'


@pytest.fixture()
def client():
    from web.app import app
    app.config["TESTING"] = True
    designer_api._VALIDATOR_CACHE.clear()
    return app.test_client()


def post(client, body, **kw):
    return client.post("/api/validate", json=body, **kw)


def test_pin_records_validator_sha_matching_installed_file():
    pin = yaml.safe_load((FRAMEWORK_ROOT / "policy/designer-pin.yaml").read_text())
    data = (FRAMEWORK_ROOT / pin["validator_path"]).read_bytes()
    assert hashlib.sha256(data).hexdigest() == pin["validator_sha256"]
    assert len(data) == pin["validator_bytes"]


def test_clean_map_ok_with_no_findings(client):
    r = post(client, {"bpmn": CLEAN})
    assert r.status_code == 200
    d = r.get_json()
    assert d == {"ok": True, "findings": [], "errors": 0, "warnings": 0}


def test_warnings_keep_ok_true_and_shape(client):
    d = post(client, {"bpmn": WARNS}).get_json()
    assert d["ok"] is True and d["errors"] == 0 and d["warnings"] == len(d["findings"]) > 0
    assert set(d["findings"][0]) == {"severity", "rule", "location", "message"}


def test_broken_map_returns_the_rule_id(client):
    d = post(client, {"bpmn": BROKEN}).get_json()
    # T-4845: ok means the check ran (832 T-1300 §1); the error count is in "errors".
    assert d["ok"] is True and d["errors"] >= 1
    assert "E-XML-STRUCTURE" in [f["rule"] for f in d["findings"]]


def test_garbage_is_a_parse_finding_not_empty(client):
    r = post(client, {"bpmn": "<not xml"})
    assert r.status_code == 200
    assert "E-XML-PARSE" in [f["rule"] for f in r.get_json()["findings"]]


@pytest.mark.parametrize("body", [{}, {"bpmn": ""}, {"bpmn": "   "}, {"bpmn": 5}, []])
def test_empty_input_is_400(client, body):
    assert post(client, body).status_code == 400


def test_validator_absent_is_503_not_empty_list(client, monkeypatch):
    monkeypatch.setattr(designer_api, "_PIN_FILE", Path("/nonexistent/designer-pin.yaml"))
    r = post(client, {"bpmn": CLEAN})
    assert r.status_code == 503
    assert "findings" not in r.get_json()


def test_validator_sha_mismatch_is_503(client, monkeypatch, tmp_path):
    pin = yaml.safe_load((FRAMEWORK_ROOT / "policy/designer-pin.yaml").read_text())
    pin["validator_sha256"] = "0" * 64
    f = tmp_path / "pin.yaml"
    f.write_text(yaml.safe_dump(pin))
    monkeypatch.setattr(designer_api, "_PIN_FILE", f)
    r = post(client, {"bpmn": CLEAN})
    assert r.status_code == 503 and "mismatch" in r.get_json()["error"]


def test_unpinned_validator_is_503(client, monkeypatch, tmp_path):
    f = tmp_path / "pin.yaml"
    f.write_text("version: '0'\n")
    monkeypatch.setattr(designer_api, "_PIN_FILE", f)
    assert post(client, {"bpmn": CLEAN}).status_code == 503


def test_unexpected_failure_is_500(client, monkeypatch):
    class Boom:
        @staticmethod
        def run_xml(_):
            raise RuntimeError("boom")
    monkeypatch.setattr(designer_api, "_load_validator", lambda: (Boom, None))
    assert post(client, {"bpmn": CLEAN}).status_code == 500


def test_no_csrf_token_needed_same_origin_json(client):
    # the designer sends no token; the app-level guard must not 403 this route
    r = client.post("/api/validate", json={"bpmn": CLEAN}, headers={"Origin": "http://localhost"})
    assert r.status_code == 200


def test_cross_origin_refused(client):
    r = client.post("/api/validate", json={"bpmn": CLEAN}, headers={"Origin": "http://evil.example"})
    assert r.status_code == 403


def test_form_post_refused(client):
    r = client.post("/api/validate", data={"bpmn": CLEAN})
    assert r.status_code == 415
