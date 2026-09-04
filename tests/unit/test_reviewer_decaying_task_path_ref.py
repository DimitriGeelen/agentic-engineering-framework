"""T-3274: pin the decaying-`.tasks/active/` verification-reference detector.

A verification line that pins another task by its `.tasks/active/<T-XXXX>` path
passes at close and becomes a permanent false-red once that task moves to
`.tasks/completed/`. The detector must flag exactly that decayed shape — and
must stay silent on the three neighbouring shapes that look similar but are
fine, because a detector that fires on live sibling references would cry wolf
on nearly every task that coordinates with another.

Both directions are asserted deliberately. A test that only proves the detector
fires cannot distinguish "works" from "always fires".
"""

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


@pytest.fixture()
def corpus(tmp_path):
    """A minimal .tasks/ tree: one active task, one completed task."""
    tasks = tmp_path / ".tasks"
    (tasks / "active").mkdir(parents=True)
    (tasks / "completed").mkdir(parents=True)
    (tasks / "active" / "T-2000-still-going.md").write_text("live\n")
    (tasks / "completed" / "T-1000-all-done.md").write_text("done\n")
    # The task doing the referencing — its own location is what anchors the
    # detector's walk up to `.tasks/`.
    subject = tasks / "completed" / "T-1234-subject.md"
    subject.write_text("subject\n")
    return subject


def test_flags_decayed_reference(corpus):
    """Referenced task has moved to completed/ — the line can never pass again."""
    line = "grep -q PATTERN .tasks/active/T-1000-*.md"
    findings = ss.detect_decaying_task_path_ref(line, str(corpus))
    assert len(findings) == 1
    assert findings[0].pattern_id == "decaying-task-path-ref"
    assert "T-1000" in findings[0].evidence


def test_silent_on_live_reference(corpus):
    """Referenced task is still in active/ — a legitimate in-flight reference."""
    line = "grep -q PATTERN .tasks/active/T-2000-*.md"
    assert ss.detect_decaying_task_path_ref(line, str(corpus)) == []


def test_silent_on_tray_agnostic_form(corpus):
    """The documented repair — `.tasks/*/` matches wherever the task lives."""
    line = "grep -q PATTERN .tasks/*/T-1000-*.md"
    assert ss.detect_decaying_task_path_ref(line, str(corpus)) == []


def test_silent_on_comment_lines(corpus):
    """Comments are not executed, so they cannot decay into a false red."""
    line = "# see .tasks/active/T-1000-*.md for context"
    assert ss.detect_decaying_task_path_ref(line, str(corpus)) == []


def test_silent_when_tasks_dir_unresolvable(corpus):
    """Without a resolvable .tasks/ tree the detector cannot tell decayed from
    live, so it must stay silent rather than guess."""
    line = "grep -q PATTERN .tasks/active/T-1000-*.md"
    assert ss.detect_decaying_task_path_ref(line, None) == []
    assert ss.detect_decaying_task_path_ref(line, "/nonexistent/x.md") == []


def test_self_reference_decays_too(corpus):
    """The shape that blocked all 14 CTL-028 backfills in T-3265 round 3: a
    completed task whose verification greps its own former active/ path."""
    line = "grep -q 'status:' .tasks/active/T-1234-*.md"
    findings = ss.detect_decaying_task_path_ref(line, str(corpus))
    assert len(findings) == 1
    assert "T-1234" in findings[0].evidence


def test_mixed_line_reports_only_decayed_refs(corpus):
    """One line naming both a live and a decayed task is still broken, and the
    evidence must name the decayed one — that is what the author has to fix."""
    line = "cat .tasks/active/T-2000-*.md .tasks/active/T-1000-*.md"
    findings = ss.detect_decaying_task_path_ref(line, str(corpus))
    assert len(findings) == 1
    # Evidence is "<decayed ids> no longer in active/ — <raw line>". The raw
    # line legitimately contains both ids; only the id LIST must be narrowed
    # to the decayed one, since that is what the author has to fix.
    decayed_ids = findings[0].evidence.split(" no longer in active/")[0]
    assert decayed_ids == "T-1000"


def test_reports_line_number(corpus):
    """Location must point at the offending line, not the block."""
    block = "\n".join(
        [
            "echo fine",
            "# a comment",
            "grep -q PATTERN .tasks/active/T-1000-*.md",
        ]
    )
    findings = ss.detect_decaying_task_path_ref(block, str(corpus))
    assert len(findings) == 1
    assert findings[0].location == "Verification:line 3"


def test_registered_in_anti_patterns_yaml():
    """The advisory and the reviewer both resolve the pattern through the
    registry; an unregistered detector is invisible to `fw reviewer`."""
    import yaml

    data = yaml.safe_load((ROOT / "policy" / "anti-patterns.yaml").read_text())
    patterns = data.get("patterns", data) if isinstance(data, dict) else data
    ids = {p["id"] for p in patterns if isinstance(p, dict) and "id" in p}
    assert "decaying-task-path-ref" in ids
