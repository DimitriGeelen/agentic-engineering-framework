"""T-1470: Watchtower /inception/decide hardens against side-effect failure.

When `fw inception decide` records the primary decision but a downstream
side-effect (episodic gen, emit_review, status update) fails, the endpoint
must return 200 with a warning, NOT 500 — the user has already committed.

This test mocks `run_fw_command` to control exit code while the task body
on disk shows the decision recorded.
"""
from __future__ import annotations

import sys
from pathlib import Path
from unittest import mock

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))


TASK_BODY_DECIDED = """---
id: {task_id}
name: "T-1470 hardening test"
description: "test"
status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-25T00:00:00Z
last_update: 2026-04-25T00:00:00Z
date_finished: 2026-04-25T00:00:00Z
---

# {task_id}: hardening

## Decision

**Decision:** {decision_upper}
**Rationale:** simulated successful primary
**Decided:** 2026-04-25T00:00:00Z

## Updates

### 2026-04-25T00:00:00Z — task-created [test]
"""

TASK_BODY_NOT_DECIDED = """---
id: {task_id}
name: "T-1470 primary-failed test"
description: "test"
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-25T00:00:00Z
last_update: 2026-04-25T00:00:00Z
date_finished: null
---

# {task_id}: not yet decided

## Updates
"""


@pytest.fixture
def consumer_project(tmp_path, monkeypatch):
    (tmp_path / ".tasks/active").mkdir(parents=True)
    (tmp_path / ".tasks/completed").mkdir()
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f'version: "test"\nframework_path: {REPO_ROOT}\n')

    import web.shared
    import web.subprocess_utils
    import web.blueprints.inception
    monkeypatch.setattr(web.shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(web.subprocess_utils, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(web.blueprints.inception, "PROJECT_ROOT", tmp_path)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.delenv("CLAUDECODE", raising=False)
    return tmp_path


def _flask_client():
    from web.app import app
    app.config["TESTING"] = True
    client = app.test_client()
    client.get("/health")
    with client.session_transaction() as sess:
        sess.setdefault("_csrf_token", "test-csrf-token")
        token = sess["_csrf_token"]
    return client, token


def test_decide_returns_200_when_primary_landed_and_side_effect_failed(consumer_project):
    """T-1470: Watchtower must NOT return 500 when the decision body shows
    the decision is already recorded. The user has committed; surface side-
    effect failure as a warning."""
    task_id = "T-9991"
    # Pre-place task in completed/ with Decision block already recorded —
    # simulates "primary landed" state.
    (consumer_project / ".tasks/completed" / f"{task_id}-test.md").write_text(
        TASK_BODY_DECIDED.format(task_id=task_id, decision_upper="GO")
    )
    # Mark reviewed so the route's marker logic is happy
    (consumer_project / ".context/working" / f".reviewed-{task_id}").write_text("test\n")

    client, csrf = _flask_client()

    # Mock run_fw_command to return ok=False (side-effect failed) but the
    # task body on disk already shows the decision (primary landed).
    with mock.patch(
        "web.blueprints.inception.run_fw_command",
        return_value=("primary recorded\n", "episodic gen failed: yaml parse error\n", False),
    ):
        # Non-htmx form path
        resp = client.post(
            f"/inception/{task_id}/decide",
            data={"decision": "go", "rationale": "T-1470 hardening test rationale", "_csrf_token": csrf},
        )

    # Must NOT be 500 — primary landed
    assert resp.status_code == 302, f"expected redirect, got {resp.status_code}: {resp.data[:200]!r}"
    # Must redirect with ?warning=, not ?error=
    location = resp.headers.get("Location", "")
    assert "warning=" in location, f"expected ?warning= in redirect, got {location!r}"
    assert "error=" not in location, f"unexpected ?error= in redirect: {location!r}"


def test_decide_htmx_returns_200_warning_when_primary_landed(consumer_project):
    """T-1470: htmx path returns the success fragment + warning text, not 500."""
    task_id = "T-9992"
    (consumer_project / ".tasks/completed" / f"{task_id}-test.md").write_text(
        TASK_BODY_DECIDED.format(task_id=task_id, decision_upper="GO")
    )
    (consumer_project / ".context/working" / f".reviewed-{task_id}").write_text("test\n")

    client, csrf = _flask_client()

    with mock.patch(
        "web.blueprints.inception.run_fw_command",
        return_value=("ok\n", "warn: side-effect blip\n", False),
    ):
        resp = client.post(
            f"/inception/{task_id}/decide",
            data={"decision": "go", "rationale": "htmx hardening", "_csrf_token": csrf},
            headers={"HX-Request": "true"},
        )

    assert resp.status_code == 200, f"expected 200 (decision recorded), got {resp.status_code}"
    body = resp.data.decode()
    assert "Decision recorded" in body
    assert "GO" in body
    # Warning text is present
    assert "side-effect" in body.lower() or "warning" in body.lower() or "⚠" in body


def test_decide_returns_500_when_primary_did_not_land(consumer_project):
    """T-1470: Existing failure path preserved — when the task body shows
    no Decision block, exit-non-zero must still surface as error."""
    task_id = "T-9993"
    # Task in active/ with NO Decision block — primary did NOT land
    (consumer_project / ".tasks/active" / f"{task_id}-test.md").write_text(
        TASK_BODY_NOT_DECIDED.format(task_id=task_id)
    )
    (consumer_project / ".context/working" / f".reviewed-{task_id}").write_text("test\n")

    client, csrf = _flask_client()

    with mock.patch(
        "web.blueprints.inception.run_fw_command",
        return_value=("", "fatal: review marker missing\n", False),
    ):
        resp = client.post(
            f"/inception/{task_id}/decide",
            data={"decision": "go", "rationale": "primary-failed test", "_csrf_token": csrf},
        )

    # Form path: redirect with ?error= (existing T-1454 behavior preserved)
    assert resp.status_code == 302
    location = resp.headers.get("Location", "")
    assert "error=" in location, f"expected ?error= in redirect, got {location!r}"


def test_decide_htmx_surfaces_error_when_primary_did_not_land(consumer_project):
    """T-1470 → T-2051: primary failure surfaces a swappable 200 error fragment.

    T-1470 distinguished primary-failure from side-effect-failure; T-2051 then
    changed the primary-failure htmx response from 500 to a swappable 200
    ("Decision not recorded" + reason), since htmx ignores non-2xx swaps.
    The invariant this test guards: a failed primary is never rendered as a
    recorded decision, and the reason is visible.
    """
    task_id = "T-9994"
    (consumer_project / ".tasks/active" / f"{task_id}-test.md").write_text(
        TASK_BODY_NOT_DECIDED.format(task_id=task_id)
    )
    (consumer_project / ".context/working" / f".reviewed-{task_id}").write_text("test\n")

    client, csrf = _flask_client()

    with mock.patch(
        "web.blueprints.inception.run_fw_command",
        return_value=("", "fatal\n", False),
    ):
        resp = client.post(
            f"/inception/{task_id}/decide",
            data={"decision": "go", "rationale": "primary-failed htmx", "_csrf_token": csrf},
            headers={"HX-Request": "true"},
        )

    assert resp.status_code == 200
    assert b"Decision not recorded" in resp.data
    assert b"fatal" in resp.data
    # Never rendered as a recorded decision
    assert b"Decision recorded" not in resp.data
