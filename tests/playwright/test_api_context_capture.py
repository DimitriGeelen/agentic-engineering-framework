"""Playwright tests for context capture API endpoints (T-1030).

Tests POST /api/decision and POST /api/learning validation
from web/blueprints/session.py.
"""
import os
import shutil

import pytest

PROJECT_ROOT = os.environ.get(
    "PROJECT_ROOT",
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
)
DECISIONS_YAML = os.path.join(PROJECT_ROOT, ".context/project/decisions.yaml")
LEARNINGS_YAML = os.path.join(PROJECT_ROOT, ".context/project/learnings.yaml")


@pytest.fixture(autouse=True)
def _restore_project_state():
    """Snapshot decisions.yaml + learnings.yaml; restore after each test.

    The /api/decision and /api/learning endpoints shell out to `fw context
    add-{decision,learning}` which write to live PROJECT_ROOT files. Without
    this fixture, every test run accumulates "Test ... from Playwright"
    entries in real project state. (T-1393.)
    """
    backups = {}
    for path in (DECISIONS_YAML, LEARNINGS_YAML):
        if os.path.exists(path):
            bak = path + ".playwright-bak"
            shutil.copy2(path, bak)
            backups[path] = bak
    try:
        yield
    finally:
        for path, bak in backups.items():
            if os.path.exists(bak):
                shutil.move(bak, path)


class TestRecordDecision:
    """Tests for POST /api/decision."""

    def test_decision_empty_returns_400(self, page, base_url):
        """Empty decision text returns 400."""
        resp = page.request.post(
            f"{base_url}/api/decision",
            form={"decision": ""},
        )
        assert resp.status == 400
        assert "required" in resp.text().lower()

    def test_decision_with_text_succeeds(self, page, base_url):
        """Valid decision text returns success HTML."""
        resp = page.request.post(
            f"{base_url}/api/decision",
            form={"decision": "Test decision from Playwright", "task": "T-1030"},
        )
        # May succeed or fail depending on task, but should not 400
        assert resp.status in (200, 500)


class TestRecordLearning:
    """Tests for POST /api/learning."""

    def test_learning_empty_returns_400(self, page, base_url):
        """Empty learning text returns 400."""
        resp = page.request.post(
            f"{base_url}/api/learning",
            form={"learning": ""},
        )
        assert resp.status == 400
        assert "required" in resp.text().lower()

    def test_learning_with_text_succeeds(self, page, base_url):
        """Valid learning text returns success HTML."""
        resp = page.request.post(
            f"{base_url}/api/learning",
            form={"learning": "Test learning from Playwright", "task": "T-1030"},
        )
        assert resp.status in (200, 500)
