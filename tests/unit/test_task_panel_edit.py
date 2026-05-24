"""T-2017 (arc-007 S4b): inline-edit task meta cells in the side panel.

S4a shipped the panel as a read-only fragment; S4b makes the meta cells
(status/owner/horizon/type) editable for *active* tasks by reusing the shared
`inline_select` macro + the existing /api/task/<id>/<field> endpoints — no new JS.

Server-side contract proven here:
  - an ACTIVE task's panel renders an editable select for each of the four meta
    fields, each posting to its endpoint and each carrying a CSRF token;
  - a COMPLETED task's panel stays read-only (its status falls outside the active
    enum, so editing would be meaningless);
  - the endpoints still enforce enum validation (bad value → 400) and a valid
    value routes through `fw task update` (mocked — no repo mutation in the test).

The click→change→confirm→persist browser flow is proven in
tests/playwright/test_task_panel_edit.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

ROOT = Path(__file__).resolve().parents[2]


def _client():
    from web.app import app
    return app.test_client()


def _first_task_id(location: str):
    """First task id in .tasks/<location>/ — robust to individual tasks moving."""
    d = ROOT / ".tasks" / location
    for f in sorted(d.glob("T-*.md")):
        return f.name.split("-")[0] + "-" + f.name.split("-")[1]
    return None


def test_active_task_panel_has_editable_selects():
    tid = _first_task_id("active")
    assert tid, "expected at least one active task to test against"
    html = _client().get(f"/tasks/{tid}/panel").get_data(as_text=True)
    # one inline-edit form per meta field, posting to its existing endpoint
    for field in ("status", "owner", "horizon", "type"):
        assert f'hx-post="/api/task/{tid}/{field}"' in html, f"missing {field} edit form"
    # each form carries a CSRF token (the macro's hidden field — double cover with
    # the body-level htmx:configRequest header listener)
    assert html.count('name="_csrf_token"') >= 4
    # panel-scoped result spans, not the detail page's shared ids
    assert 'id="wt-panel-horizon-result"' in html


def test_completed_task_panel_is_read_only():
    tid = _first_task_id("completed")
    assert tid, "expected at least one completed task to test against"
    html = _client().get(f"/tasks/{tid}/panel").get_data(as_text=True)
    # completed tasks expose NO inline-edit forms in the panel
    assert f'hx-post="/api/task/{tid}/status"' not in html
    assert "wt-panel-edit-cell" not in html
    # but it still renders as the read fragment
    assert tid in html and "Status" in html


def test_panel_edit_endpoint_rejects_invalid_enum():
    c = _client()
    c.get("/project")  # establish CSRF token
    with c.session_transaction() as s:
        tok = s.get("_csrf_token")
    tid = _first_task_id("active")
    r = c.post(f"/api/task/{tid}/horizon", data={"horizon": "whenever"},
               headers={"X-CSRF-Token": tok})
    assert r.status_code == 400
    assert "Invalid horizon" in r.get_data(as_text=True)


def test_panel_edit_endpoint_persists_valid_value(monkeypatch):
    """A valid value routes through `fw task update` — mocked so no task mutates."""
    import web.blueprints.tasks as tasks_mod

    calls = []

    def fake_run(cmd, *a, **k):
        calls.append(cmd)
        return ("ok", "", True)

    monkeypatch.setattr(tasks_mod, "run_fw_command", fake_run)

    c = _client()
    c.get("/project")
    with c.session_transaction() as s:
        tok = s.get("_csrf_token")
    tid = _first_task_id("active")
    r = c.post(f"/api/task/{tid}/horizon", data={"horizon": "later"},
               headers={"X-CSRF-Token": tok})
    assert r.status_code == 200
    assert "Horizon set to later" in r.get_data(as_text=True)
    assert ["task", "update", tid, "--horizon", "later"] in calls


def test_panel_edit_endpoint_enforces_csrf():
    tid = _first_task_id("active")
    # state-changing POST with no token is refused
    assert _client().post(f"/api/task/{tid}/horizon",
                          data={"horizon": "now"}).status_code == 403
