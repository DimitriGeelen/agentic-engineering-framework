"""T-4081 / G-114 — a Watchtower decision commit must not be reverted by the next commit.

`_commit_decision` commits through a scratch GIT_INDEX_FILE and advances HEAD. Before
the fix the real .git/index kept the pre-decision blobs for the decision paths, so the
next ordinary `git add other && git commit` wrote them back and reverted the decision
(working tree kept it, uncommitted). All fixtures are temp repos; no hooks installed,
so the load-bearing assertions are made on the committed tree and on `git ls-files -s`.
"""
import importlib
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TASK_ID = "T-9200"
ACTIVE = f".tasks/active/{TASK_ID}-decide-me.md"
COMPLETED = f".tasks/completed/{TASK_ID}-decide-me.md"
DECIDED = (f"---\nid: {TASK_ID}\nstatus: work-completed\nworkflow_type: inception\n---\n"
           f"# {TASK_ID}\n\n## Decision\n\n**Decision**: GO\n\n**Rationale**: approved\n")


def _git(repo, *args):
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, f"git {' '.join(args)}: {r.stderr or r.stdout}"
    return r.stdout


def _init(tmp_path):
    for d in (".tasks/active", ".tasks/completed", ".context/working"):
        (tmp_path / d).mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "t@t")
    _git(tmp_path, "config", "user.name", "t")
    _git(tmp_path, "config", "commit.gpgsign", "false")


@pytest.fixture
def repo(tmp_path, monkeypatch):
    _init(tmp_path)
    (tmp_path / ACTIVE).write_text(
        f"---\nid: {TASK_ID}\nstatus: started-work\nworkflow_type: inception\n---\n# {TASK_ID}\n")
    (tmp_path / "other.txt").write_text("0\n")
    (tmp_path / "inflight.txt").write_text("0\n")
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-qm", "seed")
    # what `fw inception decide` leaves: decision written, then git mv to completed/
    (tmp_path / ACTIVE).write_text(DECIDED)
    _git(tmp_path, "mv", ACTIVE, COMPLETED)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.inception)
    yield tmp_path, web.blueprints.inception


def test_next_ordinary_commit_does_not_revert_the_decision(repo):
    path, inc = repo
    ok, msg = inc._commit_decision(TASK_ID, "go")
    assert ok, msg
    (path / "other.txt").write_text("1\n")
    _git(path, "add", "other.txt")
    _git(path, "commit", "-qm", "unrelated")
    assert "**Decision**: GO" in _git(path, "show", f"HEAD:{COMPLETED}")
    assert _git(path, "status", "--porcelain", "--", ".tasks").strip() == ""


def test_real_index_matches_head_for_decision_paths_only(repo):
    path, inc = repo
    (path / "inflight.txt").write_text("1\n")
    _git(path, "add", "inflight.txt")  # other in-flight work, staged before the decision
    ok, msg = inc._commit_decision(TASK_ID, "go")
    assert ok, msg
    assert _git(path, "diff", "--cached", "--name-only").split() == ["inflight.txt"]
    assert _git(path, "ls-files", "--", ".tasks/active").strip() == ""


def test_detector_names_a_reverted_decision_and_clears_when_kept(repo):
    path, inc = repo
    ok, _ = inc._commit_decision(TASK_ID, "go")
    assert ok
    det = REPO_ROOT / "lib" / "watchtower_decision_revert.py"

    def run():
        return subprocess.run([sys.executable, "-I", str(det), "--repo", str(path)],
                              capture_output=True, text=True)

    r = run()
    assert r.returncode == 0, r.stdout
    # simulate the pre-fix failure: a later commit writes the old blob back
    (path / COMPLETED).write_text(DECIDED.replace("**Decision**: GO", ""))
    _git(path, "commit", "-qam", "revert by stale index")
    r = run()
    assert r.returncode == 2 and f"REVERTED {TASK_ID}" in r.stdout, r.stdout


# T-4112 — codex DO-NOT-SHIP on hotfix v1.8.10: the refresh ignored git's exit code, so a
# held .git/index.lock made it a silent no-op and the next commit reverted the decision.

def test_held_index_lock_is_surfaced_not_a_silent_success(repo, monkeypatch):
    import time
    path, inc = repo
    monkeypatch.setattr(time, "sleep", lambda s: None)  # exhaust the retries instantly
    lock = path / ".git" / "index.lock"
    real_reset = inc._refresh_real_index

    def reset_with_lock_held(paths):
        lock.write_text("")  # a concurrent git command that never lets go
        try:
            return real_reset(paths)
        finally:
            lock.unlink()

    inc._refresh_real_index = reset_with_lock_held
    try:
        ok, msg = inc._commit_decision(TASK_ID, "go")
    finally:
        inc._refresh_real_index = real_reset
    assert not ok, msg
    assert "NOT refreshed" in msg and "git reset -q -- " in msg and COMPLETED in msg, msg
    assert "**Decision**: GO" in _git(path, "show", f"HEAD:{COMPLETED}")  # it IS committed

    # the runner's follow-up commit heals the index; then the next commit keeps the decision
    ok, msg = inc._commit_decision(TASK_ID, "go", followup=True)
    assert ok, msg
    (path / "other.txt").write_text("1\n")
    _git(path, "add", "other.txt")
    _git(path, "commit", "-qm", "unrelated")
    assert "**Decision**: GO" in _git(path, "show", f"HEAD:{COMPLETED}")


def test_lock_released_during_retries_keeps_the_decision(repo):
    import threading
    path, inc = repo
    lock = path / ".git" / "index.lock"
    real_reset = inc._refresh_real_index
    timer = threading.Timer(0.3, lock.unlink)

    def reset_while_lock_briefly_held(paths):
        lock.write_text("")
        timer.start()  # contention clears mid-retry
        return real_reset(paths)

    inc._refresh_real_index = reset_while_lock_briefly_held
    try:
        ok, msg = inc._commit_decision(TASK_ID, "go")
    finally:
        inc._refresh_real_index = real_reset
    assert ok, msg
    timer.join()  # whatever happened, the lock is gone before the next commit
    (path / "other.txt").write_text("1\n")
    _git(path, "add", "other.txt")
    _git(path, "commit", "-qm", "unrelated")
    assert "**Decision**: GO" in _git(path, "show", f"HEAD:{COMPLETED}")
    assert _git(path, "status", "--porcelain", "--", ".tasks").strip() == ""
