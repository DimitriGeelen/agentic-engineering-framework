---
id: T-1178
name: "Structural bugfix-learning enforcement — ensure every bugfix task captures
  a learning (G-016)"
description: >
  Inception: Structural bugfix-learning enforcement — ensure every bugfix task captures
  a learning (G-016)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-12T17:32:17Z
last_update: '2026-08-16T22:24:24Z'
date_finished: 2026-04-12T22:15:38Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
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
  - ts: '2026-08-16T22:24:24Z'
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

# T-1178: Structural bugfix-learning enforcement — ensure every bugfix task captures a learning (G-016)

## Problem Statement

0% of 145 bugfix tasks have captured learnings. The `fw fix-learned` command exists (T-329) but is never invoked because there is no structural trigger — learning capture depends entirely on agent behavioral memory, which is consistently skipped during ops-heavy fix cycles. G-016 has been watching since 2026-02-22 with a decision trigger of "same bug class reappears 3rd time" or "bugfix-to-learning ratio stays below 35%". The ratio is at 0% — far below the 35% threshold. The existing `update-task.sh` already prints a learning prompt on task completion (visible in the task update output), but agents ignore it because it's non-blocking.

## Assumptions

- A1: A blocking gate at task completion (similar to P-011 verification gate) would be too disruptive — most bugfixes are routine
- A2: A WARNING-level prompt with specific guidance would be more effective than the current generic prompt
- A3: The audit system can track the ratio and flag it as WARN/FAIL
- A4: Making `fw fix-learned` easier (auto-filling task ref) would increase adoption

## Exploration Plan

1. Audit how update-task.sh currently prompts for learnings — **check what exists**
2. Check if the audit system already tracks bugfix-learning coverage — **verified: WARN at 0%**
3. Evaluate options: (a) gate in update-task.sh, (b) post-commit hook, (c) enhanced prompt, (d) cron/audit escalation
4. Propose bounded build task

## Technical Constraints

- Cannot block task completion on missing learnings — too disruptive for routine fixes
- Must work across all providers (bash-only, no Claude Code specifics)
- Should not add >5s to task completion flow

## Scope Fence

**IN scope:** RCA of why learning capture is skipped, evaluation of structural enforcement options, build proposal.
**OUT of scope:** Retroactive learning generation for existing tasks. Changing the behavioral rule in CLAUDE.md.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1178`
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- A structural enforcement option exists that improves capture rate without blocking routine workflows
- The fix is bounded (single file change, <100 lines)
- Audit already tracks the metric (no new audit code needed)

**NO-GO if:**
- All options require blocking task completion (too disruptive)
- The only fix is a behavioral rule change (already exists, doesn't work)

## Verification

# Research artifact exists
test -f docs/reports/T-1178-bugfix-learning-enforcement.md

## Recommendation

**Recommendation:** GO — enhance update-task.sh learning prompt with actionable guidance + fw fix-learned shortcut

**Rationale:** The current learning prompt in `update-task.sh` is generic ("Consider: fw context add-learning...") and easily ignored. Three escalation levels are feasible:

1. **Level 1 (enhanced prompt):** Replace the generic prompt with specific guidance based on the bugfix class. Include the exact `fw fix-learned T-XXX "description"` command with task ID pre-filled. Make it visually prominent (colored box, not just text).

2. **Level 2 (audit escalation):** The audit already tracks bugfix-learning coverage at WARN. Escalate to FAIL when ratio drops below 10% (currently 0%). This makes it visible in `fw doctor` and pre-push audit.

3. **Level 3 (soft gate):** Add a "learning missing" check to the completion flow that prints a WARNING but does NOT block. The agent sees it, the human sees it in Watchtower. Over time, the combination of prompt + audit + visibility should raise the ratio.

**Evidence:**
- Current ratio: 0% (0/145 bugfix tasks have learnings)
- G-016 decision trigger met: ratio far below 35% threshold
- `update-task.sh` already detects bugfix tasks and prints a prompt (line ~800)
- `fw fix-learned` already exists but is never invoked
- Audit already tracks `Bugfix-learning coverage` as WARN

**Proposed build tasks:**
1. Enhance `update-task.sh` learning prompt — pre-fill `fw fix-learned T-XXX` command, make visually prominent
2. Escalate audit bugfix-learning check from WARN to FAIL below 10%

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — enhance update-task.sh learning prompt with actionable guidance + fw fix-learned shortcut

Rationale: The current learning prompt in `update-task.sh` is generic ("Consider: fw context add-learning...") and easily ignored. Three escalation levels are feasible:

1. Level 1 (enhanced prompt): Replace the generic prompt with specific guidance based on the bugfix class. Include the exact `fw fix-learned T-XXX "description"` command with task ID pre-filled. Make it visually prominent (colored box, not just text).

2. Level 2 (audit escalation): The audit already tracks bugfix-learning coverage at WARN. Escalate to FAIL when ratio drops below 10% (currently 0%). This makes it visible in `fw doctor` and pre-push audit.

3. Level 3 (soft gate): Add a "learning missing" check to the completion flow that prints a WARNING but does NOT block. The agent sees it, the human sees it in Watchtower. Over time, the combination of prompt + audit + visibility should raise the ratio.

Evidence:
- Current ratio: 0% (0/145 bugfix tasks have learnings)
- G-016 decision trigger met: ratio far below 35% threshold
- `update-task.sh` already detects bugfix tasks and prints a prompt (line ~800)
- `fw fix-learned` already exists but is never invoked
- Audit already tracks `Bugfix-learning coverage` as WARN

Proposed build tasks:
1. Enhance `update-task.sh` learning prompt — pre-fill `fw fix-learned T-XXX` command, make visually prominent
2. Escalate audit bugfix-learning check from WARN to FAIL below 10%

**Date**: 2026-04-12T22:15:38Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — enhance update-task.sh learning prompt with actionable guidance + fw fix-learned shortcut

Rationale: The current learning prompt in `update-task.sh` is generic ("Consider: fw context add-learning...") and easily ignored. Three escalation levels are feasible:

1. Level 1 (enhanced prompt): Replace the generic prompt with specific guidance based on the bugfix class. Include the exact `fw fix-learned T-XXX "description"` command with task ID pre-filled. Make it visually prominent (colored box, not just text).

2. Level 2 (audit escalation): The audit already tracks bugfix-learning coverage at WARN. Escalate to FAIL when ratio drops below 10% (currently 0%). This makes it visible in `fw doctor` and pre-push audit.

3. Level 3 (soft gate): Add a "learning missing" check to the completion flow that prints a WARNING but does NOT block. The agent sees it, the human sees it in Watchtower. Over time, the combination of prompt + audit + visibility should raise the ratio.

Evidence:
- Current ratio: 0% (0/145 bugfix tasks have learnings)
- G-016 decision trigger met: ratio far below 35% threshold
- `update-task.sh` already detects bugfix tasks and prints a prompt (line ~800)
- `fw fix-learned` already exists but is never invoked
- Audit already tracks `Bugfix-learning coverage` as WARN

Proposed build tasks:
1. Enhance `update-task.sh` learning prompt — pre-fill `fw fix-learned T-XXX` command, make visually prominent
2. Escalate audit bugfix-learning check from WARN to FAIL below 10%

**Date**: 2026-04-12T22:15:38Z

## Updates

### 2026-04-12T17:32:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T22:15:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — enhance update-task.sh learning prompt with actionable guidance + fw fix-learned shortcut

Rationale: The current learning prompt in `update-task.sh` is generic ("Consider: fw context add-learning...") and easily ignored. Three escalation levels are feasible:

1. Level 1 (enhanced prompt): Replace the generic prompt with specific guidance based on the bugfix class. Include the exact `fw fix-learned T-XXX "description"` command with task ID pre-filled. Make it visually prominent (colored box, not just text).

2. Level 2 (audit escalation): The audit already tracks bugfix-learning coverage at WARN. Escalate to FAIL when ratio drops below 10% (currently 0%). This makes it visible in `fw doctor` and pre-push audit.

3. Level 3 (soft gate): Add a "learning missing" check to the completion flow that prints a WARNING but does NOT block. The agent sees it, the human sees it in Watchtower. Over time, the combination of prompt + audit + visibility should raise the ratio.

Evidence:
- Current ratio: 0% (0/145 bugfix tasks have learnings)
- G-016 decision trigger met: ratio far below 35% threshold
- `update-task.sh` already detects bugfix tasks and prints a prompt (line ~800)
- `fw fix-learned` already exists but is never invoked
- Audit already tracks `Bugfix-learning coverage` as WARN

Proposed build tasks:
1. Enhance `update-task.sh` learning prompt — pre-fill `fw fix-learned T-XXX` command, make visually prominent
2. Escalate audit bugfix-learning check from WARN to FAIL below 10%

### 2026-04-12T22:15:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-926ce010
- **Timestamp:** 2026-06-02T14:55:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
