"""T-2021: Cockpit System Health renders traceability as a percentage, not a raw dict.

`fw scan` writes `project_health.traceability` as a dict
({score, total_tasks, completed, active}); the cockpit template was authored for
the scalar int that `core._get_traceability()` returns. Jinja stringified the dict
→ the System Health panel showed `{'score': 0.97…, …}` instead of a percentage.

These tests pin the producer/consumer contract by driving controlled scan data
through the *real* cockpit template (GET "/" with `load_scan` monkeypatched):
  - dict shape → a percentage, never the dict repr;
  - legacy scalar shape → still renders as-is (defensive);
  - missing → a placeholder, no traceback.

The live-render taste check is the single Human [REVIEW] AC; the browser render is
covered in tests/playwright/test_cockpit_traceability.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _client():
    from web.app import app
    return app.test_client()


def _scan_with_traceability(trace):
    """Minimal scan payload — get_cockpit_context reads the rest via .get() defaults."""
    return {
        "project_health": {
            "traceability": trace,
            "audit_status": "PASS",
            "knowledge": {"learnings": 1, "patterns": 2, "decisions": 3},
        },
    }


def test_dict_traceability_renders_percentage(monkeypatch):
    from web.blueprints import core
    trace = {"score": 0.9746, "total_tasks": 1577, "completed": 1537, "active": 40}
    monkeypatch.setattr(core, "load_scan", lambda: _scan_with_traceability(trace))
    html = _client().get("/").get_data(as_text=True)
    # the raw Python dict repr must NOT leak into the page
    assert "{'score'" not in html
    # 0.9746 * 100 → round → 97%
    assert '<span class="wt-pulse-value">97%</span>' in html


def test_scalar_traceability_still_renders(monkeypatch):
    """Legacy scalar shape (core._get_traceability int) renders unchanged — defensive."""
    from web.blueprints import core
    monkeypatch.setattr(core, "load_scan", lambda: _scan_with_traceability(42))
    html = _client().get("/").get_data(as_text=True)
    assert '<span class="wt-pulse-value">42</span>' in html
    assert "{'score'" not in html


def test_missing_traceability_renders_placeholder(monkeypatch):
    """None/missing → '?' placeholder, page still renders (no traceback)."""
    from web.blueprints import core
    monkeypatch.setattr(core, "load_scan", lambda: _scan_with_traceability(None))
    resp = _client().get("/")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert '<span class="wt-pulse-value">?</span>' in html
