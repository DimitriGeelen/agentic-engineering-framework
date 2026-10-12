"""T-4127 - codex round 2 on hotfix v1.8.10: the Watchtower decision commit must leave no
window in which an ordinary commit can revert it.

The scratch-GIT_INDEX_FILE design advanced HEAD first and refreshed the real index
afterwards; a commit in between used the stale real index and wrote the old blobs back.
The decision now commits through git's REAL index (`git commit --only -- paths`), which
holds .git/index.lock from before the tree is built until after the ref moved. All
fixtures are temp repos.
"""
import importlib
import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TASK_ID = "T-9300"
ACTIVE = f".tasks/active/{TASK_ID}-decide-me.md"
COMPLETED = f".tasks/completed/{TASK_ID}-decide-me.md"
STARTED = f"---\nid: {TASK_ID}\nstatus: started-work\nworkflow_type: inception\n---\n# {TASK_ID}\n"
DECIDED = (f"---\nid: {TASK_ID}\nstatus: work-completed\nworkflow_type: inception\n---\n"
           f"# {TASK_ID}\n\n## Decision\n\n**Decision**: GO\n\n**Rationale**: approved\n")


def _git(repo, *args, check=True):
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, timeout=30)
    if check:
        assert r.returncode == 0, f"git {' '.join(args)}: {r.stderr or r.stdout}"
    return r


def _build(tmp_path, monkeypatch, use_git_mv):
    for d in (".tasks/active", ".tasks/completed", ".context/working"):
        (tmp_path / d).mkdir(parents=True)
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "t@t")
    _git(tmp_path, "config", "user.name", "t")
    _git(tmp_path, "config", "commit.gpgsign", "false")
    (tmp_path / ACTIVE).write_text(STARTED)
    (tmp_path / "other.txt").write_text("0\n")
    (tmp_path / "inflight.txt").write_text("0\n")
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-qm", "seed")
    (tmp_path / ACTIVE).write_text(DECIDED)
    if use_git_mv:
        _git(tmp_path, "mv", ACTIVE, COMPLETED)
    else:  # plain mv: new path untracked, old path deleted in the working tree only
        os.rename(tmp_path / ACTIVE, tmp_path / COMPLETED)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.inception)
    return web.blueprints.inception


@pytest.fixture(params=["git-mv", "plain-mv"])
def repo(request, tmp_path, monkeypatch):
    inc = _build(tmp_path, monkeypatch, request.param == "git-mv")
    return tmp_path, inc


def _kept(path):
    assert "**Decision**: GO" in _git(path, "show", f"HEAD:{COMPLETED}").stdout
    assert _git(path, "ls-tree", "-r", "--name-only", "HEAD", "--", ".tasks/active").stdout.strip() == ""


def _ordinary_commit(path):
    (path / "other.txt").write_text("1\n")
    _git(path, "add", "other.txt")
    _git(path, "commit", "-qm", "unrelated")


def test_competing_commit_right_after_the_decision_commit_cannot_revert_it(repo, monkeypatch):
    """Codex finding 1: inject an ordinary commit at the earliest point after Watchtower's
    `git commit` returns - where the old design still had a stale real index."""
    path, inc = repo
    real_run = subprocess.run
    fired = []

    def run(cmd, *a, **kw):
        r = real_run(cmd, *a, **kw)
        if (isinstance(cmd, list) and cmd[:2] == ["git", "commit"]
                and "inception decision" in " ".join(cmd) and not fired):
            fired.append(1)
            _ordinary_commit(path)
        return r

    monkeypatch.setattr(subprocess, "run", run)
    ok, msg = inc._commit_decision(TASK_ID, "go")
    monkeypatch.setattr(subprocess, "run", real_run)
    assert ok, msg
    assert fired, "the injection point never fired"
    _kept(path)


def test_ordinary_commit_attempted_inside_the_decision_commit_is_refused_by_git(repo):
    """The lock is held for the whole decision commit: a commit started from inside its
    pre-commit hook (i.e. mid-commit) cannot take the index and fails."""
    path, inc = repo
    hook = path / ".git" / "hooks" / "pre-commit"
    probe = path / "probe.out"
    hook.write_text(
        "#!/bin/sh\n"
        "case \"$(git log -1 --format=%s 2>/dev/null)\" in 'competing') exit 0;; esac\n"
        "[ -f probe.done ] && exit 0\n"
        f"env -u GIT_INDEX_FILE git commit -qm competing --allow-empty >/dev/null 2>&1; echo $? > {probe}\n"
        "touch probe.done\n")
    hook.chmod(0o755)
    ok, msg = inc._commit_decision(TASK_ID, "go")
    assert ok, msg
    assert probe.read_text().strip() != "0", "a competing commit succeeded mid-decision-commit"
    _kept(path)


def test_other_staged_work_is_neither_swept_in_nor_lost(repo):
    path, inc = repo
    (path / "inflight.txt").write_text("1\n")
    _git(path, "add", "inflight.txt")
    ok, msg = inc._commit_decision(TASK_ID, "go")
    assert ok, msg
    assert _git(path, "diff", "--cached", "--name-only").stdout.split() == ["inflight.txt"]
    assert "inflight.txt" not in _git(path, "show", "--name-only", "--format=", "HEAD").stdout
    assert _git(path, "log", "-1", "--format=%s").stdout.strip() == \
        f"{TASK_ID}: inception decision GO (via Watchtower)"
    _ordinary_commit(path)
    _kept(path)
    assert _git(path, "status", "--porcelain", "--", ".tasks").stdout.strip() == ""


def test_held_index_lock_fails_visibly_and_loses_nothing(repo, monkeypatch):
    import time
    path, inc = repo
    monkeypatch.setattr(time, "sleep", lambda s: None)
    lock = path / ".git" / "index.lock"
    lock.write_text("")
    try:
        ok, msg = inc._commit_decision(TASK_ID, "go")
    finally:
        lock.unlink()
    assert not ok and msg, (ok, msg)
    assert (path / COMPLETED).read_text() == DECIDED  # working tree untouched
    ok, msg = inc._commit_decision(TASK_ID, "go", followup=True)  # retry after release
    assert ok, msg
    _kept(path)


def test_stale_real_index_with_decision_already_in_head_is_healed(repo, tmp_path):
    """Follow-up heal: HEAD holds the decision (committed by the pre-T-4127 scratch path)
    but the real index still has the old blobs."""
    path, inc = repo
    env = {**os.environ, "GIT_INDEX_FILE": str(tmp_path.parent / f"scratch-{path.name}")}
    for cmd in (["read-tree", "HEAD"], ["add", "--", ACTIVE, COMPLETED],
                ["commit", "-qm", "scratch commit"]):
        r = subprocess.run(["git", *cmd], cwd=path, env=env, capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
    ok, msg = inc._commit_decision(TASK_ID, "go", followup=True)
    assert ok, msg
    _ordinary_commit(path)
    _kept(path)
