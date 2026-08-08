"""T-2864 — the Watchtower decision commit must stage BOTH sides of a rename.

Origin incident: the operator recorded GO on T-2863 through Watchtower. The
decision was written to the task file and the commit was refused by the G-052
duplicate-task-ID pre-commit gate, leaving the decision on disk and out of
history — the repository's authoritative record said the inception was still
undecided.

Mechanism. `_commit_decision` builds a SCRATCH index seeded from `git read-tree
HEAD` (T-2708), then `git add`s only the paths it collected from `git status
--porcelain`. `update-task.sh` archives with `git mv` when the task file is
tracked (T-1523), so porcelain reports a single RENAME line:

    RM .tasks/active/T-x.md -> .tasks/completed/T-x.md

The old parse kept only the destination. HEAD still contains the *active* path,
so the scratch index ended up carrying the task id under BOTH .tasks/active/ and
.tasks/completed/ — exactly the G-052 violation, produced by the committer
itself.

ANTI-VACUITY. These tests run in a temp repo with no hooks installed, so the
commit succeeds whether or not the bug is present — asserting "committed is
True" would pass on the broken code. The load-bearing assertion is therefore
made against the COMMITTED TREE (the active path must be gone), and
`test_rename_form_is_actually_produced` pins the precondition that this state
really does yield the ` -> ` form. If that precondition ever stops holding, the
other tests are no longer exercising the defect and this one goes red first.
"""

import importlib
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]

TASK_ID = "T-9100"
ACTIVE = f".tasks/active/{TASK_ID}-decide-me.md"
COMPLETED = f".tasks/completed/{TASK_ID}-decide-me.md"


def _git(repo, *args, check=True):
    r = subprocess.run(
        ["git", *args], cwd=repo, capture_output=True, text=True, timeout=30
    )
    if check and r.returncode != 0:
        raise AssertionError(f"git {' '.join(args)} failed: {r.stderr or r.stdout}")
    return r.stdout


@pytest.fixture
def repo(tmp_path, monkeypatch):
    """An isolated project root that is a real git repo, mid-decide."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")

    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "test@test")
    _git(tmp_path, "config", "user.name", "test")
    _git(tmp_path, "config", "commit.gpgsign", "false")

    (tmp_path / ACTIVE).write_text(
        f"---\nid: {TASK_ID}\nstatus: started-work\nworkflow_type: inception\n---\n"
        f"# {TASK_ID}\n\n## Recommendation\n\n**Recommendation:** GO\n"
    )
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-qm", "seed")

    # Reproduce what `fw inception decide` leaves behind: the Decision block is
    # written into the file, then update-task.sh `git mv`s it to completed/.
    (tmp_path / ACTIVE).write_text(
        f"---\nid: {TASK_ID}\nstatus: work-completed\nworkflow_type: inception\n---\n"
        f"# {TASK_ID}\n\n## Recommendation\n\n**Recommendation:** GO\n"
        f"\n## Decision\n\n**Decision**: GO\n\n**Rationale**: approved\n"
    )
    _git(tmp_path, "mv", ACTIVE, COMPLETED)

    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import web.shared
    import web.blueprints.inception

    importlib.reload(web.shared)
    importlib.reload(web.blueprints.inception)
    yield tmp_path, web.blueprints.inception


def test_rename_form_is_actually_produced(repo):
    """Precondition anchor: without the ` -> ` form these tests prove nothing."""
    repo_path, _ = repo
    porcelain = _git(repo_path, "status", "--porcelain", "--untracked-files=all")
    assert " -> " in porcelain, (
        "expected a staged-rename porcelain line; got:\n" + porcelain
    )
    assert ACTIVE in porcelain and COMPLETED in porcelain


def test_commit_removes_the_active_path_from_the_tree(repo):
    """The load-bearing assertion — survives the absence of pre-commit hooks."""
    repo_path, inc = repo
    committed, msg = inc._commit_decision(TASK_ID, "go")
    assert committed is True, f"commit failed: {msg}"

    tree = _git(repo_path, "ls-tree", "-r", "HEAD", "--name-only").splitlines()
    assert COMPLETED in tree, "decision file missing from the committed tree"
    assert ACTIVE not in tree, (
        "G-052: the task id is under BOTH active/ and completed/ in the committed "
        "tree — the rename's source side was never staged"
    )


def test_committed_tree_has_no_duplicate_task_ids(repo):
    """The property the G-052 gate actually enforces, asserted directly."""
    repo_path, inc = repo
    committed, msg = inc._commit_decision(TASK_ID, "go")
    assert committed is True, f"commit failed: {msg}"

    tree = _git(repo_path, "ls-tree", "-r", "HEAD", "--name-only").splitlines()
    active_ids = {
        p.split("/")[2].split("-")[0] + "-" + p.split("/")[2].split("-")[1]
        for p in tree
        if p.startswith(".tasks/active/")
    }
    completed_ids = {
        p.split("/")[2].split("-")[0] + "-" + p.split("/")[2].split("-")[1]
        for p in tree
        if p.startswith(".tasks/completed/")
    }
    assert not (active_ids & completed_ids), (
        f"duplicate task ids in committed tree: {active_ids & completed_ids}"
    )


def test_decision_block_reaches_history(repo):
    """The point of the whole path: the human's decision must be IN history."""
    repo_path, inc = repo
    committed, _ = inc._commit_decision(TASK_ID, "go")
    assert committed is True

    blob = _git(repo_path, "show", f"HEAD:{COMPLETED}")
    assert "**Decision**: GO" in blob


def test_untracked_two_line_form_still_works(tmp_path, monkeypatch):
    """The plain-`mv` shape (file was untracked) must keep working — T-2864 widened
    the parse, it did not replace it."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "test@test")
    _git(tmp_path, "config", "user.name", "test")
    _git(tmp_path, "config", "commit.gpgsign", "false")
    (tmp_path / ".gitkeep").write_text("")
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-qm", "seed")

    # Never tracked → lands in completed/ as a plain untracked add.
    (tmp_path / COMPLETED).write_text(
        f"---\nid: {TASK_ID}\nstatus: work-completed\n---\n\n## Decision\n\n"
        f"**Decision**: GO\n"
    )

    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import web.shared
    import web.blueprints.inception

    importlib.reload(web.shared)
    importlib.reload(web.blueprints.inception)

    committed, msg = web.blueprints.inception._commit_decision(TASK_ID, "go")
    assert committed is True, f"commit failed: {msg}"
    tree = _git(tmp_path, "ls-tree", "-r", "HEAD", "--name-only").splitlines()
    assert COMPLETED in tree
