"""Append-only recall telemetry — the "Used" signal (T-3019, T-3005 slice 6a).

Why this module exists
----------------------
The four signals in the T-3005 control architecture answer four different
questions about the vector substrate: is it *fresh*, is it *online*, is it
*correct*, and is it *used*. The first three now have controls. This is the
fourth, and it catches a failure the others cannot see.

A substrate can be fresh, online and correct while nobody queries it. That is
the G-064 zero-consumer shape: a subsystem that passes every health check it has
because every health check it has is the only thing exercising it. The framework
has shipped that failure before — a control whose sole caller was its own test.
Nothing goes red, because nothing is wrong; the thing is simply pointless, and
pointlessness has no error code.

So: one row per recall, and a doctor verdict that goes WARN when the log has no
rows in the window. Zero rows for a week does not mean recall is broken. It
means recall is not being used, which is a different problem with a different
remedy, and until now it was indistinguishable from working perfectly.

What a row is
-------------
One row per *outermost* recall call. `hybrid_search()` calls the semantic path
internally and `rag_retrieve()` calls `hybrid_search()`; those are implementation
detail, not three separate uses. Counting them separately would inflate the
"used" number by exactly the factor nobody would notice, which is the failure
mode of every metric that counts what is easy instead of what was asked. The
re-entrancy guard below is what makes one user query equal one row.

Query text, and why misses carry it
-----------------------------------
Every row carries `query_hash`. Only *miss* and *unavailable* rows carry the
query text itself.

Two reasons. The antifragile half of slice 6 reads this log to decide what to
reindex first — "agents keep asking about X and getting nothing" is only
actionable if you know what X was, and a hash is not X. But hit rows do not need
the text for anything, and writing it there would inflate the log to record what
was already answered. So the text is written exactly where it will be read.

This is a data-retention decision and it is the operator's, not ours: it is
filed as the one Human AC on T-3019.

Failure policy (L-331)
----------------------
Telemetry must never break a search. A write failure here degrades observability;
raising would degrade the thing being observed, which is a worse trade in every
case. So writes are guarded.

But guarded is not silent. Swallowed telemetry failures are how a log reads
empty for a month and everyone concludes nobody is searching. The failure count
is kept in memory and surfaced by `recall_telemetry_state()`, so "no rows" and
"rows we could not write" are answerable as different questions — which is the
same distinction (absence vs. fault) the whole T-3005 arc turns on.
"""

from __future__ import annotations

import calendar
import contextvars
import hashlib
import json
import logging
import os
import time
from pathlib import Path

log = logging.getLogger(__name__)

# Outcome classes. Deliberately three, not two: a recall that could not run is
# not a recall that found nothing, and collapsing them would hide an outage
# inside a miss count.
HIT = "hit"
MISS = "miss"
UNAVAILABLE = "unavailable"


def _found_something(n_hits, top_score) -> bool:
    """Did this recall actually retrieve anything, as opposed to merely return rows?

    Read `top_score`, not `n_hits`. `_semantic_search` is an unthresholded KNN —
    `k = limit * 3`, no distance filter (web/embeddings.py:1134) — so it returns the
    nearest rows for *any* query vector. `n_hits == 0` therefore only holds when the
    index is empty, which the Fresh/Online/Correct signals already cover. Classifying
    on it made the miss dimension incapable of firing: 35 rows, `miss_rate 0.0`, with
    `zqxjv wombat photosynthesis quarterly` recorded as a 9-hit success (T-3021).

    The threshold is not a tuned constant. `similarity = max(0, 1.0 - distance)`
    (web/embeddings.py:1147) clamps everything at or past L2 distance 1.0 to exactly
    zero, so `top_score == 0` is the retriever's own declaration that nothing came
    within its rankable range. Measured separation on the live index: every known-good
    query > 0 (min 0.016, median 0.106), every nonsense and plausible-but-absent query
    exactly 0.

    This is a floor, not a relevance threshold — it catches "found nothing at all",
    not "found something poor". A genuine query scoring 0.016 is barely clear of it.
    Deliberately not raised beyond the clamp boundary: any higher number would be
    invented rather than measured, and inventing one is how the previous rule got its
    apparent authority.
    """
    if n_hits <= 0:
        return False
    if top_score is None:
        # Rows came back carrying no numeric score at all — an unscored surface, not
        # a miss. Trust the row count rather than silently reclassifying it.
        return True
    return top_score > 0


# Surfaces. Named so a reader can tell which entry point was used without
# guessing from the shape of the row.
SURFACE_SEMANTIC = "semantic"
SURFACE_HYBRID = "hybrid"
SURFACE_RAG = "rag"

# Re-entrancy depth. A ContextVar rather than a module global so concurrent
# Flask requests cannot decrement each other's counter, and rather than
# threading.local so it also holds if any of this moves under async.
_depth: contextvars.ContextVar[int] = contextvars.ContextVar(
    "recall_telemetry_depth", default=0
)

# Not-silent-failure bookkeeping. See the module docstring: the point is that
# "nothing was written" and "we failed to write" stay separable afterwards.
_state: dict[str, object] = {
    "written": 0,
    "write_failures": 0,
    "last_error": None,
}


def telemetry_path() -> Path:
    """Where rows land. Config-resolved so consumers can relocate it."""
    from web.config import Config

    override = os.environ.get("FW_RECALL_TELEMETRY_PATH")
    if override:
        return Path(override)
    return Path(Config.VECTOR_DB_PATH).parent / "recall-telemetry.jsonl"


def recall_telemetry_state() -> dict:
    """Rows written, writes that failed, and the last error — this process only.

    Deliberately not read from the file: this answers "is the writer working?",
    and a reader that consults the artifact it is checking cannot distinguish an
    empty log from a broken pen.
    """
    return dict(_state)


def query_hash(query: str) -> str:
    """Stable short hash of a normalised query, for counting repeats."""
    normalised = " ".join(query.lower().split())
    return hashlib.sha256(normalised.encode("utf-8")).hexdigest()[:16]


def parse_ts(ts) -> float | None:
    """Row timestamp → epoch seconds, or None if unreadable.

    Named and exported so it can be pinned against a known epoch directly.
    Testing it only through `read_rows` would leave the UTC-vs-local question
    answerable *only* on a host whose timezone is not UTC — a test that fires
    on the author's machine and is silently inert in CI, which is the same dead
    instrument this module exists to prevent one level down.

    `calendar.timegm` is the UTC inverse of `strptime`. `time.mktime` would
    read these stamps as local and shift the window by the host's offset.
    """
    try:
        return calendar.timegm(time.strptime(ts, "%Y-%m-%dT%H:%M:%SZ"))
    except (ValueError, TypeError):
        return None


def _write_row(row: dict) -> None:
    """Append one JSON line. Never raises — see the failure policy above."""
    try:
        path = telemetry_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        line = json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n"
        # O_APPEND plus a single write() is atomic per line on POSIX for
        # payloads under PIPE_BUF. Rows are small by construction (the query
        # text only rides along on misses), so concurrent writers interleave
        # cleanly rather than tearing a line in half.
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
        try:
            os.write(fd, line.encode("utf-8"))
        finally:
            os.close(fd)
        _state["written"] = int(_state["written"]) + 1
    except Exception as exc:  # noqa: BLE001 — never break the caller's search
        _state["write_failures"] = int(_state["write_failures"]) + 1
        _state["last_error"] = f"{type(exc).__name__}: {str(exc)[:120]}"
        log.debug("recall telemetry write failed: %s", exc)


class record:
    """Context manager recording one row per outermost recall.

    Usage::

        with record(SURFACE_SEMANTIC, query) as r:
            results = ...
            r.observe(results)

    Nested uses are counted but do not emit — `hybrid_search` calling the
    semantic path is one recall, not two. If the body raises `EmbedUnavailable`
    the row is still written, with `outcome=unavailable` and the embed class;
    that row is the most diagnostic one in the file and is exactly the one a
    naive implementation loses.
    """

    def __init__(self, surface: str, query: str):
        self.surface = surface
        self.query = query
        self.n_hits = 0
        self.top_score = None
        self._started = 0.0
        self._outermost = False
        self._token = None

    @staticmethod
    def _classify(n_hits, top_score):
        """Exposed for tests; see module-level `_found_something`."""
        return HIT if _found_something(n_hits, top_score) else MISS

    def observe(self, results) -> None:
        """Record what came back. Accepts a result list or a search() dict."""
        if isinstance(results, dict):
            results = results.get("results", [])
        results = results or []
        self.n_hits = len(results)
        scores = [
            r.get("score") for r in results
            if isinstance(r, dict) and isinstance(r.get("score"), (int, float))
        ]
        self.top_score = max(scores) if scores else None

    def __enter__(self):
        self._outermost = _depth.get() == 0
        self._token = _depth.set(_depth.get() + 1)
        self._started = time.monotonic()
        return self

    def __exit__(self, exc_type, exc, tb):
        if self._token is not None:
            _depth.reset(self._token)
        if not self._outermost:
            return False  # nested call — counted by its parent, not by itself

        latency_ms = int((time.monotonic() - self._started) * 1000)

        if exc is not None:
            # `status` is the embed class when this came from EmbedUnavailable.
            # Anything else still earns a row: a recall that blew up is a recall
            # that was attempted, and silence here is the original bug.
            status = getattr(exc, "status", None) or type(exc).__name__
            outcome = UNAVAILABLE
        else:
            status = None
            outcome = HIT if _found_something(self.n_hits, self.top_score) else MISS

        row = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "surface": self.surface,
            "query_hash": query_hash(self.query),
            "n_hits": self.n_hits,
            "top_score": self.top_score,
            "latency_ms": latency_ms,
            "outcome": outcome,
        }
        if status is not None:
            row["embed_status"] = status
        # The text rides along only where it will be read — see the docstring.
        if outcome in (MISS, UNAVAILABLE):
            row["query"] = self.query[:500]

        _write_row(row)
        return False  # never suppress the caller's exception


def read_rows(since_seconds: float | None = None) -> list[dict]:
    """Parse the log. Malformed lines are skipped, not fatal.

    A half-written line from a crashed process must not make the whole signal
    unreadable — that would convert a small write fault into a total loss of the
    usage signal, which is the opposite of what this file is for.
    """
    path = telemetry_path()
    if not path.exists():
        return []

    cutoff = None
    if since_seconds is not None:
        cutoff = time.time() - since_seconds

    rows = []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except (ValueError, TypeError):
                    continue
                if not isinstance(row, dict):
                    continue
                if cutoff is not None:
                    epoch = parse_ts(row.get("ts"))
                    if epoch is None or epoch < cutoff:
                        continue
                rows.append(row)
    except OSError:
        return []
    return rows


def usage_summary(window_days: float = 7.0) -> dict:
    """Counts over the window, for the doctor verdict and Watchtower.

    `rows == 0` is the zero-consumer signal. It is reported as its own fact
    rather than folded into a rate, because a rate over zero samples is a
    number that looks like an answer.
    """
    rows = read_rows(since_seconds=window_days * 86400)
    hits = sum(1 for r in rows if r.get("outcome") == HIT)
    misses = sum(1 for r in rows if r.get("outcome") == MISS)
    unavailable = sum(1 for r in rows if r.get("outcome") == UNAVAILABLE)
    latencies = [r.get("latency_ms") for r in rows
                 if isinstance(r.get("latency_ms"), (int, float))]

    return {
        "window_days": window_days,
        "rows": len(rows),
        "hits": hits,
        "misses": misses,
        "unavailable": unavailable,
        "miss_rate": round(misses / len(rows), 3) if rows else None,
        "median_latency_ms": (
            int(sorted(latencies)[len(latencies) // 2]) if latencies else None
        ),
        "path": str(telemetry_path()),
    }
