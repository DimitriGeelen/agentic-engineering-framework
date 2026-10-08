"""T-4008 — a reviewer that cites a screenshot must still get its verdict committed.

`*.png` is ignored repo-wide, and `_commit_rows` ran `git add -- <paths>`: git refused the
WHOLE add when one path was ignored, the commit never ran, and the reviewer's green stayed
uncommitted (2026-10-08: T-4000's green V-20261008-fbf03f03 never counted).
"""
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib import verdict_ledger as vl  # noqa: E402


def _git(root, *a):
    return subprocess.run(["git", *a], cwd=root, capture_output=True, text=True, check=True).stdout


def _repo(tmp_path):
    root = tmp_path / "proj"
    root.mkdir()
    _git(root, "init", "-q")
    _git(root, "config", "user.email", "t@t")
    _git(root, "config", "user.name", "t")
    (root / ".gitignore").write_text("*.png\n")
    _git(root, "add", ".gitignore")
    _git(root, "commit", "-qm", "init")
    return root


def test_an_ignored_screenshot_is_committed_with_its_row(tmp_path):
    root = _repo(tmp_path)
    ev = root / ".context" / "reviews" / "evidence" / "T-1" / "shot.png"
    ev.parent.mkdir(parents=True)
    ev.write_bytes(b"\x89PNG fake")
    (root / vl.VERDICTS).write_text('{"id": "V-1"}\n')
    rel = str(ev.relative_to(root))
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, [rel]), "judge-x-worker",
                               "T-1: reviewer verdict")
    assert err == "" and sha
    files = set(_git(root, "show", "--name-only", "--format=", "HEAD").split())
    assert rel in files and str(vl.VERDICTS) in files
    assert _git(root, "log", "-1", "--format=%an").strip() == "judge-x-worker"


def test_control_only_the_named_paths_are_committed(tmp_path):
    root = _repo(tmp_path)
    (root / vl.VERDICTS).parent.mkdir(parents=True, exist_ok=True)
    (root / vl.VERDICTS).write_text('{"id": "V-1"}\n')
    (root / "unrelated.txt").write_text("not mine\n")
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, []), "w", "T-1: reviewer verdict")
    assert err == ""
    files = set(_git(root, "show", "--name-only", "--format=", "HEAD").split())
    assert files == {str(vl.VERDICTS)}
