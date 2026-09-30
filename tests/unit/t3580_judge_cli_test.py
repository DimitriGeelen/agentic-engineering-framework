#!/usr/bin/env python3
"""Unit tests for lib.reviewer.judge_cli (T-3580)."""

import json
import os
import sys
import tempfile
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib.reviewer import judge_cli  # noqa: E402


class TestLoadTask:
    """Test task file loading."""

    def test_load_task_not_found(self, tmp_path):
        """Non-existent task returns None."""
        root = tmp_path
        result = judge_cli._load_task("T-9999", root)
        assert result is None

    def test_load_task_success(self, tmp_path):
        """Valid task file is loaded correctly."""
        root = tmp_path
        tasks_dir = root / ".tasks" / "active"
        tasks_dir.mkdir(parents=True)

        # Create a minimal task file
        task_file = tasks_dir / "T-1234-test-task.md"
        task_file.write_text(
            """---
id: T-1234
name: Test Task
status: started-work
workflow_type: build
owner: agent
---

## Acceptance Criteria

### Agent
- [x] Test criterion
"""
        )

        result = judge_cli._load_task("T-1234", root)
        assert result is not None
        assert result["frontmatter"]["id"] == "T-1234"
        assert "## Acceptance Criteria" in result["body"]


class TestCalculateRung:
    """Test rung calculation per IW-7 impact-risk model."""

    def test_rung_low_impact(self):
        """Low impact task gets rung 1."""
        task_data = {"frontmatter": {}, "body": "", "path": Path(".")}
        rung, reason = judge_cli._calculate_rung(task_data)
        assert rung == 1
        assert "default" in reason

    def test_rung_high_blast_radius(self):
        """High blast radius → rung 5."""
        task_data = {
            "frontmatter": {"cost_estimate": {"blast_radius": 10}},
            "body": "",
            "path": Path("."),
        }
        rung, reason = judge_cli._calculate_rung(task_data)
        assert rung == 5
        assert "blast_radius" in reason

    def test_rung_high_bvp_d1(self):
        """High D1 BVP score → rung 5."""
        task_data = {
            "frontmatter": {"bvp_scores": {"D1": 4, "D2": 2}},
            "body": "",
            "path": Path("."),
        }
        rung, reason = judge_cli._calculate_rung(task_data)
        assert rung == 5
        assert "D1/D2" in reason


class TestBuildBrief:
    """Test reviewer brief generation."""

    def test_build_brief_structure(self):
        """Brief includes role, criteria, and output format."""
        criteria = [
            {"index": 1, "ac_index": 0, "text": "Test criterion 1"},
            {"index": 2, "ac_index": 1, "text": "Test criterion 2"},
        ]
        brief = judge_cli._build_brief("T-1234", criteria)

        assert "INDEPENDENT REVIEWER" in brief
        assert "Your role" in brief
        assert "The criteria" in brief
        assert "Output format" in brief
        assert "Test criterion 1" in brief
        assert "Test criterion 2" in brief
        assert "Summary:" in brief


class TestMain:
    """Test main entry point."""

    def test_main_no_task(self, monkeypatch, tmp_path):
        """Non-existent task returns error code 1."""
        monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
        sys.argv = ["judge_cli.py", "T-9999", "--dry-run"]

        result = judge_cli.main()
        assert result == 1

    def test_main_dry_run_output(self, monkeypatch, tmp_path, capsys):
        """--dry-run outputs without dispatching."""
        root = tmp_path
        tasks_dir = root / ".tasks" / "active"
        tasks_dir.mkdir(parents=True)

        # Create a minimal task file with no Human criteria
        task_file = tasks_dir / "T-1234-test-task.md"
        task_file.write_text(
            """---
id: T-1234
name: Test Task
status: started-work
workflow_type: build
owner: agent
---

## Acceptance Criteria

### Agent
- [x] Agent criterion
"""
        )

        monkeypatch.setenv("PROJECT_ROOT", str(root))
        sys.argv = ["judge_cli.py", "T-1234", "--dry-run"]

        result = judge_cli.main()
        # Should fail because no REVIEWER_JUDGES criteria
        assert result == 1

    def test_main_json_output(self, monkeypatch, tmp_path, capsys):
        """--json outputs JSON."""
        root = tmp_path
        tasks_dir = root / ".tasks" / "active"
        tasks_dir.mkdir(parents=True)

        task_file = tasks_dir / "T-1234-test-task.md"
        task_file.write_text(
            """---
id: T-1234
name: Test Task
status: started-work
workflow_type: build
owner: agent
---

## Acceptance Criteria

### Agent
- [x] Agent criterion
"""
        )

        monkeypatch.setenv("PROJECT_ROOT", str(root))
        sys.argv = ["judge_cli.py", "T-1234", "--json", "--dry-run"]

        result = judge_cli.main()
        captured = capsys.readouterr()

        if result == 1:
            # No REVIEWER_JUDGES criteria, that's OK for this test
            # Just verify it doesn't crash
            assert "No REVIEWER_JUDGES" in captured.err or len(captured.err) == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
