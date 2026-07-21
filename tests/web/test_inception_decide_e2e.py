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


def test_inception_decide_failure_htmx_surfaces_swappable_error(consumer_project, monkeypatch):
    """htmx failure path returns a swappable 200 error fragment (T-2051).

    Pre-T-2051 this was a 500 — but htmx hx-swap ignores non-2xx, so the GO
    button never changed and the human re-clicked (T-2030). The contract now:
    HTTP 200 + "Decision not recorded" fragment carrying the failure reason.
    """
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

    assert resp.status_code == 200
    assert b"Decision not recorded" in resp.data
    assert b"Required AC unchecked: foo" in resp.data


# T-1746 — pin the three RCs from T-1745 RCA.
# Without these tests, RC1 + RC2 + RC3 silently regress and produce another
# silent no-op on the human's primary decision-recording channel.

INCEPTION_TASK_TEMPLATE_BOLD_VERDICT = INCEPTION_TASK_TEMPLATE.replace(
    "**Recommendation:** GO — proven by E2E test.",
    "**Recommendation:** **GO** — proven by E2E test.",
)


def test_t1746_rc1_validator_accepts_bold_emphasized_verdict(consumer_project, monkeypatch):
    """RC1: `**Recommendation:** **GO**` (inner emphasis) must pass the decide gate.

    Origin: T-1744 was authored with `**GO**` (bold). The validator regex in
    `lib/task-audit.sh::audit_inception_recommendation` rejected this and the
    Watchtower form silently no-op'd 4× across 2h. This pins the regression.
    """
    task_id = "T-9990"
    slug = f"{task_id}-bold-verdict"
    task_file = consumer_project / ".tasks/active" / f"{slug}.md"
    task_file.write_text(INCEPTION_TASK_TEMPLATE_BOLD_VERDICT.format(task_id=task_id))
    (consumer_project / "docs/reports" / f"{task_id}-e2e.md").write_text(
        f"# {task_id} research\n"
    )
    (consumer_project / ".context/working" / f".reviewed-{task_id}").write_text("e2e\n")

    client, csrf = _flask_client(monkeypatch)

    resp = client.post(
        f"/inception/{task_id}/decide",
        data={"decision": "go", "rationale": "RC1 regression pin", "_csrf_token": csrf},
    )
    assert resp.status_code in (200, 302), (
        f"unexpected status {resp.status_code}; body={resp.data[:200]!r}"
    )
    body = _read_task_body(consumer_project, task_id)
    assert "## Decision" in body
    assert "GO" in body.upper()
    # Decision must actually persist — not just appear via comment template.
    # Canonical marker emitted by `fw inception decide` is `**Decision:** GO`.
    assert re.search(r"\*\*Decision:\*\*\s*\**GO\**", body, re.IGNORECASE), (
        f"Decision marker not written; bold-verdict gate may have rejected. body[:500]={body[:500]!r}"
    )


def test_t1746_rc2_primary_landed_no_false_positive_on_placeholder():
    """RC2: `_decision_recorded_in_task` must NOT report primary_landed=True
    just because the `## Decision` template comment contains the word 'go'.

    Direct unit test of the function — bypasses Flask. Origin: T-1745 RCA.
    """
    import os, tempfile, shutil
    import web.blueprints.inception as inception_bp

    d = tempfile.mkdtemp(prefix="t1746-rc2-")
    try:
        tdir = os.path.join(d, ".tasks", "active")
        os.makedirs(tdir)
        # Task body with ONLY the placeholder comment in ## Decision (the
        # exact pre-decide template state that triggered the bug)
        with open(os.path.join(tdir, "T-9989-rc2.md"), "w") as f:
            f.write(
                "---\nid: T-9989\n---\n# T-9989\n## Decision\n\n"
                "<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale \"...\" -->\n\n"
                "## Updates\n"
            )
        orig = inception_bp.PROJECT_ROOT
        inception_bp.PROJECT_ROOT = d
        try:
            assert inception_bp._decision_recorded_in_task("T-9989", "go") is False, (
                "RC2 false-positive regression: placeholder comment text triggers "
                "primary_landed=True. Comment-strip + canonical marker check is missing."
            )
            assert inception_bp._decision_recorded_in_task("T-9989", "no-go") is False
            assert inception_bp._decision_recorded_in_task("T-9989", "defer") is False
        finally:
            inception_bp.PROJECT_ROOT = orig
    finally:
        shutil.rmtree(d, ignore_errors=True)


def test_t1746_rc2_no_substring_collision_between_go_and_nogo():
    """RC2 sub-bug: `"GO" in "NO-GO"` was True under the old substring check.
    Now uses regex verdict capture — must distinguish GO from NO-GO cleanly.
    """
    import os, tempfile, shutil
    import web.blueprints.inception as inception_bp

    d = tempfile.mkdtemp(prefix="t1746-rc2b-")
    try:
        tdir = os.path.join(d, ".tasks", "completed")
        os.makedirs(tdir)
        with open(os.path.join(tdir, "T-9988-nogo.md"), "w") as f:
            f.write(
                "---\nid: T-9988\n---\n# T-9988\n## Decision\n\n"
                "**Decision:** NO-GO\n\n## Updates\n"
            )
        orig = inception_bp.PROJECT_ROOT
        inception_bp.PROJECT_ROOT = d
        try:
            # NO-GO recorded — asking 'go' must return False
            assert inception_bp._decision_recorded_in_task("T-9988", "go") is False
            assert inception_bp._decision_recorded_in_task("T-9988", "no-go") is True
        finally:
            inception_bp.PROJECT_ROOT = orig
    finally:
        shutil.rmtree(d, ignore_errors=True)


def test_t1746_rc2_accepts_both_decision_marker_formats():
    """RC2 sub-bug: `fw inception decide` writes TWO marker formats:
    - `**Decision**: GO` (colon outside bold) in the canonical ## Decision body
    - `- **Decision:** GO` (colon inside bold) in the Updates entry
    `_decision_recorded_in_task` must accept both. Without this test,
    catching only one variant means real on-disk decisions (like T-1744)
    are reported as primary_landed=False even when they really did land.
    """
    import os, tempfile, shutil
    import web.blueprints.inception as inception_bp

    for label, body_marker in [
        ("colon-outside-bold", "**Decision**: GO"),  # what lib/inception.sh:556 writes
        ("colon-inside-bold",  "**Decision:** GO"),   # what lib/inception.sh:598 writes
        ("bulleted-inside",    "- **Decision:** GO"),
    ]:
        d = tempfile.mkdtemp(prefix=f"t1746-fmt-{label}-")
        try:
            tdir = os.path.join(d, ".tasks", "completed")
            os.makedirs(tdir)
            with open(os.path.join(tdir, f"T-9987-{label}.md"), "w") as f:
                f.write(
                    f"---\nid: T-9987\n---\n# T-9987\n## Decision\n\n{body_marker}\n\n## Updates\n"
                )
            orig = inception_bp.PROJECT_ROOT
            inception_bp.PROJECT_ROOT = d
            try:
                assert inception_bp._decision_recorded_in_task("T-9987", "go") is True, (
                    f"Decision marker format {label!r} ({body_marker!r}) not accepted"
                )
            finally:
                inception_bp.PROJECT_ROOT = orig
        finally:
            shutil.rmtree(d, ignore_errors=True)


def test_t1746_rc3_warning_banner_renders_for_active_inception(consumer_project, monkeypatch):
    """RC3 wiring: when fw fails AND primary_landed=True (real side-effect
    failure), the handler redirects with ?warning=. The template must render
    the yellow banner when ?warning= is present on an active inception detail
    page. Self-contained — uses a fresh fixture inception in active/ to avoid
    depending on the live state of any real task.
    """
    _make_inception_task(consumer_project, "T-9986")
    from web.app import app
    client = app.test_client()
    resp = client.get("/inception/T-9986?warning=side+effect+warning")
    assert resp.status_code == 200, f"unexpected status {resp.status_code}"
    assert b"Decision recorded with warning" in resp.data, (
        "RC3 regression: ?warning= banner not rendered. "
        "inception_detail.html must show a yellow alert when ?warning= present "
        "for an active inception."
    )
