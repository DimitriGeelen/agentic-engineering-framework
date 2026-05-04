# T-1717 — Embeddings generation strategy for context and component fabric

**Type:** Inception (grill-driven)
**Filed:** 2026-05-04
**Owner:** human
**Status:** Phase 1 — Research (in progress)

## Purpose

Re-evaluate the current embeddings substrate that powers context richness in
prompt generation:

- where embeddings are **generated** (which content is embedded, by what tool,
  on which trigger)
- where embeddings are **stored** (which vector DB, schema, indexing strategy)
- where embeddings are **retrieved** (which queries hit the vector DB, where
  results feed into prompt assembly — task briefing, ask, recall, search,
  resume, etc.)
- the **principles** that govern what gets embedded vs. what doesn't, the
  refresh/staleness model, and the deduplication/scoping model

The grill outcome must answer: **is the current strategy fit-for-purpose, and
if not, what specific change unlocks more value?**

## Phase 1 — Research findings

### Generation substrate

- **Model:** `nomic-embed-text-v2-moe` (768-dim) via local **Ollama**, invoked
  in `web/embeddings.py:_embed()` (~lines 64–74). Replaced 384-dim
  `all-MiniLM-L6-v2` per T-263.
- **Indexed sources** (10) — collected by `web/search_utils.py:collect_files()`
  (~lines 68–95):
  tasks (`active/` + `completed/`), episodic memory (`.context/episodic/`),
  project memory (`.context/project/{learnings,decisions,patterns}.yaml`),
  component fabric (`.fabric/components/*.yaml`), specs, handovers,
  reports under `docs/reports/`, QA, research, plus a couple more buckets.
- **Trigger:** on-demand lazy-load. `_get_db()` (embeddings.py:53) checks a
  **1-hour TTL** and rebuilds the index if stale or missing. **No cron job
  drives indexing.** Manual rebuild via `/discovery` UI.
- **Chunking:** markdown-aware — split on headings, max 1500 chars,
  150-char overlap (embeddings.py:93–137, sized in T-263).
- **Refresh / staleness:** full reindex on TTL expiry; no incremental
  per-file invalidation; deletions handled by full rebuild.
- **Failures:** Ollama unreachable → exception re-raised (no fallback);
  malformed files skipped silently; oversized chunks truncated by chunker.

### Storage substrate

- **Vector DB:** **sqlite-vec** — embedded library, in-process. Not Qdrant,
  Chroma, FAISS, or pgvector. Single SQLite file.
- **Path:** `.context/working/fw-vec-index.db` (~75 MB at present).
- **Schema:** two tables.
  - `documents` — metadata: path, title, category, task_id, chunk_index,
    chunk_text.
  - `vec_documents` — virtual table holding 768-dim FLOAT vectors,
    **L2 distance**.
- **Scale:** ~21,292 chunks across ~1,380 files; 9 logical categories.
- **Partitioning:** single global collection. Logical separation by the
  `category` field — *no per-project / per-arc / per-task isolation in
  the vector layer.*
- **Portability:** index file is **git-committed** (not in .gitignore).
  Fresh consumer clones inherit the pre-built index; no regeneration
  required to start querying.
- **Connection:** in-process singleton `_db`; lazy load on first call.
  No systemd, no Docker, no remote service.
- **Hybrid retrieval:** Reciprocal Rank Fusion of vector + FTS (sqlite
  full-text), with optional cross-encoder rerank (T-269) on top candidates.

### Retrieval substrate

- **Call sites** (every place the framework hits the vector DB):
  1. **`fw ask "query"`** → `lib/ask.py` → `web.embeddings.rag_retrieve` →
     formats RAG context → Ollama LLM (synchronous, returns answer + sources).
  2. **`fw recall "query"`** → `agents/context/lib/memory-recall.py:100` →
     `web.embeddings.hybrid_search(query, limit=limit*3)` → keyword
     fallback when retrieval thin.
  3. **Web UI** — `/search`, `/search-hybrid`, `/ask` (streaming),
     `/discovery` (`web/blueprints/discovery.py:165`,
     `web/blueprints/api.py:253`).
  4. **Task briefing** — emitted by `bin/fw work-on` / `fw inception start` /
     `fw task create` (the "Related knowledge" + "Sources (10 chunks)"
     block we saw on T-1717 filing).
  5. Likely also surfaced via knowledge_management MCP tool
     (`mcp__skills__knowledge_management_query_learnings`).
- **Query format:** natural-language string; for briefing the query
  template is "Brief me on task T-XXX: <name>. What prior work, patterns,
  and decisions are relevant? What should I watch out for?"
- **Pipeline:** embed query → L2 ANN over `vec_documents` (limit×3
  candidates) → RRF fusion with FTS hits → optional cross-encoder
  rerank → top-K chunks (typically 10).
- **Result delivery:**
  - `fw ask` → printed answer + numbered sources (LLM-mediated).
  - `fw recall` / briefing → printed list of source chunks (no LLM
    synthesis on briefing).
  - Web `/ask` → streaming SSE.
- **Scope:** **global** — every query hits the entire index. No filtering
  by project, arc, current task, or focus.
- **Latency / reliability:** no published SLO; Ollama embeddings call is
  the dominant cost. Hard fail when Ollama is down (no graceful fallback
  to FTS-only that I found in this scan).

### Principles in play (declared and de-facto)

| Principle | Origin | Status |
|---|---|---|
| **Local-first compute** | Ollama for embeddings + LLM | enforced (no cloud calls) |
| **Single in-process store** | sqlite-vec | enforced (no external service) |
| **Hybrid retrieval** | RRF(vector, FTS) + cross-encoder rerank | enforced (T-263, T-269) |
| **Lazy / TTL-driven index** | `_get_db()` 1-hour rebuild | enforced (no cron) |
| **Portable index** | git-committed `fw-vec-index.db` | enforced (consumer clones get pre-built) |
| **Govern­ance-artifact corpus** | tasks, episodics, learnings, decisions, fabric, handovers | de-facto (no source code, no commit messages, no PRs) |
| **Global retrieval** | one collection, query sees everything | de-facto (no per-arc / per-task scoping) |
| **No incremental update** | full rebuild on TTL expiry | de-facto (no file-watch or post-write hook) |
| **Markdown-aware chunking** | heading-split, 1500/150 | enforced (T-263) |

## Phase 2 — Playback

Played back to human in conversation. Five surprises surfaced (source code
not indexed, index in git, 1-hour TTL weakness + 2-month-stale on-disk
evidence, global retrieval, hard Ollama dependency). Human validated
the substrate findings and corrected weighting:
- **Source code + commits should be indexed**, coupled with component
  fabric blast-radius
- **Index in git is acceptable** if recreatable on loss
- **Freshness is broken** and needs structural fix
- **Scoping is powerful** but breakdown risk needs mitigation
- **Provider routing is the right framing** — investigate orchestration

Full dialogue captured under § Dialogue Log.

## Phase 3 — Grill (purpose / goal / intent)

Three rounds of grilling. Headline-pain reframe: **(c) arc-coherence
failure** is the dominant signal, not search-quality. Agent self-rating
must be evidence-driven, not subjective. Adaptive freshness telemetry
preferred over fixed targets. Orchestrator coupling endorsed.
Q4 (rigidity-vs-evolution) → answer: structural materialisation→reflection
loop; sibling task T-1718 filed.

Full Q&A captured under § Dialogue Log.

## Phase 4 — Strengths and weaknesses

*Anchored to the validated headline pain from Phase 3: arc-coherence
failure (agent loses focus, pivots to low-value, doesn't complete arcs) +
agent amnesia (forgets prior learnings) + decision-quality (misses
applicable rules).*

### Strengths of the current substrate

| Strength | Evidence | Worth preserving |
|---|---|---|
| Local-first compute | Ollama + sqlite-vec, no cloud calls | yes — supports portability D4 |
| Single in-process store | sqlite-vec embedded, no sidecar | yes — D3 usability |
| Hybrid retrieval | RRF(vector, FTS) + cross-encoder rerank (T-263, T-269) | yes — beats pure-vector |
| Markdown-aware chunking | heading-split 1500/150 respects governance shape | yes |
| Index committed to git | fresh consumers get instant retrieval | partial — see weaknesses |
| Governance-artefact corpus | low noise, high signal | partial — see weaknesses |

### Weaknesses (anchored to validated intent)

| # | Weakness | Connects to which pain | Severity |
|---|---|---|---|
| W1 | **Arc-coherence blind** — chunks text-similar, not arc-aware. Retrieval doesn't surface "what arc, headline mechanic, shipped scope, next coherent step" | (c) arc-coherence failure | HIGH |
| W2 | **Source code + commits not indexed** — the *work itself* invisible; only our *discussion of it* | (a) amnesia, (b) decision-quality | HIGH |
| W3 | **Component-fabric edges not woven into retrieval** — blast-radius computable but not relevance-weighted | (c) arc-coherence | HIGH |
| W4 | **Index actually 2 months stale** (file mtime 2026-03-10) — TTL rebuild appears not firing or not touching mtime | (a) catastrophic amnesia | CRITICAL |
| W5 | **Hard Ollama dependency** — no fallback, no provider routing, no learning loop | reliability D2 | MEDIUM |
| W6 | **No outcome feedback** — retrieval quality unmeasured against task success | all three pains | HIGH |
| W7 | **Global retrieval, no scoping** — focus / arc / blast-radius ignored | (c) arc-coherence | MEDIUM |
| W8 | **Index in git** — 75 MB binary couples to source-of-truth review, bloats history | portability D4 | LOW |
| W9 | **No happiness signal** — agent cannot learn from task ratings | feedback loop | HIGH |
| W10 | **Reviewer agent integration absent** — reviewer verdict not feeding retrieval-quality scoring | feedback loop | MEDIUM |

### What's structurally aligned vs. what fights the framework

**Aligned:** local-first (D4), hybrid retrieval, markdown-aware chunking,
governance corpus.

**Fighting:** TTL-driven rebuild instead of post-write incremental
(antifragility D1 — silent staleness ≠ failures-as-learning); index
binary in git (portability D4 — couples binary to source-of-truth review);
no provider routing (reliability D2 — single point of failure); no
outcome feedback (antifragility D1 — no learning loop).

## Phase 5 — Improvement suggestions

### Vertical-slice plan (per T-1718 Evolution-gate discipline)

Each slice ships end-to-end before the next begins. Each gets 5-7 days
of real usage, an Evolution log entry, and a happiness rating before
sequel slices are committed.

#### Slice 1 — Prove the loop *(smallest end-to-end vertical)*

- **Post-write incremental embedding** on `lib/learnings.sh add` and
  `update-task.sh --status work-completed` — single-chunk embed, insert
  into sqlite-vec, no full rebuild. Closes W4 (catastrophic amnesia
  case A1, <5s freshness on this machine this session).
- **Happiness flag** on `fw task update --status work-completed
  --happiness +1..+5 / -1..-5` (CLI) + Watchtower one-tap UI.
  Initial schema in `.context/working/happiness.jsonl`. Closes W9.
- **One provider-routing decision** through litellm: `fw ask` calls
  resolver → routes to local Ollama (default) OR claude-via-cloud
  (fallback when Ollama unreachable). Captures dispatch + outcome.
  Closes W5 partially.
- **Watchtower telemetry panel** — current freshness, recent ratings,
  routing decisions, miss-rate sketch. Visibility from day 1.

**Falsifier:** if after 7 days of usage, amnesia-incident self-reports
don't drop AND retrieval miss-rate (chunks-written-recently-not-found)
is unchanged → Slice 1 hypothesis falsified, Recommendation revisited
via `fw inception revise`.

#### Slice 2 — Broaden corpus + couple to component fabric

- Index source code (with chunker tuned for code, not markdown)
- Index commit messages from `git log` (each commit = one chunk;
  metadata: SHA, author, date, files-touched)
- Wire component-fabric edges into retrieval: chunks tagged with
  component_id where applicable; query expansion via 1-hop
  blast-radius for in-scope tasks. Closes W2, W3.

#### Slice 3 — Scope-aware retrieval with boost-not-filter

- Layered scope: global priors always included (CLAUDE.md, top
  learnings/decisions/principles)
- In-scope chunks (current arc + 1-hop component-fabric edges) get
  ×1.5 score boost; out-of-scope still competes
- Two-pass retry: scoped first; if top-K scores below threshold,
  second pass global
- Provenance on every returned chunk (in-scope ✓ / hop / global)
- Closes W7, mitigates the breakdown-risk reflection from Phase 3
  Q3a.

#### Slice 4 — Reviewer ↔ outcome integration

- Reviewer verdict (pass/warn/fail per AC, drift, reverify) flows into
  `dispatch-outcomes.jsonl` alongside happiness rating
- Composite quality signal: reviewer + happiness + AC-pass + RCA-absent
  → single "quality score" per task
- Routes back to retrieval-quality learning + provider-routing learning
- Closes W6, W10. Validates the Q2 happiness-signal hypothesis with
  reviewer as anchor, not feeling.

#### Slice 5 — De-couple index from git + adaptive freshness

- Remove `fw-vec-index.db` from tracked tree; add to `.gitignore`
- Lazy regeneration on first query post-clone; explicit `fw index
  rebuild` for forced rebuild
- Adaptive freshness telemetry: miss-rate × cost-rate × value-signal
  → bounded knob auto-tune (within range, with manual override always
  winning)
- Closes W8 + telemetry side of Q3a.

### Cross-cutting design choices (agreed at grill)

1. **Quality > affordable cost > simplicity preferred** (Q3 ranking)
2. **Cross-machine federation deferred** to T-704 (not in scope)
3. **Multi-signal agent self-rating** — composite from mechanical +
   reactive + lagging + relational signals; not subjective; ratings
   mutable with audit trail; reviewer verdict is dominant input
4. **Evolution gate (T-1718) prerequisite** — applied to T-1717's own
   build streams as eat-our-dogfood validation
5. **Orchestrator coupling explicit** — T-1717 = pilot consumer of
   resolver/outcome substrate; success of T-1717 = validation of
   orchestrator-arc headline mechanic

### Risks acknowledged

| Risk | Mitigation |
|---|---|
| Scope-by-blast-radius is unproven hypothesis | Slice 3 telemetry is the falsifier; boost-not-filter limits breakdown blast |
| Cloud providers introduce cost variance | Routing-decision logging + cost cap config + manual override always wins |
| Index regeneration cost on first query post-clone | Bounded ~minutes for 21k chunks; one-time cost; user-visible progress |
| Reviewer AC-classification fix needed but separate | Filed as sibling concern; not blocking T-1717 |
| T-1718 Evolution-gate may not land before Slice 1 | Recommendation makes T-1718 explicit prerequisite; sequencing decided at decide-time |
| litellm proxy must actually be running | Verified at Slice 1 entry — `fw doctor` should warn if not |

## Dialogue Log

> Per C-001: capture questions posed, answers given, course corrections,
> and outcome/decision evolution. Conversational reasoning lives here.

### 2026-05-04 — Inception kickoff

- **Human:** New ARC, "Embeddings generation strategy", grill me. Analyse our
  architecture, workflow, design, principles. Report findings. Identify
  strengths and weaknesses. Drill me on purpose / goal / intent. Suggest
  improvements.
- **Agent:** Proposed playback-first structure (5 phases), recommended (a)
  standalone inception now / arc-promotion post-decision. Human: chose (a).
- **Outcome:** Filed T-1717 with placeholder DEFER (recommendation forms
  post-Phase-3). Phase 1 research begins.

### 2026-05-04 — Phase 2 playback + Phase 3 round 1

**Findings surprising to human:**
- Source code + commit messages NOT indexed (only governance artefacts) →
  human: "would be very beneficial especially coupled with blast radius"
- Vector index committed to git (75 MB binary in repo) → human: ok if
  recreatable on loss
- 1-hour TTL was already weak; agent then surfaced **on-disk evidence
  index file mtime is 2026-03-10 — 2 months stale.** Real freshness much
  worse than headline.
- Global retrieval, no scoping → human: scope-by-blast-radius is powerful
  but raises breakdown risk → asked agent to reflect on mitigations
- Hard Ollama dependency → human: "use other local provider, OpenRouter,
  Claude as fallback. Investigate orchestration/routing work — would be
  brilliant usecase to test and learn"

**Agent reflection on scope-breakdown risk:**
1. Cross-cutting principles (CLAUDE.md, gates, §ACD pattern) live everywhere
2. Episodic value comes from analogy across distance (T-1715 RCA started
   from completely unrelated trigger)
3. Agent doesn't know what it doesn't know — most useful chunk is the
   unexpected one
4. False confidence is worse than no context (same shape as §ACD)

**Mitigation stack proposed:**
- Layered scope (always include global priors)
- Boost-not-filter (in-scope ×1.5, out-of-scope still competes)
- Component-fabric edge expansion (auto-include 1-hop blast radius)
- Two-pass retry (scoped first; if low scores, global fallback)
- Provenance in returned chunks (in-scope ✓ / hop / global)
- Explicit `--global` escape hatch

**Orchestrator integration investigation:**
- litellm proxy already shipped (T-1700) — model_list with ollama-backed
  claude-named entries on .107
- Resolver + outcome substrate shipped (T-1696/97/98) — 3 real dispatches,
  100% enrichment, but only TermLink worker_kind in production
- G-064: orchestrator has zero production consumers
- Embedding routing fits perfectly: every retrieval → resolver → routing
  decision → outcome-enrichment learns cost/quality/latency per provider.
  Closes G-064.

**Phase 3 round 1 — human answers:**

- **Q1 (user-visible failure):**
  - (a) `fw recall` wrong/missing — **major, often, sometimes catastrophic**
    (agent amnesia)
  - (b) agent decisions miss applicable learning — **major, regular**
  - (c) weak context → losing focus on purpose/goals, not completing arcs,
    pivoting to low-value stuff — **happening, harder to qualify but the
    most important signal: this is arc-coherence failure, not just token
    waste**
- **Q2 (success criteria):** human proposes **happiness signal**:
  - both human and agent rate task completion (-5..-1 unhappy, +1..+5 happy)
  - low friction for human (optional)
  - becomes feedback signal for retrieval-quality learning
  - secondary: less used escalation (agent gets it right more often)
- **Q3 (constraint ranking):**
  - **Quality > everything** (non-negotiable, top)
  - Cost: must stay acceptable / affordable
  - Simplicity: preferable, not constraint
  - (i)/(ii)/(iii) — pending agent elaboration on freshness

## Recommendation

**Recommendation:** GO (conditional)

**Rationale:** Three convergent reasons.

1. **The pain is real, sustained, and high-cost.** Catastrophic agent
   amnesia (Q1a) and arc-coherence failure (Q1c) are damaging existing
   work — confirmed by the human in Phase 3 ("often occurring damaging,
   sometimes catastrophic"). On-disk evidence corroborates: the index
   file mtime is 2026-03-10, ~2 months stale, meaning the production
   substrate has been blind to recent learnings/decisions/episodics.
   This is not a hypothetical optimisation — it's a live, daily failure.

2. **The substrate exists; this is integration, not greenfield.**
   sqlite-vec + Ollama + RRF + cross-encoder rerank are shipped (T-263,
   T-269). litellm proxy is shipped (T-1700). Resolver + outcome
   enrichment + dispatch envelopes are shipped (T-1696/97/98). Reviewer
   agent is shipped (T-1443). What's missing is the *connections* — a
   feedback loop, a routing layer, a freshness mechanism. Composition
   of existing primitives.

3. **The fit is structurally aligned.** T-1717 simultaneously
   (a) fixes the headline pain, (b) closes G-064 (orchestrator with zero
   production consumers — embeddings + LLM become consumer #1), and
   (c) provides the validation deliverable for the orchestrator-arc's
   headline mechanic. Three structural problems addressed by one
   coherent build, sequenced via vertical slices to prevent §ACD
   substrate-vs-deliverable conflation.

**Conditions on GO** (must be satisfied at decide-time, before any
build commit):

- (i) **T-1718 Evolution-gate** lands first OR is committed to land in
  parallel with Slice 1. The Evolution-gate is the structural
  enforcement that protects T-1717's own build from the §ACD pattern
  the inception just diagnosed. Eating our dogfood is non-negotiable.
- (ii) **Vertical-slice discipline**: Slice 1 ships end-to-end with
  7 days of real usage (and a falsifier check) before Slice 2 is
  committed. No parallel multi-stream build. Each slice has a populated
  Evolution log entry before the next begins.
- (iii) **Headline mechanic stated as user-visible result**, not
  substrate. Suggested wording for the build task:
  > *Agent issues `fw recall` → resolver routes to optimal embedding
  > provider for query class → returns chunks with provenance →
  > outcome enrichment captures happiness rating → next routing
  > decision improves. **User-visible: amnesia incidents drop,
  > arc-coherence telemetry trends positive across the orchestrator-arc.***
- (iv) **Orchestrator coupling made explicit** — T-1717's build task
  must declare itself the pilot consumer of the orchestrator-arc and
  reference G-064 closure as a co-deliverable. Closes the substrate
  gap simultaneously with the embeddings gap.

**Evidence:**

- **Live failure evidence:** `.context/working/fw-vec-index.db` mtime
  2026-03-10 → production retrieval has been ~2 months stale on disk.
- **Pain confirmed:** Phase 3 Q1 — human reported (a) `fw recall`
  wrong/missing as "major, often, sometimes catastrophic"; (c) weak
  context → "losing focus on purpose/goals, not completing arcs,
  pivoting to low-value stuff" as the most important signal.
- **Substrate exists:** litellm-config.yaml, lib/resolver.py (25k LOC),
  lib/outcome.py (14k LOC), 3 real dispatches with 100% enrichment,
  reviewer 3-layer system with daily Pass-B cron.
- **G-064 open and citable:** orchestrator-arc shipped substrate, has
  zero production consumers — concerns register confirms.
- **Scale manageable:** ~21,292 chunks across ~1,380 files; 75 MB
  index; minutes to regenerate.
- **Pattern precedent:** T-1715 → T-1716 demonstrates structural
  enforcement > advisory text. Same shape applies here: arc-coherence
  rules in CLAUDE.md exist as advice; T-1717 makes them mechanical
  via retrieval.

**Risk acknowledged:**

- **Scope-by-blast-radius is an unproven hypothesis** — Slice 3
  telemetry is the falsifier. Boost-not-filter design limits the
  breakdown blast if hypothesis is wrong (out-of-scope chunks still
  compete).
- **Cloud providers introduce cost variance** — mitigated by routing
  log + cost cap + manual override.
- **Reviewer AC-classification noise** is a separate concern (filed
  for capture) — not blocking T-1717.
- **Cross-machine freshness deferred** to T-704; this arc covers
  same-machine A1/B1 only.
- **The Evolution-gate prerequisite (T-1718) is itself unbuilt** —
  honest meta-risk: we are conditioning T-1717 on a sibling structural
  fix that hasn't shipped. Acceptable only if (i) T-1718 ships first
  OR (ii) we accept the §ACD risk consciously and log it as a Tier-2
  bypass at build commit. Human decides at decide-time.

**Sequencing recommendation:** T-1718 Slice 1 → T-1717 Slice 1 → Evaluate
→ subsequent slices alternating between the two arcs as evidence
warrants.
