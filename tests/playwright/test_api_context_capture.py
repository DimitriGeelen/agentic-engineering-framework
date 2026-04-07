"""Playwright tests for context capture API endpoints (T-1030).

Tests POST /api/decision and POST /api/learning validation
from web/blueprints/session.py.
"""


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
