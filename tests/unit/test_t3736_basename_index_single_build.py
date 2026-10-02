"""T-3736: unmatched bare names must not each re-walk the tree.

/inception pages took minutes (279 s measured): every miss forced a basename-index
rebuild once the index was 3 s old, and under load a walk took longer than that.
Resolving many unmatched names in one go must cost at most one index build and
one whole-tree walk.
"""
import sys
import threading
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import web.shared as shared  # noqa: E402


def _reset():
    shared._BASENAME_INDEX["built"] = 0.0
    shared._BASENAME_INDEX["index"] = {}
    shared._TREE_NAMES["built"] = 0.0
    shared._TREE_NAMES["names"] = frozenset()


def test_many_misses_build_index_and_walk_tree_at_most_once(monkeypatch):
    _reset()
    builds = {"index": 0, "tree": 0}
    real_build = shared._build_basename_index
    real_walk = shared.os.walk

    def counting_build(now):
        builds["index"] += 1
        return real_build(now)

    def counting_walk(top, *a, **kw):
        if Path(top) == Path(shared.PROJECT_ROOT):
            builds["tree"] += 1
        return real_walk(top, *a, **kw)

    monkeypatch.setattr(shared, "_build_basename_index", counting_build)
    monkeypatch.setattr(shared.os, "walk", counting_walk)

    for i in range(200):
        # task-shaped (exercises _exists_anywhere) and generic misses
        shared._resolve_bare_name(f"T-99{i:03d}-no-such-report.md")
        shared._resolve_bare_name(f"no_such_file_{i}.yaml")

    assert builds["index"] <= 1, builds
    assert builds["tree"] <= 1, builds


def test_concurrent_misses_share_one_build(monkeypatch):
    _reset()
    builds = {"index": 0}
    real_build = shared._build_basename_index

    def slow_counting_build(now):
        builds["index"] += 1
        import time
        time.sleep(0.2)  # a slow walk, as under load
        return real_build(now)

    monkeypatch.setattr(shared, "_build_basename_index", slow_counting_build)
    threads = [threading.Thread(target=shared._resolve_bare_name, args=(f"miss_{i}.md",))
               for i in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert builds["index"] == 1, builds
