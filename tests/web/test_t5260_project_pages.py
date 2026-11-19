"""T-5260: a project's own Watchtower pages, registered as `page` extensions.

Every test builds a fixture project in a temp dir (tests/fixtures/project_ext copied,
plus a register written there). The real `.framework-extensions.yaml` is never touched.
"""
import json
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("PROJECT_ROOT", str(FRAMEWORK_ROOT))

import web.app as web_app  # noqa: E402

FIXTURE = FRAMEWORK_ROOT / "tests" / "fixtures" / "project_ext"
STATE = Path(".context") / "working" / "watchtower-extensions.json"


def _entry(eid, kind, *paths):
    return {"id": eid, "kind": kind, "paths": list(paths), "words": "fixture decision",
            "decided_by": "operator", "date": "2026-11-19"}


def _project(tmp_path, entries):
    root = tmp_path / "proj"
    shutil.copytree(FIXTURE, root)
    (root / ".framework-extensions.yaml").write_text(json.dumps({"extensions": entries}))
    return root


@pytest.fixture
def clean_modules():
    before = set(sys.modules)
    path_before = list(sys.path)
    yield
    for name in set(sys.modules) - before:
        if name.startswith("fw_project_page_") or name == "hosts_helper":
            sys.modules.pop(name, None)
    sys.path[:] = path_before


def _app(monkeypatch, root):
    """A fresh Watchtower app whose project is the fixture."""
    monkeypatch.setattr(web_app, "PROJECT_ROOT", root)
    return web_app.create_app()


def test_registered_page_is_served_with_its_template_static_and_helper(tmp_path, monkeypatch, clean_modules):
    root = _project(tmp_path, [_entry("hosts", "page", "web_ext/hosts.py")])
    client = _app(monkeypatch, root).test_client()
    resp = client.get("/hosts")
    html = resp.get_data(as_text=True)
    assert resp.status_code == 200
    assert "project-page-marker" in html           # the project's own template
    assert "<td>charlie</td>" in html              # the project's helper module
    assert '<summary title="Work"' in html         # inside the normal Watchtower chrome
    css = client.get("/ext/hosts_ext/static/hosts_ext.css")
    assert css.status_code == 200 and b"fixture static file" in css.data
    assert "/ext/hosts_ext/static/hosts_ext.css" in html


def test_framework_pages_still_served_and_registered_after_the_frameworks(tmp_path, monkeypatch, clean_modules):
    root = _project(tmp_path, [_entry("hosts", "page", "web_ext/hosts.py")])
    app = _app(monkeypatch, root)
    assert list(app.blueprints)[-1] == "hosts_ext"
    assert app.test_client().get("/cron").status_code == 200


def test_unregistered_file_in_the_folder_is_not_loaded(tmp_path, monkeypatch, clean_modules):
    root = _project(tmp_path, [_entry("hosts", "page", "web_ext/hosts.py")])
    app = _app(monkeypatch, root)
    assert app.test_client().get("/unregistered").status_code == 404
    assert "unregistered_ext" not in app.blueprints


def test_no_register_means_no_project_pages_and_no_report(tmp_path, monkeypatch, clean_modules):
    root = tmp_path / "proj"
    shutil.copytree(FIXTURE, root)
    app = _app(monkeypatch, root)
    assert app.test_client().get("/hosts").status_code == 404
    assert not (root / STATE).exists()


def test_project_template_cannot_shadow_a_framework_template(tmp_path, monkeypatch, clean_modules):
    root = _project(tmp_path, [_entry("hosts", "page", "web_ext/hosts.py")])
    resp = _app(monkeypatch, root).test_client().get("/hosts/shadow")
    html = resp.get_data(as_text=True)
    assert resp.status_code == 200
    assert "PROJECT-SHADOW-MARKER" not in html
    assert "Scheduled Jobs" in html


def test_broken_page_is_skipped_with_one_line_and_watchtower_still_serves(tmp_path, monkeypatch, caplog, clean_modules):
    root = _project(tmp_path, [_entry("broken", "page", "web_ext/broken.py"),
                               _entry("hosts", "page", "web_ext/hosts.py")])
    with caplog.at_level(logging.WARNING, logger="web.project_extensions"):
        app = _app(monkeypatch, root)
    lines = [r for r in caplog.records if "broken" in r.getMessage()]
    assert len(lines) == 1 and "skipped" in lines[0].getMessage()
    client = app.test_client()
    assert client.get("/").status_code == 200
    assert client.get("/hosts").status_code == 200      # the page after the broken one
    st = json.loads((root / STATE).read_text())
    assert [p["id"] for p in st["pages"]["skipped"]] == ["broken"]
    assert "ModuleNotFoundError" in st["pages"]["skipped"][0]["reason"]
    assert [p["id"] for p in st["pages"]["loaded"]] == ["hosts"]


def test_route_collision_is_skipped_whole_and_the_framework_route_wins(tmp_path, monkeypatch, caplog, clean_modules):
    root = _project(tmp_path, [_entry("collide", "page", "web_ext/collide.py")])
    with caplog.at_level(logging.WARNING, logger="web.project_extensions"):
        app = _app(monkeypatch, root)
    assert len([r for r in caplog.records if "collide" in r.getMessage()]) == 1
    client = app.test_client()
    resp = client.get("/tasks")
    assert resp.status_code == 200 and b"PROJECT-COLLIDE-MARKER" not in resp.data
    assert client.get("/collide-only").status_code == 404
    assert "collide_ext" not in app.blueprints
    st = json.loads((root / STATE).read_text())
    assert "route /tasks already exists" in st["pages"]["skipped"][0]["reason"]


def test_missing_file_and_module_without_bp_are_skipped(tmp_path, monkeypatch, clean_modules):
    root = _project(tmp_path, [_entry("gone", "page", "web_ext/gone.py"),
                               _entry("nobp", "page", "web_ext/hosts_helper.py")])
    app = _app(monkeypatch, root)
    assert app.test_client().get("/").status_code == 200
    st = json.loads((root / STATE).read_text())
    assert {p["id"] for p in st["pages"]["skipped"]} == {"gone", "nobp"}


def test_broken_register_does_not_stop_watchtower(tmp_path, monkeypatch, clean_modules):
    root = _project(tmp_path, [])
    (root / ".framework-extensions.yaml").write_text("extensions: [oops\n")
    app = _app(monkeypatch, root)
    assert app.test_client().get("/").status_code == 200
    assert json.loads((root / STATE).read_text())["register_error"]


def _status(root, verb):
    out = subprocess.run([sys.executable, str(FRAMEWORK_ROOT / "lib" / "extensions.py"),
                          "--project", str(root), verb], capture_output=True, text=True, check=True)
    return [ln.split("\t") for ln in out.stdout.splitlines()]


def test_doctor_and_audit_rows_list_loaded_and_warn_on_skipped(tmp_path, monkeypatch, clean_modules):
    root = _project(tmp_path, [_entry("hosts", "page", "web_ext/hosts.py"),
                               _entry("broken", "page", "web_ext/broken.py"),
                               _entry("gone", "page", "web_ext/gone.py")])
    _app(monkeypatch, root)
    for verb in ("web-status", "audit"):
        rows = _status(root, verb)
        assert any(r[0] == "INFO" and "Project pages loaded by Watchtower (1): hosts" in r[1]
                   and "/hosts" in r[1] for r in rows), (verb, rows)
        assert any(r[0] == "WARN" and "Project page broken" in r[1] for r in rows), (verb, rows)
    # the T-5259 audit check covers a page's registered path
    assert any(r[0] == "WARN" and "registered path web_ext/gone.py does not exist" in r[1]
               for r in _status(root, "audit"))


def test_registered_but_watchtower_not_started_yet_is_said(tmp_path):
    root = _project(tmp_path, [_entry("hosts", "page", "web_ext/hosts.py")])
    rows = _status(root, "web-status")
    assert rows and rows[0][0] == "INFO" and "not loaded yet" in rows[0][1]

