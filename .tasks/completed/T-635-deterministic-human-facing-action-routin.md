---
id: T-635
name: "Deterministic human-facing action routing — structural enforcement that agent
  always routes through Watchtower/fw-task-review instead of pasting raw commands"
description: >
  Inception: Deterministic human-facing action routing — structural enforcement that
  agent always routes through Watchtower/fw-task-review instead of pasting raw commands

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: [agents/context/check-tier0.sh]
related_tasks: []
created: 2026-03-27T08:42:51Z
last_update: '2026-08-16T22:25:35Z'
date_finished: 2026-03-27T09:56:30Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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
  - ts: '2026-08-16T22:25:35Z'
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

# T-635: Deterministic human-facing action routing — structural enforcement that agent always routes through Watchtower/fw-task-review instead of pasting raw commands

## Problem Statement

The agent keeps bypassing standard human-facing tools (fw task review, Watchtower /approvals) by pasting raw commands as text. This happened 3+ times in the current session alone — minutes after building T-634 (deterministic review). Behavioral rules (T-325, T-372) have failed to fix this pattern. We need structural enforcement at every layer.

## Assumptions

1. The CLI layer (emit_review auto-fire) works — problem is the agent doesn't run the command
2. Claude Code has no PreTextOutput hook — we cannot block raw command presentation
3. Making the correct path easier than the wrong path will reduce (not eliminate) bypassing
4. check-tier0.sh is the best enforcement point for Tier 0 actions (already fires structurally)
5. Skills are the best enforcement point for agent behavior (easier to invoke than compose)

## Exploration Plan

- Spike 1: Hook fire analysis — what fires when agent presents human actions (done)
- Spike 2: Can we detect raw command presentation? (done — no, but PostToolUse is advisory)
- Spike 3: check-tier0.sh emit Watchtower link on block (done — feasible, ~10 lines)
- Spike 4: Workflow skills /go-decision, /approve (done — feasible, markdown files)
- Spike 5: CLAUDE.md behavioral backup rule (done — least reliable layer)

## Technical Constraints

- Claude Code hooks: PreToolUse can block (exit 2), PostToolUse is advisory only
- No PreTextOutput hook exists — agent text output is unmonitorable
- Skills must be invoked by the agent — no auto-trigger mechanism
- check-tier0.sh runs in PreToolUse context — can emit to stderr (shown to agent)

## Scope Fence

**IN:** check-tier0.sh enhancement, /go-decision skill, CLAUDE.md rule
**OUT:** PostToolUse detection of raw commands (advisory-only, low value), changes to Claude Code hook system

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale (docs/reports/T-635-human-action-routing.md)

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
- At least 2 of 3 deliverables are feasible with <50 lines each
- The structural enforcement point (check-tier0.sh) can emit Watchtower links
- Evidence of 3+ bypasses in a single session (confirmed: this session)

**NO-GO if:**
- Claude Code adds PreTextOutput hooks (making behavioral enforcement possible — revisit approach)
- The overhead of routing through Watchtower is unacceptable for fast workflows

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: 3+ bypasses this session, all 3 deliverables feasible under 50 lines each

**Date**: 2026-03-27T09:48:39Z
## Decision

**Decision**: GO

**Rationale**: 3+ bypasses this session, all 3 deliverables feasible under 50 lines each

**Date**: 2026-03-27T09:48:39Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-27T08:43:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27T09:48:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 3+ bypasses this session, all 3 deliverables feasible under 50 lines each

### 2026-03-27T09:56:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dc5ed6ec
- **Timestamp:** 2026-06-02T15:04:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
