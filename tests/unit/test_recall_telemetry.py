"""Recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a).

What these tests are actually guarding
--------------------------------------
The tempting version of this test file asserts "a row gets written". That
version passes against an implementation that writes three rows per query, or
that loses the row whenever the query fails, or that silently writes nothing
because the directory is unwritable. All three are the failure this signal
exists to prevent, and all three are invisible to a test that only counts
"more than zero".

So each guarantee here is asserted in both directions, and the re-entrancy
guard is mutation-verified rather than assumed: `hybrid_search` reaches the
semantic path through the *public* `search`, so a test that says "one row"
would pass for the wrong reason if the code routed around the guard instead of
relying on it.
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import recall_telemetry as T  # noqa: E402
from web.embed_health import EmbedHealth, EmbedUnavailable  # noqa: E402


@pytest.fixture(autouse=True)
def _isolated_log(tmp_path, monkeypatch):
    """Every test writes to its own log, and starts with clean counters."""
    log = tmp_path / "recall-telemetry.jsonl"
    monkeypatch.setenv("FW_RECALL_TELEMETRY_PATH", str(log))
    monkeypatch.setitem(T._state, "written", 0)
    monkeypatch.setitem(T._state, "write_failures", 0)
    monkeypatch.setitem(T._state, "last_error", None)
    return log


def _rows(log):
    if not log.exists():
        return []
    return [json.loads(line) for line in log.read_text().splitlines() if line.strip()]


# --------------------------------------------------------------------------
# One row per outermost recall
# --------------------------------------------------------------------------

def test_a_single_recall_writes_exactly_one_row(_isolated_log):
    with T.record(T.SURFACE_SEMANTIC, "how does dispatch work") as r:
        r.observe([{"path": "a.md", "score": 0.7}])

    rows = _rows(_isolated_log)
    assert len(rows) == 1
    assert rows[0]["surface"] == T.SURFACE_SEMANTIC
    assert rows[0]["outcome"] == T.HIT
    assert rows[0]["n_hits"] == 1


def test_a_nested_recall_does_not_write_its_own_row(_isolated_log):
    """The whole point of the guard: one user query is one row, not two.

    Without this, `hybrid_search` (which calls `search`) would double every
    row — inflating the usage count by exactly the factor nobody would think
    to check, since both numbers look plausible.
    """
    with T.record(T.SURFACE_HYBRID, "outer") as outer:
        with T.record(T.SURFACE_SEMANTIC, "outer") as inner:
            inner.observe([{"path": "a.md", "score": 0.5}])
        outer.observe([{"path": "a.md", "score": 0.5}])

    rows = _rows(_isolated_log)
    assert len(rows) == 1, f"expected one row for one query, got {rows}"
    # And it is the *outer* surface that is recorded — the user asked for a
    # hybrid search, not for the semantic leg of one.
    assert rows[0]["surface"] == T.SURFACE_HYBRID


def test_depth_is_restored_so_the_next_recall_still_counts(_isolated_log):
    """A leaked depth counter would silence every subsequent query forever."""
    with T.record(T.SURFACE_HYBRID, "first") as outer:
        with T.record(T.SURFACE_SEMANTIC, "first") as inner:
            inner.observe([])
        outer.observe([{"path": "a.md", "score": 0.5}])

    assert T._depth.get() == 0

    with T.record(T.SURFACE_SEMANTIC, "second") as r:
        r.observe([{"path": "b.md", "score": 0.5}])

    assert len(_rows(_isolated_log)) == 2


def test_depth_is_restored_even_when_the_body_raises(_isolated_log):
    """The failing path is the one that must not poison later counting."""
    with pytest.raises(RuntimeError):
        with T.record(T.SURFACE_SEMANTIC, "boom"):
            raise RuntimeError("nope")

    assert T._depth.get() == 0

    with T.record(T.SURFACE_SEMANTIC, "after") as r:
        r.observe([{"path": "a.md", "score": 0.5}])

    assert len(_rows(_isolated_log)) == 2


# --------------------------------------------------------------------------
# The failing recall is the row you most want, and the one most easily lost
# --------------------------------------------------------------------------

def test_an_unavailable_embed_path_still_writes_a_row(_isolated_log):
    health = EmbedHealth(status="ollama-down", detail="connection refused")
    with pytest.raises(EmbedUnavailable):
        with T.record(T.SURFACE_SEMANTIC, "anything"):
            raise EmbedUnavailable(health)

    rows = _rows(_isolated_log)
    assert len(rows) == 1
    assert rows[0]["outcome"] == T.UNAVAILABLE
    assert rows[0]["embed_status"] == "ollama-down"


def test_the_original_exception_is_not_swallowed(_isolated_log):
    """Telemetry observes; it must never change what the caller sees."""
    health = EmbedHealth(status="contention", detail="server busy")
    with pytest.raises(EmbedUnavailable) as caught:
        with T.record(T.SURFACE_SEMANTIC, "q"):
            raise EmbedUnavailable(health)

    assert caught.value.status == "contention"


def test_an_unclassified_exception_still_earns_a_row(_isolated_log):
    """A recall that blew up is a recall that was attempted.

    Silence here would be the original T-3004 bug in miniature — the failure
    that leaves no trace is the one that runs for five months.
    """
    with pytest.raises(ValueError):
        with T.record(T.SURFACE_RAG, "q"):
            raise ValueError("something else entirely")

    rows = _rows(_isolated_log)
    assert rows[0]["outcome"] == T.UNAVAILABLE
    assert rows[0]["embed_status"] == "ValueError"


# --------------------------------------------------------------------------
# Query text lands exactly where it will be read — asserted both directions
# --------------------------------------------------------------------------

def test_a_miss_row_carries_the_query_text(_isolated_log):
    with T.record(T.SURFACE_SEMANTIC, "obscure unindexed topic") as r:
        r.observe([])

    row = _rows(_isolated_log)[0]
    assert row["outcome"] == T.MISS
    assert row["query"] == "obscure unindexed topic"


def test_a_hit_row_carries_only_the_hash(_isolated_log):
    with T.record(T.SURFACE_SEMANTIC, "well indexed topic") as r:
        r.observe([{"path": "a.md", "score": 0.9}])

    row = _rows(_isolated_log)[0]
    assert row["outcome"] == T.HIT
    assert "query" not in row, "hit rows must not retain raw query text"
    assert row["query_hash"] == T.query_hash("well indexed topic")


# --------------------------------------------------------------------------
# T-3021 — a recall that returns rows but retrieved nothing is a MISS.
#
# These assert a SHAPE, not a value: "rows returned at top_score 0 is not a
# hit" is true at any corpus size, with no threshold to tune and nothing to
# grow stale. The rule they replace (`n_hits > 0`) was a value assertion that
# happened to hold only while the index was sparse.
# --------------------------------------------------------------------------

def test_rows_returned_at_zero_score_are_a_miss_not_a_hit(_isolated_log):
    """The defect, pinned. Unthresholded KNN returns neighbours for gibberish.

    Live shape from the populated index: `zqxjv wombat photosynthesis quarterly`
    → 9 rows, every score clamped to 0. Under the old `n_hits > 0` rule this was
    recorded as a 9-hit success.
    """
    with T.record(T.SURFACE_SEMANTIC, "zqxjv wombat photosynthesis quarterly") as r:
        r.observe([{"path": f"noise{i}.md", "score": 0} for i in range(9)])

    row = _rows(_isolated_log)[0]
    assert row["outcome"] == T.MISS, (
        "9 rows at similarity 0 is the retriever saying nothing was within "
        "rankable range — not nine successes"
    )
    assert row["n_hits"] == 9, "the row count is still reported; only its meaning changed"


def test_the_miss_that_now_fires_retains_its_query_text(_isolated_log):
    """Why this defect mattered beyond the metric.

    Query text is kept on misses only. While misses could not fire, no query
    text was ever retained, so T-3005 slice 6b (miss-driven reindex priority)
    had no corpus to rank. This is the join that unblocks it.
    """
    with T.record(T.SURFACE_SEMANTIC, "postgres vacuum autovacuum tuning") as r:
        r.observe([{"path": "x.md", "score": 0}, {"path": "y.md", "score": 0}])

    row = _rows(_isolated_log)[0]
    assert row["outcome"] == T.MISS
    assert row["query"] == "postgres vacuum autovacuum tuning"


def test_a_barely_positive_score_is_still_a_hit(_isolated_log):
    """The floor sits at the clamp boundary and nowhere above it.

    0.016 was the weakest genuine known-good query measured on the live index.
    If someone later 'tightens' this into a tuned relevance threshold, this
    goes red — which is the point.
    """
    with T.record(T.SURFACE_SEMANTIC, "large file scan pre-push") as r:
        r.observe([{"path": "a.md", "score": 0.016}])

    assert _rows(_isolated_log)[0]["outcome"] == T.HIT


def test_unscored_rows_are_trusted_rather_than_reclassified(_isolated_log):
    """A surface that returns no numeric score is not thereby a miss."""
    with T.record(T.SURFACE_RAG, "some query") as r:
        r.observe([{"path": "a.md"}, {"path": "b.md"}])

    assert _rows(_isolated_log)[0]["outcome"] == T.HIT


def test_zero_rows_remains_a_miss(_isolated_log):
    """The old rule's true positives are still true positives."""
    with T.record(T.SURFACE_SEMANTIC, "nothing at all") as r:
        r.observe([])

    assert _rows(_isolated_log)[0]["outcome"] == T.MISS


def test_miss_rate_is_non_zero_once_miss_class_queries_are_present(_isolated_log):
    """The summary field an operator actually reads."""
    with T.record(T.SURFACE_SEMANTIC, "good") as r:
        r.observe([{"path": "a.md", "score": 0.4}])
    with T.record(T.SURFACE_SEMANTIC, "gibberish") as r:
        r.observe([{"path": "b.md", "score": 0}])

    s = T.usage_summary(window_days=1.0)
    assert s["rows"] == 2
    assert s["misses"] == 1
    assert s["miss_rate"] == 0.5


def test_an_unavailable_row_carries_the_query_text(_isolated_log):
    """Same reasoning as a miss: you cannot re-run what you did not record."""
    with pytest.raises(EmbedUnavailable):
        with T.record(T.SURFACE_SEMANTIC, "lost question"):
            raise EmbedUnavailable(EmbedHealth(status="ollama-down", detail="x"))

    assert _rows(_isolated_log)[0]["query"] == "lost question"


def test_query_hash_is_stable_across_casing_and_whitespace(_isolated_log):
    assert T.query_hash("How  Does\tDispatch Work") == T.query_hash("how does dispatch work")
    assert T.query_hash("a") != T.query_hash("b")


# --------------------------------------------------------------------------
# Write failures degrade observability, never the search (L-331)
# --------------------------------------------------------------------------

def test_a_write_failure_does_not_reach_the_caller(monkeypatch, _isolated_log):
    monkeypatch.setenv("FW_RECALL_TELEMETRY_PATH", "/proc/nonexistent/cannot/write.jsonl")

    # No exception escapes: the search that this wraps must still return.
    with T.record(T.SURFACE_SEMANTIC, "q") as r:
        r.observe([{"path": "a.md", "score": 0.5}])

    assert T.recall_telemetry_state()["write_failures"] == 1


def test_a_write_failure_is_counted_not_swallowed(monkeypatch, _isolated_log):
    """"No rows" and "rows we could not write" must stay separable.

    Collapsing them is how a log reads empty for a month and everyone
    concludes nobody is searching.
    """
    monkeypatch.setenv("FW_RECALL_TELEMETRY_PATH", "/proc/nonexistent/x.jsonl")

    with T.record(T.SURFACE_SEMANTIC, "q") as r:
        r.observe([])

    state = T.recall_telemetry_state()
    assert state["written"] == 0
    assert state["write_failures"] == 1
    assert "Error" in str(state["last_error"]) or state["last_error"]


def test_successful_writes_are_counted(_isolated_log):
    with T.record(T.SURFACE_SEMANTIC, "q") as r:
        r.observe([{"path": "a.md", "score": 0.5}])

    assert T.recall_telemetry_state()["written"] == 1
    assert T.recall_telemetry_state()["write_failures"] == 0


# --------------------------------------------------------------------------
# Reading the log back
# --------------------------------------------------------------------------

def test_a_malformed_line_does_not_destroy_the_signal(_isolated_log):
    """One torn write must not convert into total loss of the usage signal."""
    _isolated_log.write_text(
        '{"ts":"2026-08-15T10:00:00Z","outcome":"hit","latency_ms":5}\n'
        'this is not json at all\n'
        '{"ts":"2026-08-15T10:00:01Z","outcome":"miss","latency_ms":6}\n'
        '{"truncated": \n'
    )
    rows = T.read_rows()
    assert len(rows) == 2
    assert [r["outcome"] for r in rows] == ["hit", "miss"]


def test_a_missing_log_reads_as_empty_not_as_an_error(_isolated_log):
    assert T.read_rows() == []
    assert T.usage_summary()["rows"] == 0


def test_the_window_excludes_older_rows(_isolated_log):
    import calendar, time

    now = time.time()
    fresh = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 3600))
    stale = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 30 * 86400))
    _isolated_log.write_text(
        json.dumps({"ts": stale, "outcome": "hit", "latency_ms": 1}) + "\n"
        + json.dumps({"ts": fresh, "outcome": "hit", "latency_ms": 1}) + "\n"
    )

    assert len(T.read_rows(since_seconds=7 * 86400)) == 1
    assert len(T.read_rows()) == 2


def test_timestamps_are_read_as_utc_under_a_non_utc_host_timezone(monkeypatch):
    """The local-time misread is invisible unless the test supplies an offset.

    Worth spelling out, because the first two versions of this test were both
    wrong in instructive ways. Writing a row "an hour ago" and asserting it
    falls inside a two-hour window fails on a UTC+2 host and passes on a UTC
    one. Pinning the absolute epoch instead does *not* fix that: under TZ=UTC
    `time.mktime` and `calendar.timegm` are the same function, so there is no
    defect there to detect — verified by mutating the implementation and
    watching it stay green under TZ=UTC.

    The offset is therefore not an environmental nuisance to be factored out;
    it is the input the defect needs in order to exist. So the test supplies
    one rather than inheriting whatever the host happens to have, and is
    discriminating in UTC CI and on a developer laptop alike.
    """
    import datetime
    import time as _time

    monkeypatch.setenv("TZ", "Asia/Kolkata")  # UTC+5:30 — and never DST-equal to UTC
    _time.tzset()
    try:
        # Oracle from datetime with an explicit UTC tzinfo — independent of the
        # strptime/timegm pair under test, rather than the implementation
        # agreeing with itself.
        expected = datetime.datetime(
            2026, 8, 15, 12, 0, 0, tzinfo=datetime.timezone.utc
        ).timestamp()
        assert T.parse_ts("2026-08-15T12:00:00Z") == expected == 1786795200
    finally:
        monkeypatch.undo()
        _time.tzset()


def test_an_unreadable_timestamp_is_none_rather_than_an_exception():
    assert T.parse_ts("not a timestamp") is None
    assert T.parse_ts(None) is None
    assert T.parse_ts("2026-08-15 12:00:00") is None


# --------------------------------------------------------------------------
# usage_summary — the shape the doctor verdict consumes
# --------------------------------------------------------------------------

def test_usage_summary_separates_the_three_outcomes(_isolated_log):
    for q, results in [("a", [{"path": "x", "score": 0.5}]), ("b", []), ("c", [])]:
        with T.record(T.SURFACE_SEMANTIC, q) as r:
            r.observe(results)
    with pytest.raises(EmbedUnavailable):
        with T.record(T.SURFACE_SEMANTIC, "d"):
            raise EmbedUnavailable(EmbedHealth(status="ollama-down", detail="x"))

    s = T.usage_summary()
    assert s["rows"] == 4
    assert s["hits"] == 1
    assert s["misses"] == 2
    assert s["unavailable"] == 1


def test_miss_rate_is_none_rather_than_zero_when_there_are_no_rows(_isolated_log):
    """A rate over zero samples is a number that looks like an answer."""
    s = T.usage_summary()
    assert s["rows"] == 0
    assert s["miss_rate"] is None
    assert s["median_latency_ms"] is None


# --------------------------------------------------------------------------
# Through the real recall surfaces
#
# The tests above exercise `record` directly, which proves the guard works in
# isolation and proves nothing about whether the recall functions use it. These
# drive the actual `search` / `hybrid_search` / `rag_retrieve` entry points.
#
# This is the pair that mutation-discriminates: `_hybrid_search` calls the
# *public* `search`, so the one-row assertion below only holds because the
# re-entrancy guard suppresses the nested row. Delete the guard and this goes
# red. Route `_hybrid_search` around `search` instead and the guard becomes
# untestable — which is exactly the shape that let an earlier mutation test in
# this arc pass against broken code.
# --------------------------------------------------------------------------

class _FakeDB:
    """Returns one vec row: (id, distance, path, title, category, task_id, text)."""

    def __init__(self, rows):
        self._rows = rows

    def execute(self, sql, params=()):
        self._last = sql
        return self

    def fetchall(self):
        return self._rows

    def fetchone(self):
        return ("chunk text",)


@pytest.fixture
def _fake_recall(monkeypatch):
    """Wire the recall surfaces to fixtures, leaving telemetry entirely real."""
    from web import embeddings as E
    import web.search as WS

    rows = [(1, 0.2, "docs/a.md", "A", "docs", "T-1", "chunk about dispatch")]
    monkeypatch.setattr(E, "_get_db", lambda: _FakeDB(rows))
    monkeypatch.setattr(E, "_embed_single", lambda q: b"\x00" * 4)
    monkeypatch.setattr(WS, "search", lambda q, limit=20: {"categories": {}})
    # rerank() is a separate concern and may reach for a model; identity is
    # the honest stand-in for "ranking happened".
    monkeypatch.setattr(E, "rerank", lambda q, c, top_k=10: c[:top_k])
    return E


def test_search_writes_one_row(_fake_recall, _isolated_log):
    result = _fake_recall.search("dispatch")
    assert result["total_hits"] == 1

    rows = _rows(_isolated_log)
    assert len(rows) == 1
    assert rows[0]["surface"] == T.SURFACE_SEMANTIC
    assert rows[0]["outcome"] == T.HIT


def test_hybrid_search_writes_one_row_not_two(_fake_recall, _isolated_log):
    """`hybrid_search` calls the public `search`. One query, one row.

    Mutation check: removing the re-entrancy guard in `recall_telemetry.record`
    turns this red with len(rows) == 2.
    """
    result = _fake_recall.hybrid_search("dispatch")
    assert result["total_hits"] >= 1

    rows = _rows(_isolated_log)
    assert len(rows) == 1, f"one query must be one row, got {len(rows)}: {rows}"
    assert rows[0]["surface"] == T.SURFACE_HYBRID


def test_rag_retrieve_writes_one_row(_fake_recall, _isolated_log):
    out = _fake_recall.rag_retrieve("dispatch")
    assert isinstance(out, list)

    rows = _rows(_isolated_log)
    assert len(rows) == 1
    assert rows[0]["surface"] == T.SURFACE_RAG


def test_a_dead_embed_path_leaves_a_row_behind(_fake_recall, _isolated_log):
    """The outage case, end to end: search raises and the row survives.

    This is the row that did not exist during the five-month T-3004 outage,
    and its absence is why nobody could say when recall stopped working.
    """
    def _dead(_query):
        raise EmbedUnavailable(EmbedHealth(status="ollama-down", detail="refused"))

    _fake_recall._embed_single = _dead
    import web.embeddings as E
    E._embed_single = _dead

    with pytest.raises(EmbedUnavailable):
        E.search("dispatch")

    rows = _rows(_isolated_log)
    assert len(rows) == 1
    assert rows[0]["outcome"] == T.UNAVAILABLE
    assert rows[0]["embed_status"] == "ollama-down"
    assert rows[0]["query"] == "dispatch"


def test_observe_accepts_a_search_result_dict(_isolated_log):
    """`search()` returns a dict; `rag_retrieve()` returns a list. Both work."""
    with T.record(T.SURFACE_SEMANTIC, "q") as r:
        r.observe({"query": "q", "total_hits": 2,
                   "results": [{"path": "a", "score": 0.4},
                               {"path": "b", "score": 0.9}]})

    row = _rows(_isolated_log)[0]
    assert row["n_hits"] == 2
    assert row["top_score"] == 0.9
