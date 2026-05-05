"""T-1754 — Regression tests for fabric enrich's .bats parser.

Pre-fix: enrich.py only handled .sh and .py extensions, so all 50+ bats
files in tests/unit/ stayed edgeless even when they pointed at clear
system-under-test scripts.

Contract: detect_bats_deps emits edges for the common patterns:
  - VAR="$FRAMEWORK_ROOT/path.sh" assignments
  - bash "$REPO_ROOT/path" invocations
  - bare bin/fw references
  - literal framework paths (agents/.../*.sh, lib/*.sh, tools/*.py)
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "agents" / "fabric" / "lib"))

import enrich  # noqa: E402


@pytest.fixture
def fw_root(tmp_path):
    """Build a synthetic framework tree with the targets the test refs expect."""
    (tmp_path / "agents" / "audit").mkdir(parents=True)
    (tmp_path / "agents" / "audit" / "audit.sh").write_text("#!/bin/bash\n")
    (tmp_path / "lib").mkdir()
    (tmp_path / "lib" / "paths.sh").write_text("#!/bin/bash\n")
    (tmp_path / "tools").mkdir()
    (tmp_path / "tools" / "g064-readiness.py").write_text("# stub\n")
    (tmp_path / "bin").mkdir()
    (tmp_path / "bin" / "fw").write_text("#!/bin/bash\n")
    return str(tmp_path)


def _targets(edges):
    return sorted({t for t, _ in edges})


def test_var_assignment_to_framework_root_path(fw_root):
    content = """\
#!/usr/bin/env bats
setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "audit runs" {
    run bash "$AUDIT"
}
"""
    edges = enrich.detect_bats_deps(content, "tests/unit/audit_flock.bats", fw_root)
    assert "agents/audit/audit.sh" in _targets(edges)


def test_bash_repo_root_invocation(fw_root):
    content = """\
@test "fw gaps renders" {
    run bash "$REPO_ROOT/bin/fw" gaps
}
"""
    edges = enrich.detect_bats_deps(content, "tests/unit/test_fw_gaps.bats", fw_root)
    assert "bin/fw" in _targets(edges)


def test_bare_bin_fw_reference(fw_root):
    content = """\
@test "smoke" {
    run bin/fw audit
}
"""
    edges = enrich.detect_bats_deps(content, "tests/unit/smoke.bats", fw_root)
    assert "bin/fw" in _targets(edges)


def test_literal_path_in_quoted_argument(fw_root):
    content = """\
@test "lib loads" {
    source "lib/paths.sh"
}
"""
    edges = enrich.detect_bats_deps(content, "tests/unit/paths.bats", fw_root)
    assert "lib/paths.sh" in _targets(edges)


def test_empty_file_yields_no_edges(fw_root):
    edges = enrich.detect_bats_deps("", "tests/unit/empty.bats", fw_root)
    assert edges == []


def test_no_self_reference(fw_root):
    """Tests located AT a path must not emit an edge to themselves."""
    self_path = "agents/audit/audit.sh"
    content = 'AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"\n'
    edges = enrich.detect_bats_deps(content, self_path, fw_root)
    assert self_path not in _targets(edges)


def test_dedupes_within_same_edge_type(fw_root):
    """Multiple matches of the same (target, type) pair collapse to one edge."""
    content = """\
@test "a" { run bash "$REPO_ROOT/agents/audit/audit.sh"; }
@test "b" { run bash "$REPO_ROOT/agents/audit/audit.sh"; }
@test "c" { run bash "$REPO_ROOT/agents/audit/audit.sh"; }
"""
    edges = enrich.detect_bats_deps(content, "tests/unit/x.bats", fw_root)
    audit_edges = [e for e in edges if e[0] == "agents/audit/audit.sh"]
    # Same target, same type — one edge.
    assert len(audit_edges) == 1
    assert audit_edges[0][1] == "tests"


def test_unknown_target_is_skipped(fw_root):
    """Pattern matches but target does not exist on disk → no edge."""
    content = 'X="$FRAMEWORK_ROOT/agents/nonexistent/ghost.sh"\n'
    edges = enrich.detect_bats_deps(content, "tests/unit/x.bats", fw_root)
    assert _targets(edges) == []


def test_tools_python_path_reference(fw_root):
    """Bats tests sometimes invoke tools/*.py — covered by literal-path branch."""
    content = '@test "tool runs" { run python3 tools/g064-readiness.py --json; }\n'
    edges = enrich.detect_bats_deps(content, "tests/unit/g064.bats", fw_root)
    assert "tools/g064-readiness.py" in _targets(edges)
