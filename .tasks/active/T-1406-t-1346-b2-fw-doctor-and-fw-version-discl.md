---
id: T-1406
name: "T-1346-B2 fw doctor and fw version disclose active framework mode"
description: >
  Build B2 from T-1346 GO decomposition: fw doctor and fw version print which framework copy resolved (vendored, global, framework-repo) with absolute path and version pin. Closes the silent-leak observability gap from T-1346 — even after T-1356 (B1) flips rule order, users have no signal showing which copy is active. Acceptance: (1) fw version output includes 'Mode: <vendored|global|framework-repo>' + path; (2) fw doctor includes a structural section reporting same; (3) bats test asserts mode line appears for each resolution path.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-23T18:43:36Z
last_update: 2026-04-23T18:43:36Z
date_finished: null
---

# T-1406: T-1346-B2 fw doctor and fw version disclose active framework mode

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `_detect_fw_mode()` function exists in `bin/fw` and returns one of `vendored|framework-repo|global|unknown`
- [x] `fw version` prints `Mode: <mode>` line below `Framework:` path
- [x] `fw doctor` includes a structural check showing active mode + path
- [x] Bats test `tests/unit/fw_mode_detection.bats` passes; covers all three resolution paths (vendored, framework-repo, global)
- [x] `fw doctor` and `fw version` continue to exit 0 in framework-repo mode (no regression)

## Verification

bin/fw version 2>&1 | grep -q "^Mode: framework-repo"
bin/fw doctor 2>&1 | grep -q "Active mode: framework-repo"
bats tests/unit/fw_mode_detection.bats

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

### 2026-04-23T18:43:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1406-t-1346-b2-fw-doctor-and-fw-version-discl.md
- **Context:** Initial task creation
