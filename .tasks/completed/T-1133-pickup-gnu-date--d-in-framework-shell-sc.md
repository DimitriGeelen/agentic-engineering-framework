---
id: T-1133
name: "Pickup: GNU date -d in framework shell scripts fails silently on macOS — causes episodic generation failures (from 010-termlink)"
description: >
  Auto-created from pickup envelope. Source: 010-termlink, task T-962. Type: bug-report.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-12T09:00:04Z
last_update: 2026-04-22T05:25:52Z
date_finished: 2026-04-22T05:25:52Z
---

# T-1133: Pickup: GNU date -d in framework shell scripts fails silently on macOS — causes episodic generation failures (from 010-termlink)

## Problem Statement

External pickup from 010-termlink proposing: GNU date -d in framework shell scripts fails silently on macOS. Verification this session: the proposed fix has already shipped in T-1134 + T-1158. Triage decision is whether to DEFER as duplicate.

## Assumptions

1. T-1134 + T-1158 already implements the proposed fix — TESTED TRUE (see Evidence)
2. No additional scope remains beyond what's shipped — TESTED TRUE

## Exploration Plan

5-min time-box (done):
- Locate the proposed fix in framework code — DONE
- Verify T-1134 + T-1158 status — DONE (work-completed)
- Diff pickup proposal vs shipped behavior — DONE (matches)

## Technical Constraints

None. Triage only.

## Scope Fence

**IN:** decide whether T-1133 adds anything beyond the T-1134 + T-1158 fix.
**OUT:** re-implementing what's already shipped.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (proposal matches what T-1134 + T-1158 already shipped)
- [x] Assumptions tested (2/2 true)
- [x] Recommendation written with rationale (DEFER — shipped in T-1134 + T-1158)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- New scope exists beyond T-1134 + T-1158's fix

**NO-GO if:**
- The fix is already in tree (this is the case here — DEFER)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER (close as duplicate of T-1134 + T-1158)

**Rationale:** External pickup from 010-termlink proposing "GNU date -d in framework shell scripts fails silently on macOS". Verification this session shows the fix is already in tree, shipped by T-1134 + T-1158. Closing the pickup is the correct response — no new work to do.

**Evidence:**
- lib/compat.sh exports _date_to_epoch and _date_relative with fallback chain: GNU date → BSD date → python3
- All agents/ scripts already use the helpers (no raw 'date -d' in agents/)
- Only bin/fw:1159 and bin/fw:1167 use raw 'date -d' with inline BSD fallback (still portable)
- T-1134 (initial portability) and T-1158 (helpers) shipped the proposed fix

If 010-termlink is observing the symptom anew, root cause is likely a stale framework copy on the consumer side — operator should run `fw upgrade` on 010-termlink to pick up T-1134 + T-1158.

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

**Decision**: DEFER

**Rationale**: Recommendation: DEFER (close as duplicate of T-1134 + T-1158)

Rationale: External pickup from 010-termlink proposing "GNU date -d in framework shell scripts fails silently on macOS". Verification this session shows the fix is already in tree, shipped by T-1134 + T-1158. Closing the pickup is the correct response — no new work to do.

Evidence:
- lib/compat.sh exports _date_to_epoch and _date_relative with fallback chain: GNU date → BSD date → python3
- All agents/ scripts already use the helpers (no raw 'date -d' in agents/)
- Only bin/fw:1159 and bin/fw:1167 use raw 'date -d' with inline BSD fallback (still portable)
- T-1134 (initial portability) and T-1158 (helpers) shipped the proposed fix

If 010-termlink is observing the symptom anew, root cause is likely a stale framework copy on the consumer side — operator should run `fw upgrade` on 010-termlink to pick up T-1134 + T-1158.

**Date**: 2026-04-20T09:40:33Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T09:41:34Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-20T09:40:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER (close as duplicate of T-1134 + T-1158)

Rationale: External pickup from 010-termlink proposing "GNU date -d in framework shell scripts fails silently on macOS". Verification this session shows the fix is already in tree, shipped by T-1134 + T-1158. Closing the pickup is the correct response — no new work to do.

Evidence:
- lib/compat.sh exports _date_to_epoch and _date_relative with fallback chain: GNU date → BSD date → python3
- All agents/ scripts already use the helpers (no raw 'date -d' in agents/)
- Only bin/fw:1159 and bin/fw:1167 use raw 'date -d' with inline BSD fallback (still portable)
- T-1134 (initial portability) and T-1158 (helpers) shipped the proposed fix

If 010-termlink is observing the symptom anew, root cause is likely a stale framework copy on the consumer side — operator should run `fw upgrade` on 010-termlink to pick up T-1134 + T-1158.

### 2026-04-22T05:25:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-22T05:25:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
