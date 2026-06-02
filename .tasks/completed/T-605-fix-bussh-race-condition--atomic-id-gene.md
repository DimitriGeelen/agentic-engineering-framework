---
id: T-605
name: "Fix bus.sh race condition — atomic ID generation for multi-agent safety"
description: >
  bus.sh uses find|wc -l for result ID generation (R-001, R-002). Two concurrent fw bus post calls get same ID — second overwrites first. Fix with atomic ID generation (mkdir-based or counter file with flock). bus.sh is the only component explicitly designed for multi-agent use that has zero concurrency protection. Origin: T-579 steelman/strawman analysis. Scope: bus.sh ID generation only, not full dedup layer.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-25T13:51:44Z
last_update: 2026-03-25T14:08:59Z
date_finished: 2026-03-25T14:08:59Z
---

# T-605: Fix bus.sh race condition — atomic ID generation for multi-agent safety

## Context

`bus.sh` lines 119-124 use `find | wc -l` for result ID generation. Two concurrent `fw bus post` calls see the same count, both create R-001, second overwrites first. Origin: T-579 steelman analysis.

## Acceptance Criteria

### Agent
- [x] ID generation uses atomic mkdir-based approach (portable, no flock needed)
- [x] Concurrent `fw bus post` calls produce unique IDs (no overwrites)
- [x] Existing bus functionality unchanged (post, read, manifest, clear)
- [x] Works on both Linux and macOS (D4: Portability)

## Verification

# bus.sh syntax check
bash -n lib/bus.sh
# Atomic ID generation pattern present (mkdir as test-and-set)
grep -q 'mkdir.*_bus_candidate.*lock' lib/bus.sh

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

### 2026-03-25T13:51:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-605-fix-bussh-race-condition--atomic-id-gene.md
- **Context:** Initial task creation

### 2026-03-25T13:51:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T14:08:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-688fb0d8
- **Timestamp:** 2026-06-02T15:03:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
