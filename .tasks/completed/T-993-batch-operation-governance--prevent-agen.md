---
id: T-993
name: "Batch operation governance — prevent agent batch-modifying task horizons without
  per-task justification"
description: >
  Inception: Batch operation governance — prevent agent batch-modifying task horizons
  without per-task justification

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-07T09:53:46Z
last_update: '2026-08-16T22:25:45Z'
date_finished: 2026-04-13T13:20:24Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:34Z'
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
  - ts: '2026-08-16T22:25:45Z'
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

# T-993: Batch operation governance — prevent agent batch-modifying task horizons without per-task justification

## Problem Statement

Agent batch-moved ~30 tasks' horizons without per-task justification (T-992). User intervened. No structural gate prevents this. The framework prevents agents from completing tasks without evidence (sovereignty gate) and from making GO/NO-GO decisions (Tier 0), but horizon/tag/metadata batch changes have zero enforcement.

Research artifact: `docs/reports/T-993-batch-operation-governance.md`

## Assumptions

- A-001: Batch operations (>3 same operation in a loop) are the pattern to detect
- A-002: The existing check-tier0.sh mechanism can be extended for batch detection
- A-003: Requiring --reason on horizon changes provides audit trail

## Exploration Plan

1. Audit existing controls: check-tier0.sh, update-task.sh, CLAUDE.md rules (done)
2. Evaluate 4 options: Tier 0 pattern, CLAUDE.md rule, --reason flag, batch detection hook
3. Write recommendation

## Technical Constraints

- Hooks fire on Bash tool calls — `fw task update` runs via Bash so hooks CAN intercept
- check-tier0.sh does regex matching on bash commands
- update-task.sh accepts --horizon without --reason
- R-037 (false positive risk on bash text matching) applies

## Scope Fence

**IN scope:** Preventing blind batch task metadata changes (horizon, tags)
**OUT of scope:** Individual per-task changes with justification

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-993`
  2. Review the Recommendation section and go/no-go criteria
  3. Record decision via Watchtower or CLI
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification

## Go/No-Go Criteria

**GO if:**
- At least one option provides structural enforcement (not just advisory)
- Implementation fits in one session
- No false positive risk on legitimate single-task changes

**NO-GO if:**
- All options are advisory-only
- Implementation requires hook infrastructure changes
- High false positive rate on legitimate operations

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO — Implement Option C + B (combined)

**Rationale:** Option C (--reason flag in update-task.sh for horizon changes) provides structural enforcement at the point of action. Combined with Option B (CLAUDE.md rule), this gives both enforcement and guidance. Option D (batch detection) adds unnecessary complexity for a rare event.

**Evidence:**
- T-992: Agent proposed batch-moving 30+ tasks without justification — user had to intervene manually
- check-tier0.sh already enforces inception decisions (T-557) — same pattern could work for batch detection, but simpler to gate at the tool level
- update-task.sh already validates horizon values — adding --reason is a small change
- CLAUDE.md already has §Human Task Completion Rule (T-372) as precedent for "evidence before change"

**Proposed implementation (2 build tasks):**
1. **Build task 1:** Add `--reason` flag to `fw task update --horizon` — log reason in Updates section. Without --reason, print warning but allow (soft gate initially).
2. **Build task 2:** Add CLAUDE.md rule: "Each horizon change requires justification. Never batch-modify >3 tasks without per-task evidence."

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

**Decision**: NO-GO

**Rationale**: Recommendation: GO — Implement Option C + B (combined)

Rationale: Option C (--reason flag in update-task.sh for horizon changes) provides structural enforcement at the point of action. Combined with Option B (CLAUDE.md rule), this gives both enforcement and guidance. Option D (batch detection) adds unnecessary complexity for a rare event.

Evidence:
- T-992: Agent proposed batch-moving 30+ tasks without justification — user had to intervene manually
- check-tier0.sh already enforces inception decisions (T-557) — same pattern could work for batch detection, but simpler to gate at the tool level
- update-task.sh already validates horizon values — adding --reason is a small change
- CLAUDE.md already has §Human Task Completion Rule (T-372) as precedent for "evidence before change"

Proposed implementation (2 build tasks):
1. Build task 1: Add `--reason` flag to `fw task update --horizon` — log reason in Updates section. Without --reason, print warning but allow (soft gate initially).
2. Build task 2: Add CLAUDE.md rule: "Each horizon change requires justification. Never batch-modify >3 tasks without per-task evidence."

**Date**: 2026-04-13T11:27:37Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-07T09:54:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:26:26Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-13T11:27:37Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Recommendation: GO — Implement Option C + B (combined)

Rationale: Option C (--reason flag in update-task.sh for horizon changes) provides structural enforcement at the point of action. Combined with Option B (CLAUDE.md rule), this gives both enforcement and guidance. Option D (batch detection) adds unnecessary complexity for a rare event.

Evidence:
- T-992: Agent proposed batch-moving 30+ tasks without justification — user had to intervene manually
- check-tier0.sh already enforces inception decisions (T-557) — same pattern could work for batch detection, but simpler to gate at the tool level
- update-task.sh already validates horizon values — adding --reason is a small change
- CLAUDE.md already has §Human Task Completion Rule (T-372) as precedent for "evidence before change"

Proposed implementation (2 build tasks):
1. Build task 1: Add `--reason` flag to `fw task update --horizon` — log reason in Updates section. Without --reason, print warning but allow (soft gate initially).
2. Build task 2: Add CLAUDE.md rule: "Each horizon change requires justification. Never batch-modify >3 tasks without per-task evidence."

### 2026-04-13T13:20:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** T-1226: Status fix for stuck inception

### 2026-04-13T13:20:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: NO-GO decision recorded via Watchtower

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ddb6f71a
- **Timestamp:** 2026-06-02T15:06:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
