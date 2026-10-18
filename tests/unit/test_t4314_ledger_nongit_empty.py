"""T-4314: in a project that is not a git repository, the verdict-ledger audit reports no
fault when there is nothing to verify (no ledger rows), and still fails closed when rows exist.

Origin: audit_corpus_lint_findings.bats / audit_seed_corpus_refs.bats build non-git fixture
projects with no ledger; `fw audit` exited 2 there on every release since the T-3581 check.
"""

import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LEDGER = REPO / "lib" / "verdict_ledger.py"


def _audit(root: Path) -> subprocess.CompletedProcess:
    env = dict(os.environ, PROJECT_ROOT=str(root), GIT_CEILING_DIRECTORIES=str(root.parent))
    return subprocess.run([sys.executable, str(LEDGER), "audit"], cwd=str(root), env=env,
                          capture_output=True, text=True, timeout=120)


def _project(tmp_path: Path) -> Path:
    root = tmp_path / "proj"
    (root / ".tasks" / "active").mkdir(parents=True)
    (root / ".context" / "reviews").mkdir(parents=True)
    return root


def test_no_ledger_no_git_is_not_a_fault(tmp_path):
    root = _project(tmp_path)
    r = _audit(root)
    out = r.stdout + r.stderr
    assert "git cannot answer" not in out, out
    assert r.returncode == 0, out


def test_blank_ledger_no_git_is_not_a_fault(tmp_path):
    root = _project(tmp_path)
    (root / ".context" / "reviews" / "verdicts.jsonl").write_text("\n \n")
    r = _audit(root)
    out = r.stdout + r.stderr
    assert "git cannot answer" not in out, out
    assert r.returncode == 0, out


def test_rows_without_git_still_fail_closed(tmp_path):
    root = _project(tmp_path)
    (root / ".context" / "reviews" / "verdicts.jsonl").write_text('{"id": "V-x", "task": "T-1"}\n')
    r = _audit(root)
    out = r.stdout + r.stderr
    assert "git cannot answer" in out, out
    assert r.returncode != 0, out
