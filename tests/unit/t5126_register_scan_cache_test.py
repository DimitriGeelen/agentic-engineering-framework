"""T-5126 (1409 msg 0fe0e269): find_register_docs remembers, per doc and keyed by (mtime_ns,
size), whether it holds a register, so a long-lived Watchtower no longer re-reads every
docs/**/*.md on each request. New, changed and deleted docs are still picked up."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE / "lib"))

import design_register as dr  # noqa: E402

REG = "# Design\n\n```yaml\nregister:\n  - id: R-1\n    text: thing\n    owner_task: T-0001\n    status: open\n```\n"
PLAIN = "# Notes\n\nno register here\n"


@pytest.fixture(autouse=True)
def _fresh_cache():
    dr._REGISTER_SCAN_CACHE.clear()
    yield
    dr._REGISTER_SCAN_CACHE.clear()


def _root(tmp_path: Path) -> Path:
    (tmp_path / "docs" / "sub").mkdir(parents=True)
    (tmp_path / "docs" / "plain.md").write_text(PLAIN)
    return tmp_path


def _names(root: Path) -> list[str]:
    return [p.name for p in dr.find_register_docs(root)]


def _bump(p: Path, text: str) -> None:
    st = p.stat()
    p.write_text(text)
    os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns + 10_000_000))


def test_a_register_doc_is_found_and_a_plain_one_is_not(tmp_path):
    root = _root(tmp_path)
    (root / "docs" / "sub" / "design.md").write_text(REG)
    assert dr.parse_register(root / "docs" / "sub" / "design.md"), "fixture must be a real register"
    assert _names(root) == ["design.md"]


def test_an_unchanged_doc_is_not_read_again(tmp_path, monkeypatch):
    root = _root(tmp_path)
    _names(root)
    reads = []
    real = Path.read_text
    monkeypatch.setattr(Path, "read_text", lambda self, *a, **k: (reads.append(self.name), real(self, *a, **k))[1])
    _names(root)
    assert "plain.md" not in reads


def test_a_new_register_doc_is_picked_up(tmp_path):
    root = _root(tmp_path)
    assert _names(root) == []
    (root / "docs" / "new.md").write_text(REG)
    assert _names(root) == ["new.md"]


def test_a_doc_that_gains_a_register_is_picked_up(tmp_path):
    root = _root(tmp_path)
    assert _names(root) == []
    _bump(root / "docs" / "plain.md", REG)
    assert _names(root) == ["plain.md"]


def test_a_doc_that_loses_its_register_drops_out(tmp_path):
    root = _root(tmp_path)
    d = root / "docs" / "design.md"
    d.write_text(REG)
    assert _names(root) == ["design.md"]
    _bump(d, PLAIN)
    assert _names(root) == []


def test_a_deleted_doc_drops_out(tmp_path):
    root = _root(tmp_path)
    d = root / "docs" / "design.md"
    d.write_text(REG)
    assert _names(root) == ["design.md"]
    d.unlink()
    assert _names(root) == []


def test_results_are_identical_cold_and_warm_on_this_repo():
    cold = dr.find_register_docs(_HERE)
    viol_cold = dr.register_violations(_HERE)
    warm = dr.find_register_docs(_HERE)
    viol_warm = dr.register_violations(_HERE)
    assert cold == warm
    assert viol_cold == viol_warm
