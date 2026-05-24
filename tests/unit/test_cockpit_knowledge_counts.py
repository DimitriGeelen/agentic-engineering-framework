"""T-2022: Cockpit System Health Knowledge counts come from live helpers, not a missing scan key.

`cockpit.html` used to read `health.get('knowledge', {}).get(...)`, but `fw scan`
never writes `project_health.knowledge` → the counts were always `0L, 0P, 0D`.
The fix mirrors `index.html`: `core.index()` passes `knowledge_counts`
(`_get_knowledge_counts`) and `pattern_summary` (`_get_pattern_summary`) into the
cockpit context, and the template reads them.

These tests drive controlled helper values through the *real* cockpit template
(GET "/" with `load_scan` + the helpers monkeypatched) and assert the rendered
Knowledge spans reflect them — pinning the helper→template wiring.

The live-render taste check is the single Human [REVIEW] AC; the browser render is
covered in tests/playwright/test_cockpit_knowledge_counts.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _client():
    from web.app import app
    return app.test_client()


def _scan_minimal():
    """Minimal scan so core.index() takes the cockpit branch."""
    return {
        "project_health": {
            "traceability": {"score": 0.97, "total_tasks": 10, "completed": 9, "active": 1},
            "audit_status": "PASS",
        },
    }


def test_knowledge_counts_sourced_from_helpers(monkeypatch):
    from web.blueprints import core
    monkeypatch.setattr(core, "load_scan", _scan_minimal)
    monkeypatch.setattr(core, "_get_knowledge_counts",
                        lambda: {"learnings": 99, "practices": 5, "decisions": 88})
    monkeypatch.setattr(core, "_get_pattern_summary",
                        lambda: {"failure": 1, "success": 2, "antifragile": 3, "workflow": 1})
    html = _client().get("/").get_data(as_text=True)
    assert '<span class="wt-pulse-value">99</span>L' in html   # learnings
    assert '<span class="wt-pulse-value">7</span>P' in html    # 1+2+3+1 pattern types
    assert '<span class="wt-pulse-value">88</span>D' in html   # decisions
    # the old always-zero render must be gone
    assert '<span class="wt-pulse-value">0</span>L' not in html


def test_cockpit_renders_nonzero_with_real_corpus(monkeypatch):
    """With the real helpers (populated corpus), the page renders 200 and L is non-zero."""
    from web.blueprints import core
    monkeypatch.setattr(core, "load_scan", _scan_minimal)
    resp = _client().get("/")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    # corpus has hundreds of learnings — the Knowledge line must not be 0L
    assert '<span class="wt-pulse-value">0</span>L,' not in html
