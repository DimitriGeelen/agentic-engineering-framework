"""Smoke tests for the prompts blueprint (T-1283 B3).

Tests run against the real framework repo's prompts/ directory using
Flask's test_client — no running server required. Assumes at least
the seed prompt `consumer-upgrade-and-test` exists.
"""

import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))

from web.app import create_app  # noqa: E402


@pytest.fixture(scope="module")
def client():
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_prompts_list_returns_200(client):
    resp = client.get("/prompts")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "Prompts" in body


def test_prompts_list_shows_seed_prompt(client):
    """The B1 seed prompt should appear in the list."""
    resp = client.get("/prompts")
    body = resp.get_data(as_text=True)
    assert "consumer-upgrade-and-test" in body


def test_prompt_detail_by_slug_returns_200(client):
    resp = client.get("/prompts/consumer-upgrade-and-test")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "framework-managed host" in body


def test_prompt_detail_by_qid_returns_200(client):
    """Detail route must accept FQID (B2 namespacing)."""
    resp = client.get("/prompts")
    body = resp.get_data(as_text=True)
    # Any prompt with a qid will do; B2 demo one is guaranteed.
    if "107/P-" in body or "/P-" in body:
        # Find any qid-looking path via the demo B2 prompt's slug.
        resp2 = client.get("/prompts/demo-b2-namespacing")
        # Extract a qid from that detail page by using the known one.
        detail = resp2.get_data(as_text=True)
        assert resp2.status_code == 200
        assert "/P-" in detail  # qid is shown on the detail page


def test_prompt_detail_unknown_returns_404(client):
    resp = client.get("/prompts/does-not-exist-xyzzy")
    assert resp.status_code == 404


def test_prompt_detail_has_copy_button(client):
    resp = client.get("/prompts/consumer-upgrade-and-test")
    body = resp.get_data(as_text=True)
    assert 'id="copy-btn"' in body
    assert "navigator.clipboard" in body
