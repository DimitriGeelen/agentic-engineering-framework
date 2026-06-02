---
id: T-882
name: "TermLink-based cron dispatch — spawn scheduled Claude sessions for deterministic audit/health tasks with interpreted output"
description: >
  Inception: TermLink-based cron dispatch — spawn scheduled Claude sessions for deterministic audit/health tasks with interpreted output

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-05T06:58:24Z
last_update: 2026-04-13T13:20:23Z
date_finished: 2026-04-13T13:20:23Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-882: TermLink-based cron dispatch — spawn scheduled Claude sessions for deterministic audit/health tasks with interpreted output

## Problem Statement

Currently, the framework runs cron audits via bash scripts (agents/audit/audit.sh) which are purely mechanical — they check structural compliance but cannot interpret meaning, suggest fixes, or learn from patterns. The cron system also has zombie accumulation issues (T-866).

The idea: use TermLink to spawn scheduled Claude sessions (`claude -p` or `claude-fw`) that run deterministic but AI-interpreted tasks:
- Audit interpretation — not just "WARN: 70 stale tasks" but "these 12 tasks are safe to close because..."
- Health remediation — automatically fix simple issues found by `fw doctor`
- Cross-project health checks — fleet-wide status with intelligent summarization
- Pattern mining — scan episodic memory for recurring patterns worth promoting

**Key question:** What's the value vs cost of replacing/augmenting bash cron jobs with TermLink-dispatched Claude sessions? The sessions cost tokens, but produce richer output and can take actions.

**For whom:** Framework operators who want proactive, intelligent maintenance without manual sessions.
**Why now:** TermLink dispatch is stable (T-571, T-818), cron registry exists (T-448), `claude-fw` wrapper handles auto-restart. The primitives are ready.

## Assumptions

- A1: `claude -p` can be reliably invoked from cron (no TTY, no interactive prompts)
- A2: TermLink can spawn and manage cron-triggered sessions (PTY injection or `termlink run`)
- A3: Output from scheduled sessions can be captured and stored deterministically
- A4: Token cost per scheduled session is acceptable (<$0.10 for a 5-min health check)
- A5: Scheduled sessions should remain deterministic (same input → same structural actions) while adding interpretive value
- A6: Local LLM (Ollama on .107) could handle some tasks to reduce API costs

## Exploration Plan

### Spike 1: Dispatch mechanism comparison
1. `claude -p` directly from cron (simplest)
2. `termlink run` wrapping `claude -p` (observable, killable)
3. `fw termlink dispatch` from cron (task-tagged, budget-aware)
4. PTY injection into standing session (complex, bidirectional)

### Spike 2: Use case value assessment
1. Which current bash cron tasks would benefit from AI interpretation?
2. What new scheduled tasks become possible with AI interpretation?
3. Cost per scheduled session (token usage, latency, reliability)
4. Failure modes (API down, context exhaustion, hallucination in automated actions)

### Spike 3: Determinism and safety
1. How to ensure scheduled sessions don't take unintended actions
2. Output interpretation — structured JSON vs free-form
3. Integration with existing cron registry (T-448)
4. Local LLM fallback for cost-sensitive tasks

## Technical Constraints

- Cron runs without TTY — `claude -p` needs `--no-interactive` or equivalent
- Budget gate needs to work in headless sessions
- Output must be captured to file (no terminal)
- Token costs must be bounded and tracked

## Scope Fence

**IN scope:**
- Evaluating dispatch mechanisms (spike 1)
- Identifying valuable scheduled AI tasks (spike 2)
- Safety model for automated AI actions (spike 3)
- Cost analysis

**OUT of scope:**
- Building the full system (that's a build task after GO)
- Cross-machine dispatch (TermLink hub — separate concern)
- Replacing ALL bash cron with AI (some tasks should stay mechanical)

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] All 3 spikes completed with findings
- [x] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-882-termlink-cron-dispatch.md`
  2. Evaluate cost/value tradeoff
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-882 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- At least 3 use cases where AI interpretation adds clear value over bash scripting
- Token cost per session is predictable and bounded
- A safe dispatch mechanism exists that prevents unintended actions

**NO-GO if:**
- Token cost exceeds value of automated interpretation
- No reliable headless dispatch mechanism exists
- Safety model can't prevent automated AI from taking destructive actions

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

- **Recommendation:** GO
- **Rationale:** 5 high-value use cases identified. `fw termlink dispatch` mechanism already works. Token cost ~$1-3/day. Safety model (read-only + structured output + action separation) prevents unintended mutations.
- **Evidence:**
  - 4 dispatch mechanisms evaluated, Option C (fw termlink dispatch) is best
  - `claude -p` works headlessly from cron (no TTY needed)
  - `--json-schema` enables deterministic structured output
  - Hybrid local/API approach reduces cost for simple tasks
  - Research in `docs/reports/T-882-termlink-cron-dispatch.md`

## Decision

**Decision**: NO-GO

**Rationale**: - Recommendation: GO
- Rationale: 5 high-value use cases identified. `fw termlink dispatch` mechanism already works. Token cost ~$1-3/day. Safety model (read-only + structured output + action separation) prevents unintended mutations.
- Evidence:
  - 4 dispatch mechanisms evaluated, Option C (fw termlink dispatch) is best
  - `claude -p` works headlessly from cron (no TTY needed)
  - `--json-schema` enables deterministic structured output
  - Hybrid local/API approach reduces cost for simple tasks
  - Research in `docs/reports/T-882-termlink-cron-dispatch.md`

**Date**: 2026-04-13T11:27:35Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-05T07:10:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:26:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-13T11:27:35Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: GO
- Rationale: 5 high-value use cases identified. `fw termlink dispatch` mechanism already works. Token cost ~$1-3/day. Safety model (read-only + structured output + action separation) prevents unintended mutations.
- Evidence:
  - 4 dispatch mechanisms evaluated, Option C (fw termlink dispatch) is best
  - `claude -p` works headlessly from cron (no TTY needed)
  - `--json-schema` enables deterministic structured output
  - Hybrid local/API approach reduces cost for simple tasks
  - Research in `docs/reports/T-882-termlink-cron-dispatch.md`

### 2026-04-13T13:20:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** T-1226: Status fix for stuck inception

### 2026-04-13T13:20:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: NO-GO decision recorded via Watchtower

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4af2c7b7
- **Timestamp:** 2026-06-02T15:05:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
