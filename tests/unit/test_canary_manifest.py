"""Canary + corpus manifest — T-3011 (slice 2 of T-3005).

The canaries are positive controls, so the load-bearing tests here are the ones
that watch them go RED. A control nobody has seen fail is a hypothesis (T-3005
constraint 3), and this arc has already shipped four instruments that were green
because they asserted nothing.

Retrieval is exercised against an injected fake `search_fn` rather than a real
index: the real corpus is 393,082 chunks and a build takes hours, so a test that
depended on one would never run and the control would go unverified — which is
how we got here.
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import canary as C  # noqa: E402
from web import corpus_manifest as M  # noqa: E402

TOKEN = "FWCANARY-1700000000"


def fake_search(top_path):
    """A search_fn that always returns `top_path` as the first hit."""
    def _search(query, limit=5):
        return {"results": [{"path": top_path, "score": 0.9}]}
    return _search


def routing_search(mapping, default=None):
    """Return a different top hit per probe, so the two canaries can differ."""
    def _search(query, limit=5):
        path = mapping.get(query, default)
        return {"results": ([{"path": path}] if path else [])}
    return _search


# --------------------------------------------------------------------------
# GREEN: both canaries top-hit their own paraphrase
# --------------------------------------------------------------------------

def test_both_canaries_green_when_each_is_top_hit():
    search = routing_search({
        C.content_canary(TOKEN).probe: C.CONTENT_PATH,
        C.tail_canary(TOKEN).probe: C.TAIL_PATH,
    })
    results = C.verify_canaries(search, TOKEN)
    assert [r.name for r in results] == ["content", "tail"]
    assert all(r.ok for r in results), [r.detail for r in results]


# --------------------------------------------------------------------------
# RED: the four ways the pipeline can break
# --------------------------------------------------------------------------

def test_canary_goes_red_when_index_lacks_it():
    """Stale index: the canary was never planted, so something else wins."""
    results = C.verify_canaries(fake_search(".tasks/active/T-1.md"), TOKEN)
    assert not any(r.ok for r in results)
    assert all(r.top_hit == ".tasks/active/T-1.md" for r in results)


def test_canary_goes_red_when_search_returns_nothing():
    """Dead embed path: search succeeds structurally but retrieves nothing."""
    results = C.verify_canaries(lambda q, limit=5: {"results": []}, TOKEN)
    assert not any(r.ok for r in results)
    assert all("no results" in r.detail for r in results)


def test_canary_reports_fault_instead_of_raising():
    """A canary that crashes is a canary that reports nothing.

    The original outage was invisible partly because errors were discarded by
    `2>/dev/null`; a health check that propagates exceptions gets swallowed the
    same way.
    """
    def boom(query, limit=5):
        raise RuntimeError("ollama unreachable")

    results = C.verify_canaries(boom, TOKEN)
    assert not any(r.ok for r in results)
    assert all("search raised" in r.detail for r in results)


def test_tail_canary_alone_goes_red_when_truncation_regresses():
    """The discriminating case, and the reason there are two canaries.

    If the chunker starts truncating again (OBS-251), the SHORT canary still
    resolves -- it fits under the cap -- while the tail canary's sentence is
    missing from the index. A single canary would report green here.
    """
    search = routing_search(
        {C.content_canary(TOKEN).probe: C.CONTENT_PATH},
        default="docs/reports/something-else.md",
    )
    results = {r.name: r for r in C.verify_canaries(search, TOKEN)}
    assert results["content"].ok, "short canary should survive truncation"
    assert not results["tail"].ok, "tail canary must catch truncation"
    assert "truncation regressed" in results["tail"].detail


# --------------------------------------------------------------------------
# The canaries' own properties
# --------------------------------------------------------------------------

def test_content_canary_is_provably_under_the_chunk_cap():
    """A canary that is itself truncated would be green for the wrong reason."""
    from web import embeddings as E
    assert len(C.content_canary(TOKEN).text) < E.MAX_CHUNK_CHARS


def test_tail_canary_sentence_sits_past_the_old_truncation_point():
    """Otherwise it would have survived the pre-T-3010 bug and prove nothing."""
    text = C.tail_canary(TOKEN).text
    idx = text.index("Cinnabar Ledger Reconciliation Rule")
    assert idx > C.TAIL_OFFSET_CHARS, (
        f"tail sentence at offset {idx}, needs to be past "
        f"{C.TAIL_OFFSET_CHARS}"
    )


def test_canary_probes_never_contain_the_literal_token():
    """Probing by token would let BM25 carry the canary with embeddings dead."""
    for doc in C.all_canaries(TOKEN):
        assert TOKEN not in doc.probe
        assert "FWCANARY" not in doc.probe


def test_verify_asserts_rank_not_score():
    """No score threshold anywhere: T-3007's model switch must not recalibrate it.

    A hit with an implausibly low score is still a pass if it ranks first --
    that is the point, not an oversight.
    """
    def low_score(query, limit=5):
        path = (C.CONTENT_PATH if query == C.content_canary(TOKEN).probe
                else C.TAIL_PATH)
        return {"results": [{"path": path, "score": 0.001}]}

    assert all(r.ok for r in C.verify_canaries(low_score, TOKEN))


# --------------------------------------------------------------------------
# Manifest
# --------------------------------------------------------------------------

def test_manifest_round_trips(tmp_path):
    db = tmp_path / "vec.db"
    m = M.build_manifest(
        num_docs=10, num_chunks=99, model="m", embedding_dim=768,
        max_chunk_chars=1024, embed_context_tokens=512, canary_token=TOKEN,
        started_at=1.0, project_root=tmp_path,
    )
    M.write_manifest(db, m)
    back = M.read_manifest(db)
    assert back is not None
    for k in ("num_docs", "num_chunks", "model", "embedding_dim",
              "max_chunk_chars", "embed_context_tokens", "canary_token"):
        assert back[k] == m[k], k


def test_missing_manifest_reads_as_absent_not_error(tmp_path):
    assert M.read_manifest(tmp_path / "nope.db") is None


def test_corrupt_manifest_reads_as_absent_not_error(tmp_path):
    db = tmp_path / "vec.db"
    M.manifest_path_for(db).write_text("{not json at all")
    assert M.read_manifest(db) is None


def test_non_dict_manifest_reads_as_absent(tmp_path):
    db = tmp_path / "vec.db"
    M.manifest_path_for(db).write_text(json.dumps([1, 2, 3]))
    assert M.read_manifest(db) is None


def test_age_is_none_without_a_manifest():
    assert M.age_seconds(None) is None
    assert M.age_seconds({"finished_at": "not a number"}) is None


def test_manifest_records_the_cap_and_the_ceiling_it_derives_from(tmp_path):
    """Slice 4 needs to tell an index built under the old uncapped chunker from
    one built after T-3010, without re-deriving it from the data."""
    m = M.build_manifest(
        num_docs=1, num_chunks=1, model="m", embedding_dim=768,
        max_chunk_chars=1024, embed_context_tokens=512, canary_token=TOKEN,
        started_at=1.0, project_root=tmp_path,
    )
    assert m["max_chunk_chars"] == 1024
    assert m["embed_context_tokens"] == 512


@pytest.mark.parametrize("phrase", [
    "Verdigris Beacon Calibration",
    "Cinnabar Ledger Reconciliation",
])
def test_canary_topics_are_absent_from_the_real_corpus(phrase):
    """If a canary topic ever appears in genuine content, it stops being unique
    and the control silently weakens — the canary could lose its own probe to a
    real document and report a truncation that never happened.

    Scoped to exactly the files `collect_files()` indexes, which is what "real
    content" means here. An earlier version grepped the whole tree and kept
    tripping on .pyc and .pytest_cache artifacts; widening the exclusion list
    each time would have been fitting the test to the noise rather than to the
    claim.
    """
    from web.search_utils import collect_files

    offenders = []
    for f in collect_files():
        try:
            if phrase in f.read_text(errors="replace"):
                offenders.append(str(f))
        except Exception:
            continue
    assert not offenders, (
        f"canary phrase {phrase!r} appears in indexed content: {offenders[:5]} — "
        f"re-coin the canary topic in web/canary.py"
    )


def test_decoy_is_planted_but_never_asserted_on():
    """The decoy must be indexed (so it can compete) and must not be verified.

    It earns its place by losing: if truncation drops the tail sentence, the
    decoy out-ranks the canary and the canary reports red. Without it, "top
    hit" is satisfied by having no rival -- which is how the tail canary was
    observed passing under a deliberately truncating chunker.
    """
    planted = {d.path for d in C.all_canaries(TOKEN)}
    assert C.DECOY_PATH in planted
    verified = {r.name for r in C.verify_canaries(fake_search("x"), TOKEN)}
    assert verified == {"content", "tail"}, "decoy must not be a verified canary"
