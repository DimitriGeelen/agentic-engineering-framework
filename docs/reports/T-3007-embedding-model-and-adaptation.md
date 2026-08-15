# T-3007 — Embedding model upgrade and domain adaptation from AEF's own corpus

**Status:** research captured, decision pending
**Filed:** 2026-08-15
**Related:** T-3004 (substrate liveness), T-3005 (controls), T-3006 (embed path restored), T-261/T-263 (original model choice), T-1717 (embeddings strategy grill), T-1719 (routing loop)

## Provenance and how to read this

The substance below was supplied by the operator, produced by another agent. It
is **not** my independent research and is recorded as such. It is split into
three tiers so a future reader can tell what is load-bearing:

| Tier | Meaning |
|---|---|
| **Verified** | Checked against this tree in this session |
| **Attributed** | Plausible and internally consistent, but not verified — external benchmarks and post-cutoff releases |
| **My assessment** | My own analysis, agreeing or disagreeing |

This matters because the recommendation rests on benchmark deltas I cannot
confirm offline, while the *sequencing* argument — the part that actually changes
what we do next — rests on facts I did verify.

## Verified in-tree

| Claim | Check | Result |
|---|---|---|
| Current model is `nomic-embed-text-v2-moe`, 768-dim | `web/config.py:39`, `embeddings.py:76` | confirmed |
| `EMBEDDING_DIM = 768` is hardcoded | `web/embeddings.py:76` | confirmed |
| …and it **binds the vec0 schema** | `embeddings.py:211` — `embedding FLOAT[{EMBEDDING_DIM}]` | confirmed |
| Chunker targets ~1500 chars (~375 tok) | `embeddings.py:137` | confirmed |
| `qa_feedback` has no chunk-id column | `web/qa_feedback.py:21-29` — `query, answer_preview, model, rating, comment, created_at` | confirmed |
| Storage is sqlite-vec, hybrid with BM25 via RRF, Qwen3-Reranker-0.6B | `embeddings.py` `hybrid_search`, `rerank` | confirmed |
| **The model's context ceiling is 512 tokens** | T-3009, `tools/measure_chunk_tokens.py`, 2026-08-15 | **confirmed — promoted from Attributed** |

### The 512-token ceiling: measured, not inferred (T-3009, 2026-08-15)

Promoted out of *Attributed* below. Two independent measurements against the running
`nomic-embed-text-v2-moe`, reproducible via `tools/measure_chunk_tokens.py`:

1. **The ceiling is 512 and it is hard.** `prompt_eval_count` saturates at exactly 512
   for every input from 400 words upward.
2. **It is real truncation, not a reporting cap.** Two texts sharing a >512-token prefix
   and differing only in their suffixes embed to **cosine 1.000000000** — bit-identical,
   the suffixes were discarded. The control pair (same suffixes, short prefix) comes back
   at 0.502, so the test discriminates.

**But the consequence is smaller than the concern that motivated checking.** Measured
over the corpus `build_index()` would produce today:

| | |
|---|---|
| chunks | **287,812** |
| chars — mean / p50 / p95 / p99 / max | 637 / 382 / 1,335 / 3,299 / **170,873** |
| chars-per-token (n=247 sampled) | min 2.01, median 3.19, max 4.20 |
| provably **under** the ceiling | 267,196 (92.8%) |
| provably **over** — exact lower bound | **4,255 (1.5%)** |
| ambiguous band, resolved by sampling 300 | 16,361, of which 21.0% over |
| **estimated total losing content** | **~7,691 (2.7%)** |

So the ceiling is real and ~2.7% of chunks are silently lossy. That is a genuine defect,
but it does **not** make the corpus broadly untrustworthy, and it is *not* the third
substrate-wide defect the pre-measurement reasoning feared. Recording the negative half
explicitly: 92.8% of chunks are provably fine, and the ~1500-char chunk target is doing
most of the work of keeping them there.

**Two findings that matter more than the ceiling itself:**

- **The corpus is 287,812 chunks, not the ~21k the source assumed** — 13.7× larger. This
  invalidates cost arithmetic downstream: a full re-embed is a much larger operation than
  step C's sequencing argument priced in, and the domain-adaptation data floor
  (§"On domain adaptation") is reached far more easily than argued.
- **The chunker's 1500-char cap does not hold.** p99 is 3,299 chars and the largest chunk
  is **170,873** — 114× the target, losing ~99.7% of its content at embed time.
  `_chunk_content` splits sections on `\n\n`; a section with no paragraph breaks is
  emitted whole, uncapped. This is a distinct bug from the ceiling and is filed
  separately — fixing it removes most of the 2.7% without any model change.

**For T-3005 slice 2:** the canary must be a chunk that is provably under the ceiling,
otherwise a green canary would prove nothing about the 2.7%. Conversely a *second*,
deliberately oversized canary is the cheapest standing detector for the chunker bug
regressing.

**The dimension binding is the important one.** Switching to any model with a
different output dimension is not "three constants and a reindex" — it is a
schema migration of the `vec_documents` virtual table plus a full re-embed of
every chunk. That raises the cost of doing it *standalone* and lowers the cost of
doing it *alongside a reindex we already owe*.

## Attributed (not independently verified)

- Qwen3-Embedding-0.6B: MTEB(Eng,v2) ~70.7 vs ~62 for the current model; 32K
  context; ~1.5 GB; Apache-2.0; native Matryoshka (dimension-truncatable).
- BGE-M3 as the multilingual/hybrid alternative (~63–65, 8192 tok).
- Qwen3-Reranker-4B stronger than the 0.6B currently used; Jina Reranker v3.5
  (0.6B) reportedly beating Qwen3-Reranker-4B on structured/technical data.
- ~~The current model's context ceiling is 512 tokens~~ — **promoted to Verified by
  T-3009 on 2026-08-15; see above.** It is 512, it is hard, and it truncates silently.
  The source was right. (It remains attributed that this is *shorter* than
  nomic-embed-text v1.5's 8192 — we did not measure v1.5.)
- Domain-adaptation data floor of roughly 1,000–50,000 query-document pairs.

The 512-token ceiling is the most consequential attributed claim, because it is
checkable and it interacts with a verified fact: our chunks run to ~375 tokens
plus a prepended title, so longer chunks sit near the ceiling and may be silently
truncated. **Worth verifying before the switch** — if true, the current index is
not merely stale but partially lossy, a third independent defect on top of
T-3004's two.

## My assessment

### On switching models — agree, with the reason changed

The recommendation is right but the argument in the source is the weaker one.
"+8–9 MTEB points" is a reason to *prefer* Qwen3-Embedding-0.6B; it is not a
reason to act now, and MTEB deltas notoriously under-predict gains on a narrow
technical corpus like ours.

The reason to act now is sequencing, and it follows from the verified facts:

> T-3005 slices 3 and 5 require a full reindex regardless. A model switch
> requires a full reindex *and* a schema migration. Doing them together costs one
> reindex; doing them apart costs two — and the second lands after the freshness
> controls have been calibrated against the old model's score distribution.

That last clause is the part I would not want to discover late. The canary
threshold and the coverage/score rails from T-3005 slice 2 encode assumptions
about what a "good" similarity score looks like. Calibrate them against
`nomic-embed-text-v2-moe`, then swap the model, and every threshold needs
revisiting — with the controls themselves now suspect, which is the one thing
this arc cannot afford.

**So: decide the model before building slice 2's thresholds, not after.**

### On domain adaptation — agree it is now viable, disagree on one input

The source says the T-261 deferral ("insufficient training data") no longer
holds, citing ~21k chunks. Right in principle. Three corrections:

> **Superseded figure (T-3009, 2026-08-15):** every "~21k chunks" below should read
> **287,812**. The corpus is 13.7× the assumed size. This *strengthens* correction 1
> (the data floor is trivially clearable once pairs exist) and *worsens* correction 3
> (an LLM pass over 288k chunks is a far larger generation job than over 21k). The
> original wording is left intact so the reasoning stays legible.

1. **21k chunks is not 21k training pairs.** The data floor applies to
   *(query, document)* pairs, and we have essentially none. Synthetic query
   generation is therefore not one option among several — it is the only path
   that reaches the floor in the near term. The source implies this; it should be
   stated as a dependency rather than a menu item.

2. **The "mine real usage for free" path is empty, and I checked.**
   `qa_feedback.db` holds **1 row**. Adding `context_chunk_ids` is cheap and
   correct and should be done — but it yields training data at the rate the Q&A
   feature is actually used, which today rounds to zero. Framing it as a
   near-term source would set up exactly the kind of expectation this arc has
   spent three tasks correcting.

3. **Synthetic generation has an infrastructure prerequisite we just measured.**
   It needs an LLM pass over ~21k chunks. Generation is currently starved on the
   shared host (T-3006: `qwen3:14b` 503s for the same reason embeddings did), and
   the CPU sidecar cannot serve a 14B model at that volume. The adaptation work
   is blocked behind a GPU-slot decision, not behind data.

### On the query-side adapter — strong idea, wrong order

The source recommends a query-side-only adapter partly because it avoids
re-embedding 21k documents, "sidestepping the index-staleness pain". Correct in
isolation, but it composes badly with the model switch: an adapter trained
against `nomic-embed-text-v2-moe` embeddings is discarded the moment the base
model changes.

**Order: switch the model (riding the reindex), then adapt on top of the new
base.** The other order spends the adapter work twice.

### What I would not do yet

Reranker changes. The source floats three options; we have no measurement of the
current reranker's contribution to result quality, and swapping a component whose
baseline is unmeasured is how you end up unable to attribute a regression.
Reranking belongs after the controls can show a score distribution at all.

## Proposed shape (for the operator's decision)

| # | Step | Depends on |
|---|---|---|
| A | Verify the 512-token ceiling against our actual chunk-length distribution | nothing — cheap, do first |
| B | Decide the target model; make `EMBEDDING_DIM` and the vec0 schema derive from the model rather than a constant | A |
| C | Switch + reindex as one operation, riding T-3005 slices 3/5 | B, T-3005 slices 1–3 |
| D | Add `context_chunk_ids` to `qa_feedback` | nothing — cheap, do now, value accrues later |
| E | Synthetic query generation over the corpus | GPU-slot decision (T-3006 boundary) |
| F | Query-side adapter on the new base | C + E |

A and D are cheap and independent. C is the decision that must not be made late.
E and F are blocked on infrastructure, not on data or design.

## Recommendation

**Recommendation:** GO — on A, B and D now; C sequenced into the T-3005 reindex;
E and F deferred behind the GPU-slot decision.

**Rationale:** The switch is well-argued and the model choice looks right, but the
operative fact is one I verified rather than one from the benchmarks:
`EMBEDDING_DIM` binds the vec0 schema, so a model change is a migration plus a
full re-embed. We already owe a full reindex. Doing these together costs one
reindex and lets T-3005's freshness thresholds be calibrated once, against the
model we intend to keep. Doing them apart costs two reindexes and invalidates the
controls mid-arc. The adaptation half is genuinely unblocked on data volume but
newly blocked on generation capacity — which the source could not have known,
because that was measured after the research was written.

**Evidence:**
- `embeddings.py:211` binds the vec0 virtual table to `EMBEDDING_DIM` (`:76`)
- `qa_feedback.db`: 1 row; schema has no chunk-id column
- Chunker at 1500 chars against an attributed 512-token model ceiling
- T-3006: generation on the shared host 503s (`qwen3:14b` unloaded), and the CPU
  sidecar cannot serve it at 21k-chunk volume

**Open, and deliberately unresolved:** every benchmark number above is attributed.
If the model choice turns on the margin between Qwen3-Embedding-0.6B and BGE-M3,
that margin should be measured on our own corpus with a small retrieval eval set,
not taken from MTEB.

## Dialogue Log

### 2026-08-15 — research supplied mid-session

- **Operator:** passed in an external agent's research on switching the embedding
  provider and on using AEF's own embedding data to adapt the model; asked for it
  to be captured in design decisions and the design updated.
- **Agent:** captured with provenance tiers rather than absorbed as my own
  findings. Verified six in-tree claims, all of which held. Corrected three points
  (pairs ≠ chunks; the 1-row feedback DB; generation starvation as a new blocker)
  and reversed the adapter-vs-switch order. Kept the recommendation but replaced
  its primary argument: sequencing against the reindex we already owe, not the
  MTEB delta.
