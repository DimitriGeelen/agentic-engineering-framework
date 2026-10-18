"""T-4242 - a Watchtower decide left .git/index.lock (no holder) and a stale index.

dimitri-mint-dev, vendored 1.8.10, twice: the decision commit landed, .git/index.lock
stayed behind, and the real index kept the task file at its pre-decision blob and the
episodic staged as deleted, so the next plain commit would revert the GO.

Cause: git exports GIT_INDEX_FILE=<repo>/.git/index.lock to the hooks of `git commit -a`.
A Watchtower started from there handed it on, and the decide's git then used the lock
file AS its index. Every fixture here is a temp repo; nothing touches the live repo.
"""
import importlib
import os
import subprocess

import pytest

TASK_ID = "T-9420"
ACTIVE = f".tasks/active/{TASK_ID}-decide-me.md"
COMPLETED = f".tasks/completed/{TASK_ID}-decide-me.md"
EPISODIC = f".context/episodic/{TASK_ID}.yaml"
STARTED = f"---\nid: {TASK_ID}\nstatus: started-work\nworkflow_type: inception\n---\n"
DECIDED = (f"---\nid: {TASK_ID}\nstatus: work-completed\nworkflow_type: inception\n---\n"
           "\n## Decision\n\n**Decision**: GO\n")


def _clean():
    return {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}


def _git(repo, *args, check=True):
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True,
                       timeout=30, env=_clean())
    if check:
        assert r.returncode == 0, f"git {' '.join(args)}: {r.stderr or r.stdout}"
    return r


@pytest.fixture
def repo(tmp_path, monkeypatch):
    for d in (".tasks/active", ".tasks/completed", ".context/working", ".context/episodic"):
        (tmp_path / d).mkdir(parents=True)
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "t@t")
    _git(tmp_path, "config", "user.name", "t")
    _git(tmp_path, "config", "commit.gpgsign", "false")
    (tmp_path / ACTIVE).write_text(STARTED)
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-qm", "seed")
    # What the decide chain leaves: decision written, `git mv` to completed/, episodic.
    (tmp_path / ACTIVE).write_text(DECIDED)
    _git(tmp_path, "mv", ACTIVE, COMPLETED)
    (tmp_path / EPISODIC).write_text("task_id: T-9420\n")
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    return tmp_path, importlib.reload(web.blueprints.inception)


def _clean_after(path):
    assert not (path / ".git" / "index.lock").exists(), "stale .git/index.lock left behind"
    assert "**Decision**: GO" in _git(path, "show", f"HEAD:{COMPLETED}").stdout
    assert _git(path, "cat-file", "-e", f"HEAD:{EPISODIC}", check=False).returncode == 0
    # The real index agrees with HEAD: a plain commit now cannot revert anything.
    assert _git(path, "status", "--porcelain", "--", ".tasks", ".context/episodic").stdout == ""


def test_inherited_git_index_file_does_not_hijack_the_decision_commit(repo, monkeypatch):
    """The reported shape: GIT_INDEX_FILE points at .git/index.lock (as in a commit -a hook)."""
    path, inc = repo
    monkeypatch.setenv("GIT_INDEX_FILE", str(path / ".git" / "index.lock"))
    ok, msg = inc._commit_decision(TASK_ID, "go", followup=True)
    monkeypatch.delenv("GIT_INDEX_FILE")
    assert ok, msg
    _clean_after(path)


def test_inherited_git_dir_and_work_tree_are_ignored(repo, monkeypatch, tmp_path_factory):
    path, inc = repo
    other = tmp_path_factory.mktemp("elsewhere")
    _git(other, "init", "-q")
    monkeypatch.setenv("GIT_DIR", str(other / ".git"))
    monkeypatch.setenv("GIT_WORK_TREE", str(other))
    ok, msg = inc._commit_decision(TASK_ID, "go", followup=True)
    monkeypatch.delenv("GIT_DIR")
    monkeypatch.delenv("GIT_WORK_TREE")
    assert ok, msg
    _clean_after(path)
    assert _git(other, "rev-parse", "--verify", "-q", "HEAD", check=False).returncode != 0


def test_index_out_of_step_with_head_after_the_commit_is_refused_loudly(repo):
    """Whatever puts the real index back after the commit, the decide must not report success."""
    path, inc = repo
    hook = path / ".git" / "hooks" / "post-commit"
    hook.write_text("#!/bin/sh\n"
                    f"env -u GIT_INDEX_FILE git reset -q HEAD~1 -- {COMPLETED} {EPISODIC}\n")
    hook.chmod(0o755)
    ok, msg = inc._commit_decision(TASK_ID, "go", followup=True)
    assert not ok
    assert "index" in msg and "revert" in msg and "git restore --staged" in msg


def test_git_clean_env_strips_repo_local_vars_only():
    from web import decide_runner as dr
    env = {"GIT_INDEX_FILE": "x", "GIT_DIR": "y", "GIT_WORK_TREE": "z",
           "GIT_AUTHOR_NAME": "keep", "PATH": "/bin"}
    out = dr.git_clean_env(env)
    assert out == {"GIT_AUTHOR_NAME": "keep", "PATH": "/bin"}
    live = subprocess.run(["git", "rev-parse", "--local-env-vars"], capture_output=True,
                          text=True, timeout=30).stdout.split()
    assert set(live) <= dr.GIT_LOCAL_ENV_VARS, set(live) - dr.GIT_LOCAL_ENV_VARS


def test_runner_launch_does_not_pass_git_local_vars(tmp_path, monkeypatch):
    from web import decide_runner as dr
    (tmp_path / ".context" / "working").mkdir(parents=True)
    seen = {}

    class _Proc:
        def wait(self):
            return 0

    def fake_popen(cmd, **kw):
        seen.update(kw.get("env") or {})
        return _Proc()

    monkeypatch.setenv("GIT_INDEX_FILE", str(tmp_path / ".git" / "index.lock"))
    monkeypatch.setattr(dr.subprocess, "Popen", fake_popen)
    dr.launch(TASK_ID, "go", "r", project_root=tmp_path, framework_root=tmp_path)
    assert seen and "GIT_INDEX_FILE" not in seen
    assert seen.get("PROJECT_ROOT") == str(tmp_path)
