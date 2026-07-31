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


def test_commit_decision_batched_decisions_both_commit(tmp_path, monkeypatch):
    """T-2708 regression: two decisions recorded seconds apart in one operator
    batch must both commit. Reproduces the RCA's failure mode deterministically:
    T-9101's decision files are already staged in the REAL index (standing in
    for a concurrent Watchtower request's `git add`, or residue from a prior
    failed attempt — see RCA "Why it cannot self-clear") when T-9100's decision
    is committed. The pre-fix implementation reads/writes the real index, so it
    sees T-9101's staged files as "foreign" and refuses T-9100 — leaving only
    one of the two decisions committed. The fix never reads the real index, so
    T-9100 commits regardless of what's staged there."""
    active_a = _init_repo(tmp_path)
    active_b = tmp_path / ".tasks" / "active" / "T-9101-y.md"
    active_b.write_text("---\nid: T-9101\nstatus: started-work\n---\n# T-9101\n")
    _git("add", "-A", cwd=tmp_path)
    _git("commit", "-q", "-m", "baseline-2", cwd=tmp_path)

    _simulate_decide(tmp_path, active_a)
    completed_b = tmp_path / ".tasks" / "completed" / "T-9101-y.md"
    active_b.rename(completed_b)
    completed_b.write_text(completed_b.read_text() + "\n## Decision\n\n**Decision**: GO\n")
    (tmp_path / ".context" / "episodic" / "T-9101.yaml").write_text("id: T-9101\n")

    # Stand in for the other decision's in-flight `git add` landing first.
    _git("add", "--", ".tasks/completed/T-9101-y.md", ".context/episodic/T-9101.yaml",
         cwd=tmp_path)

    inc = _load_inception(tmp_path, monkeypatch)

    committed_a, msg_a = inc._commit_decision("T-9100", "go")
    committed_b, msg_b = inc._commit_decision("T-9101", "go")

    assert committed_a is True, msg_a
    assert committed_b is True, msg_b

    log = _git("log", "--oneline", cwd=tmp_path).stdout
    assert "T-9100:" in log
    assert "T-9101:" in log
    # Two decision commits landed on top of the two baseline commits.
    assert len(log.strip().splitlines()) == 4


def test_commit_decision_failure_leaves_index_untouched(tmp_path, monkeypatch):
    """T-2708 regression: a decision commit that fails must leave the operator's
    real index exactly as it found it — no staged residue that would poison the
    next decision. Pin this by pre-staging unrelated work, failing a decision
    commit, and asserting the real index's staged set is byte-identical after."""
    active = _init_repo(tmp_path)
    hookdir = tmp_path / ".git" / "hooks"
    hookdir.mkdir(parents=True, exist_ok=True)
    hook = hookdir / "commit-msg"
    hook.write_text("#!/bin/sh\necho 'blocked by test hook' >&2\nexit 1\n")
    hook.chmod(0o755)

    _simulate_decide(tmp_path, active)

    # Pre-existing unrelated staged work, as an agent session mid-commit-cadence
    # would leave behind.
    (tmp_path / "agent-in-progress.txt").write_text("agent session work in flight\n")
    _git("add", "agent-in-progress.txt", cwd=tmp_path)
    before = _git("diff", "--cached", "--name-only", cwd=tmp_path).stdout

    inc = _load_inception(tmp_path, monkeypatch)
    committed, msg = inc._commit_decision("T-9100", "go")
    assert committed is False
    assert msg

    after = _git("diff", "--cached", "--name-only", cwd=tmp_path).stdout
    assert after == before  # real index byte-identical: no residue from the failed attempt
    assert after.strip() == "agent-in-progress.txt"


def test_commit_decision_ignores_preexisting_staged_work(tmp_path, monkeypatch):
    """T-2708 regression: the property the old foreign-staged guard protected
    must survive the fix — pre-existing unrelated staged work is never swept
    into a decision commit, now enforced by construction (scratch index only
    ever receives `wanted` paths) rather than by refusal."""
    active = _init_repo(tmp_path)
    _simulate_decide(tmp_path, active)

    (tmp_path / "agent-in-progress.txt").write_text("agent session work in flight\n")
    _git("add", "agent-in-progress.txt", cwd=tmp_path)

    inc = _load_inception(tmp_path, monkeypatch)
    committed, msg = inc._commit_decision("T-9100", "go")
    assert committed is True, msg

    files = _git("show", "--no-renames", "--name-only", "--pretty=format:", "HEAD",
                 cwd=tmp_path).stdout.split()
    assert "agent-in-progress.txt" not in files

    # The unrelated file is still staged in the real index — untouched, not committed.
    staged = _git("diff", "--cached", "--name-only", cwd=tmp_path).stdout
    assert "agent-in-progress.txt" in staged
