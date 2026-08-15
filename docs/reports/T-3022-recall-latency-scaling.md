# T-3022 — Recall latency is O(corpus): brute-force KNN scans 1.22 GB per query

**Status:** inception, exploration in progress
**Filed:** 2026-08-15
**Recommendation:** GO (see `## Recommendation` in the task)

---

## Problem

A semantic recall against the framework index takes **~1.0–1.2 s**. Essentially all of
that is a brute-force scan of every vector in the corpus. The scan cost is a function
of corpus size and nothing else, so latency grows linearly with a corpus that is
designed to grow — hourly incrementals, ~9,150 documents today, 398,594 chunks.

The intercept is tolerable. **The slope is the finding.**

## Measurements

All figures from the live index on this host, 2026-08-15, after the T-3016 bulk
reindex (396,797 chunks at build time; 398,594 at measurement).

### The cost does not scale with result count

| k | median latency |
|---|----------------|
| 1 | 1028 ms |
| 5 | 1048 ms |
| 50 | 1125 ms |
| 200 | 1221 ms |

A **200× change in k moves latency 19%.** If the work were proportional to results
returned, k=200 would cost multiples of k=1. It does not. The dominant term is fixed
per query — a full scan — and only heap maintenance scales with k.

### Where the second goes

| stage | median |
|-------|--------|
| `_embed_single` (cached) | 0 ms |
| `_embed_single` (novel query, network) | 201 ms |
| vector query, k=15 | 1019 ms |
| `_semantic_search` end-to-end | 1000 ms |

`web/embeddings.py:228` wraps embedding in `@lru_cache(maxsize=256)`. Repeat queries
therefore skip the network entirely and are ~100% scan. A **novel** query pays
201 ms embed + ~1030 ms scan ≈ 1.23 s.

Worth stating because it inverts the intuitive diagnosis: the network call to the
embedding host is *not* the bottleneck, and the cache makes it look even smaller than
it is in real use.

### Why the scan is exhaustive

```sql
CREATE VIRTUAL TABLE vec_documents USING vec0(
    id INTEGER PRIMARY KEY,
    embedding FLOAT[768]
)
```

No partition key, no ANN structure — sqlite-vec `vec0` compares the query vector
against every stored vector. Data scanned per query:

```
398,594 vectors × 768 dims × 4 bytes = 1.22 GB
```

At ~1 s that is ≈1.2 GB/s, consistent with a memory-bandwidth-bound linear scan. The
number is not a symptom of a misconfiguration; it is what the chosen storage does.

### A hypothesis that was wrong, recorded because it was cheap to test

Every recall in this session logged `embed failover: http://127.0.0.1:11435 unusable
… retrying on http://192.168.10.107:11434` — the local sidecar (OBS-259) is down. I
expected a per-query tax from the failed connection attempt.

| configuration | median |
|---------------|--------|
| dead primary, failover to healthy host | 1052 ms |
| pointed directly at healthy host | 1022 ms |

**~30 ms, ≈3%.** `ECONNREFUSED` on localhost returns immediately rather than timing
out. The failover (T-3017) is genuinely cheap, and this is incidental field evidence
that it works. It downgrades OBS-259 from a performance issue to hygiene — worth
fixing, not worth prioritising as latency work.

## Why this class is easy to miss

The same shape as the `stat`-per-file pre-push gate diagnosed in T-3020, and as the
miss-signal defect in T-3021:

- No moment of failure. Nothing goes red. Latency degrades continuously, one document
  at a time, and every control we own is event-shaped.
- A **value** budget on query latency ("must be under 2 s") is either not yet breached
  or, once breached, is met by raising the number — the growth is legitimate.
- The **shape** assertion — "recall must not scan the entire corpus per query" — is
  true or false independent of corpus size, was false in May, is false now, and has
  no threshold to argue about.

Framing owed to 832-Workflow-designer, agent-chat-arc offset 11924: *values are
supposed to move, which is exactly why value-based instruments cannot see this class;
shapes are not supposed to move.*

## Candidates

Not yet costed. Listed with what each would need to prove.

| # | Candidate | Expected effect | Needs proving |
|---|-----------|-----------------|---------------|
| A | Binary quantization + full-vector rescore of top-N | ~32× less data scanned; two-stage bounds recall loss | Recall loss **on this corpus**. Our known-good scores are already low (median 0.106, min 0.016) so headroom above the zero-clamp is thin — the T-3021 miss floor could start swallowing real hits. |
| B | Matryoshka truncation 768→256 | ~3×, no search-path change | Whether `EMBEDDING_MODEL` was trained to support prefix truncation. Cheap to check, unknown today. |
| C | Partition key | Prunes only when the query carries the predicate | Probably ~0 for `fw recall` / `/search`, which are global. May apply to the RAG path if it is scopeable by category. Expected to dissolve. |
| D | Accept, and assert the shape | 0 | That 1 s is acceptable at projected growth — an operator judgment, not a measurement. |

A and D are not exclusive: the shape assertion is worth having regardless of which
optimisation lands, because it is what stops the next regression from being invisible.

## What is NOT claimed

- That 1 s is unacceptable. It is fine interactively today. The concern is the slope.
- That binary quantization will work here. It is the leading candidate on general
  grounds and is unproven against this corpus.
- That the corpus will keep growing at the observed rate. One bulk reindex is not a
  growth curve. IW-7 depends on data that started accumulating this week.

## Open items

Tracked as IW-1..IW-7 in the task. IW-1/2/3 are answered at confidence 3 (measured
above). IW-4/5/6/7 are deferred pending spikes — and IW-7, "does this matter yet",
is the go/no-go hinge and belongs to the operator.

## Dialogue Log

### 2026-08-15 — round 1, with 832-Workflow-designer (agent-chat-arc)

832 argued that value-based instruments are structurally blind to continuously-decaying
costs, and that shape assertions are the counter. Applied here without being asked to:
this investigation started as "is the dead embed sidecar costing us latency?" — a value
question — and the answer was no, 3%. Re-asking it as a shape question ("what does the
cost depend on?") produced the actual finding in one measurement.

Recorded because the reframing, not the measurement, is what found it. The measurement
was three lines of Python either way.
