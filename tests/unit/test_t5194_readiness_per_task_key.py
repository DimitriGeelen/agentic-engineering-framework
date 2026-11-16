"""T-5194: a task's cached review readiness depends only on the review-ledger rows that can
concern it (plus a global fingerprint of rows that name no task), not on every
.context/reviews/*.jsonl mtime.

Before: one append for ANY task invalidated every awaiting task (T-5186 F4). The fixture
below is a throwaway project; the readiness computation is a stand-in that reads the
fixture ledgers, so the test is about the cache key, not about verdict_ledger.
"""
import json
import os
import sys
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import shared  # noqa: E402

TASKS = ("T-9001", "T-9002", "T-9003")


def _rows(root: Path, name: str) -> list:
    f = root / ".context" / "reviews" / name
    if not f.exists():
        return []
    out = []
    for ln in f.read_text().splitlines():
        try:
            out.append(json.loads(ln))
        except ValueError:
            continue
    return out


def truth(root: Path, task_id: str) -> tuple:
    """From-scratch readiness over the fixture ledgers: READY iff the task's newest verdict
    is green, its dispatch has a completion (looked up by dispatch id only), and no global
    freeze row exists."""
    if any(r.get("freeze") for r in _rows(root, "notes.jsonl")):
        return shared.WAITING_ON_AGENT, ("frozen",)
    mine = [r for r in _rows(root, "verdicts.jsonl") if r.get("task") == task_id]
    if not mine or mine[-1]["outcome"] != "green":
        return shared.WAITING_ON_AGENT, ("not green",)
    disp = {r["dispatch_id"] for r in _rows(root, "dispatches.jsonl") if r.get("task") == task_id}
    done = {r["dispatch_id"] for r in _rows(root, "completions.jsonl")}
    if not disp & done:
        return shared.WAITING_ON_AGENT, ("no completion",)
    return shared.READY, ()


@pytest.fixture()
def rig(tmp_path, monkeypatch):
    (tmp_path / ".context" / "reviews").mkdir(parents=True)
    paths = {}
    for tid in TASKS:
        p = tmp_path / f"{tid}-x.md"
        p.write_text(f"---\nid: {tid}\n---\n")
        paths[tid] = p
    calls: dict = {t: 0 for t in TASKS}

    def fake_compute(task_id, body, root, path, stamp, used=None):
        calls[task_id] += 1
        if used is not None:
            used.append(True)
        return truth(root, task_id)

    monkeypatch.setattr(shared, "PROJECT_ROOT", str(tmp_path))
    monkeypatch.setattr(shared, "_compute_readiness", fake_compute)
    monkeypatch.setattr(shared, "_git_generation", lambda root: (0, 0))
    monkeypatch.setattr(shared, "_task_git_generation", lambda root, tid: 0)
    shared._READINESS_CACHE.clear()
    shared._LEDGER_INDEX.clear()
    yield tmp_path, paths, calls
    t = shared._READINESS_REFRESH_THREAD.get("t")
    if t is not None:
        t.join(timeout=5)
    shared._READINESS_CACHE.clear()
    shared._LEDGER_INDEX.clear()


def append(root: Path, name: str, row) -> None:
    with open(root / ".context" / "reviews" / name, "a") as fh:
        fh.write((row if isinstance(row, str) else json.dumps(row)) + "\n")


def ask(paths, tid, **kw):
    return shared.review_readiness(tid, "", "", paths[tid], **kw)[0]


def seed(root):
    for i, tid in enumerate(TASKS):
        append(root, "dispatches.jsonl", {"dispatch_id": f"d{i}", "task": tid})
        append(root, "verdicts.jsonl", {"id": f"v{i}", "task": tid, "outcome": "red"})


def test_an_append_naming_x_recomputes_x_only(rig):
    root, paths, calls = rig
    seed(root)
    for t in TASKS:
        ask(paths, t)
    base = dict(calls)
    append(root, "verdicts.jsonl", {"id": "v9", "task": "T-9001", "outcome": "green"})
    for t in TASKS:
        ask(paths, t)
    assert calls["T-9001"] == base["T-9001"] + 1
    assert calls["T-9002"] == base["T-9002"]          # reused
    assert calls["T-9003"] == base["T-9003"]


def test_a_row_tied_to_x_by_its_dispatch_id_recomputes_x(rig):
    root, paths, calls = rig
    seed(root)
    append(root, "verdicts.jsonl", {"id": "v9", "task": "T-9001", "outcome": "green"})
    assert ask(paths, "T-9001") == shared.WAITING_ON_AGENT
    ask(paths, "T-9002")
    base = dict(calls)
    append(root, "completions.jsonl", {"dispatch_id": "d0", "kind": "completion"})  # names no task
    assert ask(paths, "T-9001") == shared.READY
    ask(paths, "T-9002")
    assert calls["T-9001"] == base["T-9001"] + 1
    assert calls["T-9002"] == base["T-9002"]


@pytest.mark.parametrize("change", ["no-task", "torn", "dup-id", "rewrite", "unterminated",
                                    "illegible-task", "lowercase-task"])
def test_a_change_no_task_owns_recomputes_everyone(rig, change):
    root, paths, calls = rig
    seed(root)
    for t in TASKS:
        ask(paths, t)
    base = dict(calls)
    f = root / ".context" / "reviews" / "verdicts.jsonl"
    if change == "no-task":
        append(root, "notes.jsonl", {"note": "hello"})
    elif change == "torn":
        append(root, "verdicts.jsonl", '{"task": "T-9001", "outc')
    elif change == "dup-id":
        append(root, "verdicts.jsonl", {"id": "v0", "task": "T-9002", "outcome": "red"})
    elif change == "illegible-task":
        # review #1: verdict_ledger refuses EVERY task on a verdicts row whose `task` is not
        # `T-<digits>`, even though its dispatch id names T-9001
        append(root, "verdicts.jsonl", {"id": "v8", "task": "?", "dispatch_id": "judge-t-9001-r2-bb",
                                        "outcome": "green"})
    elif change == "lowercase-task":
        append(root, "verdicts.jsonl", {"id": "v8", "task": "t-9001", "outcome": "green"})
    elif change == "rewrite":   # a committed row of T-9002 edited: the ledger refuses as a whole
        f.write_text(f.read_text().replace('"v1", "task": "T-9002", "outcome": "red"',
                                           '"v1", "task": "T-9002", "outcome": "reddd"'))
    else:
        with open(f, "a") as fh:
            fh.write('{"id": "v7", "task": "T-9002"')
    for t in TASKS:
        ask(paths, t)
    assert all(calls[t] == base[t] + 1 for t in TASKS), (change, calls, base)


def test_a_stale_ready_is_never_served(rig):
    root, paths, calls = rig
    seed(root)
    append(root, "verdicts.jsonl", {"id": "v9", "task": "T-9001", "outcome": "green"})
    append(root, "completions.jsonl", {"dispatch_id": "d0"})
    assert ask(paths, "T-9001") == shared.READY
    append(root, "verdicts.jsonl", {"id": "v10", "task": "T-9001", "outcome": "red"})
    assert ask(paths, "T-9001", allow_stale=True) == shared.WAITING_ON_AGENT
    append(root, "verdicts.jsonl", {"id": "v11", "task": "T-9001", "outcome": "green"})
    assert ask(paths, "T-9001") == shared.READY
    append(root, "notes.jsonl", {"freeze": True})
    assert ask(paths, "T-9001", allow_stale=True) == shared.WAITING_ON_AGENT


def test_cached_readiness_equals_a_from_scratch_computation_over_a_sequence_of_appends(rig):
    root, paths, calls = rig
    seed(root)
    steps = [
        ("verdicts.jsonl", {"id": "a1", "task": "T-9001", "outcome": "green"}),
        ("completions.jsonl", {"dispatch_id": "d0"}),
        ("verdicts.jsonl", {"id": "a2", "task": "T-9002", "outcome": "green"}),
        ("verdicts.jsonl", {"id": "a3", "task": "T-9003", "outcome": "green"}),
        ("completions.jsonl", {"dispatch_id": "d2"}),
        ("dispatches.jsonl", {"dispatch_id": "d5", "task": "T-9002"}),
        ("completions.jsonl", {"dispatch_id": "d5"}),
        ("verdicts.jsonl", {"id": "a4", "task": "T-9001", "outcome": "red"}),
        ("notes.jsonl", {"freeze": True}),
        ("verdicts.jsonl", {"id": "a5", "task": "T-9003", "outcome": "red",
                            "note": "also concerns T-9001"}),
    ]
    for t in TASKS:
        ask(paths, t)
    for name, row in steps:
        append(root, name, row)
        for t in TASKS:
            for stale in (False, True):
                got = ask(paths, t, allow_stale=stale)
                want = truth(root, t)[0]
                if stale and got != want:
                    # allow_stale may only under-report readiness, never over-report
                    assert got == shared.WAITING_ON_AGENT
                else:
                    assert got == want, (name, row, t, stale)


def test_the_index_is_built_once_per_stamp_not_once_per_task(rig, monkeypatch):
    root, paths, calls = rig
    seed(root)
    reads = {"n": 0}
    real = Path.read_bytes

    def counting(self):
        reads["n"] += 1
        return real(self)

    monkeypatch.setattr(Path, "read_bytes", counting)
    for t in TASKS:
        ask(paths, t)
    assert reads["n"] == 2          # two ledger files, read once each for all three tasks


def test_a_stamp_that_does_not_match_the_files_falls_back_to_the_whole_stamp(rig):
    root, paths, calls = rig
    seed(root)
    assert shared._ledger_index(root, ("not", "a", "real", "stamp")) is None
    real = shared._readiness_stamp(root)
    assert shared._readiness_task_key(root, "T-9001", ("x",)) == ("x",)
    assert shared._readiness_task_key(root, "T-9001", real)[1] == "idx"


def test_an_escaped_task_spelling_is_still_attributed_to_its_task(rig):
    # review #2: `"task":"T-9002"` is T-9002's row to the validator; it must move T-9002's key
    # even though the raw bytes only name T-9001 (in the dispatch id)
    root, paths, calls = rig
    seed(root)
    for t in TASKS:
        ask(paths, t)
    base = dict(calls)
    append(root, "verdicts.jsonl", '{"id": "v8", "task": "T\\u002d9002", "dispatch_id": "judge-t-9001-x", "outcome": "green"}')
    for t in TASKS:
        ask(paths, t)
    assert calls["T-9002"] == base["T-9002"] + 1
