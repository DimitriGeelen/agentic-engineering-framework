---
id: T-800
name: "Token efficiency strategies — reduce per-task and per-session cost through
  context management, output discipline, caching, and dispatch optimization"
description: >
  Inception: Explore and evaluate strategies for reducing per-task and per-session
  token costs.
  Map each strategy against the four constitutional directives (Antifragility, Reliability,
  Usability,
  Portability). Quantify the framework's current token overhead, analyze historical
  usage patterns,
  and identify high-ROI optimizations. Depends on T-799 for cost tracking infrastructure.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [cost, tokens, efficiency, context-budget]
components: [budget-gate, checkpoint, bin-fw, hook-config]
related_tasks: [T-799, T-596, T-701, T-699, T-136, T-073]
created: 2026-04-01T09:25:47Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-04-01T11:24:07Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-800: Token efficiency strategies — reduce per-task and per-session cost through context management, output discipline, caching, and dispatch optimization

## Problem Statement

The framework governs token budget as a **session-survival concern** (P-009: don't run out of context) but ignores the **financial cost** of token consumption. With 800+ tasks completed across hundreds of sessions, there is zero visibility into:

- How much each task costs in tokens/dollars
- What the framework's own governance overhead costs (CLAUDE.md loading, hook output injection, memory files, skills definitions = ~20-25K tokens per session before any work)
- Whether architectural choices (Task tool sub-agents vs TermLink dispatch, compaction-and-continue vs fresh sessions) have measurably different cost profiles
- Whether cost is trending up or down as the framework matures

**The physics:** LLM inference scales O(n^2) with context size due to self-attention. This means the cost of each turn accelerates as context fills — a turn at 900K context costs ~20x more compute than the same turn at 200K. Output tokens cost 3-5x more than input tokens. Prompt caching can reduce repeated prefix costs. These are architectural realities, not billing quirks.

**The tension:** The framework's Antifragility directive loads rich context (learnings, patterns, episodic memory, component fabric) to prevent repeat failures. This is valuable — but it has a cost. The question is: *is the failure-prevention value of each loaded context element worth its token cost?*

**For whom:** Framework operator — budget visibility, ROI analysis, cost optimization.
**Why now:** At 800 tasks, usage patterns are mature. The data source exists (JSONL transcripts). T-799 will provide the tracking infrastructure. This task explores what to *do* with that data.

## Assumptions

1. The framework's ~20-25K token overhead per session is a significant % of total session cost (not negligible)
2. Prompt caching (Anthropic's cached prefix feature) could reduce CLAUDE.md reload costs significantly
3. TermLink dispatch is measurably cheaper than Task tool sub-agents for equivalent work (due to context inheritance)
4. Shorter sessions (more frequent handovers) are cheaper than long sessions with compaction, due to quadratic scaling
5. Some loaded context (skills definitions, memory files, component fabric) has low utilization-to-cost ratio
6. Historical JSONL transcripts contain enough data to empirically validate these assumptions

## Exploration Plan

**Spike 1: Empirical baseline — current cost profile** (TermLink worker 1)
- Parse 5-10 recent JSONL transcripts for token usage patterns
- Measure: tokens per turn at different context levels, total session tokens, input vs output ratio
- Quantify: framework overhead tokens vs productive work tokens
- Deliverable: `docs/reports/T-800-spike-1-baseline.md`

**Spike 2: Prompt caching opportunity** (TermLink worker 2)
- Research current Anthropic prompt caching: how it works, pricing, what qualifies
- Measure: how much of our per-session prefix is cacheable (CLAUDE.md, system prompt, skills)
- Estimate: cost reduction if caching is enabled/optimized
- Check: does Claude Code already use prompt caching? If so, what's cached?
- Deliverable: `docs/reports/T-800-spike-2-caching.md`

**Spike 3: Dispatch cost comparison — Task tool vs TermLink** (TermLink worker 3)
- Analyze token cost of Task tool sub-agents (they inherit parent context)
- Compare with TermLink dispatch (independent sessions, start fresh)
- Model: at what parent context level does TermLink become cheaper?
- Deliverable: `docs/reports/T-800-spike-3-dispatch-costs.md`

**Spike 4: Session length optimization** (TermLink worker 4)
- Model: cost of one long session (0→200K→compact→0→200K) vs two fresh sessions (0→200K, 0→200K)
- Factor in: handover overhead, resume overhead, quadratic curve shape
- Identify: optimal session length for cost efficiency
- Deliverable: `docs/reports/T-800-spike-4-session-length.md`

**Spike 5: Directive mapping — cost vs governance value** (TermLink worker 5)
- Map each token-consuming framework element against the four directives:
  | Element | Tokens | Directive served | Evidence of value | Cost-justified? |
  |---------|--------|-----------------|-------------------|-----------------|
  | CLAUDE.md | ~15K | All four | Core governance | Likely yes |
  | Memory files | ~2K | Antifragility | Cross-session learning | Measure |
  | Skills defs | ~1K | Usability | Skill routing | Measure |
  | Hook output | variable | Reliability | Enforcement | Measure |
  | Episodic/handover | ~3-5K | Antifragility | Session continuity | Measure |
- Identify: which elements have highest tokens-per-value-unit
- Propose: tiered loading (load-on-demand vs always-load) per directive priority
- Deliverable: `docs/reports/T-800-spike-5-directive-mapping.md`

**Spike 6: /clear vs /compact vs continue — context reset strategies** (part of Spike 4 worker or synthesis)
- `/clear` = hard reset, zero tokens, no carry-over. Cheapest restart but most context loss
- `/compact` = summarize + reinject (~3K summary). Preserves continuity but summary may include noise
- Continue = keep going with accumulated context. Most expensive per-turn (quadratic), but no reload cost
- **The quality angle:** "context quality is king" — 100K of focused, relevant tokens costs less AND performs better than 300K polluted with stale debug output, old tool results, and abandoned approaches
- Model: at what context fill % does `/clear` + selective reload become cheaper than continuing?
- Model: does `/compact` summary quality degrade the cost-benefit vs `/clear` + structured handover reload?
- Key question: is there a "context hygiene" protocol — clear at defined checkpoints (after each task completion? after each commit?) — that optimizes both cost and quality?
- Deliverable: fold into `docs/reports/T-800-spike-4-session-length.md`

**Synthesis** (after all spikes)
- Combine findings into ranked strategy recommendations
- Each strategy scored on: cost reduction potential, implementation effort, directive alignment
- Produce final research artifact: `docs/reports/T-800-token-efficiency-strategies.md`

## Technical Constraints

- JSONL transcripts are in `~/.claude/projects/` — outside PROJECT_ROOT (read-only access needed)
- Transcript parsing must be streaming (files can be 100MB+)
- Prompt caching behavior may be opaque — Anthropic may cache automatically without explicit control
- Token pricing changes over time — analysis should use configurable rates
- The framework cannot reduce CLAUDE.md size without governance trade-offs — any reduction is a directive decision
- Context window is currently 1M (Opus 4.6) but was 200K recently (T-596) — strategies must work across sizes

## Scope Fence

**IN scope:**
- Empirical measurement of current token usage patterns
- Prompt caching feasibility and ROI
- Dispatch strategy cost comparison (Task tool vs TermLink)
- Session length optimization modeling
- Framework overhead analysis and tiered loading design
- Directive-mapped strategy recommendations

**OUT of scope:**
- Building the cost tracking infrastructure (that's T-799)
- Changing CLAUDE.md content (this task recommends, a follow-up task implements)
- Anthropic billing/API key management
- Model selection optimization (using Haiku vs Opus for sub-tasks — separate concern)
- Real-time cost alerts during sessions (future task if GO)

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Empirical data shows >20% of session tokens are framework overhead (not productive work)
- At least 2 strategies identified with >15% cost reduction potential and low implementation effort
- Strategies align with (or don't conflict with) constitutional directives
- T-799 tracking infrastructure makes ongoing measurement feasible

**NO-GO if:**
- Framework overhead is <10% of total session cost (optimization not worth the effort)
- All high-impact strategies require sacrificing governance quality (Antifragility/Reliability)
- Token costs are already well-optimized by Anthropic's infrastructure (caching, etc.)
- No reliable way to measure the impact of changes (can't tell if optimization worked)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** Reframed for subscription — token efficiency drives session lifetime and response quality

## Decisions

**Decision**: GO

**Rationale**: Reframed for subscription — token efficiency drives session lifetime and response quality

**Date**: 2026-04-01T22:14:44Z
## Decision

**Decision**: GO

**Rationale**: Reframed for subscription — token efficiency drives session lifetime and response quality

**Date**: 2026-04-01T22:14:44Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-01T09:44:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-01T11:24:07Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Reframed for subscription — token efficiency drives session lifetime and response quality

### 2026-04-01T11:24:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-01T11:29:51Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Reframed for subscription — token efficiency drives session lifetime and response quality

### 2026-04-01T22:14:44Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Reframed for subscription — token efficiency drives session lifetime and response quality

### 2026-04-12T09:27:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b9b7e1b3
- **Timestamp:** 2026-06-02T15:04:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
