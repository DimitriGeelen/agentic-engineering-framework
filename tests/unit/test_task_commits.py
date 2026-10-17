"""T-3189 — a commit belongs to a task only when its SUBJECT opens with the task id.

Measured on T-3179: d998545b8 is a T-3180 commit whose body reads 'Ref: T-3179 (landing
thread)'; every resolver that asked `git log --grep` for T-3179 counted it as T-3179's and
donated web/blueprints/inception.py, firing the render-surface gate on a task that touched no
render surface. lib/task_commits.py is now the single definition; these tests pin it with a
fixture repo, plus the call sites that route through it.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import task_commits  # noqa: E402


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


def _commit(repo: Path, path: str, *messages: str) -> None:
    f = repo / path
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(path + "\n")
    _git(repo, "add", "-A")
    args = ["commit", "-q"]
    for m in messages:
        args += ["-m", m]
    _git(repo, *args)


@pytest.fixture()
def repo(tmp_path: Path) -> Path:
    r = tmp_path / "repo"
    r.mkdir()
    _git(r, "init", "-q", ".")
    _git(r, "config", "user.email", "t3189@test")
    _git(r, "config", "user.name", "t3189")
    _git(r, "config", "commit.gpgsign", "false")
    _commit(r, "lib/own.sh", "T-9100: the task's own work")
    # The T-3179 shape: another task's commit citing T-9100 in a trailer.
    _commit(r, "web/blueprints/donor.py", "T-9101: unrelated render edit",
            "Ref: T-9100 (landing thread)")
    # git's ^ anchors per LINE, so a body line opening with the id is the subtle case.
    _commit(r, "web/templates/body-line.html", "T-9102: something else",
            "T-9100: mentioned at the start of a body line")
    _commit(r, "web/templates/mid.html", "T-9103: render edit, T-9100 filed alongside")
    _commit(r, "lib/listed.sh", "T-9104, T-9100: close both")
    _commit(r, "lib/slash.sh", "T-9105/T-9100: close both")
    _commit(r, "lib/collide.sh", "T-91000: longer id")
    return r


def test_ref_trailer_is_not_attributed(repo: Path) -> None:
    files = task_commits.owned_files(repo, "T-9100")
    assert "web/blueprints/donor.py" not in files


def test_body_line_opening_with_id_is_not_attributed(repo: Path) -> None:
    assert "web/templates/body-line.html" not in task_commits.owned_files(repo, "T-9100")


def test_mid_subject_mention_is_not_attributed(repo: Path) -> None:
    assert "web/templates/mid.html" not in task_commits.owned_files(repo, "T-9100")


def test_prefix_collision_is_not_attributed(repo: Path) -> None:
    assert "lib/collide.sh" not in task_commits.owned_files(repo, "T-9100")
    assert task_commits.owned_files(repo, "T-910") == []


def test_subject_prefixed_and_listed_ids_are_attributed(repo: Path) -> None:
    assert task_commits.owned_files(repo, "T-9100") == ["lib/listed.sh", "lib/own.sh", "lib/slash.sh"]
    assert task_commits.owned_files(repo, "T-9104") == ["lib/listed.sh"]
    assert task_commits.owned_files(repo, "T-9101") == ["web/blueprints/donor.py"]


def test_cli_files_and_shas(repo: Path) -> None:
    run = lambda *a: subprocess.run([sys.executable, str(ROOT / "lib" / "task_commits.py"), *a,
                                     "--root", str(repo)], capture_output=True, text=True, check=True)
    assert run("files", "T-9100").stdout.split() == ["lib/listed.sh", "lib/own.sh", "lib/slash.sh"]
    assert len(run("shas", "T-9100").stdout.split()) == 3
    assert run("files", "not-a-task").stdout == ""


@pytest.mark.parametrize("subject,tid,expected", [
    ("T-1: x", "T-1", True),
    ("T-1, T-2: close", "T-2", True),
    ("T-1 and T-2: close", "T-2", True),
    ("T-12: x", "T-1", False),
    ("fix T-1: x", "T-1", False),
    ("WM-001: file T-1", "T-1", False),
    ("T-1 x", "T-1", False),
])
def test_owns(subject: str, tid: str, expected: bool) -> None:
    assert task_commits.owns(subject, tid) is expected


def test_verdict_ledger_shares_the_definition() -> None:
    from lib import verdict_ledger
    assert verdict_ledger._owns is task_commits.owns
    assert verdict_ledger._OWN_SUBJECT_RE is task_commits.OWN_SUBJECT_RE


def test_call_sites_route_through_the_helper() -> None:
    render = (ROOT / "lib" / "render_surface.sh").read_text()
    assert "task_commits.py" in render and "--grep" not in render
    update = (ROOT / "agents" / "task-create" / "update-task.sh").read_text()
    assert 'git log --all --oneline --grep="$TASK_ID"' not in update
    assert '"--grep", "^" + t' not in update
    assert update.count("task_commits") >= 2
    judge = (ROOT / "lib" / "reviewer" / "judge_cli.py").read_text()
    assert "task_commits.owned_files" in judge
