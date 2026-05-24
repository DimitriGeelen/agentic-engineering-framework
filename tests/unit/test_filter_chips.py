"""T-2016 (arc-007 S4c): active-filter chips on the tasks board.

The chip list is computed in the route (`_build_active_filter_chips`) so the
per-chip clear-URL logic — drop just this filter, keep the rest — is unit-testable
without a browser. The click→reload behaviour is proven in
tests/playwright/test_filter_chips.py.
"""

from __future__ import annotations

import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _chips(active, view="board"):
    from web.blueprints.tasks import _build_active_filter_chips
    return _build_active_filter_chips(active, view)


def test_one_chip_per_active_filter():
    chips = _chips({"owner": "agent", "horizon": "now", "tag": ""})
    keys = {c["key"] for c in chips}
    assert keys == {"owner", "horizon"}          # empty tag excluded
    labels = {c["label"] for c in chips}
    assert "owner: agent" in labels and "horizon: now" in labels


def test_no_filters_no_chips():
    assert _chips({"owner": "", "q": "", "status": None}) == []


def test_each_clear_url_preserves_the_other_filters():
    chips = {c["key"]: c for c in _chips({"owner": "agent", "horizon": "now"})}
    # the owner chip clears owner but KEEPS horizon (per-chip isolation, not clear-all)
    owner_q = parse_qs(urlparse(chips["owner"]["clear_url"]).query)
    assert "owner" not in owner_q and owner_q.get("horizon") == ["now"]
    # and symmetrically
    horizon_q = parse_qs(urlparse(chips["horizon"]["clear_url"]).query)
    assert "horizon" not in horizon_q and horizon_q.get("owner") == ["agent"]


def test_clear_url_keeps_current_view():
    chips = _chips({"status": "issues"}, view="list")
    assert parse_qs(urlparse(chips[0]["clear_url"]).query).get("view") == ["list"]


def test_board_renders_chip_per_active_filter():
    from web.app import app
    c = app.test_client()
    # no filters → no chip bar
    h0 = c.get("/tasks").get_data(as_text=True)
    assert "data-filter-chip" not in h0
    # two filters → a chip for each + a clear-all
    h = c.get("/tasks?owner=agent&horizon=now").get_data(as_text=True)
    assert 'data-filter-chip="owner"' in h
    assert 'data-filter-chip="horizon"' in h
    assert "filter-chips-clear-all" in h


def test_shareable_filtered_url_marks_both_chips():
    from web.app import app
    c = app.test_client()
    h = c.get("/tasks?owner=agent&status=issues").get_data(as_text=True)
    assert 'data-filter-chip="owner"' in h and 'data-filter-chip="status"' in h
