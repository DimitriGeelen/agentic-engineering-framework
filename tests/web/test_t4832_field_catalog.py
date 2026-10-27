"""T-4832: GET /api/field-catalog serves the project's field catalog to designer
0.30.0's ref picker (832 contract T-1312; design docs/reports/T-4832-field-catalog-design.md).

Absent (key unset or file missing) is 404 {ok:false, error:"no field catalog"} -- the
designer hides its picker on that. Malformed is 422 for the whole file, with an error
naming the rule and never a filesystem path. A valid file is served unchanged.
"""

import gzip
import json

import pytest

import web.blueprints.designer_api as designer_api


@pytest.fixture()
def project(tmp_path, monkeypatch):
    root = tmp_path / "proj"
    root.mkdir()
    monkeypatch.setattr(designer_api, "PROJECT_ROOT", root)
    monkeypatch.delenv("FW_DESIGNER_FIELD_CATALOG", raising=False)
    monkeypatch.delenv("FW_DESIGNER_FIELD_CATALOG_MAX_BYTES", raising=False)
    return root


@pytest.fixture()
def client():
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


def _configure(root, rel, extra=""):
    (root / ".framework.yaml").write_text(f"DESIGNER_FIELD_CATALOG: {rel}\n{extra}")


def _catalog(n=1300):
    return {
        "version": 1,
        "attributes": [
            {"ref": f"crm.customer.f{i}", "notation": f"Customer.f{i}", "label": f"Field {i}",
             "system": "crm", "systemLabel": "CRM", "entity": "Customer", "dataType": "string",
             "keyRole": None, "sources": ["s1"], "x-unknown": {"kept": i}}
            for i in range(n)
        ],
        "x-top-level": "kept",
    }


def _write(root, data, name="catalog.json"):
    (root / name).write_text(data if isinstance(data, str) else json.dumps(data))


def _get(client, gz=False):
    headers = {"Accept-Encoding": "gzip"} if gz else {"Accept-Encoding": "identity"}
    return client.get("/api/field-catalog", headers=headers)


def _json(resp):
    data = resp.data
    if resp.headers.get("Content-Encoding") == "gzip":
        data = gzip.decompress(data)
    return json.loads(data)


def _assert_422(resp, rule, root):
    assert resp.status_code == 422
    body = _json(resp)
    assert body["ok"] is False and rule in body["error"]
    assert str(root.parent) not in body["error"] and ".json" not in body["error"]


def test_unset_key_is_404(client, project):
    resp = _get(client)
    assert resp.status_code == 404
    assert _json(resp) == {"ok": False, "error": "no field catalog"}


def test_missing_file_is_404(client, project):
    _configure(project, "nope.json")
    resp = _get(client)
    assert resp.status_code == 404
    assert _json(resp) == {"ok": False, "error": "no field catalog"}


def test_valid_catalog_served_unchanged(client, project):
    cat = _catalog(1300)
    _write(project, cat)
    _configure(project, "catalog.json")
    resp = _get(client)
    assert resp.status_code == 200
    assert resp.headers.get("Content-Encoding") is None
    assert _json(resp) == {"ok": True, "catalog": cat}


def test_env_overrides_file(client, project, monkeypatch):
    _write(project, _catalog(3), "other.json")
    _configure(project, "missing.json")
    monkeypatch.setenv("FW_DESIGNER_FIELD_CATALOG", "other.json")
    assert _get(client).status_code == 200


def test_missing_ref_is_422(client, project):
    cat = _catalog(5)
    del cat["attributes"][3]["ref"]
    _write(project, cat)
    _configure(project, "catalog.json")
    _assert_422(_get(client), "attribute 3 has no ref", project)


def test_blank_ref_is_422(client, project):
    cat = _catalog(5)
    cat["attributes"][2]["ref"] = "   "
    _write(project, cat)
    _configure(project, "catalog.json")
    _assert_422(_get(client), "attribute 2 has no ref", project)


def test_duplicate_ref_is_422_case_sensitive(client, project):
    cat = _catalog(5)
    cat["attributes"][4]["ref"] = cat["attributes"][1]["ref"].upper()
    _write(project, cat)
    _configure(project, "catalog.json")
    assert _get(client).status_code == 200  # differing case is a different ref
    cat["attributes"][4]["ref"] = cat["attributes"][1]["ref"]
    _write(project, cat)
    _assert_422(_get(client), "is duplicated", project)


@pytest.mark.parametrize("version", [2, "1", True, 1.0, None])
def test_wrong_version_is_422(client, project, version):
    cat = _catalog(2)
    cat["version"] = version
    _write(project, cat)
    _configure(project, "catalog.json")
    _assert_422(_get(client), "version must be 1", project)


def test_non_object_row_and_non_array_attributes_are_422(client, project):
    _configure(project, "catalog.json")
    _write(project, {"version": 1, "attributes": [{"ref": "a"}, "b"]})
    _assert_422(_get(client), "attribute 1 is not an object", project)
    _write(project, {"version": 1, "attributes": {"ref": "a"}})
    _assert_422(_get(client), "attributes must be an array", project)
    _write(project, "{not json")
    _assert_422(_get(client), "not valid UTF-8 JSON", project)


def test_oversized_file_is_422_whole(client, project):
    _write(project, _catalog(50))
    size = (project / "catalog.json").stat().st_size
    _configure(project, "catalog.json", f"DESIGNER_FIELD_CATALOG_MAX_BYTES: {size - 1}\n")
    _assert_422(_get(client), "larger than DESIGNER_FIELD_CATALOG_MAX_BYTES", project)
    _configure(project, "catalog.json", f"DESIGNER_FIELD_CATALOG_MAX_BYTES: {size}\n")
    assert _get(client).status_code == 200


def test_path_escaping_root_is_refused(client, project, tmp_path):
    _write(tmp_path, _catalog(3), "outside.json")
    _configure(project, "../outside.json")
    _assert_422(_get(client), "outside the project root", project)
    _configure(project, str(tmp_path / "outside.json"))
    _assert_422(_get(client), "outside the project root", project)
    (project / "link.json").symlink_to(tmp_path / "outside.json")
    _configure(project, "link.json")
    _assert_422(_get(client), "outside the project root", project)


def test_gzip_when_accepted_plain_otherwise(client, project):
    cat = _catalog(1300)
    _write(project, cat)
    _configure(project, "catalog.json")
    gz = _get(client, gz=True)
    assert gz.status_code == 200
    assert gz.headers["Content-Encoding"] == "gzip"
    assert "Accept-Encoding" in gz.headers["Vary"]
    assert _json(gz) == {"ok": True, "catalog": cat}
    plain = _get(client)
    assert plain.headers.get("Content-Encoding") is None
    assert "Accept-Encoding" in plain.headers["Vary"]
    assert len(gz.data) < len(plain.data) / 5
