# Phase 4: Watchtower Intelligence Layer — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Watchtower from a read-only dashboard into a shared intelligence layer that detects project opportunities/issues, computes prioritized recommendations, and gives both humans (cockpit UI) and AI agents (structured YAML) a synthesized picture plus controls to act.

**Architecture:** A stateless scan engine (`web/watchtower/`) reads all project state (Tier 3), runs detection rules, and outputs structured YAML to `.context/scans/LATEST.yaml`. The cockpit UI replaces the current dashboard with scan-driven sections and inline controls. All mutations go through existing `fw` CLI commands (Tier 1). One scan, two interfaces.

**Tech Stack:** Python 3 (Flask, PyYAML), Jinja2 + htmx (cockpit UI), Pico CSS, Bash (CLI integration)

**Design Doc:** `docs/plans/2026-02-14-phase4-watchtower-intelligence-design.md` (718 lines, v2)

---

## Task 1: Scan Engine Foundation

**Files:**
- Create: `web/watchtower/__init__.py`
- Create: `web/watchtower/scanner.py`
- Create: `web/watchtower/test_scan.py`
- Create: `.context/scans/.gitkeep`

**Context:** The scan engine is Framework AUTHORITY — not an agent, not a regular CLI command. It lives in `web/watchtower/` alongside the existing Flask app. It reads all project state (tasks, patterns, learnings, practices, decisions, gaps, audits, handovers, git log) and produces structured YAML output.

**Reference files to understand existing patterns:**
- `web/blueprints/core.py:16-25` — `_load_yaml()` pattern for safe YAML loading
- `web/blueprints/core.py:28-62` — how tasks/gaps are read from filesystem
- `web/blueprints/session.py:20-48` — `_git()` and `_fw()` subprocess helpers
- `web/shared.py:15-17` — path resolution (`APP_DIR`, `FRAMEWORK_ROOT`, `PROJECT_ROOT`)

**Step 1: Write the test fixtures**

Create a conftest-style fixture factory at the top of the test file. This synthetic project directory is used by ALL scan engine tests.

```python
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
```

**Step 2: Write the initial scanner test**

```python
# Append to web/watchtower/test_scan.py

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
```

**Step 3: Run tests to verify they fail**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'web.watchtower'`

**Step 4: Create the scanner module**

```python
# web/watchtower/__init__.py
"""Watchtower Intelligence Layer — Framework AUTHORITY scan engine."""
```

```python
# web/watchtower/scanner.py
"""Watchtower scan engine — reads project state, produces structured scan output.

The scan engine is Framework AUTHORITY intelligence. It reads all project
state (Tier 3: pre-approved diagnostic) and writes structured YAML to
.context/scans/. It NEVER directly mutates tasks, patterns, or context.

Usage:
    from web.watchtower.scanner import scan
    result = scan(project_root="/path/to/project")
"""

import os
import re
import subprocess
import yaml
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def scan(project_root: str | Path | None = None,
         framework_root: str | Path | None = None) -> dict:
    """Run a full project scan. Returns structured scan result dict.

    This is the main entry point. Called by:
    - fw scan (CLI)
    - fw context init (auto-scan at session start)
    - POST /api/scan (cockpit refresh)
    """
    project_root = Path(project_root or os.environ.get("PROJECT_ROOT", "."))
    framework_root = Path(
        framework_root or os.environ.get("FRAMEWORK_ROOT", str(project_root))
    )

    errors = []
    inputs = gather_inputs(project_root, framework_root, errors)

    # Import rules and run them (deferred import to avoid circular deps)
    from .rules import run_all_rules
    from .prioritizer import prioritize_work_queue
    from .feedback import compute_feedback

    needs_decision, framework_recommends, opportunities, risks = run_all_rules(inputs)
    work_queue = prioritize_work_queue(inputs)
    antifragility = compute_feedback(inputs)

    scan_id = f"SC-{datetime.now(timezone.utc).strftime('%Y-%m%d-%H%M%S')}"
    scan_status = "complete" if not errors else "partial"

    output = {
        "schema_version": 1,
        "scan_id": scan_id,
        "scan_status": scan_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "errors": errors,
        "summary": generate_summary(
            inputs, needs_decision, framework_recommends, risks, work_queue
        ),
        "project_health": compute_health(inputs),
        "antifragility": antifragility,
        "needs_decision": needs_decision,
        "framework_recommends": framework_recommends,
        "opportunities": opportunities,
        "work_queue": work_queue,
        "risks": risks,
        "changes_since_last_scan": compute_delta(inputs, needs_decision,
                                                  framework_recommends),
        "recent_failures": extract_failures(inputs),
        "warnings": extract_warnings(inputs),
    }

    write_scan(project_root, scan_id, output)
    return output


# ---------------------------------------------------------------------------
# Input gathering (Tier 3 — read-only)
# ---------------------------------------------------------------------------

def gather_inputs(project_root: Path, framework_root: Path,
                  errors: list | None = None) -> dict:
    """Read all project state. Returns a dict of inputs for rules."""
    if errors is None:
        errors = []

    inputs: dict[str, Any] = {
        "project_root": project_root,
        "framework_root": framework_root,
        "active_tasks": [],
        "completed_tasks": [],
        "patterns": {},
        "learnings": {},
        "practices": {},
        "decisions": {},
        "gaps": {},
        "audits": [],
        "handover": None,
        "previous_scan": None,
        "git_log": [],
    }

    # Active tasks
    active_dir = project_root / ".tasks" / "active"
    if active_dir.exists():
        for f in sorted(active_dir.glob("T-*.md")):
            task = parse_task(f)
            if task:
                inputs["active_tasks"].append(task)

    # Completed tasks (last 100 for performance)
    completed_dir = project_root / ".tasks" / "completed"
    if completed_dir.exists():
        files = sorted(
            completed_dir.glob("T-*.md"),
            key=lambda f: f.stat().st_mtime,
            reverse=True,
        )
        for f in files[:100]:
            task = parse_task(f)
            if task:
                inputs["completed_tasks"].append(task)

    # YAML context files
    context_dir = project_root / ".context" / "project"
    for key in ("patterns", "learnings", "practices", "decisions", "gaps"):
        path = context_dir / f"{key}.yaml"
        try:
            inputs[key] = load_yaml(path)
        except Exception as exc:
            errors.append({"source": key, "error": str(exc)})

    # Audits (last 5)
    audits_dir = project_root / ".context" / "audits"
    if audits_dir.exists():
        for f in sorted(audits_dir.glob("*.yaml"), reverse=True)[:5]:
            audit = load_yaml(f)
            if audit:
                inputs["audits"].append(audit)

    # Handover
    handover_path = project_root / ".context" / "handovers" / "LATEST.md"
    if handover_path.exists():
        try:
            inputs["handover"] = handover_path.read_text(errors="replace")
        except Exception as exc:
            errors.append({"source": "handover", "error": str(exc)})

    # Previous scan
    scans_dir = project_root / ".context" / "scans"
    if scans_dir.exists():
        latest = scans_dir / "LATEST.yaml"
        if latest.exists():
            inputs["previous_scan"] = load_yaml(latest)

    # Git log (last 20 commits)
    try:
        result = subprocess.run(
            ["git", "-C", str(project_root), "log", "--oneline", "-20"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            inputs["git_log"] = result.stdout.strip().split("\n")
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return inputs


# ---------------------------------------------------------------------------
# Output writing
# ---------------------------------------------------------------------------

def write_scan(project_root: Path, scan_id: str, output: dict):
    """Write scan output to .context/scans/ and update LATEST.yaml symlink."""
    scans_dir = project_root / ".context" / "scans"
    scans_dir.mkdir(parents=True, exist_ok=True)

    filename = f"{scan_id}.yaml"
    filepath = scans_dir / filename

    with open(filepath, "w") as f:
        yaml.dump(output, f, default_flow_style=False, sort_keys=False,
                  allow_unicode=True)

    # Update LATEST.yaml symlink
    latest = scans_dir / "LATEST.yaml"
    if latest.exists() or latest.is_symlink():
        latest.unlink()
    latest.symlink_to(filename)


# ---------------------------------------------------------------------------
# Summary & health computation
# ---------------------------------------------------------------------------

def generate_summary(inputs, needs_decision, framework_recommends, risks,
                     work_queue) -> str:
    """Generate natural-language summary for LLM consumption."""
    lines = []
    n_active = len(inputs["active_tasks"])
    n_completed = len(inputs["completed_tasks"])

    audit_status = _get_audit_status(inputs)
    traceability = _get_traceability(inputs)

    lines.append(
        f"Project has {n_active} active task(s) and {n_completed} completed."
        f" Audit: {audit_status}. Traceability: {traceability}%."
    )

    if work_queue:
        top = work_queue[0]
        lines.append(
            f"Top priority: {top['task_id']} ({top['name']})."
        )

    if needs_decision:
        lines.append(f"{len(needs_decision)} item(s) need your decision.")

    if framework_recommends:
        lines.append(
            f"Framework has {len(framework_recommends)} recommendation(s)."
        )

    if risks:
        lines.append(f"{len(risks)} risk(s) detected.")

    if not needs_decision and not framework_recommends and not risks:
        lines.append("All clear — no items requiring attention.")

    return "\n".join(lines)


def compute_health(inputs) -> dict:
    """Compute project health metrics."""
    n_active = len(inputs["active_tasks"])
    n_completed = len(inputs["completed_tasks"])
    traceability = _get_traceability(inputs)
    audit_status = _get_audit_status(inputs)

    # Knowledge counts
    n_learnings = len(inputs["learnings"].get("learnings", []))
    n_practices = len(inputs["practices"].get("practices", []))
    n_decisions = len(inputs["decisions"].get("decisions", []))
    n_patterns = sum(
        len(inputs["patterns"].get(k, []))
        for k in ("failure_patterns", "success_patterns",
                   "antifragile_patterns", "workflow_patterns")
    )

    # Gaps watching
    n_gaps = len([
        g for g in inputs["gaps"].get("gaps", [])
        if g.get("status") == "watching"
    ])

    # Velocity (avg days per task from completed tasks)
    velocity = _compute_velocity(inputs)

    return {
        "tasks_active": n_active,
        "tasks_completed": n_completed,
        "traceability": f"{traceability}%",
        "knowledge": {
            "learnings": n_learnings,
            "practices": n_practices,
            "patterns": n_patterns,
            "decisions": n_decisions,
        },
        "gaps_watching": n_gaps,
        "audit_status": audit_status,
        "velocity": velocity,
    }


def compute_delta(inputs, needs_decision, framework_recommends) -> dict:
    """Compute changes since last scan."""
    prev = inputs.get("previous_scan")
    if not prev:
        return {"first_scan": True}

    prev_ids = set()
    for item in prev.get("needs_decision", []):
        prev_ids.add(item.get("id", ""))
    for item in prev.get("framework_recommends", []):
        prev_ids.add(item.get("id", ""))

    current_ids = set()
    for item in needs_decision:
        current_ids.add(item.get("id", ""))
    for item in framework_recommends:
        current_ids.add(item.get("id", ""))

    return {
        "new_recommendations": sorted(current_ids - prev_ids),
        "resolved_recommendations": sorted(prev_ids - current_ids),
    }


def extract_failures(inputs) -> list:
    """Extract recent failures from handover."""
    failures = []
    handover = inputs.get("handover", "") or ""

    if "Things Tried That Failed" in handover:
        match = re.search(
            r"## Things Tried That Failed\n\n(.*?)(?=\n## |\Z)",
            handover, re.DOTALL,
        )
        if match:
            for line in match.group(1).strip().split("\n"):
                line = line.strip()
                if line and line[0].isdigit():
                    desc = re.sub(r"^\d+\.\s*", "", line)
                    if desc:
                        failures.append({
                            "source": "handover",
                            "description": desc,
                        })
    return failures


def extract_warnings(inputs) -> list:
    """Extract warnings from handover."""
    warnings = []
    handover = inputs.get("handover", "") or ""

    if "Gotchas / Warnings" in handover:
        match = re.search(
            r"## Gotchas / Warnings.*?\n\n(.*?)(?=\n## |\Z)",
            handover, re.DOTALL,
        )
        if match:
            for line in match.group(1).strip().split("\n"):
                line = line.strip()
                if line.startswith("- "):
                    warnings.append(line[2:])
    return warnings


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def parse_task(path: Path) -> dict | None:
    """Parse task markdown with YAML frontmatter."""
    try:
        content = path.read_text(errors="replace")
        match = re.match(r"^---\n(.*?)\n---\n(.*)", content, re.DOTALL)
        if match:
            fm = yaml.safe_load(match.group(1))
            if isinstance(fm, dict):
                fm["_body"] = match.group(2)
                fm["_path"] = str(path)
                return fm
    except Exception:
        pass
    return None


def load_yaml(path: Path) -> dict:
    """Safely load YAML, return {} on failure."""
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        return data if isinstance(data, (dict, list)) else {}
    except Exception:
        return {}


def _get_audit_status(inputs) -> str:
    """Extract audit status string from inputs."""
    if not inputs["audits"]:
        return "UNKNOWN"
    s = inputs["audits"][0].get("summary", {})
    if s.get("fail", 0) > 0:
        return "FAIL"
    elif s.get("warn", 0) > 0:
        return "WARN"
    return "PASS"


def _get_traceability(inputs) -> int:
    """Compute git traceability percentage from git log."""
    git_log = inputs.get("git_log", [])
    if not git_log:
        return 100
    task_pattern = re.compile(r"T-\d{3}")
    traced = sum(1 for line in git_log if task_pattern.search(line))
    total = len(git_log)
    return round(traced / total * 100) if total > 0 else 100


def _compute_velocity(inputs) -> dict:
    """Compute task velocity from completed tasks."""
    completed = inputs["completed_tasks"]
    durations = []
    for task in completed:
        created = task.get("created")
        finished = task.get("date_finished")
        if not created or not finished or finished == "null":
            continue
        try:
            if isinstance(created, str):
                created = datetime.fromisoformat(
                    created.replace("Z", "+00:00")
                )
            if isinstance(finished, str):
                finished = datetime.fromisoformat(
                    finished.replace("Z", "+00:00")
                )
            days = (finished - created).days
            if days >= 0:
                durations.append(days)
        except (ValueError, TypeError):
            continue

    if not durations:
        return {"avg_days_per_task": None, "sample_size": 0}

    avg = round(sum(durations) / len(durations), 1)
    return {"avg_days_per_task": avg, "sample_size": len(durations)}
```

**Step 5: Run tests to verify they pass**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py -v`
Expected: All `TestGatherInputs` and `TestWriteScan` tests PASS

**Step 6: Commit**

```bash
git add web/watchtower/__init__.py web/watchtower/scanner.py web/watchtower/test_scan.py
git commit -m "T-058: Add scan engine foundation (gather_inputs + write_scan)"
```

---

## Task 2: Challenge Detection Rules

**Files:**
- Create: `web/watchtower/rules.py`
- Modify: `web/watchtower/test_scan.py` — add rule tests

**Context:** Challenge rules detect problems: stale tasks, unresolved issues, traceability drift, audit regression, gap triggers, and novel failures. Each rule returns items for the appropriate output section (`needs_decision`, `framework_recommends`, or `risks`).

**Reference:** Design doc §5.1 for rule definitions and trigger conditions.

**Step 1: Write failing tests for challenge rules**

```python
# Append to web/watchtower/test_scan.py

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
```

**Step 2: Run tests to verify they fail**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py::TestChallengeRules -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'web.watchtower.rules'`

**Step 3: Implement challenge rules**

```python
# web/watchtower/rules.py
"""Watchtower detection rules — challenge, opportunity, and strength rules.

Each rule function takes an `inputs` dict (from scanner.gather_inputs) and
returns a list of recommendation dicts for the appropriate output section.

Rule output format:
    {
        "id": "REC-001",        # Unique per scan
        "type": "stale_task",   # Rule type
        "summary": "...",       # Human-readable
        "recommended_action": {"command": "fw ...", "args": "..."},
        "priority": "high|medium|low",
        "priority_factors": [{"rule": "...", "detail": "..."}],
    }
"""

import re
from datetime import datetime, timezone


# ---------------------------------------------------------------------------
# ID counters (reset per scan)
# ---------------------------------------------------------------------------

_counters: dict[str, int] = {}


def _next_id(prefix: str) -> str:
    """Generate next sequential ID for a prefix (REC, FRA, OPP, RSK)."""
    _counters[prefix] = _counters.get(prefix, 0) + 1
    return f"{prefix}-{_counters[prefix]:03d}"


def _reset_counters():
    """Reset ID counters — call at start of each scan."""
    _counters.clear()


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def run_all_rules(inputs: dict) -> tuple[list, list, list, list]:
    """Run all detection rules. Returns (needs_decision, framework_recommends,
    opportunities, risks)."""
    _reset_counters()

    needs_decision = []
    framework_recommends = []
    opportunities = []
    risks = []

    # Challenge rules (§5.1)
    framework_recommends += check_stale_tasks(inputs)
    needs_decision += check_unresolved_healing(inputs)
    risks += check_traceability_drift(inputs)
    risks += check_audit_regression(inputs)
    needs_decision += check_gap_triggers(inputs)
    needs_decision += check_novel_failures(inputs)

    # Opportunity rules (§5.2)
    needs_decision += check_graduation_candidates(inputs)
    needs_decision += check_dead_letter_practices(inputs)
    opportunities += check_pattern_consolidation(inputs)
    opportunities += check_escalation_advancement(inputs)

    # Strength rules (§5.3)
    needs_decision += check_mitigation_ineffectiveness(inputs)

    return needs_decision, framework_recommends, opportunities, risks


# ---------------------------------------------------------------------------
# Challenge rules (§5.1)
# ---------------------------------------------------------------------------

def check_stale_tasks(inputs: dict) -> list:
    """Tasks in started-work with no update > threshold.

    Staleness threshold = 6x avg task velocity, min 7 days, default 14.
    Output section: framework_recommends
    """
    threshold = compute_stale_threshold(inputs)
    results = []
    now = datetime.now(timezone.utc)

    for task in inputs.get("active_tasks", []):
        if task.get("status") != "started-work":
            continue
        last_update = _parse_datetime(task.get("last_update"))
        if not last_update:
            continue
        days = (now - last_update).days
        if days >= threshold:
            results.append({
                "id": _next_id("FRA"),
                "type": "stale_task",
                "summary": f"{task['id']} has had no update for {days} days",
                "recommended_action": {
                    "command": "fw task update",
                    "args": f"{task['id']} --add-note 'Flagged as stale by scan'",
                },
                "priority": "medium",
                "priority_factors": [{
                    "rule": "stale_detection",
                    "detail": (f"{days} days since last update "
                               f"(threshold: {threshold} days)"),
                }],
            })
    return results


def compute_stale_threshold(inputs: dict) -> int:
    """6x average task velocity, min 7, default 14."""
    completed = inputs.get("completed_tasks", [])
    if len(completed) < 3:
        return 14

    durations = []
    for task in completed:
        created = _parse_datetime(task.get("created"))
        finished = _parse_datetime(task.get("date_finished"))
        if created and finished:
            days = (finished - created).days
            if days >= 0:
                durations.append(days)

    if not durations:
        return 14

    avg = sum(durations) / len(durations)
    return max(7, int(avg * 6))


def check_unresolved_healing(inputs: dict) -> list:
    """Tasks in issues status with no resolution > 7 days.

    Output section: needs_decision
    """
    results = []
    now = datetime.now(timezone.utc)

    for task in inputs.get("active_tasks", []):
        if task.get("status") != "issues":
            continue
        last_update = _parse_datetime(task.get("last_update"))
        if not last_update:
            continue
        days = (now - last_update).days
        if days >= 7:
            results.append({
                "id": _next_id("REC"),
                "type": "unresolved_healing",
                "summary": (f"{task['id']} has been in issues status "
                            f"for {days} days with no resolution"),
                "evidence": {"task": task["id"], "days_in_issues": days},
                "suggested_action": {
                    "command": "fw healing diagnose",
                    "args": task["id"],
                },
                "priority": "high",
                "priority_factors": [{
                    "rule": "unresolved_healing",
                    "detail": f"{days} days in issues (threshold: 7 days)",
                }],
            })
    return results


def check_traceability_drift(inputs: dict) -> list:
    """Last N commits lack task references.

    Output section: risks
    """
    git_log = inputs.get("git_log", [])
    if not git_log:
        return []

    task_pattern = re.compile(r"T-\d{3}")

    # Check last 5 commits for drift
    recent = git_log[:5]
    untraced = [line for line in recent if not task_pattern.search(line)]

    if len(untraced) >= 3:
        return [{
            "id": _next_id("RSK"),
            "type": "traceability_drift",
            "summary": (f"Last {len(recent)} commits: {len(untraced)} "
                        f"lack task references"),
            "severity": "medium" if len(untraced) < 4 else "high",
            "suggested_action": (
                "Run fw audit to verify; ensure git hooks are installed"
            ),
        }]
    return []


def check_audit_regression(inputs: dict) -> list:
    """Current audit score worse than previous.

    Output section: risks
    """
    audits = inputs.get("audits", [])
    if len(audits) < 2:
        return []

    current = audits[0].get("summary", {})
    previous = audits[1].get("summary", {})

    curr_fail = current.get("fail", 0)
    prev_fail = previous.get("fail", 0)
    curr_warn = current.get("warn", 0)
    prev_warn = previous.get("warn", 0)

    if curr_fail > prev_fail or (curr_fail == prev_fail and
                                  curr_warn > prev_warn):
        return [{
            "id": _next_id("RSK"),
            "type": "audit_regression",
            "summary": (f"Audit regression: {curr_fail}F/{curr_warn}W "
                        f"(was {prev_fail}F/{prev_warn}W)"),
            "severity": "high" if curr_fail > prev_fail else "medium",
            "suggested_action": "Run fw audit to see details",
        }]
    return []


def check_gap_triggers(inputs: dict) -> list:
    """Gap evidence approaching decision trigger threshold (>80%).

    Output section: needs_decision
    """
    results = []
    gaps = inputs.get("gaps", {})
    if isinstance(gaps, dict):
        gaps = gaps.get("gaps", [])

    for gap in gaps:
        if gap.get("status") != "watching":
            continue

        trigger_check = gap.get("trigger_check", {})
        if not isinstance(trigger_check, dict):
            continue

        # Check percentage-based triggers
        if trigger_check.get("type") == "percentage":
            current = trigger_check.get("current", 0)
            threshold = trigger_check.get("threshold", 100)
            if threshold > 0 and current >= threshold * 0.8:
                pct = round(current / threshold * 100)
                results.append({
                    "id": _next_id("REC"),
                    "type": "gap_escalation",
                    "summary": (f"{gap['id']} at {pct}% trigger threshold"
                                f" — {gap.get('title', '')}"),
                    "evidence": {
                        "current": current,
                        "threshold": threshold,
                    },
                    "suggested_action": {
                        "command": "fw task create",
                        "args": (f"--name 'Address gap {gap['id']}' "
                                 f"--type build --owner human"),
                    },
                    "priority": "high" if pct >= 90 else "medium",
                    "priority_factors": [{
                        "rule": "gap_trigger_approaching",
                        "detail": f"{pct}% of threshold (>80% triggers rec)",
                    }],
                })
    return results


def check_novel_failures(inputs: dict) -> list:
    """Tasks in issues with no matching pattern in patterns.yaml.

    Output section: needs_decision
    """
    results = []
    patterns = inputs.get("patterns", {})
    known_mitigations = set()

    for key in ("failure_patterns", "success_patterns",
                "antifragile_patterns", "workflow_patterns"):
        for p in patterns.get(key, []):
            pattern_text = p.get("pattern", "").lower()
            mitigation = p.get("mitigation", "").lower()
            if pattern_text:
                known_mitigations.add(pattern_text)
            if mitigation:
                known_mitigations.add(mitigation)

    for task in inputs.get("active_tasks", []):
        if task.get("status") != "issues":
            continue

        # Check if task body or name matches any known pattern
        task_text = (
            task.get("name", "") + " " + task.get("_body", "")
        ).lower()

        matched = any(
            pattern in task_text
            for pattern in known_mitigations
            if len(pattern) > 3
        )

        if not matched:
            results.append({
                "id": _next_id("REC"),
                "type": "novel_failure",
                "summary": (f"{task['id']} entered issues with failure "
                            f"not matching any known pattern"),
                "evidence": {
                    "task": task["id"],
                    "name": task.get("name", ""),
                },
                "suggested_action": "Diagnose and capture as new pattern",
                "priority": "high",
                "priority_factors": [{
                    "rule": "novel_failure_detection",
                    "detail": "No pattern in patterns.yaml matches",
                }],
            })
    return results


# ---------------------------------------------------------------------------
# Opportunity rules (§5.2)
# ---------------------------------------------------------------------------

def check_graduation_candidates(inputs: dict) -> list:
    """Learnings that appeared in 3+ tasks — ready to graduate to practice.

    Output section: needs_decision
    """
    results = []
    learnings = inputs.get("learnings", {}).get("learnings", [])

    for learning in learnings:
        applied_in = learning.get("applied_in", [])
        if len(applied_in) >= 3:
            results.append({
                "id": _next_id("REC"),
                "type": "graduation",
                "summary": (f"Learning {learning['id']} appeared in "
                            f"{len(applied_in)} tasks — ready to graduate"),
                "evidence": applied_in,
                "rationale": "Framework threshold is 3+ for graduation",
                "suggested_action": {
                    "command": "fw task create",
                    "args": (f"--name 'Graduate {learning['id']} to practice'"
                             f" --type refactor --owner human"),
                },
                "priority": "medium",
                "priority_factors": [{
                    "rule": "graduation_threshold",
                    "detail": (f"{len(applied_in)} occurrences "
                               f"(threshold: 3+)"),
                }],
            })
    return results


def check_dead_letter_practices(inputs: dict) -> list:
    """Practices with 0 applications and created >14 days ago.

    Output section: needs_decision
    """
    results = []
    practices = inputs.get("practices", {}).get("practices", [])
    now = datetime.now(timezone.utc)

    for practice in practices:
        if practice.get("applications", 1) > 0:
            continue
        if practice.get("status") != "active":
            continue

        origin_date = _parse_datetime(practice.get("origin_date"))
        if not origin_date:
            continue

        days = (now - origin_date).days
        if days >= 14:
            results.append({
                "id": _next_id("REC"),
                "type": "dead_letter_practice",
                "summary": (f"Practice {practice['id']} has 0 applications "
                            f"since creation {days} days ago"),
                "evidence": {
                    "practice_id": practice["id"],
                    "name": practice.get("name", ""),
                    "created": str(practice.get("origin_date", "")),
                    "applications": 0,
                },
                "suggested_action": (f"Review {practice['id']} — "
                                     f"is it wrong, irrelevant, or unenforced?"),
                "priority": "low",
                "priority_factors": [{
                    "rule": "practice_adoption",
                    "detail": (f"0 applications, {days} days since "
                               f"graduation (threshold: 14 days)"),
                }],
            })
    return results


def check_pattern_consolidation(inputs: dict) -> list:
    """3+ success patterns sharing theme keywords.

    Output section: opportunities
    """
    results = []
    patterns = inputs.get("patterns", {})
    success = patterns.get("success_patterns", [])

    if len(success) < 3:
        return []

    # Simple keyword overlap detection
    words_per_pattern = {}
    for p in success:
        text = (p.get("pattern", "") + " " + p.get("description", "")).lower()
        words = set(w for w in re.findall(r"\w+", text) if len(w) > 4)
        words_per_pattern[p.get("id", "")] = words

    # Find patterns with overlapping keywords
    ids = list(words_per_pattern.keys())
    for i, id_a in enumerate(ids):
        overlapping = [id_a]
        for id_b in ids[i + 1:]:
            overlap = words_per_pattern[id_a] & words_per_pattern[id_b]
            if len(overlap) >= 2:
                overlapping.append(id_b)
        if len(overlapping) >= 3:
            results.append({
                "id": _next_id("OPP"),
                "type": "pattern_consolidation",
                "summary": (f"{len(overlapping)} success patterns share "
                            f"common theme — candidate for practice"),
                "evidence": overlapping,
                "suggested_action": "Review patterns for practice extraction",
                "priority": "low",
            })
            break  # One consolidation suggestion per scan

    return results


def check_escalation_advancement(inputs: dict) -> list:
    """Patterns at current escalation step for 3+ occurrences.

    Output section: opportunities

    Requires patterns to have: escalation_step, occurrences_at_step fields.
    """
    results = []
    patterns = inputs.get("patterns", {})
    step_order = ["A", "B", "C", "D"]

    for key in ("failure_patterns", "success_patterns",
                "antifragile_patterns", "workflow_patterns"):
        for p in patterns.get(key, []):
            step = p.get("escalation_step")
            occurrences = p.get("occurrences_at_step", 0)
            if not step or occurrences < 3:
                continue
            step_idx = step_order.index(step) if step in step_order else -1
            if step_idx < 0 or step_idx >= len(step_order) - 1:
                continue
            next_step = step_order[step_idx + 1]
            results.append({
                "id": _next_id("OPP"),
                "type": "escalation_advancement",
                "summary": (f"Pattern {p.get('id', '?')} at step {step} "
                            f"for {occurrences} occurrences — advance "
                            f"to step {next_step}"),
                "evidence": {
                    "pattern": p.get("id"),
                    "current_step": step,
                    "occurrences_at_step": occurrences,
                },
                "suggested_action": (f"Advance {p.get('id', '?')} to "
                                     f"step {next_step}"),
                "priority": "low",
            })
    return results


# ---------------------------------------------------------------------------
# Strength rules (§5.3)
# ---------------------------------------------------------------------------

def check_mitigation_ineffectiveness(inputs: dict) -> list:
    """Patterns where mitigation was applied but failure recurred.

    Output section: needs_decision

    Checks: tasks in issues whose body mentions a known pattern's mitigation
    text — meaning the mitigation was already tried but failed.
    """
    results = []
    patterns = inputs.get("patterns", {})
    failure_patterns = patterns.get("failure_patterns", [])

    if not failure_patterns:
        return results

    for task in inputs.get("active_tasks", []):
        if task.get("status") != "issues":
            continue
        task_text = (task.get("_body", "")).lower()

        for fp in failure_patterns:
            mitigation = fp.get("mitigation", "").lower()
            pattern_text = fp.get("pattern", "").lower()
            if (mitigation and len(mitigation) > 5 and
                    mitigation in task_text and
                    pattern_text and pattern_text in task_text):
                results.append({
                    "id": _next_id("REC"),
                    "type": "mitigation_ineffective",
                    "summary": (f"Pattern {fp['id']} mitigation applied in "
                                f"{task['id']} but failure recurred"),
                    "evidence": {
                        "task": task["id"],
                        "pattern": fp["id"],
                    },
                    "suggested_action": (f"Review {fp['id']} mitigation — "
                                         f"may need escalation"),
                    "priority": "medium",
                    "priority_factors": [{
                        "rule": "mitigation_ineffectiveness",
                        "detail": (f"{fp['id']} mitigation was applied "
                                   f"but failure recurred"),
                    }],
                })
    return results


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _parse_datetime(value) -> datetime | None:
    """Parse a datetime value from YAML (string or datetime object)."""
    if value is None or value == "null":
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except (ValueError, TypeError):
            return None
    return None
```

**Step 4: Run tests to verify they pass**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py::TestChallengeRules -v`
Expected: All PASS

**Step 5: Commit**

```bash
git add web/watchtower/rules.py web/watchtower/test_scan.py
git commit -m "T-058: Add challenge detection rules (stale, healing, drift, regression, gaps, novel)"
```

---

## Task 3: Prioritizer and Feedback Engine

**Files:**
- Create: `web/watchtower/prioritizer.py`
- Create: `web/watchtower/feedback.py`
- Modify: `web/watchtower/test_scan.py` — add tests

**Context:** The prioritizer orders the work queue from active tasks (issues > stale > active by recency > captured). Session continuity boosts tasks from the last handover. The feedback engine computes antifragility metrics: patterns added, mitigations confirmed, practice adoption, and scan recommendation accuracy.

**Step 1: Write failing tests**

```python
# Append to web/watchtower/test_scan.py

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
```

**Step 2: Run tests to verify they fail**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py::TestPrioritizer web/watchtower/test_scan.py::TestFeedback -v`
Expected: FAIL — `ModuleNotFoundError`

**Step 3: Implement prioritizer**

```python
# web/watchtower/prioritizer.py
"""Work queue prioritization for the Watchtower scan engine.

Orders active tasks by: issues > stale > active (by recency) > captured.
Session continuity boosts tasks from the last handover.
"""

import re
from datetime import datetime, timezone


# Status priority weights (lower = higher priority)
STATUS_PRIORITY = {
    "issues": 0,
    "started-work": 1,
    "captured": 2,
}


def prioritize_work_queue(inputs: dict) -> list:
    """Return a prioritized list of active tasks."""
    tasks = inputs.get("active_tasks", [])
    if not tasks:
        return []

    # Extract session continuity data from handover
    handover_tasks = _extract_handover_tasks(inputs.get("handover"))

    scored = []
    for task in tasks:
        task_id = task.get("id", "")
        status = task.get("status", "captured")
        name = task.get("name", "")

        # Base score from status
        base_score = STATUS_PRIORITY.get(status, 2)

        # Recency score (more recent update = lower score = higher priority)
        last_update = _parse_datetime(task.get("last_update"))
        now = datetime.now(timezone.utc)
        recency_days = (now - last_update).days if last_update else 999

        # Priority factors
        factors = []
        factors.append({
            "rule": "status",
            "detail": f"Status: {status}",
        })

        # Session continuity boost
        continuity_boost = 0
        if task_id in handover_tasks:
            continuity_boost = -0.5  # Boost priority
            factors.append({
                "rule": "session_continuity",
                "detail": "Listed in last handover",
            })

        # Compute final score
        score = base_score + continuity_boost + (recency_days * 0.01)

        scored.append({
            "task_id": task_id,
            "name": name,
            "status": status,
            "priority": len(scored) + 1,  # Will be reassigned after sort
            "priority_factors": factors,
            "_score": score,
        })

    # Sort by score (ascending = higher priority first)
    scored.sort(key=lambda x: x["_score"])

    # Assign final priority numbers
    for i, item in enumerate(scored):
        item["priority"] = i + 1
        del item["_score"]

    return scored


def _extract_handover_tasks(handover: str | None) -> set:
    """Extract task IDs mentioned in the handover."""
    if not handover:
        return set()
    return set(re.findall(r"T-\d{3}", handover))


def _parse_datetime(value) -> datetime | None:
    """Parse datetime from YAML value."""
    if value is None or value == "null":
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except (ValueError, TypeError):
            return None
    return None
```

**Step 4: Implement feedback engine**

```python
# web/watchtower/feedback.py
"""Feedback and antifragility metrics for the Watchtower scan engine.

Computes:
- Pattern counts and growth since last scan
- Mitigation effectiveness tracking
- Practice adoption rates
- Scan recommendation accuracy (from decisions.yaml)
"""


def compute_feedback(inputs: dict) -> dict:
    """Compute antifragility metrics from project state."""
    patterns = inputs.get("patterns", {})
    practices = inputs.get("practices", {}).get("practices", [])
    learnings = inputs.get("learnings", {}).get("learnings", [])
    decisions = inputs.get("decisions", {}).get("decisions", [])
    previous_scan = inputs.get("previous_scan")

    # Pattern counts
    total_patterns = sum(
        len(patterns.get(k, []))
        for k in ("failure_patterns", "success_patterns",
                   "antifragile_patterns", "workflow_patterns")
    )

    # Patterns added since last scan
    prev_patterns = 0
    if previous_scan and isinstance(previous_scan, dict):
        prev_af = previous_scan.get("antifragility", {})
        prev_patterns = prev_af.get("patterns_total", total_patterns)
    patterns_added = max(0, total_patterns - prev_patterns)

    # Practice adoption
    active_practices = [p for p in practices if p.get("status") == "active"]
    dead_letter = [
        p for p in active_practices
        if p.get("applications", 0) == 0
    ]

    # Learnings graduated (those with 3+ applied_in)
    graduated = [
        l for l in learnings
        if len(l.get("applied_in", [])) >= 3
    ]

    # Scan accuracy from decisions (decisions with source=scan)
    scan_decisions = [
        d for d in decisions
        if d.get("source") == "scan"
    ]
    approved = len([
        d for d in scan_decisions
        if "approved" in d.get("decision", "").lower()
        or "accept" in d.get("decision", "").lower()
    ])
    dismissed = len([
        d for d in scan_decisions
        if "deferred" in d.get("decision", "").lower()
        or "dismiss" in d.get("decision", "").lower()
    ])
    total_scan_decisions = approved + dismissed

    return {
        "patterns_total": total_patterns,
        "patterns_added_since_last_scan": patterns_added,
        "learnings_graduated": len(graduated),
        "dead_letter_practices": len(dead_letter),
        "practice_adoption": {
            "active": len(active_practices),
            "with_applications": len(active_practices) - len(dead_letter),
        },
        "scan_accuracy": {
            "recommendations_approved": approved,
            "recommendations_dismissed": dismissed,
            "approval_rate": (
                round(approved / total_scan_decisions * 100)
                if total_scan_decisions > 0 else None
            ),
        },
    }
```

**Step 5: Run tests**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py::TestPrioritizer web/watchtower/test_scan.py::TestFeedback -v`
Expected: All PASS

**Step 6: Commit**

```bash
git add web/watchtower/prioritizer.py web/watchtower/feedback.py web/watchtower/test_scan.py
git commit -m "T-058: Add work queue prioritizer and feedback engine"
```

---

## Task 4: Full Scan Assembly + CLI Entry Point

**Files:**
- Create: `web/watchtower/__main__.py`
- Modify: `bin/fw` — add `scan` command
- Modify: `agents/context/lib/init.sh` — auto-scan on context init
- Modify: `web/watchtower/test_scan.py` — add integration test

**Context:** The scan engine is invoked via `fw scan` which shells out to `python3 -m web.watchtower`. The `fw context init` command auto-runs a scan at the end of session initialization.

**Step 1: Write failing integration test**

```python
# Append to web/watchtower/test_scan.py

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
```

**Step 2: Run test**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py::TestFullScan -v`
Expected: All PASS (scanner.scan() should work since all components are built)

**Step 3: Create CLI entry point**

```python
# web/watchtower/__main__.py
"""CLI entry point for the Watchtower scan engine.

Usage:
    python3 -m web.watchtower [--project-root PATH] [--quiet]
    fw scan [--quiet]
"""

import argparse
import os
import sys
import yaml

from .scanner import scan


def main():
    parser = argparse.ArgumentParser(
        description="Watchtower scan — detect opportunities, challenges, and work direction"
    )
    parser.add_argument(
        "--project-root",
        default=os.environ.get("PROJECT_ROOT"),
        help="Project root directory (default: PROJECT_ROOT env var)",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress output — only write scan YAML",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output scan result as YAML to stdout",
    )
    args = parser.parse_args()

    try:
        result = scan(project_root=args.project_root)
    except Exception as exc:
        print(f"Scan failed: {exc}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        yaml.dump(result, sys.stdout, default_flow_style=False,
                  sort_keys=False)
    elif not args.quiet:
        print(result["summary"])
        print()
        n_dec = len(result.get("needs_decision", []))
        n_rec = len(result.get("framework_recommends", []))
        n_opp = len(result.get("opportunities", []))
        n_risk = len(result.get("risks", []))
        parts = []
        if n_dec:
            parts.append(f"{n_dec} decisions")
        if n_rec:
            parts.append(f"{n_rec} recommendations")
        if n_opp:
            parts.append(f"{n_opp} opportunities")
        if n_risk:
            parts.append(f"{n_risk} risks")
        if parts:
            print("  " + " | ".join(parts))
        print(f"\nScan written to .context/scans/{result['scan_id']}.yaml")


if __name__ == "__main__":
    main()
```

**Step 4: Add `fw scan` command to `bin/fw`**

Find the `serve)` case in `bin/fw` (around line 590) and add a `scan)` case BEFORE it in the case statement. Add it near the other agent-routing commands:

```bash
    # Add after the 'note)' case (around line 588) and before 'serve)' (line 590):
    scan)
        if ! python3 -c "import yaml" 2>/dev/null; then
            echo -e "${RED}ERROR: PyYAML is not installed${NC}" >&2
            echo "  pip install -r $FRAMEWORK_ROOT/web/requirements.txt" >&2
            exit 1
        fi
        cd "$FRAMEWORK_ROOT" && exec python3 -m web.watchtower "$@"
        ;;
```

Also add a help line for scan. Find the help text section (around line 118) and add:

```bash
    echo -e "  ${GREEN}scan${NC}                  Run watchtower scan (detect opportunities & issues)"
```

**Step 5: Add auto-scan to `fw context init`**

Append to the end of `agents/context/lib/init.sh`, just before the closing `}` of `do_init()`:

```bash
    # Auto-run watchtower scan (Phase 4)
    if python3 -c "import web.watchtower" 2>/dev/null; then
        echo ""
        echo "Running watchtower scan..."
        cd "$FRAMEWORK_ROOT" && python3 -m web.watchtower --quiet 2>/dev/null && \
            echo "  Scan written to .context/scans/LATEST.yaml" || \
            echo "  (scan skipped — non-critical)"
    fi
```

**Step 6: Create `.context/scans/` directory and gitignore**

```bash
mkdir -p .context/scans
touch .context/scans/.gitkeep
```

Add to `.gitignore` (if it exists) or create one:
```
# Scan files are ephemeral (re-derivable from project state)
.context/scans/SC-*.yaml
.context/scans/LATEST.yaml
```

**Step 7: Run all tests**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py -v`
Expected: All PASS

**Step 8: Verify CLI works**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m web.watchtower`
Expected: Summary text printed, scan YAML written to `.context/scans/`

**Step 9: Commit**

```bash
git add web/watchtower/__main__.py web/watchtower/test_scan.py bin/fw agents/context/lib/init.sh .context/scans/.gitkeep
git commit -m "T-058: Add scan CLI entry point, fw scan command, context init auto-scan"
```

---

## Task 5: Cockpit UI — Layout and Progressive Disclosure

**Files:**
- Create: `web/blueprints/cockpit.py`
- Create: `web/templates/cockpit.html`
- Modify: `web/blueprints/core.py` — delegate `/` to cockpit when scan exists
- Modify: `web/app.py` — register cockpit blueprint
- Modify: `web/shared.py` — no changes expected
- Modify: `web/test_app.py` — add cockpit tests

**Context:** The cockpit replaces the current "power user" dashboard when scan data exists. It renders scan output with progressive disclosure (sections shown/hidden based on content), visual differentiation (amber/blue/green borders), and max 3 items per section. Falls back to existing dashboard when no scan data exists.

**Reference files:**
- `web/templates/index.html` — current dashboard template to understand CSS patterns
- `web/blueprints/core.py:189-235` — current `/` route
- `web/shared.py:116-134` — `render_page()` dual-rendering pattern
- Design doc §4.5 — cockpit layout spec

**Step 1: Write failing tests**

```python
# Append to web/test_app.py, in a new test class:

class TestCockpitUI:
    """Test the cockpit UI (Phase 4)."""

    def test_dashboard_shows_cockpit_when_scan_exists(self, client, app):
        """When LATEST.yaml exists, dashboard renders cockpit."""
        import yaml
        scans_dir = Path(app.config.get("PROJECT_ROOT",
                         os.environ.get("PROJECT_ROOT", "."))) / ".context" / "scans"
        scans_dir.mkdir(parents=True, exist_ok=True)
        scan_data = {
            "schema_version": 1,
            "scan_id": "SC-test",
            "scan_status": "complete",
            "summary": "Test scan summary",
            "project_health": {"tasks_active": 1, "audit_status": "PASS"},
            "needs_decision": [],
            "framework_recommends": [],
            "opportunities": [],
            "work_queue": [],
            "risks": [],
            "antifragility": {},
            "warnings": [],
        }
        (scans_dir / "SC-test.yaml").write_text(yaml.dump(scan_data))
        (scans_dir / "LATEST.yaml").symlink_to("SC-test.yaml")
        response = client.get("/")
        assert response.status_code == 200
        assert b"Test scan summary" in response.data or b"WATCHTOWER" in response.data

    def test_dashboard_falls_back_without_scan(self, client):
        """Without scan data, shows existing dashboard."""
        response = client.get("/")
        assert response.status_code == 200

    def test_cockpit_shows_needs_decision_section(self, client, app):
        """Needs Decision section appears when items exist."""
        import yaml
        scans_dir = Path(app.config.get("PROJECT_ROOT",
                         os.environ.get("PROJECT_ROOT", "."))) / ".context" / "scans"
        scans_dir.mkdir(parents=True, exist_ok=True)
        scan_data = {
            "schema_version": 1,
            "scan_id": "SC-test2",
            "scan_status": "complete",
            "summary": "Decisions needed",
            "project_health": {"tasks_active": 1, "audit_status": "PASS"},
            "needs_decision": [
                {"id": "REC-001", "type": "graduation",
                 "summary": "L-005 ready to graduate",
                 "suggested_action": "Review", "priority": "medium"},
            ],
            "framework_recommends": [],
            "opportunities": [],
            "work_queue": [],
            "risks": [],
            "antifragility": {},
            "warnings": [],
        }
        latest = scans_dir / "LATEST.yaml"
        if latest.exists() or latest.is_symlink():
            latest.unlink()
        (scans_dir / "SC-test2.yaml").write_text(yaml.dump(scan_data))
        latest.symlink_to("SC-test2.yaml")
        response = client.get("/")
        assert response.status_code == 200
        assert b"NEEDS YOUR DECISION" in response.data or b"needs-decision" in response.data.lower()
```

**Step 2: Run tests to verify they fail**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/test_app.py::TestCockpitUI -v`
Expected: FAIL — cockpit not yet implemented

**Step 3: Create cockpit blueprint**

```python
# web/blueprints/cockpit.py
"""Cockpit blueprint — scan-driven interactive dashboard.

Renders the Watchtower cockpit when scan data exists, with:
- Needs Decision (amber) — items requiring SOVEREIGNTY
- Framework Recommends (blue) — Tier 1 suggestions
- Work Direction — prioritized work queue
- Opportunities (green) — low priority improvements
- System Health + Recent Activity

All control actions shell out to existing fw CLI commands.
"""

import os
import re as re_mod
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint, request, render_template

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page

bp = Blueprint("cockpit", __name__)


def load_scan() -> dict | None:
    """Load the latest scan from .context/scans/LATEST.yaml."""
    latest = PROJECT_ROOT / ".context" / "scans" / "LATEST.yaml"
    if not latest.exists():
        return None
    try:
        with open(latest) as f:
            data = yaml.safe_load(f)
        if isinstance(data, dict) and data.get("schema_version"):
            return data
    except Exception:
        pass
    return None


def get_scan_age(scan_data: dict) -> str:
    """Human-readable age of the scan."""
    ts = scan_data.get("timestamp")
    if not ts:
        return "unknown"
    try:
        scan_time = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        delta = datetime.now(timezone.utc) - scan_time
        minutes = int(delta.total_seconds() // 60)
        if minutes < 1:
            return "just now"
        elif minutes < 60:
            return f"{minutes}m ago"
        elif minutes < 1440:
            return f"{minutes // 60}h ago"
        else:
            return f"{minutes // 1440}d ago"
    except (ValueError, TypeError):
        return "unknown"


def get_cockpit_context(scan_data: dict) -> dict:
    """Build template context from scan data."""
    return {
        "scan": scan_data,
        "scan_age": get_scan_age(scan_data),
        "needs_decision": scan_data.get("needs_decision", [])[:3],
        "needs_decision_total": len(scan_data.get("needs_decision", [])),
        "framework_recommends": scan_data.get("framework_recommends", [])[:3],
        "framework_recommends_total": len(scan_data.get("framework_recommends", [])),
        "opportunities": scan_data.get("opportunities", [])[:3],
        "opportunities_total": len(scan_data.get("opportunities", [])),
        "work_queue": scan_data.get("work_queue", []),
        "risks": scan_data.get("risks", []),
        "health": scan_data.get("project_health", {}),
        "antifragility": scan_data.get("antifragility", {}),
        "summary": scan_data.get("summary", ""),
        "warnings": scan_data.get("warnings", []),
        "recent_failures": scan_data.get("recent_failures", []),
        "scan_status": scan_data.get("scan_status", "unknown"),
    }


# ---------------------------------------------------------------------------
# Control action endpoints
# ---------------------------------------------------------------------------

def _fw(args, timeout=30):
    """Run a fw CLI command and return (stdout, stderr, ok)."""
    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw")] + args,
            capture_output=True, text=True, timeout=timeout,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode == 0
    except subprocess.TimeoutExpired:
        return "", "Command timed out", False
    except Exception as exc:
        return "", str(exc), False


def _escape(text):
    """Escape HTML."""
    return (text.replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


@bp.route("/api/scan/refresh", methods=["POST"])
def scan_refresh():
    """Trigger a fresh scan and return updated cockpit content."""
    stdout, stderr, ok = _fw(["scan", "--quiet"])
    if ok:
        scan_data = load_scan()
        if scan_data:
            ctx = get_cockpit_context(scan_data)
            return render_template("cockpit.html", **ctx)
        return '<p style="color:var(--pico-del-color)">Scan succeeded but output not found.</p>', 500
    return f'<p style="color:var(--pico-del-color)">Scan failed: {_escape(stderr[:300])}</p>', 500


@bp.route("/api/scan/approve/<rec_id>", methods=["POST"])
def scan_approve(rec_id):
    """Approve a needs_decision recommendation."""
    scan_data = load_scan()
    if not scan_data:
        return '<p style="color:var(--pico-del-color)">No scan data.</p>', 400

    # Find the recommendation
    rec = None
    for item in scan_data.get("needs_decision", []):
        if item.get("id") == rec_id:
            rec = item
            break
    if not rec:
        return f'<p style="color:var(--pico-del-color)">Recommendation {_escape(rec_id)} not found.</p>', 404

    # Execute the suggested action
    action = rec.get("suggested_action", {})
    if isinstance(action, dict) and "command" in action:
        cmd_parts = action["command"].split() + (action.get("args", "").split() if action.get("args") else [])
        stdout, stderr, ok = _fw(cmd_parts)
        if ok:
            # Record the approval as a decision
            rec_type = rec.get("type", "unknown")
            _fw(["context", "add-decision",
                 f"Approved: {rec.get('summary', rec_id)}",
                 "--rationale", f"Scan recommendation approved",
                 "--source", "scan",
                 "--recommendation-type", rec_type])
            return f'<p style="color:var(--pico-ins-color)">Approved: {_escape(rec.get("summary", rec_id)[:100])}</p>'
        return f'<p style="color:var(--pico-del-color)">Action failed: {_escape(stderr[:200])}</p>', 500

    return f'<p style="color:var(--pico-del-color)">No executable action for {_escape(rec_id)}.</p>', 400


@bp.route("/api/scan/defer/<rec_id>", methods=["POST"])
def scan_defer(rec_id):
    """Defer a needs_decision recommendation with reason."""
    reason = request.form.get("reason", "Deferred by user").strip()

    scan_data = load_scan()
    if not scan_data:
        return '<p style="color:var(--pico-del-color)">No scan data.</p>', 400

    rec = None
    for item in scan_data.get("needs_decision", []):
        if item.get("id") == rec_id:
            rec = item
            break
    if not rec:
        return f'<p style="color:var(--pico-del-color)">Not found: {_escape(rec_id)}.</p>', 404

    rec_type = rec.get("type", "unknown")
    _fw(["context", "add-decision",
         f"Deferred: {rec.get('summary', rec_id)}",
         "--rationale", reason,
         "--source", "scan",
         "--recommendation-type", rec_type])

    return f'<p style="color:var(--pico-muted-color)">Deferred: {_escape(rec.get("summary", rec_id)[:100])}</p>'


@bp.route("/api/scan/apply/<rec_id>", methods=["POST"])
def scan_apply(rec_id):
    """Apply a framework_recommends recommendation."""
    scan_data = load_scan()
    if not scan_data:
        return '<p style="color:var(--pico-del-color)">No scan data.</p>', 400

    rec = None
    for item in scan_data.get("framework_recommends", []):
        if item.get("id") == rec_id:
            rec = item
            break
    if not rec:
        return f'<p style="color:var(--pico-del-color)">Not found: {_escape(rec_id)}.</p>', 404

    action = rec.get("recommended_action", {})
    if isinstance(action, dict) and "command" in action:
        cmd_parts = action["command"].split() + (action.get("args", "").split() if action.get("args") else [])
        stdout, stderr, ok = _fw(cmd_parts)
        if ok:
            return f'<p style="color:var(--pico-ins-color)">Applied: {_escape(rec.get("summary", rec_id)[:100])}</p>'
        return f'<p style="color:var(--pico-del-color)">Failed: {_escape(stderr[:200])}</p>', 500

    return f'<p style="color:var(--pico-del-color)">No action for {_escape(rec_id)}.</p>', 400


@bp.route("/api/scan/focus/<task_id>", methods=["POST"])
def scan_focus(task_id):
    """Set focus to a task from the work queue."""
    if not re_mod.match(r"^T-\d{3}$", task_id):
        return '<p style="color:var(--pico-del-color)">Invalid task ID.</p>', 400
    stdout, stderr, ok = _fw(["context", "focus", task_id])
    if ok:
        return f'<p style="color:var(--pico-ins-color)">Focus set to {_escape(task_id)}</p>'
    return f'<p style="color:var(--pico-del-color)">Failed: {_escape(stderr[:200])}</p>', 500
```

**Step 4: Create cockpit template**

```html
{# web/templates/cockpit.html — Watchtower Cockpit (Phase 4) #}
<style>
    .wt-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:1.5rem; }
    .wt-header h1 { margin:0; font-size:1.6rem; letter-spacing:0.05em; text-transform:uppercase; }
    .wt-scan-meta { display:flex; gap:1rem; align-items:center; font-size:0.85rem; color:var(--pico-muted-color); }
    .wt-section { margin-bottom:1rem; }
    .wt-section-title { margin:0 0 0.75rem 0; font-size:1rem; letter-spacing:0.04em; text-transform:uppercase; color:var(--pico-muted-color); }
    .wt-card { border-left:4px solid var(--pico-muted-border-color); padding:0.75rem 1rem; margin-bottom:0.5rem; background:var(--pico-card-background-color); border-radius:0 4px 4px 0; }
    .wt-card-amber { border-left-color:#f9a825; }
    .wt-card-blue { border-left-color:#1565c0; }
    .wt-card-green { border-left-color:#2e7d32; }
    .wt-card-red { border-left-color:#c62828; }
    .wt-card-summary { font-weight:600; margin-bottom:0.25rem; }
    .wt-card-detail { font-size:0.85rem; color:var(--pico-muted-color); margin-bottom:0.5rem; }
    .wt-card-actions { display:flex; gap:0.5rem; flex-wrap:wrap; }
    .wt-card-actions button, .wt-card-actions a[role="button"] { font-size:0.75rem; padding:0.2em 0.6em; }
    .wt-columns { display:grid; grid-template-columns:1fr 1fr; gap:1rem; margin-bottom:1rem; }
    @media (max-width:768px) { .wt-columns { grid-template-columns:1fr; } }
    .wt-pulse { display:flex; flex-wrap:wrap; gap:1.5rem; padding:0; margin:0; list-style:none; font-size:0.9rem; }
    .wt-pulse-value { font-weight:700; }
    .wt-badge { display:inline-block; padding:0.25em 0.75em; border-radius:4px; font-size:0.8rem; font-weight:700; letter-spacing:0.04em; text-transform:uppercase; }
    .wt-badge-pass { background:#2e7d32; color:#fff; }
    .wt-badge-warn { background:#f9a825; color:#000; }
    .wt-badge-fail { background:#c62828; color:#fff; }
    .wt-allclear { text-align:center; padding:2rem; color:var(--pico-muted-color); font-style:italic; }
    .wt-show-all { font-size:0.8rem; float:right; }
    .wt-queue-item { display:flex; justify-content:space-between; align-items:center; padding:0.5em 0; border-bottom:1px solid var(--pico-muted-border-color); }
    .wt-queue-item:last-child { border-bottom:none; }
    .wt-queue-rank { font-weight:700; margin-right:0.75rem; color:var(--pico-muted-color); min-width:1.5em; }
    .wt-queue-name { flex:1; }
    .wt-queue-status { font-size:0.8rem; margin-left:0.5rem; }
    .wt-queue-status.issues { color:#c62828; }
    .wt-queue-status.started-work { color:#1565c0; }
</style>

{# --- Header ------------------------------------------------ #}
<div class="wt-header">
    <h1>Watchtower</h1>
    <div class="wt-scan-meta">
        <span>Scan: {{ scan_age }}</span>
        {% set audit_status = health.get('audit_status', 'UNKNOWN') %}
        <span class="wt-badge
            {%- if audit_status == 'PASS' %} wt-badge-pass
            {%- elif audit_status == 'WARN' %} wt-badge-warn
            {%- else %} wt-badge-fail{% endif %}">
            audit: {{ audit_status }}
        </span>
        <button class="outline" style="font-size:0.75rem; padding:0.2em 0.6em;"
                hx-post="/api/scan/refresh"
                hx-target="#content"
                hx-swap="innerHTML"
                hx-headers='{"X-CSRF-Token": "{{ csrf_token() }}"}'>
            Refresh
        </button>
    </div>
</div>

{% if scan_status == 'partial' %}
<article style="border-left:4px solid #f9a825; padding:0.5rem 1rem; margin-bottom:1rem;">
    <small>Scan partially completed — some data sources were unavailable.</small>
</article>
{% endif %}

{# --- Needs Decision (amber) -------------------------------- #}
{% if needs_decision %}
<div class="wt-section">
    <h4 class="wt-section-title">
        Needs Your Decision ({{ needs_decision_total }})
        {% if needs_decision_total > 3 %}
        <a href="#" class="wt-show-all" onclick="this.parentElement.parentElement.querySelectorAll('.wt-card-hidden').forEach(e=>e.style.display='block');this.style.display='none';return false;">Show all</a>
        {% endif %}
    </h4>
    {% for item in scan.get('needs_decision', []) %}
    <div class="wt-card wt-card-amber {{ 'wt-card-hidden' if loop.index > 3 else '' }}" style="{{ 'display:none' if loop.index > 3 else '' }}" id="rec-{{ item.id }}">
        <div class="wt-card-summary">{{ item.summary }}</div>
        {% if item.priority_factors %}
        <div class="wt-card-detail">{{ item.priority_factors[0].detail if item.priority_factors else '' }}</div>
        {% endif %}
        <div class="wt-card-actions">
            {% if item.suggested_action is mapping %}
            <button class="outline"
                    hx-post="/api/scan/approve/{{ item.id }}"
                    hx-target="#rec-{{ item.id }}"
                    hx-swap="outerHTML"
                    hx-headers='{"X-CSRF-Token": "{{ csrf_token() }}"}'>
                Approve
            </button>
            {% endif %}
            <button class="outline secondary"
                    hx-post="/api/scan/defer/{{ item.id }}"
                    hx-target="#rec-{{ item.id }}"
                    hx-swap="outerHTML"
                    hx-headers='{"X-CSRF-Token": "{{ csrf_token() }}"}'>
                Defer
            </button>
        </div>
    </div>
    {% endfor %}
</div>
{% endif %}

{# --- Framework Recommends (blue) --------------------------- #}
{% if framework_recommends %}
<div class="wt-section">
    <h4 class="wt-section-title">
        Framework Recommends ({{ framework_recommends_total }})
        {% if framework_recommends_total > 3 %}
        <a href="#" class="wt-show-all" onclick="this.parentElement.parentElement.querySelectorAll('.wt-card-hidden').forEach(e=>e.style.display='block');this.style.display='none';return false;">Show all</a>
        {% endif %}
    </h4>
    {% for item in scan.get('framework_recommends', []) %}
    <div class="wt-card wt-card-blue {{ 'wt-card-hidden' if loop.index > 3 else '' }}" style="{{ 'display:none' if loop.index > 3 else '' }}" id="fra-{{ item.id }}">
        <div class="wt-card-summary">{{ item.summary }}</div>
        {% if item.priority_factors %}
        <div class="wt-card-detail">{{ item.priority_factors[0].detail if item.priority_factors else '' }}</div>
        {% endif %}
        <div class="wt-card-actions">
            <button class="outline"
                    hx-post="/api/scan/apply/{{ item.id }}"
                    hx-target="#fra-{{ item.id }}"
                    hx-swap="outerHTML"
                    hx-headers='{"X-CSRF-Token": "{{ csrf_token() }}"}'>
                Apply
            </button>
            <button class="outline secondary"
                    onclick="this.closest('.wt-card').style.display='none'">
                Ignore
            </button>
        </div>
    </div>
    {% endfor %}
</div>
{% endif %}

{# --- Work Direction ---------------------------------------- #}
<article>
    <h4 class="wt-section-title">Work Direction</h4>
    {% if work_queue %}
    {% for item in work_queue %}
    <div class="wt-queue-item">
        <span>
            <span class="wt-queue-rank">{{ item.priority }}.</span>
            <span class="wt-queue-name">
                <a href="/tasks/{{ item.task_id }}"
                   hx-target="#content" hx-swap="innerHTML" hx-push-url="true">
                    {{ item.task_id }}: {{ item.name }}
                </a>
            </span>
            <span class="wt-queue-status {{ item.status }}">{{ item.status }}</span>
        </span>
        <span class="wt-card-actions">
            <button class="outline" style="font-size:0.7rem; padding:0.15em 0.4em;"
                    hx-post="/api/scan/focus/{{ item.task_id }}"
                    hx-target="this"
                    hx-swap="outerHTML"
                    hx-headers='{"X-CSRF-Token": "{{ csrf_token() }}"}'>
                Focus
            </button>
        </span>
    </div>
    {% endfor %}
    {% else %}
    <p style="color:var(--pico-muted-color); font-style:italic;">No active tasks.</p>
    {% endif %}
</article>

{# --- Opportunities (green) --------------------------------- #}
{% if opportunities %}
<div class="wt-section">
    <h4 class="wt-section-title">Opportunities ({{ opportunities_total }})</h4>
    {% for item in scan.get('opportunities', [])[:3] %}
    <div class="wt-card wt-card-green">
        <div class="wt-card-summary">{{ item.summary }}</div>
    </div>
    {% endfor %}
</div>
{% endif %}

{# --- All Clear banner -------------------------------------- #}
{% if not needs_decision and not framework_recommends and not opportunities and not risks %}
<div class="wt-allclear">
    <p>All Clear — no items requiring attention.</p>
</div>
{% endif %}

{# --- System Health + Recent Activity ----------------------- #}
<div class="wt-columns">
    <article>
        <h4 class="wt-section-title">System Health</h4>
        <ul class="wt-pulse">
            <li>Traceability: <span class="wt-pulse-value">{{ health.get('traceability', '?') }}</span></li>
            <li>Knowledge:
                <span class="wt-pulse-value">{{ health.get('knowledge', {}).get('learnings', 0) }}</span>L,
                <span class="wt-pulse-value">{{ health.get('knowledge', {}).get('patterns', 0) }}</span>P,
                <span class="wt-pulse-value">{{ health.get('knowledge', {}).get('decisions', 0) }}</span>D
            </li>
            <li>Gaps: <span class="wt-pulse-value">{{ health.get('gaps_watching', 0) }}</span> watching</li>
            {% if antifragility.get('patterns_added_since_last_scan', 0) > 0 %}
            <li>Strength: <span class="wt-pulse-value" style="color:#2e7d32;">+{{ antifragility.patterns_added_since_last_scan }}</span> patterns</li>
            {% endif %}
        </ul>
        <p style="margin-top:0.5rem;">
            <a href="/metrics" hx-target="#content" hx-swap="innerHTML" hx-push-url="true" style="font-size:0.85rem;">Full metrics &rarr;</a>
        </p>
    </article>

    <article>
        <h4 class="wt-section-title">Scan Summary</h4>
        <p style="font-size:0.9rem; white-space:pre-line;">{{ summary }}</p>
        {% if risks %}
        <h5 style="color:#c62828; font-size:0.85rem; margin-top:0.75rem;">Risks</h5>
        {% for risk in risks %}
        <div class="wt-card wt-card-red" style="padding:0.5rem 0.75rem;">
            <div style="font-size:0.85rem;">{{ risk.summary }}</div>
        </div>
        {% endfor %}
        {% endif %}
    </article>
</div>
```

**Step 5: Modify `core.py` to delegate to cockpit**

In `web/blueprints/core.py`, modify the `index()` function (line 189) to check for scan data and render cockpit instead:

```python
# At the top of core.py, add import:
from web.blueprints.cockpit import load_scan, get_cockpit_context

# Replace the index() function body after inception check:
@bp.route("/")
def index():
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    active_count = len(list(active_dir.glob("T-*.md"))) if active_dir.exists() else 0
    completed_count = len(list(completed_dir.glob("T-*.md"))) if completed_dir.exists() else 0

    # Inception detection: no tasks at all
    is_inception = (active_count == 0 and completed_count == 0)

    if is_inception:
        # Show inception checklist
        return render_page(
            "index.html",
            page_title="Watchtower",
            is_inception=True,
            inception_checklist=_get_inception_checklist(),
        )

    # Try cockpit view (Phase 4 — scan-driven dashboard)
    scan_data = load_scan()
    if scan_data:
        ctx = get_cockpit_context(scan_data)
        # Add recent activity (cockpit keeps this from existing dashboard)
        ctx["recent_activity"] = _get_recent_activity()
        return render_page("cockpit.html", page_title="Watchtower", **ctx)

    # Fallback: existing dashboard (no scan data)
    gaps_file = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    gap_count = 0
    if gaps_file.exists():
        with open(gaps_file) as f:
            data = yaml.safe_load(f)
        if data:
            gap_count = len([g for g in data.get("gaps", []) if g.get("status") == "watching"])

    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    last_session = "None"
    if handovers_dir.exists():
        sessions = sorted(handovers_dir.glob("S-*.md"), reverse=True)
        if sessions:
            last_session = sessions[0].stem

    audit_status, audit_pass, audit_warn, audit_fail = _get_audit_status()

    return render_page(
        "index.html",
        page_title="Watchtower",
        active_count=active_count,
        completed_count=completed_count,
        gap_count=gap_count,
        last_session=last_session,
        is_inception=False,
        audit_status=audit_status,
        audit_pass=audit_pass,
        audit_warn=audit_warn,
        audit_fail=audit_fail,
        attention_items=_get_attention_items(),
        recent_activity=_get_recent_activity(),
        knowledge_counts=_get_knowledge_counts(),
        traceability=_get_traceability(),
        inception_checklist=_get_inception_checklist(),
        pattern_summary=_get_pattern_summary(),
    )
```

**Step 6: Register cockpit blueprint in `app.py`**

Add to `web/app.py` after the other blueprint imports (around line 75):

```python
from web.blueprints.cockpit import bp as cockpit_bp
```

And register it (around line 83):

```python
app.register_blueprint(cockpit_bp)
```

**Step 7: Run all tests**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/test_app.py web/watchtower/test_scan.py -v`
Expected: All PASS (including existing tests — no regressions)

**Step 8: Commit**

```bash
git add web/blueprints/cockpit.py web/templates/cockpit.html web/blueprints/core.py web/app.py web/test_app.py
git commit -m "T-058: Add cockpit UI with scan-driven dashboard and control actions"
```

---

## Task 6: Agent Integration

**Files:**
- Modify: `agents/resume/resume.sh` — read LATEST.yaml in `status` output
- Modify: `agents/resume/lib/status.sh` — present scan data
- Modify: `web/watchtower/test_scan.py` — add tests for resume integration

**Context:** The resume agent should read and present LATEST.yaml alongside LATEST.md. The `resume quick` command should return the scan summary field. The `resume status` command should include scan-derived work queue.

**Reference files:**
- `agents/resume/resume.sh` — main resume agent script
- `agents/resume/lib/status.sh` — status subcommand implementation

**Step 1: Read resume agent files to understand current structure**

Read `agents/resume/resume.sh` and `agents/resume/lib/status.sh` before modifying.

**Step 2: Modify `resume quick` to return scan summary**

In the `quick` subcommand of the resume agent, add after reading LATEST.md:

```bash
# Read scan summary if available
SCAN_FILE="$PROJECT_ROOT/.context/scans/LATEST.yaml"
if [ -f "$SCAN_FILE" ]; then
    echo ""
    echo "=== Scan Summary ==="
    python3 -c "
import yaml, sys
with open('$SCAN_FILE') as f:
    data = yaml.safe_load(f)
if data and 'summary' in data:
    print(data['summary'])
" 2>/dev/null
fi
```

**Step 3: Modify `resume status` to include scan work queue**

In the `status` subcommand, add after the existing output:

```bash
# Include scan work queue if available
SCAN_FILE="$PROJECT_ROOT/.context/scans/LATEST.yaml"
if [ -f "$SCAN_FILE" ]; then
    echo ""
    echo "=== Scan Intelligence ==="
    python3 -c "
import yaml, sys
with open('$SCAN_FILE') as f:
    data = yaml.safe_load(f)
if not data:
    sys.exit(0)
print(f\"Scan: {data.get('scan_id', '?')} ({data.get('scan_status', '?')})\")
print(f\"Summary: {data.get('summary', 'N/A')}\")
wq = data.get('work_queue', [])
if wq:
    print(f\"\nWork Queue ({len(wq)} items):\")
    for item in wq[:5]:
        print(f\"  {item.get('priority', '?')}. {item.get('task_id', '?')}: {item.get('name', '?')} ({item.get('status', '?')})\")
nd = data.get('needs_decision', [])
if nd:
    print(f\"\nNeeds Decision ({len(nd)} items):\")
    for item in nd[:3]:
        print(f\"  - {item.get('summary', '?')}\")
" 2>/dev/null
fi
```

**Step 4: Test manually**

Run: `cd /opt/999-Agentic-Engineering-Framework && fw scan && fw resume quick`
Expected: Scan summary appears in resume output

**Step 5: Commit**

```bash
git add agents/resume/
git commit -m "T-058: Integrate scan output into resume agent (status + quick)"
```

---

## Task 7: Data Model Changes + Feedback Wiring

**Files:**
- Modify: `.context/project/patterns.yaml` — add escalation tracking fields
- Modify: `agents/context/lib/add-decision.sh` — support `--source` and `--recommendation-type` flags
- Modify: `web/watchtower/test_scan.py` — add feedback tests

**Context:** The feedback loop needs decisions.yaml to track scan source metadata (which recommendations were approved/dismissed). Patterns need escalation step tracking fields for the escalation advancement rule.

**Step 1: Add escalation fields to existing patterns**

For each pattern in `.context/project/patterns.yaml`, add:
```yaml
escalation_step: A
occurrences_at_step: 0
last_escalated: null
```

Read the current file, add these fields to every pattern entry that doesn't have them.

**Step 2: Modify add-decision to support scan metadata**

Read `agents/context/lib/add-decision.sh`. Add `--source` and `--recommendation-type` as optional flags that get included in the decision YAML entry.

The decision entry should look like:
```yaml
- id: D-XXX
  decision: "Approved: L-005 graduation"
  date: 2026-02-14
  source: scan                    # NEW: "scan" or "manual"
  recommendation_type: graduation  # NEW: from scan rec type
  rationale: "Scan recommendation approved"
```

**Step 3: Write test for feedback with scan decisions**

```python
# Append to web/watchtower/test_scan.py

class TestFeedbackWithDecisions:
    """Test feedback accuracy tracking with scan-source decisions."""

    def test_counts_approved_scan_decisions(self, project):
        from web.watchtower.scanner import gather_inputs
        from web.watchtower.feedback import compute_feedback

        # Add scan-source decisions
        _write_yaml(project / ".context" / "project" / "decisions.yaml", {
            "decisions": [
                {"id": "D-001", "decision": "Approved: L-005 graduation",
                 "source": "scan", "recommendation_type": "graduation"},
                {"id": "D-002", "decision": "Deferred: stale task",
                 "source": "scan", "recommendation_type": "stale_task"},
                {"id": "D-003", "decision": "Manual decision",
                 "source": "manual"},
            ],
        })

        inputs = gather_inputs(project, project)
        result = compute_feedback(inputs)
        assert result["scan_accuracy"]["recommendations_approved"] == 1
        assert result["scan_accuracy"]["recommendations_dismissed"] == 1
        assert result["scan_accuracy"]["approval_rate"] == 50
```

**Step 4: Run tests**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py::TestFeedbackWithDecisions -v`
Expected: PASS

**Step 5: Commit**

```bash
git add .context/project/patterns.yaml agents/context/ web/watchtower/test_scan.py
git commit -m "T-058: Add escalation fields to patterns, scan metadata to decisions"
```

---

## Task 8: Integration Tests + Polish

**Files:**
- Modify: `web/watchtower/test_scan.py` — add end-to-end integration tests
- Modify: `web/test_app.py` — verify no regressions
- Create: `.context/scans/.gitignore` — ignore ephemeral scan files

**Context:** Verify the full cycle works: scan → cockpit renders → controls work → re-scan reflects changes. Also verify performance (<3s), error handling (scan fails gracefully), and that existing tests still pass.

**Step 1: Write integration tests**

```python
# Append to web/watchtower/test_scan.py

class TestIntegration:
    """End-to-end integration tests."""

    def test_scan_then_rescan_shows_delta(self, project):
        """Two scans should show changes_since_last_scan."""
        from web.watchtower.scanner import scan

        # First scan
        result1 = scan(project_root=project, framework_root=project)
        assert result1["changes_since_last_scan"].get("first_scan") is True

        # Second scan (should detect delta)
        result2 = scan(project_root=project, framework_root=project)
        assert "first_scan" not in result2["changes_since_last_scan"]

    def test_scan_performance(self, project):
        """Scan should complete in under 3 seconds."""
        import time
        from web.watchtower.scanner import scan

        start = time.time()
        scan(project_root=project, framework_root=project)
        elapsed = time.time() - start
        assert elapsed < 3.0, f"Scan took {elapsed:.1f}s (budget: 3s)"

    def test_scan_with_corrupt_yaml(self, project):
        """Scan should handle corrupt YAML gracefully."""
        from web.watchtower.scanner import scan

        # Corrupt a YAML file
        (project / ".context" / "project" / "patterns.yaml").write_text(
            "invalid: yaml: [unterminated"
        )

        result = scan(project_root=project, framework_root=project)
        # Should still produce output (partial or complete)
        assert result["scan_id"].startswith("SC-")

    def test_all_output_ids_unique(self, project):
        """All recommendation IDs should be unique within a scan."""
        from web.watchtower.scanner import scan
        result = scan(project_root=project, framework_root=project)

        all_ids = []
        for section in ("needs_decision", "framework_recommends", "opportunities"):
            for item in result.get(section, []):
                all_ids.append(item.get("id"))

        assert len(all_ids) == len(set(all_ids)), "Duplicate IDs found"
```

**Step 2: Run ALL tests**

Run: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/watchtower/test_scan.py web/test_app.py -v`
Expected: All PASS

**Step 3: Add .gitignore for scans**

```gitignore
# .context/scans/.gitignore
# Scan results are ephemeral — re-derivable from project state
SC-*.yaml
LATEST.yaml
```

**Step 4: Visual verification**

Start the web server and verify the cockpit renders:
1. Run: `fw scan` to generate scan data
2. Open `http://localhost:3000/` in browser
3. Verify: cockpit shows Needs Decision (amber), Framework Recommends (blue), Work Direction, System Health
4. Verify: clicking Refresh triggers a new scan
5. Verify: without scan data, fallback dashboard appears

Run: `fw serve --port 3001` (if 3000 is in use) and use Playwright to screenshot.

**Step 5: Final commit**

```bash
git add web/watchtower/test_scan.py .context/scans/.gitignore
git commit -m "T-058: Add integration tests, scan gitignore, Phase 4a+4b complete"
```

---

## Summary

| Task | Description | New Files | Modified Files |
|------|-------------|-----------|----------------|
| 1 | Scan engine foundation | `web/watchtower/{__init__,scanner,test_scan}.py` | — |
| 2 | Challenge detection rules | `web/watchtower/rules.py` | `test_scan.py` |
| 3 | Prioritizer + feedback | `web/watchtower/{prioritizer,feedback}.py` | `test_scan.py` |
| 4 | CLI + context init | `web/watchtower/__main__.py` | `bin/fw`, `agents/context/lib/init.sh` |
| 5 | Cockpit UI | `web/blueprints/cockpit.py`, `web/templates/cockpit.html` | `core.py`, `app.py`, `test_app.py` |
| 6 | Agent integration | — | `agents/resume/` |
| 7 | Data model + feedback | — | `patterns.yaml`, `agents/context/` |
| 8 | Integration + polish | `.context/scans/.gitignore` | `test_scan.py` |

**Total new files:** 8
**Total modified files:** ~10
**Estimated new code:** ~1500 lines (Python + HTML)
**Test coverage:** 1 test per rule minimum, integration tests, performance test
