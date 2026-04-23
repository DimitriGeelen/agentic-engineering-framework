"""Playwright tests for /pending (T-1400, T-1268 B3).

Uses an autouse fixture that snapshots+restores the live pending-updates.yaml
so tests don't pollute project state (L-245).
"""
import json
import os
import shutil

import pytest
from playwright.sync_api import Page


TEST_URL = "http://localhost:3099"
PROJECT_ROOT = os.environ.get(
    "PROJECT_ROOT",
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
)
PENDING_FILE = os.path.join(PROJECT_ROOT, ".context/working/pending-updates.yaml")


@pytest.fixture(autouse=True)
def _isolate_pending_file():
    bak = None
    if os.path.exists(PENDING_FILE):
        bak = PENDING_FILE + ".playwright-bak"
        shutil.copy2(PENDING_FILE, bak)
    # Start each test from a clean slate
    os.makedirs(os.path.dirname(PENDING_FILE), exist_ok=True)
    with open(PENDING_FILE, "w") as f:
        f.write("pending_updates: []\n")
    try:
        yield
    finally:
        if bak and os.path.exists(bak):
            shutil.move(bak, PENDING_FILE)
        elif os.path.exists(PENDING_FILE):
            os.remove(PENDING_FILE)


def _url(path: str) -> str:
    return f"{TEST_URL}{path}"


def _write_entries(entries):
    import yaml
    with open(PENDING_FILE, "w") as f:
        yaml.dump({"pending_updates": entries}, f, default_flow_style=False, sort_keys=False)


def test_pending_page_loads_empty(page: Page):
    """Page renders with 'No pending entries' when registry is empty."""
    resp = page.goto(_url("/pending"))
    assert resp.status == 200
    content = page.locator("body").text_content()
    assert "Pending Updates" in content
    assert "No pending entries" in content


def test_pending_page_shows_registered_entry(page: Page):
    """A registered entry appears in the pending table with its id + reason."""
    _write_entries([{
        "id": "U-001",
        "command": "echo test",
        "reason": "playwright fixture entry",
        "task": "T-1400",
        "host": "local",
        "agent": "pytest",
        "created": "2026-04-23T14:00:00Z",
        "status": "pending",
        "resolved_date": None,
        "resolution_note": None,
    }])
    resp = page.goto(_url("/pending"))
    assert resp.status == 200
    content = page.locator("body").text_content()
    assert "U-001" in content
    assert "playwright fixture entry" in content
    assert "T-1400" in content


def test_resolve_api_flips_status(page: Page):
    """POST to /api/v1/pending/<id>/resolve flips status to resolved in the YAML."""
    _write_entries([{
        "id": "U-002",
        "command": "echo resolve",
        "reason": "test resolve path",
        "task": "T-1400",
        "host": "local",
        "agent": "pytest",
        "created": "2026-04-23T14:00:00Z",
        "status": "pending",
        "resolved_date": None,
        "resolution_note": None,
    }])
    resp = page.request.post(
        _url("/api/v1/pending/U-002/resolve"),
        data=json.dumps({"note": "handled by human"}),
        headers={"Content-Type": "application/json"},
    )
    assert resp.status == 200
    body = resp.json()
    assert body.get("status") == "resolved"
    # And the YAML reflects it
    import yaml
    with open(PENDING_FILE) as f:
        data = yaml.safe_load(f)
    entry = next(e for e in data["pending_updates"] if e["id"] == "U-002")
    assert entry["status"] == "resolved"
    assert entry["resolution_note"] == "handled by human"
    assert entry["resolved_date"]


def test_resolve_api_404_on_unknown_id(page: Page):
    """Resolving a nonexistent id returns 404."""
    resp = page.request.post(_url("/api/v1/pending/U-999/resolve"))
    assert resp.status == 404
