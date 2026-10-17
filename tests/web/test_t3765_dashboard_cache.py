"""T-3765: one changed task file must not re-read the whole corpus for arc membership.

The dashboard's arc-membership index is cached under the task-directory signature, so
any change to any task file misses it. Before the fix every miss re-read the frontmatter
of every task on the request thread. The fix keeps a per-file memo, so a miss re-reads
only the files whose (mtime_ns, size) moved.

Every test here runs IN-PROCESS against a committed-style tmp corpus; none touches the
operator's live Watchtower.
"""

import os
import sys
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import arc_membership  # noqa: E402

N_TASKS = 40


def _task(path: Path, tid: str, arc_id: str | None = None, tags: str = "[]") -> None:
    lines = ["---", f"id: {tid}", f"name: \"task {tid}\"", "status: started-work", f"tags: {tags}"]
    if arc_id:
        lines.append(f"arc_id: {arc_id}")
    lines += ["---", "", f"# {tid}", ""]
    path.write_text("\n".join(lines))


@pytest.fixture
def corpus(tmp_path):
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir()
    for i in range(N_TASKS):
        _task(active / f"T-{i:04d}-x.md", f"T-{i:04d}", arc_id="arc-001" if i % 2 else None)
    return tmp_path


@pytest.fixture
def read_counter(monkeypatch):
    calls = {"n": 0}
    real = arc_membership._read_head

    def counting(path):
        calls["n"] += 1
        return real(path)

    monkeypatch.setattr(arc_membership, "_read_head", counting)
    return calls


def test_membership_is_correct_with_memo(corpus):
    """The memo must not change the answer: same indices as the uncached scan."""
    memo = {}
    by_arc, by_tag = arc_membership.scan_tasks_by_arc_membership(corpus, file_memo=memo)
    assert len(by_arc["arc-001"]) == N_TASKS // 2
    assert by_tag == {}
    assert arc_membership.scan_tasks_by_arc_membership(corpus) == (by_arc, by_tag)


def test_unchanged_corpus_rereads_nothing(corpus, read_counter):
    memo = {}
    arc_membership.scan_tasks_by_arc_membership(corpus, file_memo=memo)
    assert read_counter["n"] == N_TASKS
    read_counter["n"] = 0
    arc_membership.scan_tasks_by_arc_membership(corpus, file_memo=memo)
    assert read_counter["n"] == 0


def test_one_changed_task_rereads_one_file(corpus, read_counter):
    """The regression: before the fix one touched file re-read all N_TASKS files."""
    memo = {}
    arc_membership.scan_tasks_by_arc_membership(corpus, file_memo=memo)
    read_counter["n"] = 0
    target = corpus / ".tasks" / "active" / "T-0003-x.md"
    st = target.stat()
    os.utime(target, ns=(st.st_atime_ns, st.st_mtime_ns + 1_000_000_000))
    arc_membership.scan_tasks_by_arc_membership(corpus, file_memo=memo)
    assert read_counter["n"] == 1


def test_changed_arc_membership_is_seen(corpus):
    """A memo hit must not hide a real membership change."""
    memo = {}
    arc_membership.scan_tasks_by_arc_membership(corpus, file_memo=memo)
    target = corpus / ".tasks" / "active" / "T-0004-x.md"
    _task(target, "T-0004", arc_id="arc-002")
    by_arc, _ = arc_membership.scan_tasks_by_arc_membership(corpus, file_memo=memo)
    assert "T-0004" in by_arc["arc-002"]
    assert "T-0004" not in by_arc.get("arc-001", [])


def test_dashboard_index_uses_memo_across_signature_change(corpus, read_counter, monkeypatch):
    """The wiring: core._arc_membership_index passes the per-file memo through."""
    from web import shared
    from web.blueprints import core

    monkeypatch.setattr(core, "PROJECT_ROOT", corpus)
    monkeypatch.setattr(shared, "PROJECT_ROOT", corpus)
    core._arc_membership_index()
    read_counter["n"] = 0
    target = corpus / ".tasks" / "active" / "T-0005-x.md"
    st = target.stat()
    os.utime(target, ns=(st.st_atime_ns, st.st_mtime_ns + 1_000_000_000))
    core._arc_membership_index()
    assert read_counter["n"] == 1
