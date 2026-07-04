"""T-100140: regression tests for the 2026-07-04 Watchtower livelock class.

Root cause: get_all_task_metadata() re-parsed YAML for the full task corpus
(~2.5k files, ~10s) on every 30s-TTL expiry, with no rebuild lock — under
host load the rebuild outran the TTL, every request paid it, and concurrent
pollers stampeded the threaded dev server into a 135-thread GIL livelock.

Pinned contracts:
 1. TTL rebuild is per-file mtime-cached — unchanged files are not re-parsed.
 2. Single-flight — while one thread rebuilds, others serve the stale
    snapshot instead of stampeding.
 3. load_yaml is mtime-cached and returns copies (mutation cannot poison
    the cache); parse errors still surface on every call (T-403 contract).
"""

import sys
import textwrap
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import web.shared as sh  # noqa: E402


@pytest.fixture()
def task_corpus(tmp_path, monkeypatch):
    """Small task corpus under a temp PROJECT_ROOT with clean caches."""
    for sub in ("active", "completed"):
        (tmp_path / ".tasks" / sub).mkdir(parents=True)
    for i, sub in ((1, "active"), (2, "active"), (3, "completed")):
        (tmp_path / ".tasks" / sub / f"T-{i:03d}-x.md").write_text(
            textwrap.dedent(f"""\
            ---
            id: T-{i:03d}
            name: "task {i}"
            status: captured
            ---
            body
            """)
        )
    monkeypatch.setattr(sh, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(sh, "_FM_FILE_CACHE", {})
    monkeypatch.setattr(
        sh, "_task_cache", {"data": None, "names": None, "tags": None, "ts": 0}
    )
    return tmp_path


def test_ttl_rebuild_skips_unchanged_files(task_corpus, monkeypatch):
    calls = []
    real = sh._parse_task_frontmatter

    def counting(path):
        calls.append(path.name)
        return real(path)

    monkeypatch.setattr(sh, "_parse_task_frontmatter", counting)

    data1 = sh.get_all_task_metadata()
    assert len(data1) == 3
    assert len(calls) == 3  # cold: every file parsed

    # Expire the TTL; only the touched file may be re-parsed
    sh._task_cache["ts"] = 0
    changed = task_corpus / ".tasks" / "active" / "T-001-x.md"
    changed.write_text(changed.read_text().replace("task 1", "task 1 edited"))
    calls.clear()
    data2 = sh.get_all_task_metadata()
    assert len(data2) == 3
    assert calls == ["T-001-x.md"]
    assert any(t["name"] == "task 1 edited" for t in data2)


def test_single_flight_serves_stale_without_blocking(task_corpus):
    data1 = sh.get_all_task_metadata()
    sh._task_cache["ts"] = 0  # expired
    # Simulate a rebuild in flight on another thread
    assert sh._task_cache_lock.acquire(blocking=False)
    try:
        stale = sh.get_all_task_metadata()
        assert stale is data1  # served the previous snapshot, no deadlock
    finally:
        sh._task_cache_lock.release()


def test_caller_mutation_does_not_poison_next_rebuild(task_corpus):
    data1 = sh.get_all_task_metadata()
    data1[0]["name"] = "MUTATED"
    sh._task_cache["ts"] = 0
    data2 = sh.get_all_task_metadata()
    assert all(t["name"] != "MUTATED" for t in data2)


def test_load_yaml_mtime_cached_and_copy_safe(tmp_path, monkeypatch):
    monkeypatch.setattr(sh, "_LOAD_YAML_CACHE", {})
    f = tmp_path / "data.yaml"
    f.write_text("items:\n  - a\n  - b\n")

    d1 = sh.load_yaml(f)
    d1["items"].append("MUTATION")
    d2 = sh.load_yaml(f)
    assert d2 == {"items": ["a", "b"]}  # cache not poisoned
    assert d1 is not d2

    # mtime change invalidates
    f.write_text("items:\n  - c\n")
    import os
    os.utime(f, ns=(1, 1))  # force distinct mtime_ns regardless of clock res
    assert sh.load_yaml(f) == {"items": ["c"]}


def test_load_yaml_error_resurfaces_every_call(tmp_path, monkeypatch):
    monkeypatch.setattr(sh, "_LOAD_YAML_CACHE", {})
    f = tmp_path / "bad.yaml"
    f.write_text("key: [unclosed\n")
    assert sh.load_yaml(f, label="bad") == {}
    sh.get_yaml_errors()  # drain
    assert sh.load_yaml(f, label="bad") == {}  # cached error path
    errs = sh.get_yaml_errors()
    assert errs and "bad" in errs[0]  # T-403: still surfaced on cache hit
