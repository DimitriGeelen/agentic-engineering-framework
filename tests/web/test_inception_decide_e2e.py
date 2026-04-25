"""T-1281: E2E inception decide via Watchtower → fw CLI → task body update.

Drives the full chain without mocking run_fw_command — POSTs to the
Flask route, lets it shell out to bin/fw, verifies the decision is
written into the task file on disk.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

INCEPTION_TASK_TEMPLATE = """---
id: {task_id}
name: "E2E inception under Watchtower"
description: >
  E2E test inception task created by tests/web/test_inception_decide_e2e.py.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-23T00:00:00Z
last_update: 2026-04-23T00:00:00Z
date_finished: null
---

# {task_id}: E2E inception

## Problem Statement

Verify that Watchtower POST → fw inception decide → file mutation
chain works end-to-end without mocks.

## Assumptions

- A1: Watchtower forwards form data to fw correctly
- A2: fw writes the Decision section back into the task file

## Exploration Plan

1. POST decision via Flask test client
2. Read task file from disk
3. Assert ## Decision section appears with chosen outcome

## Technical Constraints

- Flask test client (no real HTTP server)
- PROJECT_ROOT monkeypatched to tmp dir

## Scope Fence

In: decide route, fw subprocess, task body update.
Out: real network, browser automation.

## Acceptance Criteria

### Agent
- [x] Decision is recorded
- [x] Task body contains the rationale

## Go/No-Go Criteria

**GO if:** chain works without errors.
**NO-GO if:** decision not recorded.

## Verification

# noop

## Recommendation

**Recommendation:** GO — proven by E2E test.

**Rationale:** This is a synthetic test inception. The recommendation
exists only so the inception decide gate (which requires a recommendation
section >20 chars) does not block the test.

**Evidence:**
- Task file exists with this template
- POST via Flask test client triggers fw subprocess

## Decisions

## Updates

### 2026-04-23T00:00:00Z — task-created [test]
- **Action:** Created via E2E test fixture
"""


@pytest.fixture
def consumer_project(tmp_path, monkeypatch):
    """Build a real consumer project layout in tmp_path and redirect PROJECT_ROOT."""
    # Framework structure
    (tmp_path / ".tasks/active").mkdir(parents=True)
    (tmp_path / ".tasks/completed").mkdir()
    (tmp_path / ".tasks/templates").mkdir()
    (tmp_path / ".tasks/templates/zzz-default.md").touch()
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".context/audits").mkdir()
    (tmp_path / ".context/episodic").mkdir()
    (tmp_path / ".context/project").mkdir()
    (tmp_path / "docs/reports").mkdir(parents=True)

    (tmp_path / ".framework.yaml").write_text(
        f'version: "test"\nframework_path: {REPO_ROOT}\n'
    )

    # Initialize git so commit-msg hook etc don't fall over downstream
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.email", "test@test"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.name", "test"], cwd=tmp_path, check=True)

    # Redirect PROJECT_ROOT in every already-imported module that bound it
    # via `from web.shared import PROJECT_ROOT`. Each binding is independent.
    import web.shared
    import web.subprocess_utils
    import web.blueprints.inception
    monkeypatch.setattr(web.shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(web.subprocess_utils, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(web.blueprints.inception, "PROJECT_ROOT", tmp_path)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    # Strip CLAUDECODE so the inception decide gate (T-1259) doesn't fire on CLI
    monkeypatch.delenv("CLAUDECODE", raising=False)

    return tmp_path


def _make_inception_task(project_root: Path, task_id: str = "T-9999") -> Path:
    """Write a real inception task file into the temp consumer project."""
    # find_task_file uses case-sensitive `find -name "T-XXX-*.md"`; keep the T uppercase
    slug = f"{task_id}-e2e-test"
    task_file = project_root / ".tasks/active" / f"{slug}.md"
    task_file.write_text(INCEPTION_TASK_TEMPLATE.format(task_id=task_id))
    # Also create a research artifact (decide gate looks for one)
    (project_root / "docs/reports" / f"{task_id}-e2e.md").write_text(
        f"# {task_id} research\n\nE2E coverage notes.\n"
    )
    # Mark reviewed so the T-973 gate is satisfied (the route also creates this,
    # but pre-creating it isolates the test from that side-effect)
    (project_root / ".context/working" / f".reviewed-{task_id}").write_text("e2e\n")
    return task_file


def _flask_client(monkeypatch):
    """Return a Flask test client + CSRF token (warmed via dummy GET)."""
    from web.app import app
    app.config["TESTING"] = True
    client = app.test_client()
    # Warm session so a CSRF token is generated, then read it from session
    client.get("/health")
    with client.session_transaction() as sess:
        sess.setdefault("_csrf_token", "test-csrf-token")
        token = sess["_csrf_token"]
    return client, token


def _read_task_body(project_root: Path, task_id: str) -> str:
    """Read task body from active/ or completed/ — fw inception decide
    auto-completes the task, moving it to completed/."""
    for loc in ("active", "completed"):
        for f in (project_root / ".tasks" / loc).glob(f"{task_id}-*.md"):
            return f.read_text()
    raise FileNotFoundError(f"task {task_id} not found in active/ or completed/")


@pytest.mark.parametrize("decision", ["go", "no-go", "defer"])
def test_inception_decide_e2e_records_decision(consumer_project, monkeypatch, decision):
    """POST /inception/T-9999/decide writes the chosen decision into the task body."""
    _make_inception_task(consumer_project, "T-9999")
    client, csrf = _flask_client(monkeypatch)

    rationale = f"E2E test rationale for {decision}"
    resp = client.post(
        "/inception/T-9999/decide",
        data={"decision": decision, "rationale": rationale, "_csrf_token": csrf},
    )

    assert resp.status_code in (200, 302), (
        f"unexpected status {resp.status_code}; body={resp.data[:200]!r}"
    )

    body = _read_task_body(consumer_project, "T-9999")
    assert "## Decision" in body, f"## Decision section missing from task body"
    expected = decision.upper()
    assert expected in body.upper(), f"expected {expected} in task body"
    assert rationale in body, f"rationale '{rationale}' not in task body"


def test_inception_decide_auto_completes_task(consumer_project, monkeypatch):
    """After decide, the task moves from active/ → completed/ (P-010 + P-011 satisfied)."""
    _make_inception_task(consumer_project, "T-9998")
    client, csrf = _flask_client(monkeypatch)
    resp = client.post(
        "/inception/T-9998/decide",
        data={"decision": "go", "rationale": "auto-complete check", "_csrf_token": csrf},
    )
    assert resp.status_code in (200, 302)
    active_files = list((consumer_project / ".tasks/active").glob("T-9998-*.md"))
    completed_files = list((consumer_project / ".tasks/completed").glob("T-9998-*.md"))
    assert not active_files, "task should have moved out of active/"
    assert completed_files, "task should now be in completed/"


def test_inception_decide_rejects_invalid_decision(consumer_project, monkeypatch):
    """Decide route returns 400 for unknown decision values."""
    _make_inception_task(consumer_project, "T-9997")
    client, csrf = _flask_client(monkeypatch)

    resp = client.post(
        "/inception/T-9997/decide",
        data={"decision": "maybe", "rationale": "should fail", "_csrf_token": csrf},
    )
    assert resp.status_code == 400


def test_inception_decide_rejects_malformed_task_id(consumer_project, monkeypatch):
    """Decide route returns 404 for non-T- task IDs (regex guard)."""
    client, csrf = _flask_client(monkeypatch)
    resp = client.post(
        "/inception/INVALID/decide",
        data={"decision": "go", "rationale": "bad id", "_csrf_token": csrf},
    )
    assert resp.status_code == 404


def test_inception_decide_failure_redirects_with_error_param(consumer_project, monkeypatch):
    """T-1454 (OBS-017): non-htmx decide failure redirects with ?error= so the
    inception_detail page can render an error banner. Without this, the user
    sees a silent reload and clicks GO repeatedly (3 duplicate Updates entries
    captured in T-1452 session)."""
    _make_inception_task(consumer_project, "T-9996")
    client, csrf = _flask_client(monkeypatch)

    # Mock the underlying fw call to fail
    import web.blueprints.inception as inception_bp
    monkeypatch.setattr(
        inception_bp, "run_fw_command",
        lambda *args, **kwargs: ("", "Required AC unchecked: foo", False),
    )

    resp = client.post(
        "/inception/T-9996/decide",
        data={"decision": "go", "rationale": "test", "_csrf_token": csrf},
    )

    # Must be a redirect (302) with ?error= in Location, not a silent 302 to /inception/T-XXX
    assert resp.status_code == 302
    location = resp.headers.get("Location", "")
    assert "/inception/T-9996" in location, f"redirect target wrong: {location}"
    assert "error=" in location, (
        f"redirect missing error= param — silent failure regression. Location={location}"
    )
    assert "Required+AC+unchecked" in location or "Required%20AC%20unchecked" in location, (
        f"error message not propagated: {location}"
    )


def test_inception_decide_failure_htmx_returns_500(consumer_project, monkeypatch):
    """htmx path is unchanged — returns 500 with error fragment (T-643)."""
    _make_inception_task(consumer_project, "T-9995")
    client, csrf = _flask_client(monkeypatch)

    import web.blueprints.inception as inception_bp
    monkeypatch.setattr(
        inception_bp, "run_fw_command",
        lambda *args, **kwargs: ("", "Required AC unchecked: foo", False),
    )

    resp = client.post(
        "/inception/T-9995/decide",
        data={"decision": "go", "rationale": "test", "_csrf_token": csrf},
        headers={"HX-Request": "true"},
    )

    assert resp.status_code == 500
    assert b"Error:" in resp.data
