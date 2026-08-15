---
id: T-3022
name: "recall latency is O(corpus) — brute-force KNN scans 1.22GB per query"
description: >
  Inception: recall latency is O(corpus) — brute-force KNN scans 1.22GB per query

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-15T19:36:54Z
last_update: 2026-08-15T19:39:19Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-15T19:39:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3022: recall latency is O(corpus) — brute-force KNN scans 1.22GB per query

## Problem Statement

A semantic recall costs ~1.0–1.2 s, and essentially all of it is a brute-force scan of
every vector in the corpus (1.22 GB per query). Cost is a function of corpus size and
nothing else, so latency grows linearly with a corpus that is designed to grow.

**The intercept is fine; the slope is the problem.** 1 s is tolerable interactively.
At 3× the corpus it is 3 s, and nothing in the system will report that as a fault —
each individual document added is legitimate, so there is no event to notice.

For whom: every agent that calls `fw recall` / `fw ask` / `/search`, and the RAG path.
Why now: the corpus went from effectively empty to 398,594 chunks this week (T-3016),
which is the first time the scan cost has been measurable at all — and hourly
incrementals mean it only goes one way from here.

Full measurements and candidate analysis: `docs/reports/T-3022-recall-latency-scaling.md`.

## Assumptions

- **A-1:** The corpus continues to grow. Weakly held — one bulk reindex is not a growth
  curve, and the hourly incremental steady state (28 s, 9 files changed) has only a few
  cycles of history. IW-7 depends on this.
- **A-2:** Recall quality currently has thin headroom above the zero-clamp (known-good
  median 0.106, min 0.016), so any approximation that costs recall is riskier here than
  the general literature suggests. Measured, not assumed — see T-3021.
- **A-3:** Queries are global, not scoped. Holds for `fw recall` and `/search`; unverified
  for the RAG path, which is what IW-6 turns on.

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: Is the ~1s recall latency a fixed brute-force scan, or does it scale with the result count?**
  confidence: 3
  disposition: answered
  rationale: measured on the live index — k=1 → 1028ms, k=200 → 1221ms. A 200× change in k moves latency 19%, so the cost is the scan, not result assembly.

- **IW-2: Is the latency in the embedding call or the vector query?**
  confidence: 3
  disposition: answered
  rationale: vector query 1019ms of a 1000ms `_semantic_search`; novel-query embed 201ms (web/embeddings.py:228 `@lru_cache(maxsize=256)` hides it on repeats, so repeat queries are ~100% scan).

- **IW-3: Does sqlite-vec build an ANN index for `vec0`, or is the scan exhaustive by construction?**
  confidence: 3
  disposition: answered
  rationale: DDL is `CREATE VIRTUAL TABLE vec_documents USING vec0(id INTEGER PRIMARY KEY, embedding FLOAT[768])` — no partition key, no ANN structure. 398,594 × 768 × 4B = 1.22 GB scanned per query.

- **IW-4: Does binary quantization with full-vector rescoring preserve acceptable recall on THIS corpus?**
  confidence: 2
  disposition: answered
  rationale: simulated on real corpus vectors (spike 2) — binary first stage then exact rescore recovers the full exact top-10 at N=50 (10.0/10; 9.5 at N=25, 6.5 at N=10), at 32× less data scanned. Confidence 2 not 3: this is a Python simulation over a ~540-doc pool, not a live sqlite-vec bit-vector table, and required N likely grows with corpus size — the *approach* is proven, the production N is not.

- **IW-5: Does our embedding model support Matryoshka truncation (768→256), and at what recall cost?**
  confidence: 3
  disposition: answered
  rationale: model is `nomic-embed-text-v2-moe`; measured empirically rather than from docs — top-10 retention 8.8/10 at 512d (ρ=0.954), 8.2/10 at 256d (ρ=0.874), 6.0/10 at 128d. Graceful degradation but not strongly Matryoshka. Loses ~18% of top-10 for 3×, and has no rescore stage to recover it — dominated by IW-4's candidate on both axes.

- **IW-6: Is a partition key useful here, given recall is global rather than scoped?**
  confidence: 3
  disposition: dissolved
  rationale: `_rag_retrieve` (web/embeddings.py:1274-1277) selects `d.category` for output but never filters on it, and flattens BM25's per-category groups (`:1286`). No query path anywhere carries a scoping predicate, so a partition key would prune nothing. Candidate C is dead.

- **IW-7: What latency actually matters — is 1s a problem today, or only at projected growth?**
  confidence: 1
  disposition: deferred
  rationale: this is the go/no-go hinge and it is an operator judgment, not a measurement. 1s is tolerable interactively; the concern is the slope, not the intercept. Needs the growth rate over several incremental cycles, which only started accumulating this week.

## Exploration Plan

Three spikes. Done: the characterisation (IW-1/2/3) — measured, no further work needed.

- **Spike 1 — model capability check (IW-5), 15 min.** Resolve `EMBEDDING_MODEL` and
  determine whether it supports Matryoshka prefix truncation. Cheapest question here and
  it either opens candidate B or closes it outright.
- **Spike 2 — binary quantization recall measurement (IW-4), 2 h, time-boxed.** Build a
  bit-vector table over a corpus *sample*, run the same known-good / nonsense query set
  from T-3021, and measure how many known-good queries survive above the zero-clamp
  after two-stage rescoring. Sample, not full corpus — a full requantisation is build
  work and must not happen under an inception.
- **Spike 3 — RAG scopeability (IW-6), 30 min.** Read the RAG retrieval path to see
  whether it carries a category predicate that a partition key could prune on. Expected
  to dissolve the candidate; cheap enough to be worth confirming rather than assuming.

IW-7 is not a spike. It is the operator's call and needs a few weeks of growth data.

## Technical Constraints

- sqlite-vec `vec0` has **no ANN index** — there is no HNSW/IVF option to switch on. The
  scan is exhaustive by construction, so every candidate is about scanning *less data*
  rather than scanning *fewer rows*.
- Any change to vector storage format requires a **full reindex** — 95.9 min measured
  (T-3016), against a shared GPU host. That is the real cost floor on candidates A and B,
  and it means format experiments must run on a sample, not in place.
- The embedding host is shared infrastructure (`192.168.10.107:11434`); the local sidecar
  on 11435 is down (OBS-259). Measured at ~30 ms impact, so not a constraint on this work.
- Recall quality headroom is thin (A-2). An approximation that loses 10% recall in the
  literature may cost more here, because our scores sit close to the floor already.

## Scope Fence

**IN:** characterising the cost (done); measuring candidate approaches on a corpus
sample; producing a costed recommendation.

**OUT — explicitly:**
- Any change to the live vector store, index format, or embedding model. That is build
  work and requires GO first.
- Any full reindex. Sample-only during exploration.
- Tuning the T-3021 miss floor. Related (A-2) but a separate decision with its own
  evidence; bundling it here would make one go/no-go answer two questions.
- Fixing OBS-259. Measured as incidental to this problem.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

Measured on the live index: k=1 costs 1028ms and k=200 costs 1221ms, so a 200x change in result count moves latency 19% — the cost is a fixed brute-force scan of all 398,594 vectors (768 dims, 1.22GB), not result assembly. Embedding adds 201ms on a novel query (lru_cache hides it on repeats). Recall is therefore O(corpus) in a corpus designed to grow: one reindex took it from empty to 398k chunks, and hourly incrementals keep adding. This is a shape fault, not a slow value - no threshold to tune, and it degrades continuously with no event to notice. sqlite-vec vec0 has no ANN index, but does natively support binary quantization; two-stage retrieval (bit-vector scan then full-vector rescore of top-N) is the leading candidate at ~32x less data scanned with bounded recall loss. Alternatives worth costing before committing: matryoshka dimension truncation 768->256, and partition keys (weak here, since recall is global rather than scoped). Worth an inception rather than a build because the alternatives change the storage format and have different recall/latency tradeoffs that need measuring, not guessing.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-15T19:39:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
