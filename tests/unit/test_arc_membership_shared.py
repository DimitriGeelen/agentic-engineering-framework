"""T-1880 (T-NEW-15): pin shared Python API for arc-membership scans.

Sibling to tests/unit/test_arc_membership_web_surfaces.py (which pins
consumer-site behaviour). This file pins the SHARED LIBRARY itself.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from lib.arc_membership import (  # noqa: E402
    scan_tasks_by_arc_id,
    scan_tasks_by_arc_membership,
    task_has_arc_membership,
)


@pytest.fixture
def synth_root(tmp_path: Path) -> Path:
    """Synthetic PROJECT_ROOT with the 6-task fixture pattern used in
    tests/unit/arc_membership_shared.bats. Same fixture shape across
    shell/python tests so coverage parity is enforceable.
    """
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)

    # 1: legacy-tag-only
    (tmp_path / ".tasks/active/T-9001-legacy-only.md").write_text(
        "---\nid: T-9001\narc_id:\ntags: [arc:test-arc-x, build]\n---\nbody\n"
    )
    # 2: arc_id-only
    (tmp_path / ".tasks/active/T-9002-arc-id-only.md").write_text(
        "---\nid: T-9002\narc_id: test-arc-x\ntags: [build]\n---\nbody\n"
    )
    # 3: both
    (tmp_path / ".tasks/completed/T-9003-both.md").write_text(
        "---\nid: T-9003\narc_id: test-arc-x\ntags: [arc:test-arc-x, build]\n---\nbody\n"
    )
    # 4: other arc
    (tmp_path / ".tasks/active/T-9004-other-arc.md").write_text(
        "---\nid: T-9004\narc_id: some-other-arc\ntags: [arc:some-other-arc]\n---\nbody\n"
    )
    # 5: no arc
    (tmp_path / ".tasks/active/T-9005-no-arc.md").write_text(
        "---\nid: T-9005\ntags: [build]\n---\nbody\n"
    )
    # 6: body-only arc: mention (negative — must NOT match)
    (tmp_path / ".tasks/active/T-9006-body-mention.md").write_text(
        "---\nid: T-9006\ntags: [build]\n---\nbody mentions arc:test-arc-x here\n"
    )
    return tmp_path


# ─── scan_tasks_by_arc_membership ──────────────────────────────────────


def test_scan_membership_returns_arc_id_and_tag_indices(synth_root: Path):
    by_arc_id, by_tag = scan_tasks_by_arc_membership(synth_root)
    # arc_id index: T-9002 and T-9003 have arc_id=test-arc-x
    assert sorted(by_arc_id.get("test-arc-x", [])) == ["T-9002", "T-9003"]
    # tag index: T-9001 and T-9003 have arc:test-arc-x tag
    assert sorted(by_tag.get("arc:test-arc-x", [])) == ["T-9001", "T-9003"]


def test_scan_membership_empty_root(tmp_path: Path):
    by_arc_id, by_tag = scan_tasks_by_arc_membership(tmp_path)
    assert by_arc_id == {}
    assert by_tag == {}


def test_scan_membership_excludes_null_arc_id(synth_root: Path):
    # T-9001 has `arc_id:` (empty/null) — must not appear in by_arc_id.
    by_arc_id, _ = scan_tasks_by_arc_membership(synth_root)
    # Ensure no key is empty/null/~ and T-9001 not under test-arc-x
    assert "" not in by_arc_id
    assert "null" not in by_arc_id
    assert "~" not in by_arc_id
    assert "T-9001" not in by_arc_id.get("test-arc-x", [])


def test_scan_membership_union_dedup_3_tasks(synth_root: Path):
    by_arc_id, by_tag = scan_tasks_by_arc_membership(synth_root)
    # Union dedup yields exactly 3 tasks for test-arc-x.
    union = set(by_arc_id.get("test-arc-x", [])) | set(by_tag.get("arc:test-arc-x", []))
    assert union == {"T-9001", "T-9002", "T-9003"}


# ─── scan_tasks_by_arc_id ──────────────────────────────────────────────


def test_scan_by_arc_id_returns_relative_paths(synth_root: Path):
    by_arc = scan_tasks_by_arc_id(synth_root)
    paths = by_arc.get("test-arc-x", [])
    # Two paths: T-9002 (active) and T-9003 (completed).
    assert len(paths) == 2
    # Relative-to-root strings.
    assert any("T-9002" in p for p in paths)
    assert any("T-9003" in p for p in paths)
    # And explicitly relative (no leading slash, no tmp prefix).
    for p in paths:
        assert not p.startswith("/")
        assert ".tasks/" in p


def test_scan_by_arc_id_other_arc(synth_root: Path):
    by_arc = scan_tasks_by_arc_id(synth_root)
    # T-9004 → some-other-arc, single entry.
    assert "some-other-arc" in by_arc
    assert len(by_arc["some-other-arc"]) == 1


# ─── task_has_arc_membership ───────────────────────────────────────────


def test_task_has_arc_membership_arc_id_only(synth_root: Path):
    assert task_has_arc_membership(
        synth_root / ".tasks/active/T-9002-arc-id-only.md"
    )


def test_task_has_arc_membership_legacy_tag_only(synth_root: Path):
    assert task_has_arc_membership(
        synth_root / ".tasks/active/T-9001-legacy-only.md"
    )


def test_task_has_arc_membership_both(synth_root: Path):
    assert task_has_arc_membership(
        synth_root / ".tasks/completed/T-9003-both.md"
    )


def test_task_has_arc_membership_neither(synth_root: Path):
    assert not task_has_arc_membership(
        synth_root / ".tasks/active/T-9005-no-arc.md"
    )


def test_task_has_arc_membership_body_only_mention_does_not_match(
    synth_root: Path,
):
    """Frontmatter-scoped: body string `arc:test-arc-x` must NOT count."""
    assert not task_has_arc_membership(
        synth_root / ".tasks/active/T-9006-body-mention.md"
    )


def test_task_has_arc_membership_missing_file(tmp_path: Path):
    assert not task_has_arc_membership(tmp_path / "T-NOPE.md")
