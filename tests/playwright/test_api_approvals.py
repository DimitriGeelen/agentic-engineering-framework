"""Playwright tests for approvals API endpoints (T-1031).

Tests POST /api/approvals/decide validation from web/blueprints/approvals.py.
"""


class TestDecideApproval:
    """Tests for POST /api/approvals/decide error cases."""

    def test_decide_missing_hash_returns_400(self, page, base_url):
        """Missing command_hash returns 400."""
        resp = page.request.post(
            f"{base_url}/api/approvals/decide",
            form={"decision": "approved"},
        )
        assert resp.status == 400
        assert "missing" in resp.text().lower() or "hash" in resp.text().lower()

    def test_decide_invalid_decision_returns_400(self, page, base_url):
        """Invalid decision value returns 400."""
        resp = page.request.post(
            f"{base_url}/api/approvals/decide",
            form={"command_hash": "abc123", "decision": "invalid"},
        )
        assert resp.status == 400
        assert "invalid" in resp.text().lower()

    def test_decide_nonexistent_request_returns_404(self, page, base_url):
        """Decision for non-existent pending request returns 404."""
        resp = page.request.post(
            f"{base_url}/api/approvals/decide",
            form={"command_hash": "nonexistent000", "decision": "approved"},
        )
        assert resp.status == 404

    def test_complete_batch_returns_html(self, page, base_url):
        """Batch complete returns HTML (may have no tasks ready)."""
        resp = page.request.post(f"{base_url}/api/approvals/complete-batch")
        assert resp.status == 200
        body = resp.text()
        assert "<" in body  # Returns HTML
