"""Pytest configuration for web/ test suite.

T-1823 — `framework_repo` marker + auto-skip on consumer projects.

Some tests in this file assert framework-repo fixture data (G-001 in
/gaps, 001-Vision in /project, "Watchtower v" in the footer). They will
fail on consumer projects whose data shape is different. Rather than
remove them — they're load-bearing for framework-dev — we mark them and
let pytest skip on consumers.

Consumer mode is detected via the same heuristic `fw doctor` uses
(T-574): FRAMEWORK_ROOT != PROJECT_ROOT. Both env vars are exported by
the `fw` shim on every invocation; running pytest outside `fw test` (or
without those env vars set) is treated as framework-repo mode so local
hacking still exercises the full suite.
"""

import os

import pytest


def _is_consumer_mode() -> bool:
    """Return True when running on a consumer project (not the framework repo).

    Mirrors the FRAMEWORK_ROOT vs PROJECT_ROOT comparison in `bin/fw`
    (the doctor's `Check 9: Test infrastructure` block).
    """
    framework_root = os.environ.get("FRAMEWORK_ROOT")
    project_root = os.environ.get("PROJECT_ROOT")
    if not framework_root or not project_root:
        # No fw env → assume framework-repo mode (local hacking).
        return False
    return os.path.realpath(framework_root) != os.path.realpath(project_root)


def pytest_configure(config):
    """Register the `framework_repo` marker so pytest doesn't warn."""
    config.addinivalue_line(
        "markers",
        "framework_repo: test assumes framework-repo fixture data "
        "(skipped on consumer projects).",
    )


def pytest_collection_modifyitems(config, items):
    """Auto-skip `framework_repo`-marked tests on consumer projects."""
    if not _is_consumer_mode():
        return
    skip_marker = pytest.mark.skip(
        reason="framework_repo-only test — running on a consumer project "
        "(FRAMEWORK_ROOT != PROJECT_ROOT)."
    )
    for item in items:
        if "framework_repo" in item.keywords:
            item.add_marker(skip_marker)
