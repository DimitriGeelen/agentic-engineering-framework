"""T-5261: a project's own Watchtower menu entries, registered as `nav` extensions.

Fixture projects live in temp dirs (tests/fixtures/project_ext copied, register
written there). The real `.framework-extensions.yaml` is never touched.
"""
import copy
import json
import logging
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("PROJECT_ROOT", str(FRAMEWORK_ROOT))

import web.app as web_app  # noqa: E402
from web.shared import NAV_GROUPS, nav_group_labels  # noqa: E402

FIXTURE = FRAMEWORK_ROOT / "tests" / "fixtures" / "project_ext"
STATE = Path(".context") / "working" / "watchtower-extensions.json"
FRAMEWORK_TITLES = [name for name, _ in NAV_GROUPS]


def _entry(eid, kind, *paths):
    return {"id": eid, "kind": kind, "paths": list(paths), "words": "fixture decision",
            "decided_by": "operator", "date": "2026-11-19"}


PAGE = _entry("hosts", "page", "web_ext/hosts.py")


@pytest.fixture
def make_app(tmp_path, monkeypatch):
    before, path_before = set(sys.modules), list(sys.path)

    def build(entries, register=True):
        root = tmp_path / "proj"
        shutil.copytree(FIXTURE, root)
        if register:
            (root / ".framework-extensions.yaml").write_text(json.dumps({"extensions": entries}))
        monkeypatch.setattr(web_app, "PROJECT_ROOT", root)
        return web_app.create_app(), root

    yield build
    for name in set(sys.modules) - before:
        if name.startswith("fw_project_page_") or name == "hosts_helper":
            sys.modules.pop(name, None)
    sys.path[:] = path_before


def _menu(html):
    """[(group, [(label, href), ...])] as drawn, sub-headings left out."""
    nav = html[html.index('<span class="nav-items">'):html.index('<li class="spacer">')]
    out = []
    for block in nav.split('<details class="dropdown')[1:]:
        title = re.search(r'<summary title="([^"]+)"', block).group(1)
        out.append((title, re.findall(r'<a href="([^"]+)"[^>]*>([^<]+)</a>', block, re.S)))
    return [(t, [(label.strip(), href) for href, label in links]) for t, links in out]


def test_new_group_is_shown_after_the_frameworks_groups(make_app):
    app, _ = make_app([PAGE, _entry("menu", "nav", "web_ext/nav.yaml")])
    menu = _menu(app.test_client().get("/cron").get_data(as_text=True))
    assert [t for t, _ in menu] == FRAMEWORK_TITLES + ["Ring20"]
    assert menu[-1][1] == [("Hosts", "/hosts"), ("Shadow check", "/hosts/shadow")]


def test_items_are_appended_after_the_frameworks_own(make_app):
    app, _ = make_app([PAGE, _entry("menu", "nav", "web_ext/nav_append.yaml")])
    menu = dict(_menu(app.test_client().get("/cron").get_data(as_text=True)))
    assert list(menu) == FRAMEWORK_TITLES
    labels = [label for label, _ in menu["Knowledge"]]
    assert labels == nav_group_labels("Knowledge") + ["Host notes"]
    for name in FRAMEWORK_TITLES:
        if name != "Knowledge":
            assert [label for label, _ in menu[name]] == nav_group_labels(name)


def test_appending_to_a_group_with_sub_headings_adds_its_own_sub_heading_last(make_app):
    app, _ = make_app([PAGE, _entry("menu", "nav", "web_ext/nav_govern.yaml")])
    html = app.test_client().get("/cron").get_data(as_text=True)
    menu = dict(_menu(html))
    assert [label for label, _ in menu["Govern"]] == nav_group_labels("Govern") + ["Host audit"]
    assert html.index('nav-subsection-label">Operations<') < html.index('nav-subsection-label">Ring20<')


def test_missing_endpoint_is_dropped_with_one_line_each_and_reported(make_app, caplog):
    with caplog.at_level(logging.WARNING, logger="web.project_extensions"):
        app, root = make_app([PAGE, _entry("menu", "nav", "web_ext/nav_missing.yaml")])
    menu = _menu(app.test_client().get("/cron").get_data(as_text=True))
    assert menu[-1] == ("Ring20", [("Hosts", "/hosts")])
    gone = [r for r in caplog.records if "Gone" in r.getMessage()]
    assert len(gone) == 1 and "does not exist" in gone[0].getMessage()
    st = json.loads((root / STATE).read_text())
    assert [d["label"] for d in st["nav"]["dropped"]] == ["Gone", "Needs an id", "Both"]
    assert "nav_groups" not in st
    out = subprocess.run([sys.executable, str(FRAMEWORK_ROOT / "lib" / "extensions.py"),
                          "--project", str(root), "web-status"], capture_output=True, text=True, check=True)
    rows = [ln.split("\t") for ln in out.stdout.splitlines()]
    assert any(r[0] == "WARN" and "Gone was dropped" in r[1] and "does not exist" in r[2] for r in rows), rows
    assert any(r[0] == "INFO" and "Ring20 > Hosts" in r[1] for r in rows), rows


def test_item_pointing_at_a_page_that_was_skipped_is_dropped(make_app):
    app, root = make_app([_entry("menu", "nav", "web_ext/nav.yaml")])   # the page is NOT registered
    menu = _menu(app.test_client().get("/cron").get_data(as_text=True))
    assert menu[-1] == ("Ring20", [("Shadow check", "/hosts/shadow")])  # the path item stays


def test_broken_or_missing_menu_file_leaves_the_menu_as_it_was(make_app):
    app, root = make_app([_entry("gone", "nav", "web_ext/no_such_nav.yaml"),
                          _entry("bad", "nav", "web_ext/hosts_helper.py")])
    resp = app.test_client().get("/cron")
    assert resp.status_code == 200
    assert [t for t, _ in _menu(resp.get_data(as_text=True))] == FRAMEWORK_TITLES
    st = json.loads((root / STATE).read_text())
    assert {d["id"] for d in st["nav"]["dropped"]} == {"gone", "bad"}


def test_no_extension_menu_is_identical_to_todays(make_app):
    app, _ = make_app([], register=False)
    from web import project_extensions as pext
    assert pext.nav_groups(NAV_GROUPS, app) is NAV_GROUPS
    with_ext = _menu(app.test_client().get("/cron").get_data(as_text=True))
    today = _menu(web_app.app.test_client().get("/cron").get_data(as_text=True))
    assert with_ext == today
    assert [t for t, _ in today] == FRAMEWORK_TITLES


def test_merging_never_changes_the_frameworks_own_list(make_app):
    before = copy.deepcopy(NAV_GROUPS)
    app, _ = make_app([PAGE, _entry("a", "nav", "web_ext/nav.yaml"),
                       _entry("b", "nav", "web_ext/nav_append.yaml"),
                       _entry("c", "nav", "web_ext/nav_govern.yaml")])
    app.test_client().get("/cron")
    assert NAV_GROUPS == before


def test_project_entries_show_on_error_pages_and_the_project_page_marks_itself_current(make_app):
    app, _ = make_app([PAGE, _entry("menu", "nav", "web_ext/nav.yaml")])
    client = app.test_client()
    assert [t for t, _ in _menu(client.get("/no-such-page").get_data(as_text=True))][-1] == "Ring20"
    html = client.get("/hosts").get_data(as_text=True)
    assert re.search(r'<a href="/hosts"\s+aria-current="page"', html)
    assert re.search(r'<details class="dropdown active-group">\s*<summary title="Ring20"', html)
