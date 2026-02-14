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

    # Completed tasks (for velocity calculation — ~2-day durations so
    # stale threshold = max(7, int(2*6)) = 12 days, allowing T-002 to trigger)
    for i in range(4, 9):
        _write_task(p, f"T-{i:03d}", f"Completed Task {i}", "work-completed",
                    created=now - timedelta(days=4 + i),
                    last_update=now - timedelta(days=2 + i),
                    date_finished=(now - timedelta(days=2 + i)).isoformat())

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


class TestChallengeRules:
    """Test challenge/issue detection rules."""

    def test_stale_task_detected(self, project):
        """T-002 has 20 days since update, should be flagged."""
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.rules import check_stale_tasks
        inputs = gather_inputs(project, project)
        results = check_stale_tasks(inputs)
        ids = [r["summary"] for r in results]
        assert any("T-002" in s for s in ids)

    def test_non_stale_task_not_detected(self, project):
        """T-001 has 2 days since update, should not be flagged."""
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.rules import check_stale_tasks
        inputs = gather_inputs(project, project)
        results = check_stale_tasks(inputs)
        summaries = " ".join(r["summary"] for r in results)
        assert "T-001" not in summaries

    def test_stale_task_has_correct_structure(self, project):
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.rules import check_stale_tasks
        inputs = gather_inputs(project, project)
        results = check_stale_tasks(inputs)
        assert len(results) >= 1
        item = results[0]
        assert "id" in item
        assert "type" in item
        assert item["type"] == "stale_task"
        assert "summary" in item
        assert "recommended_action" in item
        assert "priority" in item
        assert "priority_factors" in item

    def test_unresolved_healing_detected(self, project):
        """T-003 is in issues status, should be flagged."""
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.rules import check_unresolved_healing
        inputs = gather_inputs(project, project)
        results = check_unresolved_healing(inputs)
        assert any("T-003" in r["summary"] for r in results)

    def test_traceability_drift_detected(self, project):
        """Provide git log with untraceable commits."""
        from web.watchtower.rules import check_traceability_drift
        inputs = {
            "git_log": [
                "abc1234 Fix something",
                "def5678 Fix another thing",
                "ghi9012 T-001: proper commit",
            ]
        }
        results = check_traceability_drift(inputs)
        assert len(results) >= 1
        assert results[0]["type"] == "traceability_drift"

    def test_traceability_no_drift(self, project):
        """All commits have task refs — no drift."""
        from web.watchtower.rules import check_traceability_drift
        inputs = {
            "git_log": [
                "abc1234 T-001: Fix something",
                "def5678 T-002: Fix another",
            ]
        }
        results = check_traceability_drift(inputs)
        assert len(results) == 0

    def test_audit_regression_detected(self):
        """Current audit worse than previous."""
        from web.watchtower.rules import check_audit_regression
        inputs = {
            "audits": [
                {"summary": {"pass": 15, "warn": 3, "fail": 2}},
                {"summary": {"pass": 18, "warn": 2, "fail": 0}},
            ]
        }
        results = check_audit_regression(inputs)
        assert len(results) >= 1
        assert results[0]["type"] == "audit_regression"

    def test_audit_no_regression(self):
        """Current audit same or better."""
        from web.watchtower.rules import check_audit_regression
        inputs = {
            "audits": [
                {"summary": {"pass": 20, "warn": 1, "fail": 0}},
                {"summary": {"pass": 18, "warn": 2, "fail": 0}},
            ]
        }
        results = check_audit_regression(inputs)
        assert len(results) == 0

    def test_gap_trigger_detected(self, project):
        """G-002 has trigger_check at 85% — should flag."""
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.rules import check_gap_triggers
        inputs = gather_inputs(project, project)
        results = check_gap_triggers(inputs)
        assert any("G-002" in r["summary"] for r in results)

    def test_novel_failure_detected(self, project):
        """T-003 is in issues but its body doesn't match any known pattern."""
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.rules import check_novel_failures
        inputs = gather_inputs(project, project)
        results = check_novel_failures(inputs)
        # T-003 is in issues — if no pattern matches, it's novel
        assert any("T-003" in r["summary"] for r in results)

    def test_run_all_rules_returns_four_lists(self, project):
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.rules import run_all_rules
        inputs = gather_inputs(project, project)
        result = run_all_rules(inputs)
        assert len(result) == 4
        needs_decision, framework_recommends, opportunities, risks = result
        assert isinstance(needs_decision, list)
        assert isinstance(framework_recommends, list)
        assert isinstance(opportunities, list)
        assert isinstance(risks, list)


class TestPrioritizer:
    """Test work queue prioritization."""

    def test_issues_ranked_first(self, project):
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.prioritizer import prioritize_work_queue
        inputs = gather_inputs(project, project)
        queue = prioritize_work_queue(inputs)
        assert len(queue) >= 2
        # T-003 (issues) should be ranked above T-001 (started-work)
        ids = [item["task_id"] for item in queue]
        assert ids.index("T-003") < ids.index("T-001")

    def test_work_queue_has_required_fields(self, project):
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.prioritizer import prioritize_work_queue
        inputs = gather_inputs(project, project)
        queue = prioritize_work_queue(inputs)
        for item in queue:
            assert "task_id" in item
            assert "name" in item
            assert "status" in item
            assert "priority" in item
            assert "priority_factors" in item

    def test_session_continuity_boost(self, project):
        """Tasks from last handover get priority boost."""
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.prioritizer import prioritize_work_queue
        inputs = gather_inputs(project, project)
        queue = prioritize_work_queue(inputs)
        # T-001 is in tasks_touched from handover
        t001 = next(q for q in queue if q["task_id"] == "T-001")
        factors = [f["rule"] for f in t001["priority_factors"]]
        assert "session_continuity" in factors

    def test_empty_tasks_returns_empty(self, tmp_path):
        from web.watchtower.prioritizer import prioritize_work_queue
        inputs = {"active_tasks": [], "handover": None}
        queue = prioritize_work_queue(inputs)
        assert queue == []


class TestFeedback:
    """Test antifragility and feedback metrics."""

    def test_computes_pattern_counts(self, project):
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.feedback import compute_feedback
        inputs = gather_inputs(project, project)
        result = compute_feedback(inputs)
        assert "patterns_total" in result
        assert result["patterns_total"] >= 2

    def test_computes_practice_adoption(self, project):
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.feedback import compute_feedback
        inputs = gather_inputs(project, project)
        result = compute_feedback(inputs)
        assert "dead_letter_practices" in result

    def test_scan_accuracy_without_previous(self, project):
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.feedback import compute_feedback
        inputs = gather_inputs(project, project)
        result = compute_feedback(inputs)
        assert "scan_accuracy" in result


class TestFullScan:
    """Integration test — full scan produces valid output."""

    def test_scan_produces_complete_output(self, project):
        from web.watchtower.scanner import scan
        result = scan(project_root=project, framework_root=project)
        assert result["schema_version"] == 1
        assert result["scan_id"].startswith("SC-")
        assert result["scan_status"] in ("complete", "partial")
        assert isinstance(result["summary"], str)
        assert len(result["summary"]) > 0
        assert isinstance(result["project_health"], dict)
        assert isinstance(result["antifragility"], dict)
        assert isinstance(result["needs_decision"], list)
        assert isinstance(result["framework_recommends"], list)
        assert isinstance(result["opportunities"], list)
        assert isinstance(result["work_queue"], list)
        assert isinstance(result["risks"], list)

    def test_scan_writes_yaml_file(self, project):
        from web.watchtower.scanner import scan
        result = scan(project_root=project, framework_root=project)
        latest = project / ".context" / "scans" / "LATEST.yaml"
        assert latest.exists()
        import yaml
        data = yaml.safe_load(latest.read_text())
        assert data["scan_id"] == result["scan_id"]

    def test_scan_detects_stale_task(self, project):
        from web.watchtower.scanner import scan
        result = scan(project_root=project, framework_root=project)
        all_summaries = " ".join(
            r.get("summary", "") for r in result["framework_recommends"]
        )
        assert "T-002" in all_summaries

    def test_scan_detects_issues_task(self, project):
        from web.watchtower.scanner import scan
        result = scan(project_root=project, framework_root=project)
        all_summaries = " ".join(
            r.get("summary", "") for r in result["needs_decision"]
        )
        assert "T-003" in all_summaries

    def test_scan_with_empty_project(self, tmp_path):
        """Scan on empty project produces valid output with no crashes."""
        from web.watchtower.scanner import scan
        empty = tmp_path / "empty"
        empty.mkdir()
        (empty / ".context" / "scans").mkdir(parents=True)
        result = scan(project_root=empty, framework_root=empty)
        assert result["scan_status"] == "complete"
        assert result["needs_decision"] == []
        assert result["work_queue"] == []

    def test_scan_summary_mentions_active_count(self, project):
        from web.watchtower.scanner import scan
        result = scan(project_root=project, framework_root=project)
        assert "3 active" in result["summary"]
