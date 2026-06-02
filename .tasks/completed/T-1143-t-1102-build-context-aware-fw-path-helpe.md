---
id: T-1143
name: "T-1102 build: context-aware fw path helper (_fw_cmd) and fix 3 hardcoded bin/fw sites"
description: >
  T-1102 build: context-aware fw path helper (_fw_cmd) and fix 3 hardcoded bin/fw sites

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-tier0.sh, lib/inception.sh, lib/paths.sh, lib/review.sh]
related_tasks: []
created: 2026-04-12T10:06:32Z
last_update: 2026-04-12T10:14:21Z
date_finished: 2026-04-12T10:14:21Z
---

# T-1143: T-1102 build: context-aware fw path helper (_fw_cmd) and fix 3 hardcoded bin/fw sites

## Context

Build from T-1102 inception (GO). Three hardcoded `bin/fw` sites break in consumer projects. Fix: add `_fw_cmd` helper to lib/paths.sh, replace all 3 sites.

## Acceptance Criteria

### Agent
- [x] _fw_cmd helper added to lib/paths.sh (returns context-aware fw command path)
- [x] lib/review.sh uses _fw_cmd instead of hardcoded bin/fw
- [x] lib/inception.sh uses _fw_cmd instead of hardcoded bin/fw
- [x] agents/context/check-tier0.sh uses _fw_cmd instead of hardcoded ./bin/fw
- [x] _emit_user_command helper emits full copy-pasteable command with cd prefix

## Verification

grep -q "_fw_cmd" lib/paths.sh
grep -q "_fw_cmd\|_emit_user_command" lib/review.sh
grep -q "_fw_cmd\|_emit_user_command" lib/inception.sh
bash -c '! grep -q "echo.*bin/fw" lib/review.sh'
bash -c '! grep -q "echo.*bin/fw" lib/inception.sh'

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

### 2026-04-12T10:06:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1143-t-1102-build-context-aware-fw-path-helpe.md
- **Context:** Initial task creation

### 2026-04-12T10:14:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5096d664
- **Timestamp:** 2026-06-02T14:55:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — agents/context/check-tier0.sh uses _fw_cmd instead of hardcoded ./bin/fw
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/context/check-tier0.sh in: agents/context/check-tier0.sh uses _fw_cmd instead of hardcoded ./bin/fw`
