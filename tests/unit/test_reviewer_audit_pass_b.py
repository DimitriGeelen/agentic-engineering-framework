"""Unit tests for lib/reviewer/audit.py --pass-b corpus mode (T-1484 v1.5b).

Builds a tiny fixture repo with two completed tasks (one PASS, one FAIL) and
verifies that `run_pass_b_reverify` produces a correctly-shaped summary,
respects --limit, counts NO-VERIFICATION separately, writes a stable YAML,
and reuses a single WorktreePool across tasks.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer.audit import (  # noqa: E402
    run_pass_b_reverify,
    write_audit_yaml,
)


def _git(args: list[str], cwd: Path) -> str:
    return subprocess.check_output(["git", *args], cwd=cwd, text=True).strip()


def _commit(repo: Path, msg: str) -> str:
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", msg], cwd=repo, check=True)
    return _git(["rev-parse", "HEAD"], repo)


def _init_repo(repo: Path) -> None:
    repo.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
    (repo / ".tasks").mkdir()
    (repo / ".tasks" / "completed").mkdir()
    (repo / "README.md").write_text("seed\n")
    _commit(repo, "seed: initial")


def _write_completed_task(repo: Path, task_id: str, verification: str, files: dict[str, str]) -> str:
    """Create files + completed task .md + commit. Returns completion SHA."""
    for rel, content in files.items():
        full = repo / rel
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(content)
    body = f"""---
id: {task_id}
name: test
status: work-completed
---

## Verification

{verification}
"""
    task_path = repo / ".tasks" / "completed" / f"{task_id}-test.md"
    task_path.write_text(body)
    return _commit(repo, f"{task_id}: complete")


# ───────────────── core summary ─────────────────


def test_pass_b_corpus_pass_and_fail(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo)
    _write_completed_task(repo, "T-9001", "test -f keep.txt", {"keep.txt": "hi"})
    _write_completed_task(repo, "T-9002", "test -f does-not-exist.txt", {"other.txt": "x"})

    summary = run_pass_b_reverify(repo)

    assert summary["mode"] == "pass-b"
    assert summary["tasks_scanned"] == 2
    t = summary["totals"]
    assert t["PASS"] == 1
    assert t["FAIL"] == 1
    assert t["ERROR"] == 0

    rows = {r["task_id"]: r for r in summary["per_task"]}
    assert rows["T-9001"]["overall"] == "PASS"
    assert rows["T-9001"]["n_pass"] == 1
    assert rows["T-9002"]["overall"] == "FAIL"
    assert rows["T-9002"]["n_fail"] == 1


def test_pass_b_no_verification_section_counted_separately(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo)
    body = """---
id: T-9003
name: test
status: work-completed
---

# No verification section.
"""
    (repo / ".tasks" / "completed" / "T-9003-test.md").write_text(body)
    _commit(repo, "T-9003: complete")

    summary = run_pass_b_reverify(repo)
    assert summary["totals"]["NO-VERIFICATION"] == 1
    assert summary["totals"]["FAIL"] == 0


def test_pass_b_limit_caps_tasks(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo)
    _write_completed_task(repo, "T-9010", "test 1 = 1", {})
    _write_completed_task(repo, "T-9011", "test 1 = 1", {})
    _write_completed_task(repo, "T-9012", "test 1 = 1", {})

    summary = run_pass_b_reverify(repo, limit=2)
    assert summary["tasks_scanned"] == 2
    assert summary["limit"] == 2


def test_pass_b_skips_network_lines(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo)
    _write_completed_task(
        repo,
        "T-9020",
        "curl http://localhost:9999/never\ntest -f keep.txt",
        {"keep.txt": "hi"},
    )

    summary = run_pass_b_reverify(repo)
    row = summary["per_task"][0]
    assert row["n_skipped"] == 1
    assert row["n_pass"] == 1
    assert row["overall"] == "PASS"


def test_pass_b_unknown_completion_sha_is_error(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo)
    # Task file references an ID with no matching commit
    body = """---
id: T-XXXX
name: test
status: work-completed
---

## Verification

test 1 = 1
"""
    (repo / ".tasks" / "completed" / "T-XXXX-test.md").write_text(body)
    _commit(repo, "seed: unrelated commit")  # no matching grep

    summary = run_pass_b_reverify(repo)
    row = summary["per_task"][0]
    assert row["overall"] == "FAIL"
    assert row["error"] is not None


# ───────────────── YAML output ─────────────────


def test_write_audit_yaml_pass_b_suffix(tmp_path):
    summary = {
        "scan_date": "2026-04-26",
        "mode": "pass-b",
        "tasks_scanned": 0,
        "totals": {"PASS": 0, "FAIL": 0, "NO-VERIFICATION": 0, "ERROR": 0},
        "per_task": [],
        "errors": [],
    }
    out = write_audit_yaml(tmp_path, summary, suffix="-pass-b")
    assert out.name == "2026-04-26-pass-b.yaml"
    loaded = yaml.safe_load(out.read_text())
    assert loaded["mode"] == "pass-b"


def test_pass_b_summary_yaml_round_trip(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo)
    _write_completed_task(repo, "T-9030", "test -f keep.txt", {"keep.txt": "x"})

    summary = run_pass_b_reverify(repo)
    out = write_audit_yaml(repo, summary, suffix="-pass-b")
    loaded = yaml.safe_load(out.read_text())

    assert loaded["mode"] == "pass-b"
    assert loaded["tasks_scanned"] == 1
    assert loaded["per_task"][0]["task_id"] == "T-9030"
    assert loaded["per_task"][0]["overall"] == "PASS"
    # required schema keys
    for key in ("scan_date", "scan_timestamp", "mode", "tasks_scanned",
                "totals", "errors", "per_task", "limit", "timeout_per_line"):
        assert key in loaded


# ───────────────── pool reuse ─────────────────


def test_pass_b_reuses_single_worktree(tmp_path, monkeypatch):
    """WorktreePool.__enter__ should be invoked exactly once per audit run."""
    repo = tmp_path / "repo"
    _init_repo(repo)
    for tid in ("T-9040", "T-9041", "T-9042"):
        _write_completed_task(repo, tid, "test 1 = 1", {})

    enter_count = {"n": 0}
    from lib.reviewer import reverify as reverify_mod

    real_enter = reverify_mod.WorktreePool.__enter__

    def counting_enter(self):
        enter_count["n"] += 1
        return real_enter(self)

    monkeypatch.setattr(reverify_mod.WorktreePool, "__enter__", counting_enter)

    summary = run_pass_b_reverify(repo)
    assert summary["tasks_scanned"] == 3
    assert enter_count["n"] == 1, "WorktreePool must be entered once per audit run"


def test_pass_b_no_leaked_worktree_after_run(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo)
    _write_completed_task(repo, "T-9050", "test -f keep.txt", {"keep.txt": "x"})

    run_pass_b_reverify(repo)

    # The pool's ephemeral path is /tmp/fw-reviewer-wt-{pid} — verify it's gone.
    leaked = Path(f"/tmp/fw-reviewer-wt-{os.getpid()}")
    assert not leaked.exists(), f"Worktree leaked at {leaked}"
