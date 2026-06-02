---
id: T-1141
name: "Pickup: PL-007: Never dump terminal commands — always use fw task review + termlink inject (from 010-termlink)"
description: >
  Auto-created from pickup envelope. Source: 010-termlink, task T-967. Type: learning.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [pickup, learning]
components: []
related_tasks: []
created: 2026-04-12T09:57:49Z
last_update: 2026-04-13T06:23:20Z
date_finished: 2026-04-12T11:05:06Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1141: Pickup: PL-007: Never dump terminal commands — always use fw task review + termlink inject (from 010-termlink)

## Problem Statement

Agents output bare CLI commands instead of using `fw task review` / Watchtower. Reported 3+ times across sessions. Root cause: framework gate scripts (update-task.sh, inception.sh, check-tier0.sh) print "run this command" in their error messages. Even with CLAUDE.md rules, agents relay these messages verbatim. The T-972 incident from 010-termlink: agent violated PL-007 within 3 minutes of building it.

**Partial fix already applied:** T-1143 added `_fw_cmd` / `_emit_user_command` helpers and fixed 3 hardcoded `bin/fw` sites. T-1142 replaced `--force` with narrow flags. But the scripts still OUTPUT commands instead of INVOKING the review UX.

## Assumptions

- A1: Making gate scripts invoke `emit_review` instead of printing commands will eliminate the class of bug (framework-caused command amnesia)
- A2: A PostToolUse hook to detect bare command patterns is too noisy (false positives on legitimate command output)
- A3: T-1146 (command amnesia RCA) covers the same structural issue and should be consolidated

## Exploration Plan

1. Audit gate scripts for remaining "output command" sites
2. Assess `emit_review` integration feasibility
3. Consolidate with T-1146

## Scope Fence

**IN:** RCA, audit, recommendation, research artifact.
**OUT:** Implementation (build task downstream).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

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
- The root cause is confirmed as framework scripts outputting commands (confirmed: T-1143 fixed 3 sites, more remain)
- The fix is incremental on existing work (confirmed: T-1143 infrastructure in place)
- Consolidation with T-1146 is feasible (confirmed: same root cause)

**NO-GO if:**
- The agent behavior is the real root cause, not framework scripts (disproved: framework scripts ARE the source)

## Verification

test -f docs/reports/T-1141-pl-007-enforcement.md
grep -q "Recommendation.*GO" docs/reports/T-1141-pl-007-enforcement.md

## Recommendation

**Recommendation:** GO — consolidate with T-1146 into one build task.

**Rationale:** The root cause is framework gate scripts outputting bare commands in error messages. T-1143 fixed the command PATH issue (bin/fw vs .agentic-framework/bin/fw), but scripts still print "run: fw inception decide..." instead of invoking `fw task review`. The fix is incremental: gate scripts should call `emit_review()` instead of echoing commands. ~50 lines across 3 files.

**Evidence:**
- 3+ incidents of agents relaying bare commands
- T-972: agent violated PL-007 within 3 minutes of building it
- T-1143 partial fix already in place (infrastructure ready)
- CLAUDE.md rule doesn't survive compaction — structural fix needed
- Research artifact: `docs/reports/T-1141-pl-007-enforcement.md`

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO — consolidate with T-1146 into one build task.

Rationale: The root cause is framework gate scripts outputting bare commands in error messages. T-1143 fixed the command PATH issu...

**Date**: 2026-04-12T11:04:25Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — consolidate with T-1146 into one build task.

Rationale: The root cause is framework gate scripts outputting bare commands in error messages. T-1143 fixed the command PATH issu...

**Date**: 2026-04-12T11:04:25Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-12T10:41:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T11:04:08Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — consolidate with T-1146 into one build task.

Rationale: The root cause is framework gate scripts outputting bare commands in error messages. T-1143 fixed the command PATH issu...

### 2026-04-12T11:04:13Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — consolidate with T-1146 into one build task.

Rationale: The root cause is framework gate scripts outputting bare commands in error messages. T-1143 fixed the command PATH issu...

### 2026-04-12T11:04:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — consolidate with T-1146 into one build task.

Rationale: The root cause is framework gate scripts outputting bare commands in error messages. T-1143 fixed the command PATH issu...

### 2026-04-12T11:05:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception complete — GO recommendation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-969254ee
- **Timestamp:** 2026-06-02T14:55:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
