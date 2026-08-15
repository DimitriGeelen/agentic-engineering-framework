"""Synthetic canary documents — a positive control for the whole retrieval path.

T-3011, slice 2 of T-3005.

T-3004 found four instruments reporting green during a total recall outage.
`is_index_ready()` counts rows; `built_at` records when the database was *opened*.
Neither can go red while the index is stale, or while embedding is dead, or while
chunks are silently truncated — because neither one ever retrieves anything.

A canary is a document the indexer plants and the checker looks for. It fails when
any link in embed → chunk → store → retrieve fails, which is precisely the span no
existing signal covers.

Three design rules, each of which came from a specific defect:

**Probe with a paraphrase, never the literal token.** The token `FWCANARY-<epoch>`
is lexically unique, so BM25 would rank it first even if the embedding path were
completely dead — the canary would be green for the wrong reason, which is the exact
failure class this arc exists to remove. Instead each canary carries a semantically
distinctive topic that appears nowhere else in the corpus, and the probe is a
paraphrase of it. Retrieval then requires the *embedding* to be real.

**Assert rank, never score.** T-3007 will change the embedding model, and score
distributions do not survive that. "Is the canary the top hit?" survives it; "is the
similarity above 0.8?" needs recalibration on every switch and silently mis-reports
in between.

**Two canaries, because there are two failure shapes.** The content canary is short
and provably under `MAX_CHUNK_CHARS`, so it can never be truncated — it tests
liveness. The tail canary is oversized with its distinctive sentence planted *past*
where the pre-T-3010 chunker would have cut, so it can only be retrieved if the whole
document was chunked and embedded. That makes it a standing detector for the OBS-251
truncation class regressing, which no unit test can be: unit tests pin the chunker,
this pins the pipeline.
"""

from __future__ import annotations

from dataclasses import dataclass

CANARY_CATEGORY = "canary"
CONTENT_PATH = "__fwcanary__/content.md"
TAIL_PATH = "__fwcanary__/tail.md"
DECOY_PATH = "__fwcanary__/decoy.md"

# How deep the tail canary's distinctive sentence must sit to be *guaranteed*
# past the embedder's 512-token ceiling.
#
# Sized against the MAXIMUM observed chars-per-token (T-3009: 4.20, and 4.31 on a
# second sample), not the median 3.19 — because the median is the wrong tail of
# the distribution for this question. A first attempt used 1,600 chars on the
# median ratio; the canary's own filler is plain English at ~4.5 chars/token, so
# the document came to ~460 tokens, was never truncated at all, and the canary
# passed under a deliberately truncating chunker. It was measured passing when it
# should have failed, which is the same false-green shape as the outage it exists
# to detect.
#
# 512 tokens × 4.4 chars/token ≈ 2,250 chars is the boundary; 6,000 is used so the
# sentence is unambiguously beyond it even if a future model tokenises this prose
# more coarsely. The cost is a slightly larger canary document — nothing.
TAIL_OFFSET_CHARS = 6000

# Topics deliberately absent from the real corpus. If any of these phrases ever
# appears in genuine project content, the canary stops being unique and must be
# re-coined — `test_canary_topics_are_absent_from_the_corpus` guards that.
_CONTENT_PROBE = "how is a verdigris hydroponic beacon calibrated against a saltwater reference cell"
_TAIL_PROBE = "how is a cinnabar ledger reconciled at the end of a quarter"


@dataclass(frozen=True)
class CanaryDoc:
    path: str
    title: str
    text: str
    probe: str


@dataclass(frozen=True)
class CanaryResult:
    name: str
    ok: bool
    detail: str
    top_hit: str | None


def _filler(n_chars: int) -> str:
    """Innocuous prose with paragraph breaks, so the tail canary's size is the
    only thing being tested — not the chunker's separator fallback."""
    para = (
        "This paragraph exists to occupy space in the canary document so that the "
        "distinctive sentence below sits past the point where a truncating chunker "
        "would have stopped reading. It carries no meaning and should never be the "
        "best match for any real query.\n\n"
    )
    out = []
    total = 0
    while total < n_chars:
        out.append(para)
        total += len(para)
    return "".join(out)


def content_canary(token: str) -> CanaryDoc:
    """Short canary: cannot be truncated, so a red result means the path is dead."""
    text = (
        f"# Framework Index Canary — content\n\n"
        f"Canary token: {token}\n\n"
        "The Verdigris Beacon Calibration Procedure is a synthetic topic that exists "
        "nowhere else in this corpus. A verdigris hydroponic beacon is calibrated by "
        "aligning its lumen aperture against a saltwater reference cell and waiting "
        "until the drift reading settles below four microvolts. If this document is "
        "retrievable by a paraphrase of that procedure, then embedding, storage and "
        "vector retrieval are all working end to end.\n"
    )
    return CanaryDoc(CONTENT_PATH, "Framework Index Canary (content)", text,
                     _CONTENT_PROBE)


def tail_canary(token: str) -> CanaryDoc:
    """Oversized canary: retrievable only if the whole document was indexed.

    The distinctive sentence is planted after TAIL_OFFSET_CHARS of filler.
    Under the pre-T-3010 chunker this document became one oversized chunk, the
    embedder read only its opening, and this sentence was absent from the index
    while the row still looked healthy.
    """
    text = (
        f"# Framework Index Canary — tail\n\n"
        f"Canary token: {token}-TAIL\n\n"
        + _filler(TAIL_OFFSET_CHARS)
        + "The Cinnabar Ledger Reconciliation Rule states that a cinnabar ledger is "
          "reconciled at the close of each quarter by folding its remainder into the "
          "next epoch's opening balance, and never by discarding it. This sentence "
          "is deliberately placed beyond the old truncation boundary.\n"
    )
    return CanaryDoc(TAIL_PATH, "Framework Index Canary (tail)", text, _TAIL_PROBE)


def decoy_canary(token: str) -> CanaryDoc:
    """A deliberate competitor for the tail probe. Not a canary — a control.

    **This exists because the tail canary was observed passing while truncated.**
    On a small index, "is the canary the top hit?" is satisfied by having no rival:
    with the tail sentence dropped, the document's embedding was filler-dominated
    and *still* ranked first, because nothing else in the corpus was closer. The
    canary was green for the wrong reason — precisely the failure class it was
    built to detect.

    The decoy is topically adjacent to the tail probe but does not contain the rule
    itself. That makes the ranking a genuine discrimination:

      - whole document indexed → the tail sentence has its own chunk, matches the
        paraphrase closely, and beats the decoy;
      - document truncated     → the tail chunk never existed, the canary's
        embedding is filler, and the decoy wins → canary reports red.

    Its probe is never asserted on directly; it earns its place by losing.
    """
    text = (
        f"# Framework Index Canary — decoy\n\n"
        f"Canary token: {token}-DECOY\n\n"
        "Ledgers are generally closed on a quarterly cycle. Bookkeeping practice "
        "varies on how a remainder or residual balance is carried, and different "
        "houses reconcile their quarterly accounts by different conventions at the "
        "end of each period. This document is topically adjacent to the tail "
        "canary's subject but does not state the reconciliation rule itself.\n"
    )
    return CanaryDoc(DECOY_PATH, "Framework Index Canary (decoy)", text,
                     _TAIL_PROBE)


def all_canaries(token: str) -> list[CanaryDoc]:
    return [content_canary(token), tail_canary(token), decoy_canary(token)]


def verify_canaries(search_fn, token: str) -> list[CanaryResult]:
    """Probe each canary and assert it is the top hit for its own paraphrase.

    `search_fn(query, limit)` is injected rather than imported so this is testable
    against a synthetic index in seconds, instead of depending on a rebuild of the
    real 393k-chunk corpus.

    Never raises: a canary that explodes is a canary that reports FAULT. The whole
    point is to produce a signal, and an exception escaping here would be swallowed
    by the same `2>/dev/null` that hid the original outage.
    """
    results = []
    for name, doc in (("content", content_canary(token)),
                      ("tail", tail_canary(token))):
        try:
            res = search_fn(doc.probe, limit=5)
        except Exception as exc:  # noqa: BLE001 — a fault is a result, not a crash
            results.append(CanaryResult(name, False, f"search raised: {exc}", None))
            continue

        hits = (res or {}).get("results") or []
        if not hits:
            results.append(CanaryResult(
                name, False, "no results for the canary probe", None))
            continue

        top = hits[0].get("path")
        if top == doc.path:
            results.append(CanaryResult(name, True, "top hit", top))
        else:
            results.append(CanaryResult(
                name, False,
                f"canary not top hit (got {top!r}); "
                + ("index may predate this canary token"
                   if name == "content" else
                   "document tail is missing from the index — truncation regressed"),
                top))
    return results
