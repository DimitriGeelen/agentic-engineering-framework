"""Playwright tests for cron job API endpoints (T-1033).

Tests /api/v1/cron/jobs/<id>/pause, resume, run, describe
from web/blueprints/cron.py.
"""
import json

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


class TestCronJobPause:
    """Tests for POST /api/v1/cron/jobs/<id>/pause."""

    def test_pause_nonexistent_job(self, page, base_url):
        """Pausing nonexistent job returns 404."""
        resp = page.request.post(f"{base_url}/api/v1/cron/jobs/nonexistent/pause")
        assert resp.status == 404
        data = resp.json()
        assert "error" in data


class TestCronJobResume:
    """Tests for POST /api/v1/cron/jobs/<id>/resume."""

    def test_resume_nonexistent_job(self, page, base_url):
        """Resuming nonexistent job returns 404."""
        resp = page.request.post(f"{base_url}/api/v1/cron/jobs/nonexistent/resume")
        assert resp.status == 404
        data = resp.json()
        assert "error" in data


class TestCronJobRun:
    """Tests for POST /api/v1/cron/jobs/<id>/run."""

    def test_run_nonexistent_job(self, page, base_url):
        """Running nonexistent job returns 404."""
        resp = page.request.post(f"{base_url}/api/v1/cron/jobs/nonexistent/run")
        assert resp.status == 404
        data = resp.json()
        assert "error" in data


class TestCronJobDescribe:
    """Tests for GET /api/v1/cron/jobs/<id>/describe."""

    def test_describe_nonexistent_job(self, page: Page):
        """Describing nonexistent job returns 404."""
        resp = page.goto(_url("/api/v1/cron/jobs/nonexistent/describe"))
        assert resp.status == 404
        text = page.locator("body").text_content()
        data = json.loads(text)
        assert "error" in data
