#!/usr/bin/env python3
"""T-4156 — READY TO CLOSE tasks (owner:human, zero Human criteria, Agent ACs
ticked) route to the reviewer ladder instead of the operator.

Pins: `fw task delegate` accepts the zero-Human-criteria case (adds one
reviewer-judged close-readiness criterion, owner unchanged, ledger line),
carve-out classes stay with the operator, and `fw review-queue` no longer
prints the R-033 dead-end command.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.delegation import REVIEWER_JUDGES, classify, frontmatter, human_criteria  # noqa: E402

FM = """---
id: T-9100
name: "fixture"
status: started-work
workflow_type: build
owner: human
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# T-9100: fixture

## Acceptance Criteria

### Agent
- [x] {ac}

### Human
<!-- template example, not a criterion
     - [ ] [REVIEW] example
-->

## Verification
true

## Updates
"""


def _run(tmp_path, ac, *args):
    d = tmp_path / ".tasks" / "active"
    d.mkdir(parents=True)
    f = d / "T-9100-fixture.md"
    f.write_text(FM.format(ac=ac))
    env = dict(os.environ, PROJECT_ROOT=str(tmp_path), FRAMEWORK_ROOT=str(ROOT))
    r = subprocess.run([sys.executable, str(ROOT / "lib" / "delegation_cli.py"),
                        "delegate", "T-9100", *args],
                       capture_output=True, text=True, env=env, cwd=str(tmp_path))
    return r, f


def test_ready_to_close_gets_reviewer_judged_criterion(tmp_path):
    r, f = _run(tmp_path, "parser handles empty input")
    assert r.returncode == 0, r.stderr
    text = f.read_text()
    crits = human_criteria(text)
    assert len(crits) == 1 and not crits[0].ticked
    assert classify(crits[0], workflow_type="build").delegation_class == REVIEWER_JUDGES
    assert frontmatter(text)["owner"] == "human"
    assert "bin/fw reviewer judge T-9100" in r.stdout
    ledger = tmp_path / ".context" / "working" / "delegations.jsonl"
    assert json.loads(ledger.read_text().splitlines()[-1])["task"] == "T-9100"


def test_dry_run_writes_nothing(tmp_path):
    r, f = _run(tmp_path, "parser handles empty input", "--dry-run")
    assert r.returncode == 0, r.stderr
    assert human_criteria(f.read_text()) == []
    assert "ready-to-close" in r.stdout.lower()


def test_carve_out_stays_with_operator(tmp_path):
    r, f = _run(tmp_path, "release is published to production")
    assert r.returncode == 0, r.stderr
    assert human_criteria(f.read_text()) == []
    assert "fw task review T-9100" in r.stdout


def test_review_queue_does_not_print_dead_end_command():
    src = (ROOT / "bin" / "fw").read_text()
    assert "task update {m.task_id} --status work-completed" not in src
    assert "task delegate {m.task_id}" in src
