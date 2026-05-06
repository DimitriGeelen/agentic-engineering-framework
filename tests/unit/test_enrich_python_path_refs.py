"""T-1758 — Regression tests for fabric enrich's Python path-ref detector.

Pre-fix: enrich.py's Python detector handled `from X import Y` and a few Flask
patterns, but missed the dominant test-file shapes:
  - Pathlib slash-chain: REPO_ROOT / "bin" / "fw"
  - Literal framework paths: "agents/handover/handover.sh"
  - Bare bin/fw in subprocess args

Contract: detect_python_path_refs emits edges for these three patterns,
deduped by (target, etype), with self-references and unknown targets skipped.
Mirrors the detect_bats_deps shape (T-1754).
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "agents" / "fabric" / "lib"))

import enrich  # noqa: E402


@pytest.fixture
def fw_root(tmp_path):
    """Synthetic framework tree with the targets the test refs expect."""
    (tmp_path / "agents" / "handover").mkdir(parents=True)
    (tmp_path / "agents" / "handover" / "handover.sh").write_text("#!/bin/bash\n")
    (tmp_path / "lib").mkdir()
    (tmp_path / "lib" / "arc.sh").write_text("#!/bin/bash\n")
    (tmp_path / "tools").mkdir()
    (tmp_path / "tools" / "g064-readiness.py").write_text("# stub\n")
    (tmp_path / "bin").mkdir()
    (tmp_path / "bin" / "fw").write_text("#!/bin/bash\n")
    return str(tmp_path)


def _targets(edges):
    return sorted({t for t, _ in edges})


def test_pathlib_slash_chain_two_segments(fw_root):
    """REPO_ROOT / "bin" / "fw" → bin/fw."""
    content = '''
from pathlib import Path
REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"
'''
    edges = enrich.detect_python_path_refs(content, "tests/unit/test_x.py", fw_root)
    assert "bin/fw" in _targets(edges)


def test_pathlib_slash_chain_three_segments(fw_root):
    """FRAMEWORK_ROOT / "agents" / "handover" / "handover.sh"."""
    content = '''
TEXT = (FRAMEWORK_ROOT / "agents" / "handover" / "handover.sh").read_text()
'''
    edges = enrich.detect_python_path_refs(content, "tests/unit/test_y.py", fw_root)
    assert "agents/handover/handover.sh" in _targets(edges)


def test_literal_quoted_framework_path(fw_root):
    """Literal "agents/handover/handover.sh" in any string context."""
    content = '''
result = subprocess.run(["bash", "agents/handover/handover.sh"])
'''
    edges = enrich.detect_python_path_refs(content, "tests/unit/test_z.py", fw_root)
    assert "agents/handover/handover.sh" in _targets(edges)


def test_bare_bin_fw_reference(fw_root):
    """`bin/fw` appearing bare in subprocess args."""
    content = '''
proc = subprocess.run(["bash", "bin/fw", "audit"])
'''
    edges = enrich.detect_python_path_refs(content, "tests/unit/test_w.py", fw_root)
    assert "bin/fw" in _targets(edges)


def test_tools_python_path(fw_root):
    """Python tools referenced as literal paths."""
    content = '''
TOOL = "tools/g064-readiness.py"
'''
    edges = enrich.detect_python_path_refs(content, "tests/unit/test_t.py", fw_root)
    assert "tools/g064-readiness.py" in _targets(edges)


def test_dedupes_within_same_edge_type(fw_root):
    """Multiple matches of the same (target, type) collapse to one edge."""
    content = '''
A = REPO_ROOT / "bin" / "fw"
B = REPO_ROOT / "bin" / "fw"
C = "bin/fw"
D = subprocess.run(["bin/fw", "audit"])
'''
    edges = enrich.detect_python_path_refs(content, "tests/unit/test_d.py", fw_root)
    fw_edges = [e for e in edges if e[0] == "bin/fw"]
    assert len(fw_edges) == 1
    assert fw_edges[0][1] == "calls"


def test_no_self_reference(fw_root):
    """A file referencing its own path must not emit an edge to itself."""
    self_path = "lib/arc.sh"
    content = 'PATH = REPO_ROOT / "lib" / "arc.sh"\n'
    edges = enrich.detect_python_path_refs(content, self_path, fw_root)
    assert self_path not in _targets(edges)


def test_unknown_target_is_skipped(fw_root):
    """Pattern matches but target does not exist on disk → no edge."""
    content = 'PATH = REPO_ROOT / "agents" / "ghost" / "missing.py"\n'
    edges = enrich.detect_python_path_refs(content, "tests/unit/test_u.py", fw_root)
    assert _targets(edges) == []


def test_empty_file_yields_no_edges(fw_root):
    edges = enrich.detect_python_path_refs("", "tests/unit/empty.py", fw_root)
    assert edges == []


def test_mixed_pathlib_and_literal(fw_root):
    """Combined patterns produce all expected edges (different targets)."""
    content = '''
FW = REPO_ROOT / "bin" / "fw"
HANDOVER = "agents/handover/handover.sh"
ARC = REPO_ROOT / "lib" / "arc.sh"
'''
    edges = enrich.detect_python_path_refs(content, "tests/unit/test_m.py", fw_root)
    targets = _targets(edges)
    assert "bin/fw" in targets
    assert "agents/handover/handover.sh" in targets
    assert "lib/arc.sh" in targets
