"""T-4903: task ids we post to GitHub link to the task file at an immutable ref."""

import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "lib"))

import gh_links  # noqa: E402

REPO = "owner/proj"


def _git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True, text=True).stdout


@pytest.fixture
def proj(tmp_path):
    root = tmp_path / "p"
    (root / ".tasks" / "active").mkdir(parents=True)
    (root / ".tasks" / "completed").mkdir(parents=True)
    (root / ".tasks" / "active" / "T-10-open-thing.md").write_text("x")
    (root / ".tasks" / "completed" / "T-20-done-thing.md").write_text("x")
    _git(tmp_path, "init", "-q", str(root))
    _git(root, "add", ".")
    _git(root, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "c1")
    sha = _git(root, "rev-parse", "HEAD").strip()
    return root, sha


def test_bare_ids_become_links_at_the_ref(proj):
    root, sha = proj
    out = gh_links.link_task_ids("Fixed in T-20, follow-up T-10.", str(root), sha, REPO)
    assert f"[T-20](https://github.com/{REPO}/blob/{sha}/.tasks/completed/T-20-done-thing.md)" in out
    assert f"[T-10](https://github.com/{REPO}/blob/{sha}/.tasks/active/T-10-open-thing.md)" in out


def test_bold_and_parenthesised_ids_are_linked(proj):
    root, sha = proj
    out = gh_links.link_task_ids("**T-20** and (T-10):", str(root), sha, REPO)
    assert out.startswith("**[T-20](")
    assert "([T-10](" in out


@pytest.mark.parametrize("text", [
    "run `fw task show T-20` first",
    "```\nT-20 in a code block\n```",
    "see [the task](https://example.org/T-20)",
    "already [T-20](https://github.com/owner/proj/blob/x/.tasks/completed/T-20-done-thing.md)",
    "https://github.com/owner/proj/issues?q=T-20",
])
def test_protected_spans_are_left_alone(proj, text):
    root, sha = proj
    assert gh_links.link_task_ids(text, str(root), sha, REPO) == text


def test_unknown_id_stays_plain_text(proj):
    root, sha = proj
    assert gh_links.link_task_ids("T-999 is not here", str(root), sha, REPO) == "T-999 is not here"


def test_no_ref_or_repo_changes_nothing(proj):
    root, _ = proj
    assert gh_links.link_task_ids("T-20", str(root), "", REPO) == "T-20"
    assert gh_links.link_task_ids("T-20", str(root), "HEAD", "") == "T-20"


def test_issue_comment_body_is_linked_before_gh_sees_it(proj, tmp_path, monkeypatch):
    root, sha = proj
    import issues
    seen = {}

    def fake_run(cmd, **kw):
        seen["cmd"], seen["input"] = cmd, kw.get("input")
        return subprocess.CompletedProcess(cmd, 0, "https://github.com/owner/proj/issues/1#c", "")

    monkeypatch.setattr(issues, "_run", fake_run)
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_ISSUES_LINK_REF", sha)
    monkeypatch.setenv("FW_ISSUES_REPO", REPO)
    issues._gh(["issue", "comment", "1", "--repo", REPO, "--body-file", "-"], stdin="Released: T-20.")
    assert f"[T-20](https://github.com/{REPO}/blob/{sha}/.tasks/completed/T-20-done-thing.md)" in seen["input"]


def test_non_comment_gh_calls_are_untouched(proj, monkeypatch):
    root, sha = proj
    import issues
    seen = {}

    def fake_run(cmd, **kw):
        seen["input"] = kw.get("input")
        return subprocess.CompletedProcess(cmd, 0, "", "")

    monkeypatch.setattr(issues, "_run", fake_run)
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_ISSUES_LINK_REF", sha)
    issues._gh(["issue", "edit", "1"], stdin="T-20")
    assert seen["input"] == "T-20"
