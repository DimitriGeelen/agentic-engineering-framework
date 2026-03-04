---
id: T-317
name: "Build fw test-onboarding CLI script (8 checkpoints)"
description: >
  Build agents/onboarding-test/test-onboarding.sh — deterministic script that creates temp project, runs fw init, exercises 8 checkpoints (scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover), captures structured PASS/WARN/FAIL output. Wire into bin/fw as 'fw test-onboarding'. No fw dependency (standalone). From T-307 GO decision.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-04T21:20:46Z
last_update: 2026-03-04T21:20:46Z
date_finished: null
---

# T-317: Build fw test-onboarding CLI script (8 checkpoints)

## Context

From T-307 inception GO decision. See `docs/reports/T-307-hybrid-onboarding-test.md`.

## Acceptance Criteria

### Agent
- [x] `agents/onboarding-test/test-onboarding.sh` exists and is executable
- [x] Script runs standalone (no fw dependency — finds own root via script location)
- [x] 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover
- [x] PASS/WARN/FAIL/SKIP output per checkpoint with summary counts
- [x] Exit code: 0=pass, 1=warnings, 2=failures
- [x] Cascading skip: failed checkpoint causes dependent checkpoints to skip
- [x] `fw test-onboarding` routes to the script
- [x] Supports `--keep` (preserve target dir), `--quiet` (no color), custom target dir
- [x] All 8 checkpoints pass on current framework (27/27 PASS)

## Verification

bash -n agents/onboarding-test/test-onboarding.sh
test -x agents/onboarding-test/test-onboarding.sh
agents/onboarding-test/test-onboarding.sh 2>&1 | grep -q "SUMMARY"
agents/onboarding-test/test-onboarding.sh 2>&1 | grep -q "ONBOARDING CLEAN"
grep -q "test-onboarding" bin/fw

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

### 2026-03-04T21:20:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-317-build-fw-test-onboarding-cli-script-8-ch.md
- **Context:** Initial task creation
