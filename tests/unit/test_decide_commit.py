"""T-2053 — the Watchtower decide handler must commit the recorded decision.

`fw inception decide` writes the `## Decision` block, moves the task file
(active→completed for GO/NO-GO) and generates the episodic, but does NOT
git-commit — the CLI relies on the agent's commit-cadence. The Watchtower path
has no agent follow-up, so without `_commit_decision` every Watchtower decision
is left as uncommitted working-tree changes (T-2030).

These tests pin `_commit_decision` / `_is_decision_file`:
  - success → ONE commit referencing T-XXX containing only the decision's own
    files (task md + episodic, including the active→completed deletion); unrelated
    churn is left uncommitted and never `git add -A`'d
  - commit failure (a commit-msg hook rejects) → returns (False, msg), no
    exception, HEAD unchanged

Tests run against a throwaway git repo (no dependency on the framework repo).
"""

import importlib
import subprocess
from pathlib import Path

import pytest


def _git(*args, cwd):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def _init_repo(tmp: Path) -> Path:
    _git("init", "-q", cwd=tmp)
    _git("config", "user.email", "t@example.com", cwd=tmp)
    _git("config", "user.name", "Test", cwd=tmp)
    (tmp / ".tasks" / "active").mkdir(parents=True)
    (tmp / ".tasks" / "completed").mkdir(parents=True)
    (tmp / ".context" / "episodic").mkdir(parents=True)
    active = tmp / ".tasks" / "active" / "T-9100-x.md"
    active.write_text("---\nid: T-9100\nstatus: started-work\n---\n# T-9100\n")
    _git("add", "-A", cwd=tmp)
    _git("commit", "-q", "-m", "baseline", cwd=tmp)
    return active


def _simulate_decide(tmp: Path, active: Path):
    """Mirror what `fw inception decide` leaves on disk for a GO: the task file
    moved active→completed (filesystem mv) + a generated episodic + unrelated churn."""
    completed = tmp / ".tasks" / "completed" / "T-9100-x.md"
    active.rename(completed)
    completed.write_text(completed.read_text() + "\n## Decision\n\n**Decision**: GO\n")
    (tmp / ".context" / "episodic" / "T-9100.yaml").write_text("id: T-9100\n")
    (tmp / "unrelated.txt").write_text("perpetual working-tree churn\n")


def _load_inception(tmp, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp))
    import web.shared
    import web.blueprints.inception as inc
    importlib.reload(web.shared)
    importlib.reload(inc)
    return inc


def test_is_decision_file(tmp_path, monkeypatch):
    inc = _load_inception(tmp_path, monkeypatch)
    assert inc._is_decision_file("T-9100", ".tasks/active/T-9100-x.md")
    assert inc._is_decision_file("T-9100", ".tasks/completed/T-9100-foo-bar.md")
    assert inc._is_decision_file("T-9100", ".context/episodic/T-9100.yaml")
    assert inc._is_decision_file("T-9100", ".context/episodic/T-9100-defer.yaml")
    # Not the decision's files:
    assert not inc._is_decision_file("T-9100", "unrelated.txt")
    assert not inc._is_decision_file("T-9100", ".tasks/active/T-9101-x.md")
    assert not inc._is_decision_file("T-9100", ".context/working/focus.yaml")


def test_commit_decision_success_scoped(tmp_path, monkeypatch):
    active = _init_repo(tmp_path)
    _simulate_decide(tmp_path, active)
    inc = _load_inception(tmp_path, monkeypatch)

    committed, msg = inc._commit_decision("T-9100", "go")
    assert committed is True
    assert "T-9100" in msg

    head = _git("log", "-1", "--pretty=%s", cwd=tmp_path).stdout.strip()
    assert head.startswith("T-9100:")
    assert "GO" in head

    # --no-renames so the active→completed move shows as explicit D + A (git
    # otherwise collapses it to a rename and lists only the destination).
    files = _git("show", "--no-renames", "--name-only", "--pretty=format:", "HEAD",
                 cwd=tmp_path).stdout.split()
    assert ".tasks/completed/T-9100-x.md" in files
    assert ".context/episodic/T-9100.yaml" in files
    assert ".tasks/active/T-9100-x.md" in files  # deletion recorded
    assert "unrelated.txt" not in files          # churn NOT swept in

    # The active file is gone from the committed tree.
    assert _git("cat-file", "-e", "HEAD:.tasks/active/T-9100-x.md", cwd=tmp_path).returncode != 0

    # The churn file is still dirty (never committed).
    st = _git("status", "--porcelain", cwd=tmp_path).stdout
    assert "unrelated.txt" in st


def test_commit_decision_failure_graceful(tmp_path, monkeypatch):
    active = _init_repo(tmp_path)
    # A commit-msg hook that always rejects (e.g. a real gate refusing the commit).
    hookdir = tmp_path / ".git" / "hooks"
    hookdir.mkdir(parents=True, exist_ok=True)
    hook = hookdir / "commit-msg"
    hook.write_text("#!/bin/sh\necho 'blocked by test hook' >&2\nexit 1\n")
    hook.chmod(0o755)

    _simulate_decide(tmp_path, active)
    inc = _load_inception(tmp_path, monkeypatch)

    committed, msg = inc._commit_decision("T-9100", "go")
    assert committed is False
    assert msg  # a non-empty failure reason, no exception raised

    # HEAD is untouched — still the baseline commit.
    head = _git("log", "-1", "--pretty=%s", cwd=tmp_path).stdout.strip()
    assert head == "baseline"
