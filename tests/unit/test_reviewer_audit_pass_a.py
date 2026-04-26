"""Unit tests for lib/reviewer/audit.py --pass-a corpus drift mode (T-1485 v1.5c).

Tiny ad-hoc fixture repos verify the corpus-level baseline init and drift
scan logic without touching the real .tasks/completed/ directory.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer.audit import (  # noqa: E402
    run_pass_a_baseline,
    run_pass_a_drift,
    write_audit_yaml,
)
from lib.reviewer.drift import read_baseline  # noqa: E402


def _setup_repo(tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    (repo / ".tasks" / "completed").mkdir(parents=True)
    return repo


def _write_completed_task(
    repo: Path,
    task_id: str,
    verification: str,
    files: dict[str, str],
    with_verdict: bool = True,
) -> Path:
    """Create files + a completed task .md (with optional `## Reviewer Verdict` block)."""
    for rel, content in files.items():
        full = repo / rel
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(content)
    verdict_block = ""
    if with_verdict:
        verdict_block = "\n\n## Reviewer Verdict (v1.4)\n\n- Overall: PASS\n"
    body = f"""---
id: {task_id}
name: test
status: work-completed
---

## Verification

{verification}{verdict_block}
"""
    p = repo / ".tasks" / "completed" / f"{task_id}-test.md"
    p.write_text(body)
    return p


# ───────────────── baseline init ─────────────────


def test_pass_a_baseline_writes_marker(tmp_path):
    repo = _setup_repo(tmp_path)
    tp = _write_completed_task(repo, "T-9001", "test -f keep.txt", {"keep.txt": "hi"})

    summary = run_pass_a_baseline(repo)

    assert summary["mode"] == "pass-a-baseline"
    assert summary["totals"]["written"] == 1
    base = read_baseline(tp.read_text())
    assert "keep.txt" in base
    assert base["keep.txt"] != ""


def test_pass_a_baseline_idempotent_without_force(tmp_path):
    repo = _setup_repo(tmp_path)
    tp = _write_completed_task(repo, "T-9002", "test -f a.txt", {"a.txt": "v1"})
    run_pass_a_baseline(repo)
    first_baseline = read_baseline(tp.read_text())

    # Mutate the file then re-run baseline without --force → should NOT overwrite
    (repo / "a.txt").write_text("v2")
    summary2 = run_pass_a_baseline(repo)
    assert summary2["totals"]["written"] == 0
    assert summary2["totals"]["skipped_existing"] == 1
    assert read_baseline(tp.read_text()) == first_baseline


def test_pass_a_baseline_force_overwrites(tmp_path):
    repo = _setup_repo(tmp_path)
    tp = _write_completed_task(repo, "T-9003", "test -f a.txt", {"a.txt": "v1"})
    run_pass_a_baseline(repo)
    first_baseline = read_baseline(tp.read_text())

    (repo / "a.txt").write_text("v2")
    summary2 = run_pass_a_baseline(repo, force=True)
    assert summary2["totals"]["written"] == 1
    assert read_baseline(tp.read_text()) != first_baseline


def test_pass_a_baseline_skips_no_verification(tmp_path):
    repo = _setup_repo(tmp_path)
    body = """---
id: T-9004
name: test
status: work-completed
---

# No verification section here.
"""
    (repo / ".tasks" / "completed" / "T-9004-test.md").write_text(body)

    summary = run_pass_a_baseline(repo)
    assert summary["totals"]["skipped_no_verification"] == 1
    assert summary["totals"]["written"] == 0


# ───────────────── drift scan ─────────────────


def test_pass_a_drift_stable_when_unchanged(tmp_path):
    repo = _setup_repo(tmp_path)
    _write_completed_task(repo, "T-9010", "test -f keep.txt", {"keep.txt": "hi"})
    run_pass_a_baseline(repo)

    summary = run_pass_a_drift(repo)
    assert summary["totals"]["STABLE"] == 1
    assert summary["totals"]["DRIFTED"] == 0


def test_pass_a_drift_detects_change(tmp_path):
    repo = _setup_repo(tmp_path)
    _write_completed_task(repo, "T-9011", "test -f a.txt", {"a.txt": "v1"})
    run_pass_a_baseline(repo)

    # Now mutate the referenced file
    (repo / "a.txt").write_text("v2-different")

    summary = run_pass_a_drift(repo)
    assert summary["totals"]["DRIFTED"] == 1
    assert summary["totals"]["STABLE"] == 0
    row = summary["per_task"][0]
    assert row["verdict"] == "DRIFTED"
    assert row["n_changed"] == 1
    assert "a.txt" in row["changed_files"]


def test_pass_a_drift_no_baseline_counted_separately(tmp_path):
    repo = _setup_repo(tmp_path)
    _write_completed_task(repo, "T-9012", "test -f keep.txt", {"keep.txt": "hi"})

    summary = run_pass_a_drift(repo)
    assert summary["totals"]["NO-BASELINE"] == 1
    assert summary["totals"]["STABLE"] == 0
    assert summary["totals"]["DRIFTED"] == 0


def test_pass_a_drift_no_verification_counted_separately(tmp_path):
    repo = _setup_repo(tmp_path)
    body = """---
id: T-9013
name: test
status: work-completed
---

# No verification.
"""
    (repo / ".tasks" / "completed" / "T-9013-test.md").write_text(body)

    summary = run_pass_a_drift(repo)
    assert summary["totals"]["NO-VERIFICATION"] == 1


def test_pass_a_drift_limit_caps_tasks(tmp_path):
    repo = _setup_repo(tmp_path)
    for i, tid in enumerate(("T-9020", "T-9021", "T-9022")):
        _write_completed_task(repo, tid, "test -f f.txt", {"f.txt": f"v{i}"})

    summary = run_pass_a_drift(repo, limit=2)
    assert summary["tasks_scanned"] == 2
    assert summary["limit"] == 2


def test_pass_a_drift_yaml_round_trip(tmp_path):
    repo = _setup_repo(tmp_path)
    _write_completed_task(repo, "T-9030", "test -f a.txt", {"a.txt": "x"})
    run_pass_a_baseline(repo)

    summary = run_pass_a_drift(repo)
    out = write_audit_yaml(repo, summary, suffix="-pass-a")
    loaded = yaml.safe_load(out.read_text())

    assert loaded["mode"] == "pass-a"
    assert loaded["tasks_scanned"] == 1
    for key in ("scan_date", "scan_timestamp", "mode", "tasks_scanned",
                "totals", "errors", "per_task", "limit"):
        assert key in loaded


def test_pass_a_baseline_yaml_round_trip(tmp_path):
    repo = _setup_repo(tmp_path)
    _write_completed_task(repo, "T-9040", "test -f a.txt", {"a.txt": "x"})

    summary = run_pass_a_baseline(repo)
    out = write_audit_yaml(repo, summary, suffix="-pass-a-baseline")
    loaded = yaml.safe_load(out.read_text())

    assert loaded["mode"] == "pass-a-baseline"
    assert loaded["totals"]["written"] == 1
    assert loaded["force"] is False
