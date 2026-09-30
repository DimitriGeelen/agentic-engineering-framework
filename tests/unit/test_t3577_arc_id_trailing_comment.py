"""T-3577 - an unquoted trailing `# comment` is not part of an arc_id value.

Origin: .tasks/completed/T-3440 carried `arc_id: arc-001   # T-3440: ...` and was
silently dropped from arc-001. Fixtures are constructed (T-3326).
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
import arc_membership as A  # noqa: E402


def _tree(tmp_path, arc_line):
    d = tmp_path / ".tasks" / "active"
    d.mkdir(parents=True)
    (d / "T-1-x.md").write_text(f"---\nid: T-1\nname: x\ntags: []\n{arc_line}\n---\n# body\n")
    return tmp_path


@pytest.mark.parametrize("line,expected", [
    ("arc_id: arc-001   # T-3440: note", "arc-001"),   # the T-3440 shape
    ("arc_id: arc-001", "arc-001"),                     # no comment: unchanged
    ('arc_id: "arc-001"  # note', "arc-001"),
    ('arc_id: "a#b"', "a#b"),                           # quoted '#' is not a comment
    ("arc_id: a#b", "a#b"),                             # no whitespace before '#': not a comment
])
def test_scan_resolves_value(tmp_path, line, expected):
    root = _tree(tmp_path, line)
    by_id, _ = A.scan_tasks_by_arc_membership(root)
    assert by_id == {expected: ["T-1"]}
    assert list(A.scan_tasks_by_arc_id(root)) == [expected]
    assert A.task_has_arc_membership(next((root / ".tasks/active").iterdir()))


def test_comment_only_value_is_unset(tmp_path):
    root = _tree(tmp_path, "arc_id:   # nothing here")
    assert A.scan_tasks_by_arc_membership(root)[0] == {}
    assert not A.task_has_arc_membership(next((root / ".tasks/active").iterdir()))
