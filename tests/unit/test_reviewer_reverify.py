"""Unit tests for lib/reviewer/reverify.py (T-1483 v1.5).

Most tests use the WorktreePool against a tiny ad-hoc git repo to keep
runtime fast. Slow integration-flavor tests (real worktree on the actual
framework repo) are tagged @pytest.mark.slow and skipped by default —
run with `pytest -m slow` to include.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer.reverify import (  # noqa: E402
    LineResult,
    ReverifyReport,
    WorktreePool,
    reverify_task,
)
from lib.reviewer.classifier import Category  # noqa: E402


def _init_repo(path: Path, files: dict[str, str]) -> str:
    """Create a tiny git repo with given files. Returns initial commit SHA."""
    path.mkdir(exist_ok=True)
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=path, check=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=path, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=path, check=True)
    for rel, content in files.items():
        full = path / rel
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(content)
        subprocess.run(["git", "add", rel], cwd=path, check=True)
    subprocess.run(
        ["git", "commit", "-q", "--allow-empty", "-m", "T-9999: initial"],
        cwd=path,
        check=True,
    )
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=path, text=True).strip()
    return sha


# ───────────────── WorktreePool ─────────────────


def test_worktree_pool_lifecycle(tmp_path):
    repo = tmp_path / "repo"
    sha = _init_repo(repo, {"hello.txt": "hi"})

    with WorktreePool(repo, base_dir=tmp_path) as pool:
        assert pool.path is not None
        assert pool.path.exists()
        assert (pool.path / "hello.txt").read_text() == "hi"

    # After exit, worktree is gone
    assert pool.path is None


def test_worktree_pool_checkout_changes_content(tmp_path):
    repo = tmp_path / "repo"
    sha1 = _init_repo(repo, {"x.txt": "v1"})

    # Make a second commit
    (repo / "x.txt").write_text("v2")
    subprocess.run(["git", "add", "x.txt"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "T-9999: bump"], cwd=repo, check=True)
    sha2 = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()

    with WorktreePool(repo, base_dir=tmp_path) as pool:
        assert pool.checkout(sha1)
        assert (pool.path / "x.txt").read_text() == "v1"
        assert pool.checkout(sha2)
        assert (pool.path / "x.txt").read_text() == "v2"


def test_worktree_pool_checkout_invalid_sha_returns_false(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo, {"a.txt": "x"})
    with WorktreePool(repo, base_dir=tmp_path) as pool:
        assert pool.checkout("0" * 40) is False


def test_worktree_pool_not_a_repo_raises(tmp_path):
    with pytest.raises(RuntimeError):
        with WorktreePool(tmp_path / "not-a-repo", base_dir=tmp_path):
            pass


# ───────────────── reverify_task ─────────────────


def _write_task(repo: Path, task_id: str, verification: str) -> Path:
    body = f"""---
id: {task_id}
name: test
status: work-completed
---

## Verification

{verification}
"""
    p = repo / f"{task_id}.md"
    p.write_text(body)
    return p


def test_reverify_skips_network_lines(tmp_path):
    repo = tmp_path / "repo"
    sha = _init_repo(repo, {"keep.txt": "hi"})
    task_path = _write_task(repo, "T-9999", "curl http://localhost:9999/never\ntest -f keep.txt")

    with WorktreePool(repo, base_dir=tmp_path) as pool:
        rep = reverify_task(task_path, pool)

    assert rep.task_id == "T-9999"
    statuses = [r.status for r in rep.results]
    cats = [r.category for r in rep.results]
    assert "SKIPPED" in statuses
    assert Category.NETWORK_DEPENDENT.value in cats


def test_reverify_passes_when_verification_passes(tmp_path):
    repo = tmp_path / "repo"
    sha = _init_repo(repo, {"keep.txt": "hi"})
    task_path = _write_task(repo, "T-9999", "test -f keep.txt")

    with WorktreePool(repo, base_dir=tmp_path) as pool:
        rep = reverify_task(task_path, pool)

    assert rep.overall == "PASS"
    assert rep.sha == sha
    assert all(r.status == "PASS" for r in rep.results)


def test_reverify_fails_when_verification_fails(tmp_path):
    repo = tmp_path / "repo"
    sha = _init_repo(repo, {"keep.txt": "hi"})
    task_path = _write_task(repo, "T-9999", "test -f does-not-exist.txt")

    with WorktreePool(repo, base_dir=tmp_path) as pool:
        rep = reverify_task(task_path, pool)

    assert rep.overall == "FAIL"
    assert any(r.status == "FAIL" for r in rep.results)


def test_reverify_no_verification_block(tmp_path):
    repo = tmp_path / "repo"
    sha = _init_repo(repo, {"keep.txt": "hi"})
    body = """---
id: T-9999
name: test
status: work-completed
---

# Just a body, no verification section.
"""
    task_path = repo / "T-9999.md"
    task_path.write_text(body)

    with WorktreePool(repo, base_dir=tmp_path) as pool:
        rep = reverify_task(task_path, pool)

    assert rep.overall == "NO-VERIFICATION"
    assert rep.results == []


def test_reverify_unknown_task_id_returns_error(tmp_path):
    repo = tmp_path / "repo"
    _init_repo(repo, {"a.txt": "x"})
    # No commit references T-XXXX
    task_path = _write_task(repo, "T-XXXX", "test -f a.txt")

    with WorktreePool(repo, base_dir=tmp_path) as pool:
        rep = reverify_task(task_path, pool)

    assert rep.error is not None
    assert "could not locate" in rep.error.lower()
    assert rep.overall == "FAIL"


def test_reverify_sets_FW_REVIEWER_REVERIFY_env(tmp_path):
    """Subprocess must see FW_REVIEWER_REVERIFY=1 so framework hooks short-circuit."""
    repo = tmp_path / "repo"
    sha = _init_repo(
        repo,
        {"check.sh": "#!/bin/bash\ntest \"${FW_REVIEWER_REVERIFY:-0}\" = \"1\"\n"},
    )
    (repo / "check.sh").chmod(0o755)
    subprocess.run(["git", "add", "check.sh"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "T-9999: add check"], cwd=repo, check=True)
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()

    task_path = _write_task(repo, "T-9999", "bash check.sh")

    with WorktreePool(repo, base_dir=tmp_path) as pool:
        rep = reverify_task(task_path, pool)

    assert rep.overall == "PASS"


def test_reverify_report_render_is_readable():
    rep = ReverifyReport(task_id="T-1", sha="abc123", overall="PASS")
    rep.results = [LineResult("test -f x", "read_only", "PASS", 0)]
    rendered = rep.render()
    assert "T-1" in rendered
    assert "PASS" in rendered
