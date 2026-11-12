"""T-5106 (1409): an unbounded .context/working/ (2.58M files) froze every Watchtower page,
because the basename index and the "does this file exist anywhere" walk went through all of it
under a lock every page needs. Both walks now take only the top-level files of
.context/working/, stop at a file-count or time budget, and fail open: a name they could not
reach stays plain text and is never marked dead."""
import logging
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import web.shared as shared  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    for rel in ("docs/reports/T-1-report.md", "docs/reports/T-2-report.md",
                ".context/working/focus.yaml",
                ".context/working/arbeitsplaetze/w1/T-77-deep.md",
                ".context/working/scratch/deep.yaml"):
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("x\n")
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    shared._BASENAME_INDEX.update({"built": 0.0, "index": {}, "truncated": False})
    shared._TREE_NAMES.update({"built": 0.0, "names": frozenset(), "truncated": False})
    shared._WALK_WARNED.clear()
    return tmp_path


def test_working_dir_contributes_only_its_top_level_files(proj):
    idx = shared._basename_index(force_fresh=True)
    assert idx.get("focus.yaml") == [".context/working/focus.yaml"]
    assert "T-77-deep.md" not in idx and "deep.yaml" not in idx
    assert idx.get("T-1-report.md") == ["docs/reports/T-1-report.md"]
    assert shared._BASENAME_INDEX["truncated"] is False


def test_tree_walk_skips_working_subfolders(proj):
    assert shared._exists_anywhere("T-1-report.md")
    assert shared._exists_anywhere("focus.yaml")
    assert not shared._exists_anywhere("T-77-deep.md")
    assert not shared._exists_anywhere("T-999-nowhere.md")


def test_file_budget_truncates_logs_once_and_fails_open(proj, monkeypatch, caplog):
    monkeypatch.setattr(shared, "_WALK_MAX_FILES", 1)
    with caplog.at_level(logging.WARNING):
        shared._basename_index(force_fresh=True)
        assert shared._BASENAME_INDEX["truncated"] is True
        # an unknown name on a truncated tree walk counts as "exists": never marked dead
        assert shared._exists_anywhere("T-999-nowhere.md")
        shared._TREE_NAMES["built"] = 0.0
        shared._exists_anywhere("T-998-nowhere.md")
    warnings = [r for r in caplog.records if "T-5106" in r.getMessage()]
    assert len(warnings) == 2           # one per walk kind, not one per rebuild


def test_time_budget_truncates(proj, monkeypatch):
    monkeypatch.setattr(shared, "_WALK_MAX_SECONDS", -1.0)   # already past the deadline
    shared._basename_index(force_fresh=True)
    assert shared._BASENAME_INDEX["truncated"] is True


def test_a_truncated_walk_never_produces_a_dead_link(proj, monkeypatch):
    monkeypatch.setattr(shared, "_WALK_MAX_FILES", 1)
    state, _target, _detail = shared._resolve_ref("T-999-nowhere.md")
    assert state != "dead"
