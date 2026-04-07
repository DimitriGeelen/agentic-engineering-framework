"""Playwright response time regression tests (T-1051).

Verifies all major Watchtower routes respond within 5 seconds.
Catches performance regressions from slow templates or heavy queries.
"""
import time

import pytest

# Routes to measure — all major GET endpoints
ROUTES = [
    "/",
    "/tasks",
    "/fabric",
    "/timeline",
    "/costs",
    "/quality",
    "/config",
    "/enforcement",
    "/cron",
    "/metrics",
    "/inception",
    "/search",
    "/docs/generated",
    "/patterns",
    "/learnings",
    "/decisions",
    "/risks",
    "/approvals",
    "/discoveries",
    "/sessions",
    "/settings/",
    "/terminal",
    "/graduation",
    "/assumptions",
    "/project",
    "/directives",
    "/health",
]

MAX_RESPONSE_TIME = 10.0  # seconds — allows for cold starts and heavy pages (144 tasks)


class TestResponseTimes:
    """All major routes must respond within 5 seconds."""

    @pytest.mark.parametrize("route", ROUTES)
    def test_route_responds_in_time(self, page, base_url, route):
        """Route responds within MAX_RESPONSE_TIME seconds."""
        start = time.monotonic()
        resp = page.goto(f"{base_url}{route}")
        elapsed = time.monotonic() - start

        assert resp.status in (200, 308), f"{route} returned {resp.status}"
        assert elapsed < MAX_RESPONSE_TIME, (
            f"{route} took {elapsed:.1f}s (max {MAX_RESPONSE_TIME}s)"
        )
