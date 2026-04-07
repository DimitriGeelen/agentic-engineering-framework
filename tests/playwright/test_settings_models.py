"""Playwright tests for settings models endpoint (T-1025).

Tests /settings/models endpoint
from web/blueprints/settings.py.
"""


class TestSettingsModels:
    """Tests for /settings/models endpoint."""

    def test_settings_models_returns_response(self, page, base_url):
        """Models endpoint returns 200."""
        resp = page.request.get(f"{base_url}/settings/models")
        assert resp.status == 200
