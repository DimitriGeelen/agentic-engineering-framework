"""T-4891: the retire_when preference-file signal must not walk the project tree.

Origin: dimitri-mint-dev's project root is a ~500 GB home directory; a recursive
glob for preferences.yaml there never finished (killed at 15 min), so every push
waited out the pre-push audit's 300 s read cap.
"""

import glob
import os
import pathlib
import subprocess
import sys

import pytest

REPO = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))

import tracked_files  # noqa: E402

NAMES = ("preference-index.yaml", "preferences.yaml")


def _git(root, *args):
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)


@pytest.fixture
def home_like(tmp_path):
    """A git project shaped like a home dir: a big ignored tree beside tracked content."""
    root = tmp_path / "home"
    root.mkdir()
    _git(root, "init", "-q")
    (root / ".gitignore").write_text(".cache/\n")
    cache = root / ".cache" / "deep" / "deeper"
    cache.mkdir(parents=True)
    (cache / "preferences.yaml").write_text("ignored: true\n")   # must not count
    for i in range(200):
        (root / ".cache" / f"blob{i}").write_text("x")
    _git(root, "add", ".gitignore")
    _git(root, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "init")
    return root


@pytest.fixture
def no_walk(monkeypatch):
    """Fail the test if the search walks the tree in any of the usual ways."""
    def boom(*a, **k):
        raise AssertionError("tree walk attempted")
    monkeypatch.setattr(os, "walk", boom)
    monkeypatch.setattr(glob, "glob", boom)
    monkeypatch.setattr(pathlib.Path, "rglob", boom)


def test_tracked_file_at_depth_is_found_without_walking(home_like, no_walk):
    sub = home_like / "projects" / "x" / ".context"
    sub.mkdir(parents=True)
    (sub / "preferences.yaml").write_text("a: 1\n")
    _git(home_like, "add", "projects/x/.context/preferences.yaml")
    assert tracked_files.find_named(str(home_like), NAMES) == [
        "projects/x/.context/preferences.yaml"]


def test_ignored_copy_does_not_count(home_like, no_walk):
    assert tracked_files.find_named(str(home_like), NAMES) == []


def test_similar_name_is_not_a_match(home_like, no_walk):
    (home_like / "my-preferences.yaml").write_text("a: 1\n")
    _git(home_like, "add", "my-preferences.yaml")
    assert tracked_files.find_named(str(home_like), NAMES) == []


def test_outside_git_only_context_and_policy_are_searched(tmp_path):
    root = tmp_path / "plain"
    (root / ".context" / "project").mkdir(parents=True)
    (root / ".context" / "project" / "preference-index.yaml").write_text("a: 1\n")
    (root / "elsewhere").mkdir()
    (root / "elsewhere" / "preferences.yaml").write_text("a: 1\n")
    env_ceiling = os.environ.get("GIT_CEILING_DIRECTORIES")
    os.environ["GIT_CEILING_DIRECTORIES"] = str(tmp_path)
    try:
        assert tracked_files.find_named(str(root), NAMES) == [
            ".context/project/preference-index.yaml"]
    finally:
        if env_ceiling is None:
            os.environ.pop("GIT_CEILING_DIRECTORIES", None)
        else:
            os.environ["GIT_CEILING_DIRECTORIES"] = env_ceiling


def test_audit_signal_b_uses_the_bounded_search():
    src = (REPO / "agents" / "audit" / "audit.sh").read_text()
    assert 'glob.glob(os.path.join(project_root, "**", name), recursive=True)' not in src
    assert "from tracked_files import find_named" in src
