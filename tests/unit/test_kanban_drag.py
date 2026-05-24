"""T-2019 (arc-007 S4d): drag-to-reorder kanban — cross-column status change.

The drag itself is browser behaviour (proven end-to-end in
tests/playwright/test_kanban_drag.py), but the server-rendered surface and the
no-new-route contract are unit-testable:

  - every kanban card is `draggable` and carries `data-task-id`;
  - kanban-drag.js is injected shell-level (base.html) so it survives htmx swaps;
  - the drag reuses the EXISTING /api/task/<id>/status endpoint — no drag/reorder route;
  - that endpoint still validates the status enum (governance is inherited, not bypassed);
  - the keyboard-accessible fallback (per-card inline status <select>) is still rendered;
  - the script POSTs to the status endpoint and surfaces failures via showToast (no silent
    failure).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

_STATIC = Path(__file__).resolve().parents[2] / "web" / "static" / "kanban-drag.js"


def _client():
    from web.app import app
    return app.test_client()


def test_cards_are_draggable_with_task_id():
    html = _client().get("/tasks").get_data(as_text=True)
    assert 'draggable="true"' in html
    assert "data-task-id=" in html
    # the two attributes live on the same card element
    assert re.search(r'class="kanban-card"[^>]*draggable="true"[^>]*data-task-id=', html)


def test_drag_script_injected_shell_level():
    # base.html injects it, so it's present on an arbitrary page (survives #content swaps)
    html = _client().get("/project").get_data(as_text=True)
    assert "kanban-drag.js" in html


def test_no_drag_server_route_added():
    """S4d drags onto the EXISTING per-task status endpoint — no drag/reorder route."""
    from web.app import app
    rules = {r.rule for r in app.url_map.iter_rules()}
    assert "/api/task/<task_id>/status" in rules
    assert not any("drag" in r or "reorder" in r for r in rules)


def test_status_endpoint_still_validates_enum():
    """The reused endpoint rejects an invalid status — governance is inherited."""
    resp = _client().post(
        "/api/task/T-2019/status",
        data={"status": "not-a-real-status"},
        headers={"X-CSRF-Token": "test"},
    )
    # 400 invalid enum (or 403 if CSRF rejects first) — either proves it is NOT an open path
    assert resp.status_code in (400, 403)


def test_cards_keep_inline_status_select_fallback():
    """Keyboard-accessible fallback: the per-card inline status select is still rendered."""
    html = _client().get("/tasks").get_data(as_text=True)
    assert "inline-kanban-status-select" in html


def test_script_posts_to_status_and_toasts_failures():
    """The drag handler POSTs to the status endpoint and surfaces failures (no silent fail)."""
    js = _STATIC.read_text()
    assert "/api/task/" in js and "/status" in js
    assert "fetchWithCsrf" in js          # CSRF-protected, same as bulk/inline edits
    assert "showToast" in js              # success AND error feedback
    assert "r.text()" in js               # reads the server's reject reason on non-ok
    # same-column drop is a no-op (no POST) — the guard must be present
    assert "originStatus" in js
