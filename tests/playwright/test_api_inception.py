"""Playwright tests for inception API endpoints (T-1031).

Tests inception decide, add-assumption, resolve-assumption validation
from web/blueprints/inception.py.
"""


class TestInceptionDecide:
    """Tests for POST /inception/<task_id>/decide."""

    def test_decide_invalid_task_id(self, page, base_url):
        """Malformed task ID returns 403 or 404."""
        resp = page.request.post(
            f"{base_url}/inception/INVALID/decide",
            form={"decision": "go", "rationale": "test"},
        )
        assert resp.status in (403, 404)

    def test_decide_invalid_decision(self, page, base_url):
        """Invalid decision value returns 400 or 403."""
        resp = page.request.post(
            f"{base_url}/inception/T-001/decide",
            form={"decision": "invalid", "rationale": "test"},
        )
        assert resp.status in (400, 403)

    def test_decide_missing_rationale(self, page, base_url):
        """Missing rationale returns 400 or 403."""
        resp = page.request.post(
            f"{base_url}/inception/T-001/decide",
            form={"decision": "go", "rationale": ""},
        )
        assert resp.status in (400, 403)


class TestAddAssumption:
    """Tests for POST /inception/<task_id>/add-assumption."""

    def test_add_assumption_invalid_task_id(self, page, base_url):
        """Malformed task ID returns 403 or 404."""
        resp = page.request.post(
            f"{base_url}/inception/INVALID/add-assumption",
            form={"statement": "test"},
        )
        assert resp.status in (403, 404)

    def test_add_assumption_empty_statement(self, page, base_url):
        """Empty statement returns 400 or 403."""
        resp = page.request.post(
            f"{base_url}/inception/T-001/add-assumption",
            form={"statement": ""},
        )
        assert resp.status in (400, 403)


class TestResolveAssumption:
    """Tests for POST /assumptions/<id>/resolve."""

    def test_resolve_invalid_id(self, page, base_url):
        """Malformed assumption ID returns 403 or 404."""
        resp = page.request.post(
            f"{base_url}/assumptions/INVALID/resolve",
            form={"action": "validate", "evidence": "test"},
        )
        assert resp.status in (403, 404)

    def test_resolve_invalid_action(self, page, base_url):
        """Invalid action returns 400 or 403."""
        resp = page.request.post(
            f"{base_url}/assumptions/A-001/resolve",
            form={"action": "invalid", "evidence": "test"},
        )
        assert resp.status in (400, 403)

    def test_resolve_missing_evidence(self, page, base_url):
        """Missing evidence returns 400 or 403."""
        resp = page.request.post(
            f"{base_url}/assumptions/A-001/resolve",
            form={"action": "validate", "evidence": ""},
        )
        assert resp.status in (400, 403)
