"""T-2018 (arc-007 S4e/S6c): bulk multi-select + floating action bar.

The selection + fan-out is client JS, but the server-side surface is unit-testable:
  - every kanban card and every list row carries a `data-bulk-select` checkbox;
  - the floating bar (#wt-bulk-bar) + bulk-actions.js are injected on every page via
    base.html (shell-level), with the Now/Next/Later horizon actions + Clear;
  - the feature reuses the existing per-task endpoint — no /api/tasks/bulk route is added.

The browser behaviour (select → bar → fan-out → toast → clear) is proven end-to-end in
tests/playwright/test_bulk_actions.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _client():
    from web.app import app
    return app.test_client()


def test_board_cards_have_bulk_checkboxes():
    html = _client().get("/tasks").get_data(as_text=True)
    assert "data-bulk-select=" in html
    assert 'class="wt-bulk-select"' in html


def test_list_rows_have_bulk_checkboxes():
    html = _client().get("/tasks?view=list").get_data(as_text=True)
    assert "data-bulk-select=" in html


def test_bulk_bar_and_script_present_on_arbitrary_page():
    html = _client().get("/project").get_data(as_text=True)
    assert 'id="wt-bulk-bar"' in html            # shell-level bar root
    assert "bulk-actions.js" in html             # the selection/fan-out logic
    assert 'id="wt-bulk-count"' in html          # the live count element


def test_bar_offers_three_horizons_and_clear():
    html = _client().get("/project").get_data(as_text=True)
    for h in ("now", "next", "later"):
        assert f'data-bulk-horizon="{h}"' in html
    assert "data-bulk-clear" in html


def test_no_bulk_server_route_added():
    """S4e fans out over the EXISTING per-task endpoint — no bulk route."""
    from web.app import app
    rules = {r.rule for r in app.url_map.iter_rules()}
    # the per-task horizon endpoint the fan-out reuses exists
    assert "/api/task/<task_id>/horizon" in rules
    # and no bulk endpoint was introduced
    assert not any("bulk" in r for r in rules)
