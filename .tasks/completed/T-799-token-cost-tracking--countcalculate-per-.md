---
id: T-799
name: "Token cost tracking — count/calculate per-task and project-total token usage
  and costs"
description: >
  Inception: Token usage tracking — count per-task and project-total token consumption.
  Subscription model (flat rate) — cost declared in tokens, not dollars.
  Data source: JSONL transcripts contain per-turn usage with cache breakdown.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: [budget-gate, checkpoint]
related_tasks: [T-800, T-699, T-596]
created: 2026-03-31T19:05:13Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-04-01T11:24:04Z
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

# T-799: Token cost tracking — count/calculate per-task and project-total token usage and costs

## Problem Statement

The framework tracks task count, traceability, and session context budget — but has zero visibility into the **financial cost** of AI agent usage. With 800+ tasks completed, the human has no way to answer:

- "How much did this task cost in tokens/dollars?"
- "What's my monthly project spend?"
- "Which task types are most expensive?"
- "Are costs trending up or down as the framework matures?"

**For whom:** The framework operator (Dimitri) — budget visibility, ROI analysis, and cost optimization.
**Why now:** At 800 tasks, cost patterns are mature enough to analyze. The framework already reads session JSONL transcripts (budget-gate.sh) — the data source exists.

## Assumptions

<!-- Register with: fw assumption add "Statement" --task T-799 -->

1. Claude Code session JSONL transcripts contain token usage data (input/output counts per turn)
2. Token counts can be attributed to tasks via commit messages and focus.yaml timestamps
3. Anthropic pricing is stable enough for dollar cost calculation (or can be configured)
4. Historical transcripts are available for retroactive analysis (not just current session)
5. The overhead of parsing transcripts is acceptable for periodic reporting (not real-time)

## Exploration Plan

**Spike 1: Data source audit** (30 min)
- Examine JSONL transcript format — what token fields exist?
- Check if input/output token counts are per-message or cumulative
- Determine if model name is recorded (pricing depends on model)
- Check availability of historical transcripts

**Spike 2: Task attribution feasibility** (30 min)
- Can we map token usage to task IDs? (focus.yaml timestamps + commit timestamps)
- What granularity is possible? (per-task, per-session, per-commit-range?)
- Edge cases: multi-task sessions, housekeeping overhead, compaction events

**Spike 3: Prior art / existing tools** (20 min)
- Does Claude Code expose usage stats natively? (API, CLI flags, /usage command)
- Any existing tools that parse Claude Code transcripts for cost?
- How does the Anthropic API report usage? (for potential API-based tracking)

**Spike 4: Design sketch** (20 min)
- Where to store cost data (SQLite via fw stats? YAML? metrics-history.yaml?)
- CLI interface: `fw costs [task|session|project|monthly]`
- Watchtower integration: cost dashboard, per-task cost badge
- Configurable pricing table (model -> $/1K input tokens, $/1K output tokens)

## Technical Constraints

- JSONL transcripts are stored in `~/.claude/projects/` — outside PROJECT_ROOT
- Transcripts can be large (100MB+ for long sessions) — streaming parse required
- Token pricing changes over time — need versioned pricing config
- Privacy: transcripts contain conversation content, cost tool should only extract numeric fields
- Cross-session attribution: a task may span multiple sessions/transcripts

## Scope Fence

**IN scope:**
- Feasibility of extracting token counts from JSONL transcripts
- Task-level and project-level cost aggregation design
- CLI and Watchtower display design
- Pricing configuration approach

**OUT of scope:**
- Real-time cost tracking during sessions (budget-gate.sh already handles context budget)
- API key management or billing integration with Anthropic
- Multi-user cost splitting
- Cost optimization recommendations (future task if GO)

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
- JSONL transcripts contain per-message token counts (input + output)
- Task attribution is feasible with reasonable accuracy (>80% of tokens attributable)
- Implementation fits within existing fw CLI + Watchtower architecture

**NO-GO if:**
- Token data is not available in transcripts (or only session-total, no per-message)
- Task attribution requires complex heuristics that would be unreliable
- Storage/parsing overhead is prohibitive for the value delivered

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Recommendation

**Recommendation:** GO
**Rationale:** JSONL data confirmed rich and structured, implementation straightforward

## Decisions

**Decision**: GO

**Rationale**: JSONL data confirmed rich and structured, implementation straightforward

**Date**: 2026-04-01T11:24:04Z
## Decision

**Decision**: GO

**Rationale**: JSONL data confirmed rich and structured, implementation straightforward

**Date**: 2026-04-01T11:24:04Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-01T09:41:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-01T11:24:04Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** JSONL data confirmed rich and structured, implementation straightforward

### 2026-04-01T11:24:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9d7b31dd
- **Timestamp:** 2026-06-02T15:04:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
