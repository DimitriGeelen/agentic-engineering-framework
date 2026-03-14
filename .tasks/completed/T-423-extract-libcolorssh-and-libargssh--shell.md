---
id: T-423
name: "Extract lib/colors.sh and lib/args.sh — shell utility consolidation (S2+S4)"
description: >
  S2: Color variables duplicated in 19 files — extract to lib/colors.sh with TTY fallback. S4: Argument parsing duplicated in 8+ files — extract shared while-case pattern to lib/args.sh. Directive scores: S2=5, S4=6. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: human
horizon: next
tags: [refactoring, shell]
components: []
related_tasks: [T-411]
created: 2026-03-10T21:04:04Z
last_update: 2026-03-12T12:41:20Z
date_finished: 2026-03-11T10:11:03Z
---

# T-423: Extract lib/colors.sh and lib/args.sh — shell utility consolidation (S2+S4)

## Context

Shell utility consolidation (S2+S4). See `docs/reports/T-411-refactoring-directive-scoring.md` § SHELL rows S2 (color vars, 19 files, score 5), S4 (arg parsing, 8 files, score 6). Bundle: both are shell infrastructure libs that support other refactoring tasks.

## Acceptance Criteria

### Agent
- [x] lib/colors.sh created with TTY-aware, NO_COLOR-respecting color variables
- [x] lib/errors.sh updated to source colors.sh instead of defining _ERR_* prefix vars
- [x] 14 files with inline color definitions updated to use shared colors via paths.sh chain
- [x] fw doctor, fw audit, fw git status, fw fabric all pass after refactor
- [x] S4 (args.sh) assessed — determined to be over-engineering, documented

### Human
- [x] [RUBBER-STAMP] Spot-check that colored output still works in terminal
  **Steps:**
  1. Run `fw doctor` in a terminal
  2. Run `fw audit --section 1`
  3. Verify colored output appears (green checks, yellow warnings)
  **Expected:** Same colored output as before the refactor
  **If not:** Check that lib/colors.sh is being sourced (add `echo "colors loaded"` to lib/colors.sh temporarily)

## Verification

# lib/colors.sh exists and is valid bash
bash -n lib/colors.sh
# lib/errors.sh sources colors.sh
grep -q "colors.sh" lib/errors.sh
# No more _ERR_ prefix color vars in errors.sh
! grep -q "_ERR_RED\|_ERR_GREEN\|_ERR_NC" lib/errors.sh
# Standalone files still have inline colors (expected)
grep -q "RED=.*033" install.sh
# Framework health check passes
fw doctor 2>&1 | grep -q "All checks passed"

## Decisions

### 2026-03-11 — S4 args.sh: skip as over-engineering
- **Chose:** Do not create lib/args.sh
- **Why:** Arg parsing is script-specific (each script has different flags). A generic parse_args() function would be more complex than the duplicated patterns it replaces. 18 files have arg loops but each is unique. No reusable abstraction exists without over-engineering.
- **Rejected:** Generic args.sh with parse_args(), shift_value(), require_arg() — adds complexity for marginal deduplication

## Updates

### 2026-03-10T21:04:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-423-extract-libcolorssh-and-libargssh--shell.md
- **Context:** Initial task creation

### 2026-03-11T10:01:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T10:11:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
