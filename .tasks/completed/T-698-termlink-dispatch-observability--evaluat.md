---
id: T-698
name: "TermLink dispatch observability — evaluate interactive vs headless worker mode
  for human observation"
description: >
  Inception: TermLink dispatch observability — evaluate interactive vs headless worker
  mode for human observation

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: [T-697, T-696, T-679, T-577]
created: 2026-03-29T08:18:33Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-29T13:34:02Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
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

# T-698: TermLink dispatch observability — evaluate interactive vs headless worker mode for human observation

## Problem Statement

`fw termlink dispatch` uses `claude -p --output-format text > result.md` — a headless pipe. The human cannot observe the worker in real time. `termlink attach` shows the shell that launched it, not the Claude session's tool calls or reasoning.

**Discovery:** T-697 (KCP deep-dive) — human asked to see what the worker was doing. Mirror terminal showed nothing useful because Claude's output was piped to a file. The worker was clearly working (pstree showed active child processes, tasks were being completed) but the human had zero visibility.

**Why now:** Path C workflow (T-696) requires human trust in an autonomous worker operating in an external project. Observability is a UX requirement, not a nice-to-have.

**Why headless was chosen:** Traced to T-143 (tl-dispatch.sh). Practical reasons: reliable output capture (no ANSI codes), macOS compat, clean kill-watchdog lifecycle. See research artifact.

## Assumptions

A-1: Interactive `claude` in a TermLink PTY session is technically feasible (vs. `claude -p`)
A-2: The human wants to see tool calls and reasoning, not just final output
A-3: There's a middle ground (e.g., `claude -p` with streaming + tee) that preserves reliability while adding observability
A-4: ~~The current headless approach was an engineering convenience, not a deliberate design choice~~ INVALIDATED — traced to deliberate choices in T-143 for output reliability

## Exploration Plan

1. **Spike 1:** Research why `run.sh` uses `claude -p` — check T-522, T-577 for original design decisions
2. **Spike 2:** Test alternatives — `claude -p` with `tee`, interactive `claude` in PTY, streaming JSON
3. **Spike 3:** Evaluate tradeoffs — reliability, output capture, human UX, context cost

## Scope Fence

**IN:** Evaluate dispatch observability options, prototype one alternative
**OUT:** Rebuilding the entire dispatch system, TermLink product changes

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Current headless design rationale documented
- [x] At least 2 alternatives evaluated with tradeoffs
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-698 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- An alternative exists that adds observability without breaking output capture reliability
- Implementation is bounded (< 1 session)

**NO-GO if:**
- All alternatives compromise reliability (output capture, error handling)
- Observability requires TermLink product changes we can't control

## Verification

# Research artifact exists
test -f docs/reports/T-698-dispatch-observability.md
# Contains alternatives evaluation
grep -q "Tradeoff Matrix" docs/reports/T-698-dispatch-observability.md
# Contains recommendation
grep -q "Recommendation" docs/reports/T-698-dispatch-observability.md

## Decisions

**Decision**: GO

**Rationale**: - Recommendation: GO
- Rationale: 4 alternatives evaluated (tee, stream-json, interactive, hybrid). Option A (tee) is a 1-line change that eliminates the complete-blackout problem. Option D (hybrid...

**Date**: 2026-03-29T13:34:02Z

## Recommendation

- **Recommendation:** GO
- **Rationale:** 4 alternatives evaluated (tee, stream-json, interactive, hybrid). Option A (tee) is a 1-line change that eliminates the complete-blackout problem. Option D (hybrid stream-json parse) is the full solution but warrants a separate build task. Option C (interactive claude) is NO-GO — output capture becomes unreliable. All options work with current TermLink (no upstream changes needed).
- **Evidence:**
  - Research artifact: `docs/reports/T-698-dispatch-observability.md`
  - Current implementation traced: `agents/termlink/termlink.sh:283` — `claude -p --output-format text > result.md`
  - Headless rationale documented from T-143, T-503, T-577
  - 4 alternatives with tradeoff matrix (effort, observability, reliability, macOS compat)
  - L-128 (KCP learnings) confirms "worker observability (headless claude -p gives zero live visibility)" as known gap
- **Next steps after GO:**
  - Phase 1 build task: change `>` to `| tee` in run.sh (1 line, bounded)
  - Phase 2 build task: stream-json parse loop for tool-call visibility (separate task)

## Decision

**Decision**: GO

**Rationale**: - Recommendation: GO
- Rationale: 4 alternatives evaluated (tee, stream-json, interactive, hybrid). Option A (tee) is a 1-line change that eliminates the complete-blackout problem. Option D (hybrid...

**Date**: 2026-03-29T13:34:02Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-29T12:55:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T13:34:02Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** - Recommendation: GO
- Rationale: 4 alternatives evaluated (tee, stream-json, interactive, hybrid). Option A (tee) is a 1-line change that eliminates the complete-blackout problem. Option D (hybrid...

### 2026-03-29T13:34:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-06T22:29:21Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-64106859
- **Timestamp:** 2026-06-02T15:04:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
