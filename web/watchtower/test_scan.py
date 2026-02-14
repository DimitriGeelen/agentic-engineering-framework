# web/watchtower/test_scan.py
"""Tests for the Watchtower scan engine."""

import os
import shutil
import textwrap
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
import yaml


@pytest.fixture
def project(tmp_path):
    """Create a synthetic project directory with known state."""
    p = tmp_path / "project"

    # Directory structure
    (p / ".tasks" / "active").mkdir(parents=True)
    (p / ".tasks" / "completed").mkdir(parents=True)
    (p / ".context" / "project").mkdir(parents=True)
    (p / ".context" / "audits").mkdir(parents=True)
    (p / ".context" / "handovers").mkdir(parents=True)
    (p / ".context" / "scans").mkdir(parents=True)
    (p / ".context" / "working").mkdir(parents=True)

    now = datetime.now(timezone.utc)

    # Active task: normal (2 days old)
    _write_task(p, "T-001", "Normal Task", "started-work",
                created=now - timedelta(days=5),
                last_update=now - timedelta(days=2))

    # Active task: stale (20 days since update)
    _write_task(p, "T-002", "Stale Task", "started-work",
                created=now - timedelta(days=30),
                last_update=now - timedelta(days=20))

    # Active task: has issues, no healing
    _write_task(p, "T-003", "Issue Task", "issues",
                created=now - timedelta(days=10),
                last_update=now - timedelta(days=8))

    # Completed tasks (for velocity calculation)
    for i in range(4, 9):
        _write_task(p, f"T-{i:03d}", f"Completed Task {i}", "work-completed",
                    created=now - timedelta(days=20 + i),
                    last_update=now - timedelta(days=10 + i),
                    date_finished=(now - timedelta(days=10 + i)).isoformat())

    # Patterns
    _write_yaml(p / ".context" / "project" / "patterns.yaml", {
        "failure_patterns": [
            {"id": "FP-001", "pattern": "Timeout on cold start",
             "mitigation": "Add retry logic", "learned_from": "T-005",
             "date_learned": "2026-02-10"},
            {"id": "FP-002", "pattern": "Import error",
             "mitigation": "Check deps", "learned_from": "T-006",
             "date_learned": "2026-02-11"},
        ],
        "success_patterns": [
            {"id": "SP-001", "pattern": "Phased implementation",
             "learned_from": "T-004", "date_learned": "2026-02-09"},
        ],
        "antifragile_patterns": [],
        "workflow_patterns": [],
    })

    # Learnings (with graduation candidate)
    _write_yaml(p / ".context" / "project" / "learnings.yaml", {
        "learnings": [
            {"id": "L-001", "learning": "Always validate inputs",
             "task": "T-004", "date": "2026-02-10",
             "source": "P-001"},
            {"id": "L-002", "learning": "Measure what exists",
             "task": "T-005", "date": "2026-02-10",
             "source": "P-001"},
            {"id": "L-003", "learning": "Graduation candidate learning",
             "task": "T-006", "date": "2026-02-11",
             "source": "P-001",
             "applied_in": ["T-004", "T-005", "T-006", "T-007"]},
        ],
    })

    # Practices (with dead-letter)
    _write_yaml(p / ".context" / "project" / "practices.yaml", {
        "practices": [
            {"id": "P-001", "name": "Active Practice",
             "status": "active", "applications": 3,
             "origin_date": "2026-01-20"},
            {"id": "P-002", "name": "Dead Letter Practice",
             "status": "active", "applications": 0,
             "origin_date": "2026-01-20"},
        ],
    })

    # Decisions
    _write_yaml(p / ".context" / "project" / "decisions.yaml", {
        "decisions": [
            {"id": "D-001", "decision": "Use YAML",
             "date": "2026-02-10", "task": "T-004"},
        ],
    })

    # Gaps (one near trigger)
    _write_yaml(p / ".context" / "project" / "gaps.yaml", {
        "gaps": [
            {"id": "G-001", "title": "Enforcement tiers spec-only",
             "status": "watching", "severity": "high",
             "evidence_collected": "None"},
            {"id": "G-002", "title": "Near trigger gap",
             "status": "watching", "severity": "medium",
             "decision_trigger": "Evidence reaches 80%",
             "trigger_check": {"type": "percentage", "current": 85, "threshold": 100}},
        ],
    })

    # Audit
    _write_yaml(p / ".context" / "audits" / "2026-02-14.yaml", {
        "timestamp": "2026-02-14T10:00:00Z",
        "summary": {"pass": 18, "warn": 2, "fail": 0},
        "findings": [
            {"level": "PASS", "check": "Tasks directory exists"},
            {"level": "WARN", "check": "Uncommitted changes present"},
        ],
    })

    # Handover
    (p / ".context" / "handovers" / "LATEST.md").write_text(textwrap.dedent("""\
        ---
        session_id: S-2026-0214-1500
        timestamp: 2026-02-14T15:00:00Z
        tasks_active: [T-001, T-002, T-003]
        tasks_touched: [T-001]
        tasks_completed: []
        ---

        # Session Handover: S-2026-0214-1500

        ## Where We Are

        Working on T-001, T-002 is stale, T-003 has issues.

        ## Things Tried That Failed

        1. **Playwright installer** — fails on Linux Mint

        ## Gotchas / Warnings for Next Session

        - Web server running on :3000
        - Check T-003 issues

        ## Suggested First Action

        Fix T-003 issues.
    """))

    return p


def _write_task(project, task_id, name, status, created, last_update,
                date_finished="null"):
    """Write a task markdown file with frontmatter."""
    slug = name.lower().replace(" ", "-")
    path = project / ".tasks"
    if status == "work-completed":
        path = path / "completed"
    else:
        path = path / "active"
    path = path / f"{task_id}-{slug}.md"
    path.write_text(textwrap.dedent(f"""\
        ---
        id: {task_id}
        name: "{name}"
        status: {status}
        workflow_type: build
        owner: human
        created: {created.isoformat()}
        last_update: {last_update.isoformat()}
        date_finished: {date_finished}
        ---

        # {task_id}: {name}

        ## Updates

        ### {last_update.isoformat()} — update
        - **Action:** Updated
    """))


def _write_yaml(path, data):
    """Write YAML data to a file."""
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)


class TestGatherInputs:
    """Test that gather_inputs reads all project state."""

    def test_loads_active_tasks(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        ids = [t["id"] for t in inputs["active_tasks"]]
        assert "T-001" in ids
        assert "T-002" in ids
        assert "T-003" in ids

    def test_loads_completed_tasks(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        assert len(inputs["completed_tasks"]) >= 4

    def test_loads_patterns(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        assert len(inputs["patterns"].get("failure_patterns", [])) == 2

    def test_loads_learnings(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        assert len(inputs["learnings"].get("learnings", [])) == 3

    def test_loads_practices(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        assert len(inputs["practices"].get("practices", [])) == 2

    def test_loads_decisions(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        assert len(inputs["decisions"].get("decisions", [])) == 1

    def test_loads_gaps(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        assert len(inputs["gaps"].get("gaps", [])) == 2

    def test_loads_audits(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        assert len(inputs["audits"]) >= 1

    def test_loads_handover(self, project):
        from web.watchtower.scanner import gather_inputs
        inputs = gather_inputs(project, project)
        assert inputs["handover"] is not None
        assert "S-2026-0214-1500" in inputs["handover"]

    def test_missing_dirs_returns_empty(self, tmp_path):
        from web.watchtower.scanner import gather_inputs
        empty = tmp_path / "empty"
        empty.mkdir()
        inputs = gather_inputs(empty, empty)
        assert inputs["active_tasks"] == []
        assert inputs["patterns"] == {}


class TestWriteScan:
    """Test that write_scan creates YAML output."""

    def test_writes_yaml_and_symlink(self, project):
        from web.watchtower.scanner import write_scan
        output = {"schema_version": 1, "scan_id": "SC-test", "summary": "test"}
        write_scan(project, "SC-test", output)

        scan_file = project / ".context" / "scans" / "SC-test.yaml"
        assert scan_file.exists()

        latest = project / ".context" / "scans" / "LATEST.yaml"
        assert latest.exists()
        assert latest.is_symlink()

        data = yaml.safe_load(latest.read_text())
        assert data["scan_id"] == "SC-test"
