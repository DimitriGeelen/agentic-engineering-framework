"""T-2015 (arc-007 S4a): slide-in dockable task side-panel — server-side guarantees.

The panel is a shell element + client-side JS, but the server-side contract is
unit-testable:
  - GET /tasks/<id>/panel returns a LEAN read fragment (id/name/meta/recommendation)
    that deliberately omits the full-page inline-edit machinery (the document-level
    listener that would leak per panel load — see the route docstring);
  - the panel shell + task-panel.js are injected on EVERY page via base.html, so the
    open/dock/Esc listeners survive htmx #content swaps;
  - the board card/row links carry data-task-panel + hx-boost="false" so the panel JS
    owns the click and the href stays a no-JS fallback;
  - the dock-save endpoint whitelists the dock value and enforces CSRF.

The browser behaviour (click→panel, dock cycle, persistence, mutual exclusion) is
proven end-to-end in tests/playwright/test_task_panel.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _client():
    from web.app import app
    return app.test_client()


def test_panel_fragment_is_lean_read_view():
    c = _client()
    html = c.get("/tasks/T-2015/panel").get_data(as_text=True)
    # the task's identity + key metadata render
    assert "T-2015" in html
    assert "Status" in html and "Horizon" in html
    # but NONE of the full-page inline-edit *script* is present (that's S4b /
    # task_detail.html; loading it into the panel would leak a document listener).
    # Match the script signatures, not bare words — this task's own AC text mentions
    # "startNameEdit" in prose, which the panel legitimately renders in the AC list.
    assert "function startNameEdit" not in html
    assert "addEventListener('htmx:afterRequest'" not in html
    assert "function startDescEdit" not in html
    # the read surface offers an escape hatch to the full editable page
    assert "Open full page" in html
    assert '/tasks/T-2015"' in html


def test_panel_route_404s_on_bad_id_and_missing_task():
    c = _client()
    assert c.get("/tasks/NOPE/panel").status_code == 404
    assert c.get("/tasks/T-99999999/panel").status_code == 404


def test_panel_shell_present_on_arbitrary_page():
    c = _client()
    html = c.get("/project").get_data(as_text=True)
    assert 'id="wt-task-panel"' in html       # the panel root (shell-level)
    assert "task-panel.js" in html            # the open/dock/Esc logic is wired in
    assert 'id="wt-task-panel-body"' in html  # the htmx swap target
    # the initial dock class is applied server-side (no flash on load)
    assert "dock-right" in html or "dock-left" in html \
        or "dock-bottom" in html or "dock-full" in html


def test_board_links_open_panel_not_full_page():
    c = _client()
    html = c.get("/tasks").get_data(as_text=True)
    assert "data-task-panel=" in html   # the panel-open hook
    assert 'hx-boost="false"' in html   # href stays the no-JS fallback


def test_dock_save_whitelists_and_requires_csrf():
    c = _client()
    c.get("/project")  # establish a CSRF token in the session
    with c.session_transaction() as s:
        tok = s.get("_csrf_token")
    # valid dock persists
    r = c.post("/settings/panel-dock/save", data={"dock": "bottom"},
               headers={"X-CSRF-Token": tok})
    assert r.status_code == 200 and r.get_json()["dock"] == "bottom"
    # junk never reaches storage as-is — falls back to the default
    r2 = c.post("/settings/panel-dock/save", data={"dock": "../etc"},
                headers={"X-CSRF-Token": tok})
    assert r2.get_json()["dock"] == "right"
    # CSRF is enforced (state-changing POST)
    assert c.post("/settings/panel-dock/save", data={"dock": "left"}).status_code == 403


def test_dock_pref_roundtrips_into_render():
    """A saved dock is reflected as the panel's initial class on the next render."""
    c = _client()
    c.get("/project")
    with c.session_transaction() as s:
        tok = s.get("_csrf_token")
    c.post("/settings/panel-dock/save", data={"dock": "bottom"},
           headers={"X-CSRF-Token": tok})
    html = c.get("/project").get_data(as_text=True)
    assert "dock-bottom" in html
