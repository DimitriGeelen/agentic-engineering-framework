"""T-2020 (arc-007 S6d): cockpit live activity feed — recent commits via htmx poll.

The feed is a read-only htmx-polled fragment; its server surface is fully unit-testable:
  - GET /cockpit/activity returns a chrome-less fragment of recent commits, with T-XXX
    references rendered as /tasks/T-XXX links;
  - the cockpit page mounts a card that POLLS that fragment (hx-trigger every Ns) — no reload;
  - the route is GET-only (read-only — no new mutation path);
  - the helper degrades to an empty-state when git returns nothing (no traceback);
  - the fragment reuses existing cockpit tokens so it restyles with the T-1990 redesign.

The live-refresh feel is the single Human [REVIEW] AC; the browser render is covered in
tests/playwright/test_cockpit_activity.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _client():
    from web.app import app
    return app.test_client()


def test_activity_route_returns_fragment_with_task_links():
    html = _client().get("/cockpit/activity").get_data(as_text=True)
    # chrome-less fragment (no <html>/<body> wrapper)
    assert "<html" not in html.lower()
    # recent commits reference tasks (P-002) → rendered as links
    assert "/tasks/T-" in html
    assert "wt-activity" in html


def test_cockpit_page_has_polling_activity_card():
    html = _client().get("/").get_data(as_text=True)
    assert 'hx-get="/cockpit/activity"' in html
    assert 'id="wt-activity"' in html
    # polls without reload — hx-trigger includes a timed poll
    assert "every" in html and "hx-trigger" in html


def test_activity_route_is_get_only():
    from web.app import app
    methods = set()
    found = False
    for r in app.url_map.iter_rules():
        if r.rule == "/cockpit/activity":
            found = True
            methods = r.methods
    assert found, "/cockpit/activity route not registered"
    assert "GET" in methods
    assert "POST" not in methods  # read-only — no mutation


def test_empty_git_shows_empty_state(monkeypatch):
    from web.blueprints import cockpit as cockpit_mod
    monkeypatch.setattr(cockpit_mod, "run_git_command", lambda *a, **k: ("", False))
    html = _client().get("/cockpit/activity").get_data(as_text=True)
    assert "No recent activity" in html  # graceful, not a traceback


def test_fragment_reuses_existing_cockpit_tokens():
    html = _client().get("/cockpit/activity").get_data(as_text=True)
    # wt-queue-item is an existing cockpit token (cockpit.html) — restyles with T-1990
    assert "wt-queue-item" in html


def test_helper_parses_commits_and_extracts_task_id(monkeypatch):
    from web.blueprints import cockpit as cockpit_mod
    fake = "abc1234\x1f2 hours ago\x1fT-2020: add activity feed\n" \
           "def5678\x1f3 days ago\x1fchore: no task ref here"
    monkeypatch.setattr(cockpit_mod, "run_git_command", lambda *a, **k: (fake, True))
    events = cockpit_mod._get_recent_commits(10)
    assert len(events) == 2
    assert events[0]["hash"] == "abc1234"
    assert events[0]["when"] == "2 hours ago"
    assert events[0]["task_id"] == "T-2020"
    assert events[1]["task_id"] is None  # untraced commit → no link
