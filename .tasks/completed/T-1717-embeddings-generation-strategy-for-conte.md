---
id: T-1717
name: "Embeddings generation strategy for context and component fabric"
description: >
  Inception: Embeddings generation strategy for context and component fabric

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [T-1715-family, G-064-closure-pilot, T-679-family, structural-fix]
components: [agents/task-create/update-task.sh, bin/fw, lib/evolution_log.sh, lib/inception.sh, tests/unit/evolution_log_gate.bats]
related_tasks: [T-1715, T-1716, T-263, T-269, T-1696, T-1697, T-1698, T-1700, T-1443, T-704, T-679, T-1718]
arc_id: embeddings-strategy
created: 2026-05-04T12:25:28Z
last_update: 2026-05-04T16:49:07Z
date_finished: 2026-05-04T16:49:07Z
---

# T-1717: Embeddings generation strategy for context and component fabric

## Problem Statement

The current embeddings substrate (sqlite-vec + Ollama, ~75 MB index at
`.context/working/fw-vec-index.db`, 1-hour TTL rebuild) is failing at three
distinct levels of severity:

1. **Catastrophic agent amnesia** (Q1a, "major, often, sometimes
   catastrophic" per human in Phase 3 grill) — `fw recall` and task-briefing
   miss learnings/decisions/episodics that were written to disk. On-disk
   evidence: index file mtime is 2026-03-10 — production retrieval has been
   blind to ~2 months of governance updates. The TTL-driven rebuild appears
   not to be firing in the way the design assumes.

2. **Decision-quality drift** (Q1b) — agent makes decisions missing rules
   that exist in the corpus. Closely related to (1) but distinct: even when
   indexed, the global-flat retrieval doesn't surface cross-cutting
   principles when they apply to a specific decision.

3. **Arc-coherence failure** (Q1c, the headline pain) — weak retrieved
   context causes loss of focus on arc purpose and goals; agent pivots to
   low-value work; arcs don't complete coherently. This is *not* a "search
   quality" problem — it's a structural property of retrieval being
   text-similar rather than arc-aware.

For: agents (machine consumers of retrieval) and humans (who pay the
governance tax of arc drift). Now: because the orchestrator-arc just
shipped substrate (T-1696/97/98) with G-064 open (zero production
consumers), and the embeddings substrate is the single highest-frequency
candidate to validate it.

## Assumptions

Listed for completeness. The grill effectively tested these implicitly via
the human's reactions; build task should formalise via `fw assumption add`.

- Source code + commit-message indexing (W2 fix) **will** materially reduce
  amnesia incidents, *not just* expand corpus size
- Component-fabric edge-based scope expansion (boost-not-filter, layered
  scope) **will** improve relevance without missing cross-cutting context
- Provider routing through the orchestrator **will** generate enough
  outcome signal to drive provider-quality learning (validates G-064
  closure path)
- A bipolar happiness signal (bounded scale, both human and agent) **will**
  produce useful learning gradient without becoming noise
- Eat-our-dogfood applied to T-1717 itself (build under T-1718 Evolution-
  gate discipline) **will** prevent the §ACD pattern this inception just
  diagnosed from biting the build phase

## Exploration Plan

Phase 1 (research): completed via 3 parallel Explore agents — see
`docs/reports/T-1717-embeddings-strategy-grill.md` Phase 1 findings.

Phase 2 (playback): completed; human validated and corrected agent's
mental model, particularly elevating (c) arc-coherence as headline pain.

Phase 3 (grill rounds 1+2): completed — Q1 pain, Q2 success criteria
(happiness signal proposed), Q3 constraint ranking (Quality > affordable
cost > simplicity), Q4 rigidity-vs-evolution (answer: structural
materialisation→reflection loop, sibling task T-1718).

Phase 4 (strengths/weaknesses): completed; 6 strengths, 10 weaknesses
documented in artifact.

Phase 5 (improvement plan): completed; 5 vertical slices with falsifier
on Slice 1.

## Technical Constraints

- **Local-first preferred** but cloud fallback acceptable when Quality
  demands it (Q3 constraint ranking: Quality > affordable Cost; Local-
  first not non-negotiable per human Phase 3)
- **Same-machine same-session freshness** target <5s (catastrophic
  amnesia case A1)
- **Cross-machine federation deferred** to T-704 (out of scope here)
- **Cost cap** required — routing decisions must respect a configurable
  per-call ceiling; manual override always wins
- **Reviewer agent compatibility** — reviewer's verdict must remain a
  first-class signal in the composite quality assessment
- **No separate vector-DB sidecar required** — sqlite-vec is acceptable
  for current scale (21k chunks); migration path to Qdrant/etc. is a
  later question, not blocking

## Scope Fence

**IN scope for T-1717's build streams (post-GO):**
- Post-write incremental embedding (Slice 1)
- Happiness signal capture + schema (Slice 1)
- Provider routing via litellm + resolver (Slice 1, expanded over slices)
- Source code + commit-message indexing (Slice 2)
- Component-fabric edge-coupled scope expansion (Slice 3)
- Reviewer ↔ outcome integration (Slice 4)
- Index de-coupling from git + adaptive freshness telemetry (Slice 5)

**OUT of scope:**
- Cross-machine federation (T-704)
- Reviewer AC-classification noise (separate sibling concern, not blocking)
- Migration off sqlite-vec to Qdrant/Chroma/etc. (later question if scale
  warrants)
- T-1718 Evolution-gate implementation (sibling task — prerequisite but
  separate scope)
- LLM model choice (covered by T-1700 / litellm proxy work)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
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

Three convergent reasons.

(1) **The pain is real, sustained, and high-cost.** Catastrophic agent
amnesia (Q1a) and arc-coherence failure (Q1c) are damaging existing
work — confirmed by the human in Phase 3 ("often occurring damaging,
sometimes catastrophic"). On-disk evidence corroborates: index file
mtime is 2026-03-10, ~2 months stale, meaning the production substrate
has been blind to recent learnings/decisions/episodics. Live, daily
failure — not a hypothetical optimisation.

(2) **The substrate exists; this is integration, not greenfield.**
sqlite-vec + Ollama + RRF + cross-encoder rerank shipped (T-263, T-269).
litellm proxy shipped (T-1700). Resolver + outcome enrichment + dispatch
envelopes shipped (T-1696/97/98). Reviewer agent shipped (T-1443). What's
missing is the connections — feedback loop, routing layer, freshness
mechanism. Composition of existing primitives.

(3) **The fit is structurally aligned.** T-1717 simultaneously (a) fixes
the headline pain, (b) closes G-064 (orchestrator with zero production
consumers — embeddings + LLM become consumer #1), (c) provides the
validation deliverable for the orchestrator-arc's headline mechanic.
Three structural problems addressed by one coherent build, sequenced via
vertical slices to prevent §ACD substrate-vs-deliverable conflation.

**GO is conditional on four prerequisites at decide-time:**

- (i) **T-1718 Evolution-gate** lands first OR commits to land in
  parallel with Slice 1. Eats our dogfood: T-1717 must not be the first
  §ACD victim of an unfixed framework gap that the inception itself
  surfaced.
- (ii) **Vertical-slice discipline applied** — Slice 1 ships end-to-end
  with 7 days of real usage and falsifier check before Slice 2 commits.
  No parallel multi-stream build. Each slice gets a populated Evolution
  log entry before the next begins.
- (iii) **Headline mechanic stated as user-visible result, not substrate.**
  Build task must declare:
  *"Agent issues `fw recall` → resolver routes to optimal embedding
  provider for query class → returns chunks with provenance → outcome
  enrichment captures happiness rating → next routing decision improves.
  **User-visible: amnesia incidents drop, arc-coherence telemetry trends
  positive across the orchestrator-arc.**"*
- (iv) **Orchestrator coupling explicit** — build task declares itself
  the pilot consumer of the orchestrator-arc and references G-064
  closure as a co-deliverable.

**Evidence:**

- Live failure: `.context/working/fw-vec-index.db` mtime 2026-03-10 →
  retrieval ~2 months stale on disk. Run `stat -c '%y' .context/working/fw-vec-index.db` to verify.
- Pain confirmed (Phase 3 dialogue log, T-1717 grill artifact lines
  ~250-260).
- Substrate exists: see `.context/litellm-config.yaml` (T-1700);
  `lib/resolver.py` 25kLOC; `lib/outcome.py` 14kLOC;
  `.context/dispatches.jsonl` (3 real dispatches, 100% enrichment ratio
  per `bin/fw orchestrator status`); reviewer 3-layer cron at 04:37.
- G-064 open and citable in concerns register.
- Scale: ~21,292 chunks across ~1,380 files; 75 MB index; minutes to
  regenerate.
- Pattern precedent: T-1715 → T-1716 demonstrates structural enforcement
  > advisory text. Same shape applies here — arc-coherence rules in
  CLAUDE.md exist as advice; T-1717 makes them mechanical via retrieval.

**Risk acknowledged:**

- Scope-by-blast-radius is unproven hypothesis — Slice 3 telemetry is
  the falsifier; boost-not-filter design limits breakdown blast.
- Cloud providers introduce cost variance — mitigated by routing log +
  cost cap + manual override.
- Reviewer AC-classification noise is separate concern (filed for
  capture) — not blocking T-1717.
- Cross-machine freshness deferred to T-704; arc covers same-machine
  A1/B1 only.
- T-1718 prerequisite is itself unbuilt — honest meta-risk: T-1717 GO
  conditions on a sibling structural fix that hasn't shipped. Acceptable
  only if (a) T-1718 ships first OR (b) human accepts the §ACD risk
  consciously and logs it as Tier-2 bypass at Slice 1 commit.

**Sequencing recommendation:** T-1718 Slice 1 → T-1717 Slice 1 →
evaluate via 7-day falsifier → subsequent slices alternating between
the two arcs as evidence warrants.

**Full Phase 1–5 dialogue, findings, and design analysis:**
[`docs/reports/T-1717-embeddings-strategy-grill.md`](../../../docs/reports/T-1717-embeddings-strategy-grill.md)

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

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale:

Three convergent reasons.

(1) The pain is real, sustained, and high-cost. Catastrophic agent
amnesia (Q1a) and arc-coherence failure (Q1c) are damaging existing
work — confirmed by the human in Phase 3 ("often occurring damaging,
sometimes catastrophic"). On-disk evidence corroborates: index file
mtime is 2026-03-10, ~2 months stale, meaning the production substrate
has been blind to recent learnings/decisions/episodics. Live, daily
failure — not a hypothetical optimisation.

(2) The substrate exists; this is integration, not greenfield.
sqlite-vec + Ollama + RRF + cross-encoder rerank shipped (T-263, T-269).
litellm proxy shipped (T-1700). Resolver + outcome enrichment + dispatch
envelopes shipped (T-1696/97/98). Reviewer agent shipped (T-1443). What's
missing is the connections — feedback loop, routing layer, freshness
mechanism. Composition of existing primitives.

(3) The fit is structurally aligned. T-1717 simultaneously (a) fixes
the headline pain, (b) closes G-064 (orchestrator with zero production
consumers — embeddings + LLM become consumer #1), (c) provides the
validation deliverable for the orchestrator-arc's headline mechanic.
Three structural problems addressed by one coherent build, sequenced via
vertical slices to prevent §ACD substrate-vs-deliverable conflation.

GO is conditional on four prerequisites at decide-time:

- (i) T-1718 Evolution-gate lands first OR commits to land in
  parallel with Slice 1. Eats our dogfood: T-1717 must not be the first
  §ACD victim of an unfixed framework gap that the inception itself
  surfaced.
- (ii) Vertical-slice discipline applied — Slice 1 ships end-to-end
  with 7 days of real usage and falsifier check before Slice 2 commits.
  No parallel multi-stream build. Each slice gets a populated Evolution
  log entry before the next begins.
- (iii) Headline mechanic stated as user-visible result, not substrate.
  Build task must declare:
  "Agent issues `fw recall` → resolver routes to optimal embedding
  provider for query class → returns chunks with provenance → outcome
  enrichment captures happiness rating → next routing decision improves.
  User-visible: amnesia incidents drop, arc-coherence telemetry trends
  positive across the orchestrator-arc."
- (iv) Orchestrator coupling explicit — build task declares itself
  the pilot consumer of the orchestrator-arc and references G-064
  closure as a co-deliverable.

Evidence:

- Live failure: `.context/working/fw-vec-index.db` mtime 2026-03-10 →
  retrieval ~2 months stale on disk. Run `stat -c '%y' .context/working/fw-vec-index.db` to verify.
- Pain confirmed (Phase 3 dialogue log, T-1717 grill artifact lines
  ~250-260).
- Substrate exists: see `.context/litellm-config.yaml` (T-1700);
  `lib/resolver.py` 25kLOC; `lib/outcome.py` 14kLOC;
  `.context/dispatches.jsonl` (3 real dispatches, 100% enrichment ratio
  per `bin/fw orchestrator status`); reviewer 3-layer cron at 04:37.
- G-064 open and citable in concerns register.
- Scale: ~21,292 chunks across ~1,380 files; 75 MB index; minutes to
  regenerate.
- Pattern precedent: T-1715 → T-1716 demonstrates structural enforcement
  > advisory text. Same shape applies here — arc-coherence rules in
  CLAUDE.md exist as advice; T-1717 makes them mechanical via retrieval.

Risk acknowledged:

- Scope-by-blast-radius is unproven hypothesis — Slice 3 telemetry is
  the falsifier; boost-not-filter design limits breakdown blast.
- Cloud providers introduce cost variance — mitigated by routing log +
  cost cap + manual override.
- Reviewer AC-classification noise is separate concern (filed for
  capture) — not blocking T-1717.
- Cross-machine freshness deferred to T-704; arc covers same-machine
  A1/B1 only.
- T-1718 prerequisite is itself unbuilt — honest meta-risk: T-1717 GO
  conditions on a sibling structural fix that hasn't shipped. Acceptable
  only if (a) T-1718 ships first OR (b) human accepts the §ACD risk
  consciously and logs it as Tier-2 bypass at Slice 1 commit.

Sequencing recommendation: T-1718 Slice 1 → T-1717 Slice 1 →
evaluate via 7-day falsifier → subsequent slices alternating between
the two arcs as evidence warrants.

Full Phase 1–5 dialogue, findings, and design analysis:
[`docs/reports/T-1717-embeddings-strategy-grill.md`](../../../docs/reports/T-1717-embeddings-strategy-grill.md)

**Date**: 2026-05-04T16:49:06Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-04T12:26:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-04T15:03:13Z — status-update [task-update-agent]
- **Change:** tags: +arc:embeddings-strategy

### 2026-05-04T16:49:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

Three convergent reasons.

(1) The pain is real, sustained, and high-cost. Catastrophic agent
amnesia (Q1a) and arc-coherence failure (Q1c) are damaging existing
work — confirmed by the human in Phase 3 ("often occurring damaging,
sometimes catastrophic"). On-disk evidence corroborates: index file
mtime is 2026-03-10, ~2 months stale, meaning the production substrate
has been blind to recent learnings/decisions/episodics. Live, daily
failure — not a hypothetical optimisation.

(2) The substrate exists; this is integration, not greenfield.
sqlite-vec + Ollama + RRF + cross-encoder rerank shipped (T-263, T-269).
litellm proxy shipped (T-1700). Resolver + outcome enrichment + dispatch
envelopes shipped (T-1696/97/98). Reviewer agent shipped (T-1443). What's
missing is the connections — feedback loop, routing layer, freshness
mechanism. Composition of existing primitives.

(3) The fit is structurally aligned. T-1717 simultaneously (a) fixes
the headline pain, (b) closes G-064 (orchestrator with zero production
consumers — embeddings + LLM become consumer #1), (c) provides the
validation deliverable for the orchestrator-arc's headline mechanic.
Three structural problems addressed by one coherent build, sequenced via
vertical slices to prevent §ACD substrate-vs-deliverable conflation.

GO is conditional on four prerequisites at decide-time:

- (i) T-1718 Evolution-gate lands first OR commits to land in
  parallel with Slice 1. Eats our dogfood: T-1717 must not be the first
  §ACD victim of an unfixed framework gap that the inception itself
  surfaced.
- (ii) Vertical-slice discipline applied — Slice 1 ships end-to-end
  with 7 days of real usage and falsifier check before Slice 2 commits.
  No parallel multi-stream build. Each slice gets a populated Evolution
  log entry before the next begins.
- (iii) Headline mechanic stated as user-visible result, not substrate.
  Build task must declare:
  "Agent issues `fw recall` → resolver routes to optimal embedding
  provider for query class → returns chunks with provenance → outcome
  enrichment captures happiness rating → next routing decision improves.
  User-visible: amnesia incidents drop, arc-coherence telemetry trends
  positive across the orchestrator-arc."
- (iv) Orchestrator coupling explicit — build task declares itself
  the pilot consumer of the orchestrator-arc and references G-064
  closure as a co-deliverable.

Evidence:

- Live failure: `.context/working/fw-vec-index.db` mtime 2026-03-10 →
  retrieval ~2 months stale on disk. Run `stat -c '%y' .context/working/fw-vec-index.db` to verify.
- Pain confirmed (Phase 3 dialogue log, T-1717 grill artifact lines
  ~250-260).
- Substrate exists: see `.context/litellm-config.yaml` (T-1700);
  `lib/resolver.py` 25kLOC; `lib/outcome.py` 14kLOC;
  `.context/dispatches.jsonl` (3 real dispatches, 100% enrichment ratio
  per `bin/fw orchestrator status`); reviewer 3-layer cron at 04:37.
- G-064 open and citable in concerns register.
- Scale: ~21,292 chunks across ~1,380 files; 75 MB index; minutes to
  regenerate.
- Pattern precedent: T-1715 → T-1716 demonstrates structural enforcement
  > advisory text. Same shape applies here — arc-coherence rules in
  CLAUDE.md exist as advice; T-1717 makes them mechanical via retrieval.

Risk acknowledged:

- Scope-by-blast-radius is unproven hypothesis — Slice 3 telemetry is
  the falsifier; boost-not-filter design limits breakdown blast.
- Cloud providers introduce cost variance — mitigated by routing log +
  cost cap + manual override.
- Reviewer AC-classification noise is separate concern (filed for
  capture) — not blocking T-1717.
- Cross-machine freshness deferred to T-704; arc covers same-machine
  A1/B1 only.
- T-1718 prerequisite is itself unbuilt — honest meta-risk: T-1717 GO
  conditions on a sibling structural fix that hasn't shipped. Acceptable
  only if (a) T-1718 ships first OR (b) human accepts the §ACD risk
  consciously and logs it as Tier-2 bypass at Slice 1 commit.

Sequencing recommendation: T-1718 Slice 1 → T-1717 Slice 1 →
evaluate via 7-day falsifier → subsequent slices alternating between
the two arcs as evidence warrants.

Full Phase 1–5 dialogue, findings, and design analysis:
[`docs/reports/T-1717-embeddings-strategy-grill.md`](../../../docs/reports/T-1717-embeddings-strategy-grill.md)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-974e00ce
- **Timestamp:** 2026-05-04T16:49:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-04T16:49:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
