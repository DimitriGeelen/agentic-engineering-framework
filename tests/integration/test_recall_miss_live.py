"""Live-retriever integration pin for the T-3021 miss classifier.

Why this exists, given T-3021 already has 32 passing tests
----------------------------------------------------------
All 32 feed the classifier a hand-built result list. They pin the *rule*
(`top_score == 0` → miss) but not the *premise* the rule depends on: that the
real retriever returns rows at score 0 for a query that matches nothing.

That premise is a fact about `_semantic_search`, and it can change without any
fixture noticing — add a distance cutoff, or alter the `max(0, 1.0 - distance)`
clamp, and every fixture test stays green while the classification it justifies
becomes wrong.

This is the failure T-3019 shipped and T-3021 diagnosed, one level down. T-3019's
`n_hits == 0` rule was verified against a sparse index, was true at the time, and
silently stopped being true when the corpus filled. A test that constructs its own
input through its own assumptions is a lenient reader of the code it is checking.

So: no fixtures here. Real embed call, real vector query, real telemetry row.

Fail-closed on purpose
----------------------
If the index or embed path is unavailable this skips — but the `## Verification`
line in T-3023 asserts the test *executed*, so a skip fails the gate rather than
passing it. "Could not check" must not be reported as "checked and fine"; that
equivalence is the whole bug class this file guards.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


@pytest.fixture(scope="module")
def live_recall(tmp_path_factory):
    """Real search path, telemetry redirected to a scratch log.

    Skips loudly — the reason names which precondition failed, so a skip is
    diagnosable rather than merely absent.
    """
    log = tmp_path_factory.mktemp("recall") / "telemetry.jsonl"
    os.environ["FW_RECALL_TELEMETRY_PATH"] = str(log)

    try:
        from web import embeddings as E
        from web import recall_telemetry as T
    except Exception as exc:  # pragma: no cover - import-time environment issue
        pytest.skip(f"cannot import search modules: {type(exc).__name__}: {exc}")

    try:
        db = E._get_db()
        count = db.execute("SELECT count(*) FROM vec_documents").fetchone()[0]
    except Exception as exc:
        pytest.skip(f"vector index unavailable: {type(exc).__name__}: {exc}")

    if not count:
        pytest.skip("vector index is empty — nothing to retrieve against")

    try:
        E._embed_single("preflight")
    except Exception as exc:
        pytest.skip(f"embed path unavailable: {type(exc).__name__}: {exc}")

    return E, T, log, count


def _rows(T, log):
    return T.read_rows(3600)


def test_gibberish_against_the_live_index_records_a_miss(live_recall):
    """The premise the T-3021 classifier rests on, read from the retriever itself.

    Two assertions, deliberately. That the outcome is `miss` is the point. That
    `n_hits > 0` is what makes this test *about the retriever*: it states the
    condition under which the old `n_hits == 0` rule would have been wrong, so
    if the retriever ever starts filtering by distance, this goes red and tells
    us the classifier's justification has moved.
    """
    E, T, log, _count = live_recall
    query = "zqxjv wombat photosynthesis quarterly flrbgnt"

    E.search(query, limit=5)

    rows = [r for r in _rows(T, log) if r.get("query") == query]
    assert rows, "the live search wrote no telemetry row at all"
    row = rows[-1]

    assert row["outcome"] == T.MISS, (
        f"gibberish classified as {row['outcome']} "
        f"(n_hits={row['n_hits']}, top_score={row['top_score']})"
    )
    assert row["n_hits"] > 0, (
        "the retriever returned zero rows for gibberish — it now filters by "
        "distance, so the T-3021 classifier's premise has changed and its "
        "fixture tests are no longer evidence of anything"
    )
    assert row["query"] == query, "miss rows must retain query text for slice 6b"


def test_a_real_query_against_the_live_index_records_a_hit(live_recall):
    """Guards the other direction.

    Without this, a retriever that returned nothing useful for *anything* would
    satisfy the miss test above and look like success.
    """
    E, T, log, _count = live_recall
    query = "task verification gate acceptance criteria"

    E.search(query, limit=5)

    rows = [r for r in _rows(T, log) if r.get("query_hash") == T.query_hash(query)]
    assert rows, "the live search wrote no telemetry row at all"
    row = rows[-1]

    assert row["outcome"] == T.HIT, (
        f"a genuine framework query classified as {row['outcome']} "
        f"(n_hits={row['n_hits']}, top_score={row['top_score']}) — either the "
        "index no longer covers the corpus or the miss floor is now cutting "
        "into real hits"
    )
    assert "query" not in row, "hit rows must not retain raw query text"
