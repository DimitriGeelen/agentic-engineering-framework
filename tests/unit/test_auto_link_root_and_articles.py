"""T-2281 (T-2275 Candidate 2): auto-linker reach over root files + docs/articles/.

Pins the contract that:
  - Depth-0 root files in ROOT_FILES (README.md, CLAUDE.md, FRAMEWORK.md,
    VERSION, LICENSE, CHANGELOG) are linkable via `is_viewable_path` AND
    `_auto_link_files` (the auto-linker promoted in T-1722).
  - New docs subdirs (docs/articles/, docs/plans/, docs/dispatch-templates/)
    are linkable through the prefix-allowlist path.
  - Non-allowlisted root files and traversal sequences are still rejected.

Origin: operator reported on /review/T-2274 that "Human AC section does
not produce full usable links: for example README.md & docs/articles/
launch-article.md". Reproduced via curl on 2026-06-09. RCA in
docs/reports/T-2275-auto-linker-rca.md traces to two structural gaps:
prefix list missing docs/articles/, and `startswith()` check
structurally excluding depth-0 paths. This test file pins both legs of
Candidate 2 — explicit ROOT_FILES allowlist plus three new prefixes.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.shared import (
    ROOT_FILES,
    VIEWABLE_DIR_PREFIXES,
    _auto_link_files,
    is_viewable_path,
)


# ---------------------------------------------------------------------------
# is_viewable_path — structural surface
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("path", sorted(ROOT_FILES))
def test_root_files_are_viewable(path):
    """All 6 named root files pass the viewable-path check (allowlist branch)."""
    assert is_viewable_path(path) is True, (
        f"{path!r} must be viewable — ROOT_FILES allowlist branch in is_viewable_path"
    )


def test_random_root_file_is_not_viewable():
    """A root file NOT in the allowlist is rejected — allowlist, not generic depth-0 rule."""
    assert is_viewable_path("random_root_file.md") is False
    assert is_viewable_path("setup.py") is False
    assert is_viewable_path("Dockerfile") is False


def test_traversal_in_root_file_still_rejected():
    """Path-traversal guard takes precedence over the ROOT_FILES allowlist."""
    assert is_viewable_path("../README.md") is False
    assert is_viewable_path("..") is False


def test_docs_articles_is_viewable():
    """docs/articles/ is in VIEWABLE_DIR_PREFIXES and serves the operator's repro path."""
    assert "docs/articles/" in VIEWABLE_DIR_PREFIXES
    assert is_viewable_path("docs/articles/launch-article.md") is True


def test_docs_plans_and_dispatch_templates_are_viewable():
    """New T-2281 prefixes work end-to-end."""
    assert is_viewable_path("docs/plans/some-plan.md") is True
    assert is_viewable_path("docs/dispatch-templates/iw-spike-worker.md") is True


# ---------------------------------------------------------------------------
# _auto_link_files — end-to-end rendering surface
# ---------------------------------------------------------------------------

def test_existing_root_file_gets_linkified():
    """README.md exists at PROJECT_ROOT → auto-linker wraps it in `<a href="/file/README.md">`."""
    html = "see <p>README.md</p> for setup"
    result = _auto_link_files(html)
    assert '<a href="/file/README.md">README.md</a>' in result


def test_root_file_inside_path_is_not_linkified():
    """`docs/foo/README.md` must not be misinterpreted as a standalone root reference.

    The root-file branch has a lookbehind that refuses matches when a
    path-body character precedes the filename — `docs/foo/README.md`
    would only be matched if `docs/foo/` were a VIEWABLE prefix (it isn't).
    """
    html = "see <p>docs/foo/README.md</p> for prose"
    result = _auto_link_files(html)
    # Should NOT have wrapped the standalone README.md tail
    assert "/file/README.md" not in result


def test_nonexistent_root_file_not_linkified():
    """CHANGELOG is in ROOT_FILES but doesn't exist at PROJECT_ROOT → no link emitted (existence-gated)."""
    # Pre-flight: confirm CHANGELOG truly doesn't exist (otherwise this test is
    # invalid). If a future maintainer adds CHANGELOG to the repo, switch this
    # assertion to a path that doesn't exist.
    from web.shared import PROJECT_ROOT
    if (PROJECT_ROOT / "CHANGELOG").exists():
        pytest.skip("CHANGELOG now exists at root — test premise no longer holds")
    html = "<p>CHANGELOG entries follow conventional commits</p>"
    result = _auto_link_files(html)
    # Existence guard refuses to wrap a non-existent path
    assert "/file/CHANGELOG" not in result


def test_existing_docs_article_gets_linkified():
    """docs/articles/launch-article.md gets `<a href="/file/...">` IF the file exists."""
    from web.shared import PROJECT_ROOT
    if not (PROJECT_ROOT / "docs/articles/launch-article.md").exists():
        pytest.skip("docs/articles/launch-article.md not present — operator-repro target absent")
    html = "<p>see docs/articles/launch-article.md</p>"
    result = _auto_link_files(html)
    assert '<a href="/file/docs/articles/launch-article.md">' in result


def test_idempotency_root_file_already_linked():
    """If a root-file path is already wrapped in `<a href="...">`, don't double-wrap."""
    pre_linked = '<a href="/file/README.md">README.md</a>'
    result = _auto_link_files(pre_linked)
    # Count of <a tags must not increase
    assert result.count('<a href="/file/') == pre_linked.count('<a href="/file/')


def test_docs_reports_path_still_works_no_regression():
    """The pre-T-2281 prefix path still works — no regression on the original T-1722 surface."""
    from web.shared import PROJECT_ROOT
    artifact = PROJECT_ROOT / "docs/reports/T-2277-watchtower-csrf-pollution.md"
    if not artifact.exists():
        pytest.skip("T-2277 artifact absent — switch to any existing docs/reports/ file")
    rel = str(artifact.relative_to(PROJECT_ROOT))
    html = f"<p>see {rel} for RCA</p>"
    result = _auto_link_files(html)
    assert f'<a href="/file/{rel}">' in result
