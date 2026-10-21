"""T-3736: unmatched bare names must not each re-walk the tree.

/inception pages took minutes (279 s measured): every miss forced a basename-index
rebuild once the index was 3 s old, and under load a walk took longer than that.
Resolving many unmatched names in one go must cost at most one index build and
one whole-tree walk.

T-4547: these tests count walks, so they neither read the clock nor the disk.
Against the real clock and the real tree the counts only held while the walk and
the loop fitted in the 30 s TTL, which a loaded host does not guarantee. A fake
monotonic clock moves only when a test moves it, and the walks yield an empty
tree (every name below is a miss either way).
"""
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import web.shared as shared  # noqa: E402


def _freeze_clock(monkeypatch):
    """Replace time.monotonic (web.shared reads it at call time) with a clock
    that moves only when the test moves it. Returns the mutable cell."""
    clock = [1000.0]
    monkeypatch.setattr(time, "monotonic", lambda: clock[0])
    return clock


def _count_walks(monkeypatch, builds, tree_cost=0.0, index_cost=0.0, clock=None):
    """Count whole-tree walks and index builds over an empty tree; a walk may
    advance the fake clock by `*_cost` seconds, as a slow walk would."""
    real_build = shared._build_basename_index

    def counting_build(now):
        builds["index"] += 1
        if clock is not None:
            clock[0] += index_cost
        return real_build(now)

    def counting_walk(top, *a, **kw):
        if Path(top) == Path(shared.PROJECT_ROOT):
            builds["tree"] += 1
            if clock is not None:
                clock[0] += tree_cost
        return iter(())

    monkeypatch.setattr(shared, "_build_basename_index", counting_build)
    monkeypatch.setattr(shared.os, "walk", counting_walk)


def _reset():
    shared._BASENAME_INDEX["built"] = 0.0
    shared._BASENAME_INDEX["index"] = {}
    shared._TREE_NAMES["built"] = 0.0
    shared._TREE_NAMES["names"] = frozenset()


def test_many_misses_build_index_and_walk_tree_at_most_once(monkeypatch):
    _freeze_clock(monkeypatch)
    _reset()
    builds = {"index": 0, "tree": 0}
    _count_walks(monkeypatch, builds)

    for i in range(200):
        # task-shaped (exercises _exists_anywhere) and generic misses
        shared._resolve_bare_name(f"T-99{i:03d}-no-such-report.md")
        shared._resolve_bare_name(f"no_such_file_{i}.yaml")

    assert builds["index"] <= 1, builds
    assert builds["tree"] <= 1, builds


def test_concurrent_misses_share_one_build(monkeypatch):
    _freeze_clock(monkeypatch)
    _reset()
    builds = {"index": 0}
    real_build = shared._build_basename_index

    def slow_counting_build(now):
        builds["index"] += 1
        time.sleep(0.2)  # a slow walk, as under load
        return real_build(now)

    monkeypatch.setattr(shared, "_build_basename_index", slow_counting_build)
    monkeypatch.setattr(shared.os, "walk", lambda top, *a, **kw: iter(()))
    threads = [threading.Thread(target=shared._resolve_bare_name, args=(f"miss_{i}.md",))
               for i in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert builds["index"] == 1, builds


def test_tree_walk_slower_than_ttl_is_not_redone(monkeypatch):
    """T-4547: a walk that outlasts the TTL (a loaded host) must not publish a
    cache that is already stale, or every following miss walks again."""
    clock = _freeze_clock(monkeypatch)
    _reset()
    builds = {"index": 0, "tree": 0}
    _count_walks(monkeypatch, builds, tree_cost=40.0, clock=clock)

    for i in range(20):
        shared._resolve_bare_name(f"T-99{i:03d}-no-such-report.md")

    assert builds["tree"] == 1, builds


def test_index_build_slower_than_ttl_is_not_redone(monkeypatch):
    clock = _freeze_clock(monkeypatch)
    _reset()
    builds = {"index": 0, "tree": 0}
    _count_walks(monkeypatch, builds, index_cost=40.0, clock=clock)

    for i in range(20):
        shared._resolve_bare_name(f"no_such_file_{i}.yaml")

    assert builds["index"] == 1, builds
