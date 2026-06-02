---
id: T-1500
name: "Pickup: T-014: fw tier0 approve hash drift — unnormalized COMMAND in check-tier0.sh:167 (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-014. Type: bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [pickup, bug-report]
components: [agents/context/check-tier0.sh, tests/unit/tier0_hash_normalization.bats]
related_tasks: []
created: 2026-04-26T11:13:17Z
last_update: 2026-04-26T11:58:24Z
date_finished: 2026-04-26T11:58:24Z
source_task_id_in_origin: T-014
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1500: Pickup: T-014: fw tier0 approve hash drift — unnormalized COMMAND in check-tier0.sh:167 (from 003-NTB-ATC-Plugin)

## Context

`agents/context/check-tier0.sh:177` hashes `$COMMAND` raw (sha256). When an agent regenerates a blocked command for retry — adding/removing whitespace, reflowing args, changing quote style — the digest drifts and the stored approval no longer matches; hook re-blocks. Companion to T-1508 sentinel: T-1508 fixed duplicate-hook self-defeat, T-1500 fixes regenerate-after-approval self-defeat.

**Source:** P-005 from 003-NTB-ATC-Plugin T-014 (commit 8aa6f3b). Pickup proposed minimal fix:
```
COMMAND_NORMALIZED=$(echo "$COMMAND" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')
COMMAND_HASH=$(echo -n "$COMMAND_NORMALIZED" | sha256sum | awk '{print $1}')
```

Single hash site at line 177; downstream consumers (sentinel 196, approval 215, pending 415, YAML 420) all use `$COMMAND_HASH` derived once.

**Security note:** Approval is single-use (consumed via `rm -f`). Whitespace normalization cannot widen attack surface — the same human approved the same risk description; trivial whitespace re-flow doesn't change semantics. Structural changes (`; rm -rf /` appended) still produce different hashes.

## Acceptance Criteria

### Agent
- [x] `check-tier0.sh:177` normalizes `$COMMAND` (collapse internal whitespace runs + trim ends) before sha256
- [x] Regression bats test: approval written for command-with-extra-whitespace matches retry without (and vice versa); structurally-different command does NOT match
- [x] Existing `tier0_idempotency.bats` still passes (T-1508 sentinel intact)
- [x] Existing `check_tier0_comment_stripping.bats` still passes (T-1427 stripping intact)

## Verification

bash -n agents/context/check-tier0.sh
bats tests/unit/tier0_hash_normalization.bats
bats tests/unit/tier0_idempotency.bats
bats tests/unit/check_tier0_comment_stripping.bats

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-26T11:13:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1500-pickup-t-014-fw-tier0-approve-hash-drift.md
- **Context:** Initial task creation

### 2026-04-26T11:55:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2543574f
- **Timestamp:** 2026-06-02T14:57:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T11:58:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
