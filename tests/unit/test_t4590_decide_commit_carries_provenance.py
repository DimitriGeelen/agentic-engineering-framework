"""T-4590 - a Watchtower decision commit carries its Human-tick provenance row and the
operator's identity.

Origin: five operator GO decisions (T-4470, T-4466, T-4517, T-4525, T-4415) FAILed the
Human-AC tick audit. `fw inception decide` appended each tick's row to
.context/reviews/human-ac-ticks.jsonl, but the decision commit staged only the task file
and the episodic, so the row stayed uncommitted until a `git stash` swept it away. Two of
those commits were also authored by a dispatch worker, because a Watchtower started from a
worker inherits its GIT_AUTHOR_*/GIT_COMMITTER_* and the decision commit passed them on.
Every fixture here is a temp repo; nothing touches the live repo.
"""
import importlib
import os
import subprocess

import pytest

TASK_ID = "T-9590"
ACTIVE = f".tasks/active/{TASK_ID}-decide-me.md"
COMPLETED = f".tasks/completed/{TASK_ID}-decide-me.md"
EPISODIC = f".context/episodic/{TASK_ID}.yaml"
LEDGER = ".context/reviews/human-ac-ticks.jsonl"
STARTED = f"---\nid: {TASK_ID}\nstatus: started-work\nworkflow_type: inception\n---\n"
DECIDED = (f"---\nid: {TASK_ID}\nstatus: work-completed\nworkflow_type: inception\n---\n"
           "\n## Decision\n\n**Decision**: GO\n")
ROW = '{"by": "root", "digest": "abc", "task": "T-9590", "via": "inception-decide"}\n'


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
    # a dispatch worker running this suite carries its own @aef.local identity
    for k in ("GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL"):
        monkeypatch.delenv(k, raising=False)
    for d in (".tasks/active", ".tasks/completed", ".context/working", ".context/episodic",
              ".context/reviews"):
        (tmp_path / d).mkdir(parents=True)
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "operator@example.com")
    _git(tmp_path, "config", "user.name", "Operator")
    _git(tmp_path, "config", "commit.gpgsign", "false")
    (tmp_path / ACTIVE).write_text(STARTED)
    (tmp_path / LEDGER).write_text("")
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-qm", "seed")
    # What the decide chain leaves: decision written, `git mv` to completed/, episodic,
    # and the Human-tick provenance row appended by lib/inception.sh.
    (tmp_path / ACTIVE).write_text(DECIDED)
    _git(tmp_path, "mv", ACTIVE, COMPLETED)
    (tmp_path / EPISODIC).write_text(f"task_id: {TASK_ID}\n")
    with (tmp_path / LEDGER).open("a") as f:
        f.write(ROW)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    return tmp_path, importlib.reload(web.blueprints.inception)


def test_decision_commit_includes_the_provenance_row(repo):
    path, inc = repo
    ok, msg = inc._commit_decision(TASK_ID, "go")
    assert ok, msg
    assert '"task": "T-9590"' in _git(path, "show", f"HEAD:{LEDGER}").stdout, \
        "the Human-tick provenance row was left uncommitted: a stash/reset loses it"
    assert _git(path, "status", "--porcelain", "--", LEDGER).stdout == ""


def test_inherited_agent_identity_does_not_author_the_decision(repo, monkeypatch):
    path, inc = repo
    for k in ("GIT_AUTHOR_NAME", "GIT_COMMITTER_NAME"):
        monkeypatch.setenv(k, "fw worker (termlink-dispatch)")
    for k in ("GIT_AUTHOR_EMAIL", "GIT_COMMITTER_EMAIL"):
        monkeypatch.setenv(k, "dispatch+w4468@aef.local")
    ok, msg = inc._commit_decision(TASK_ID, "go")
    assert ok, msg
    who = _git(path, "log", "-1", "--format=%an <%ae>|%cn <%ce>").stdout.strip()
    assert who == "Operator <operator@example.com>|Operator <operator@example.com>", who


def test_a_human_identity_in_the_env_is_kept(repo, monkeypatch):
    """Only an @aef.local agent identity is dropped; an explicit human one still applies."""
    path, inc = repo
    monkeypatch.setenv("GIT_AUTHOR_NAME", "Someone Else")
    monkeypatch.setenv("GIT_AUTHOR_EMAIL", "someone@example.com")
    ok, msg = inc._commit_decision(TASK_ID, "go")
    assert ok, msg
    assert _git(path, "log", "-1", "--format=%an <%ae>").stdout.strip() == \
        "Someone Else <someone@example.com>"
