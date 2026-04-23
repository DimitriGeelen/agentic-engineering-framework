"""T-1282: E2E inception decide on a *vendored* consumer project.

T-1281 covered the framework-repo case (PROJECT_ROOT == FRAMEWORK_ROOT).
This file covers the vendored case: a consumer project where
`.agentic-framework/` lives inside the consumer tree (symlinked to the real
framework). It exercises two paths:

1. The vendored shim works end-to-end: `<consumer>/.agentic-framework/bin/fw`
   resolves and runs from inside the consumer.
2. Watchtower's decide route, with PROJECT_ROOT pointed at the consumer,
   writes the decision into the consumer's task file (not the framework's).
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

INCEPTION_TASK_TEMPLATE = """---
id: {task_id}
name: "Vendored E2E inception"
description: >
  E2E test inception task created by tests/web/test_inception_decide_vendored_e2e.py.

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

# {task_id}: Vendored E2E inception

## Problem Statement

Verify Watchtower POST → fw inception decide → consumer task file mutation
works when the framework lives at <consumer>/.agentic-framework/.

## Assumptions

- A1: Watchtower's PROJECT_ROOT can point at a vendored consumer
- A2: fw writes the Decision into the consumer's task file, not the framework's

## Exploration Plan

1. POST decision via Flask test client
2. Read task file from consumer's .tasks/
3. Assert ## Decision section appears

## Technical Constraints

- .agentic-framework/ is a symlink to the real framework repo
- PROJECT_ROOT is monkeypatched to the consumer dir

## Scope Fence

In: vendored layout, decide route, task body update.
Out: real network, browser automation.

## Acceptance Criteria

### Agent
- [x] Vendored shim resolves
- [x] Decision is recorded in consumer's task file

## Go/No-Go Criteria

**GO if:** chain works without errors.
**NO-GO if:** decision not recorded in consumer task file.

## Verification

# noop

## Recommendation

**Recommendation:** GO — proven by E2E test.

**Rationale:** This is a synthetic test inception. The recommendation
exists only so the inception decide gate (which requires a recommendation
section >20 chars) does not block the test.

**Evidence:**
- Vendored consumer fixture exists with .agentic-framework/ symlink
- POST via Flask test client triggers fw subprocess

## Decisions

## Updates

### 2026-04-23T00:00:00Z — task-created [test]
- **Action:** Created via vendored E2E test fixture
"""


@pytest.fixture
def vendored_consumer(tmp_path, monkeypatch):
    """Build a vendored consumer layout in tmp_path.

    Layout:
        tmp_path/
            .agentic-framework -> REPO_ROOT  (symlink — vendored install)
            .tasks/{active,completed,templates}/
            .context/...
            .framework.yaml
            docs/reports/
    """
    # Vendored framework (the distinguishing feature vs T-1281)
    (tmp_path / ".agentic-framework").symlink_to(REPO_ROOT)

    # Consumer skeleton
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

    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.email", "test@test"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.name", "test"], cwd=tmp_path, check=True)

    # Same monkeypatch fan-out as T-1281 — every importer gets independent binding
    import web.shared
    import web.subprocess_utils
    import web.blueprints.inception
    monkeypatch.setattr(web.shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(web.subprocess_utils, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(web.blueprints.inception, "PROJECT_ROOT", tmp_path)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.delenv("CLAUDECODE", raising=False)

    return tmp_path


def _make_inception_task(project_root: Path, task_id: str) -> Path:
    slug = f"{task_id}-vendored-e2e"
    task_file = project_root / ".tasks/active" / f"{slug}.md"
    task_file.write_text(INCEPTION_TASK_TEMPLATE.format(task_id=task_id))
    (project_root / "docs/reports" / f"{task_id}-vendored.md").write_text(
        f"# {task_id} research\n\nVendored E2E coverage notes.\n"
    )
    (project_root / ".context/working" / f".reviewed-{task_id}").write_text("vendored-e2e\n")
    return task_file


def _flask_client():
    from web.app import app
    app.config["TESTING"] = True
    client = app.test_client()
    client.get("/health")
    with client.session_transaction() as sess:
        sess.setdefault("_csrf_token", "test-csrf-token")
        token = sess["_csrf_token"]
    return client, token


def _read_task_body(project_root: Path, task_id: str) -> str:
    for loc in ("active", "completed"):
        for f in (project_root / ".tasks" / loc).glob(f"{task_id}-*.md"):
            return f.read_text()
    raise FileNotFoundError(f"task {task_id} not found in active/ or completed/")


def test_vendored_shim_resolves(vendored_consumer):
    """`<consumer>/.agentic-framework/bin/fw version` succeeds — the vendored
    shim is reachable through the symlink."""
    fw = vendored_consumer / ".agentic-framework" / "bin" / "fw"
    assert fw.exists(), f"vendored shim missing: {fw}"
    result = subprocess.run(
        [str(fw), "version"],
        capture_output=True,
        text=True,
        timeout=10,
        cwd=vendored_consumer,
    )
    assert result.returncode == 0, f"fw version failed: {result.stderr[:200]}"


@pytest.mark.parametrize("decision", ["go", "no-go", "defer"])
def test_decide_writes_into_consumer_task(vendored_consumer, decision):
    """POST /inception/T-XXXX/decide on a vendored consumer writes the
    decision into the *consumer's* task file, not the framework's."""
    task_id = "T-9295"  # collision-free
    _make_inception_task(vendored_consumer, task_id)
    client, csrf = _flask_client()

    rationale = f"vendored E2E rationale for {decision}"
    resp = client.post(
        f"/inception/{task_id}/decide",
        data={"decision": decision, "rationale": rationale, "_csrf_token": csrf},
    )
    assert resp.status_code in (200, 302), (
        f"unexpected status {resp.status_code}; body={resp.data[:200]!r}"
    )

    body = _read_task_body(vendored_consumer, task_id)
    assert "## Decision" in body
    assert decision.upper() in body.upper()
    assert rationale in body

    # Critical: the framework's own .tasks/ must NOT have been mutated.
    framework_active = list((REPO_ROOT / ".tasks/active").glob(f"{task_id}-*.md"))
    framework_completed = list((REPO_ROOT / ".tasks/completed").glob(f"{task_id}-*.md"))
    assert not framework_active and not framework_completed, (
        f"vendored decide leaked into framework .tasks/: "
        f"active={framework_active} completed={framework_completed}"
    )


def test_decide_auto_completes_in_consumer(vendored_consumer):
    """After decide, the consumer's task moves active/ → completed/."""
    task_id = "T-9294"
    _make_inception_task(vendored_consumer, task_id)
    client, csrf = _flask_client()
    resp = client.post(
        f"/inception/{task_id}/decide",
        data={"decision": "go", "rationale": "vendored auto-complete", "_csrf_token": csrf},
    )
    assert resp.status_code in (200, 302)
    active = list((vendored_consumer / ".tasks/active").glob(f"{task_id}-*.md"))
    completed = list((vendored_consumer / ".tasks/completed").glob(f"{task_id}-*.md"))
    assert not active, "task should have moved out of consumer's active/"
    assert completed, "task should now be in consumer's completed/"
