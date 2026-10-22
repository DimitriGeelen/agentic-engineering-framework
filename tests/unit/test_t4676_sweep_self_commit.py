"""T-4676: the estimator sweeps commit their own writes.

Before: `fw bvp estimate sweep --cron` and `fw bvp estimate-cost sweep --cron`
(cron every 15 min) wrote proposals into task frontmatter and never committed.
On 2026-10-22 one pass left 427 dirty task files; they sat until an unrelated
broad commit swept them up, and they buried 28 real task-file edits.

After, in --cron mode only:
  - one commit per sweep, subject naming the sweep's task id (T-1923 / T-1935);
  - the commit holds only the files that sweep wrote;
  - a file that already had uncommitted edits before the sweep is neither written
    nor committed (its owner's edit is not ours to commit, and our write would bury it);
  - another file staged in the shared index is not swept into the commit.

Every test runs against a throwaway git repo, never the live tree.
"""

import importlib.util
import subprocess
import sys

from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
_EST = FW_ROOT / "agents" / "termlink" / "bvp-estimator" / "estimator.py"

_spec = importlib.util.spec_from_file_location("_bvp_estimator_t4676", _EST)
est = importlib.util.module_from_spec(_spec)
sys.modules["_bvp_estimator_t4676"] = est
_spec.loader.exec_module(est)


def _git(root: Path, *args) -> str:
    r = subprocess.run(["git", "-C", str(root), *args],
                       capture_output=True, text=True, check=True)
    return r.stdout


def _task(path: Path, tid: str, components=("lib/a.sh", "lib/b.sh")):
    comp = "components:\n" + "".join(f"  - {c}\n" for c in components)
    path.write_text(
        "---\n"
        f"id: {tid}\n"
        f'name: "fixture {tid}"\n'
        "status: started-work\n"
        "workflow_type: build\n"
        "owner: agent\n"
        "horizon: now\n"
        "created: 2026-01-01T00:00:00Z\n"
        "last_update: 2026-01-01T00:00:00Z\n"
        f"{comp}"
        "---\n"
        "\n"
        f"# {tid}\n"
        "\n"
        "## Acceptance Criteria\n"
        "\n"
        "### Agent\n"
        "- [ ] fix the antifragile healing loop and add a regression test\n"
    )


@pytest.fixture
def repo(tmp_path, monkeypatch):
    root = tmp_path
    (root / ".tasks" / "active").mkdir(parents=True)
    (root / ".tasks" / "completed").mkdir(parents=True)
    _git(root, "init", "-q")
    _git(root, "config", "user.email", "t@example.invalid")
    _git(root, "config", "user.name", "t4676")
    _git(root, "config", "commit.gpgsign", "false")
    for n in (9101, 9102, 9103):
        _task(root / ".tasks" / "active" / f"T-{n}-fixture.md", f"T-{n}")
    (root / "other.txt").write_text("base\n")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "base")
    monkeypatch.setattr(est, "PROJECT_ROOT", root)
    return root


def _dirty(root: Path) -> list[str]:
    return sorted(l[3:] for l in _git(root, "status", "--porcelain").splitlines())


def _head_files(root: Path) -> list[str]:
    return sorted(_git(root, "show", "--name-only", "--format=", "HEAD").split())


def _head_subject(root: Path) -> str:
    return _git(root, "log", "-1", "--format=%s").strip()


@pytest.mark.parametrize("sweep,task_id", [
    (lambda: est.cmd_sweep(stale_hours=0, cron=True), "T-1923"),
    (lambda: est.cmd_cost_sweep(stale_hours=0, cron=True), "T-1935"),
])
def test_cron_sweep_commits_exactly_its_own_writes(repo, sweep, task_id):
    assert sweep() == 0
    assert _dirty(repo) == [], f"sweep left its writes uncommitted: {_dirty(repo)}"
    assert _head_subject(repo).startswith(f"{task_id}:")
    assert _head_files(repo) == [
        f".tasks/active/T-{n}-fixture.md" for n in (9101, 9102, 9103)]
    assert int(_git(repo, "rev-list", "--count", "HEAD")) == 2, "one commit per sweep"


@pytest.mark.parametrize("sweep", [
    lambda: est.cmd_sweep(stale_hours=0, cron=True),
    lambda: est.cmd_cost_sweep(stale_hours=0, cron=True),
])
def test_file_with_prior_uncommitted_edit_is_left_alone(repo, sweep):
    owned = repo / ".tasks" / "active" / "T-9102-fixture.md"
    owned.write_text(owned.read_text() + "\n## Updates\nsomeone else's edit\n")
    before = owned.read_text()

    assert sweep() == 0

    assert owned.read_text() == before, "sweep wrote into a file with someone's edit"
    assert ".tasks/active/T-9102-fixture.md" not in _head_files(repo)
    assert _dirty(repo) == [".tasks/active/T-9102-fixture.md"]


def test_staged_unrelated_file_is_not_swept_into_the_commit(repo):
    (repo / "other.txt").write_text("staged by another worker\n")
    _git(repo, "add", "other.txt")

    assert est.cmd_sweep(stale_hours=0, cron=True) == 0

    assert "other.txt" not in _head_files(repo)
    staged = _git(repo, "diff", "--cached", "--name-only").split()
    assert staged == ["other.txt"], "the other worker's staged file must stay staged"


def test_second_sweep_makes_no_empty_commit(repo):
    est.cmd_cost_sweep(stale_hours=0, cron=True)
    n = int(_git(repo, "rev-list", "--count", "HEAD"))
    assert est.cmd_cost_sweep(stale_hours=0, cron=True) == 0
    assert int(_git(repo, "rev-list", "--count", "HEAD")) == n


def test_manual_sweep_does_not_commit(repo):
    """Without --cron the sweep is an operator's tool: it writes, the operator commits."""
    assert est.cmd_sweep(stale_hours=0, cron=False) == 0
    assert int(_git(repo, "rev-list", "--count", "HEAD")) == 1
    assert len(_dirty(repo)) == 3


def test_not_a_git_repo_still_sweeps(tmp_path, monkeypatch):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    t = tmp_path / ".tasks" / "active" / "T-9201-fixture.md"
    _task(t, "T-9201")
    monkeypatch.setattr(est, "PROJECT_ROOT", tmp_path)
    monkeypatch.setenv("GIT_CEILING_DIRECTORIES", str(tmp_path.parent))
    before = t.read_text()
    assert est.cmd_cost_sweep(stale_hours=0, cron=True) == 0
    assert t.read_text() != before
