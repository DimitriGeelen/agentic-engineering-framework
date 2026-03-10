---
id: T-414
name: "Extract lib/errors.sh — consistent die/warn/error functions (S8)"
description: >
  Create lib/errors.sh with die(), warn(), error() functions. Currently all scripts use different error patterns (echo >&2, exit 1 vs exit 2, colored vs plain). Inconsistent UX and sourcing-unsafe exit calls. Directive score: S8=8. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: captured
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, shell, reliability, usability]
components: [lib/errors.sh]
related_tasks: [T-411, T-412]
created: 2026-03-10T21:03:14Z
last_update: 2026-03-10T21:03:14Z
date_finished: null
---

# T-414: Extract lib/errors.sh — consistent die/warn/error functions (S8)

## Context

Refactoring finding S8 (score 8) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**S8 — Error handling inconsistency (all files):**
Scripts use different error patterns: `echo >&2 && exit 1`, `echo -e "$RED..." >&2 && exit 1`,
`exit 2` for severity, `return 1` (subshell-safe) vs `exit 1` (not safe in functions).
See research artifact § "SHELL SCRIPTS" row S8. Affects all agent scripts.

## Acceptance Criteria

### Agent
- [ ] lib/errors.sh created with die(), warn(), error(), info() functions
- [ ] Functions use return (not exit) for sourcing safety
- [ ] Consistent color output with TTY detection
- [ ] At least 5 agent scripts converted to use lib/errors.sh
- [ ] Exit codes standardized: 0=success, 1=error, 2=blocking error (hook convention)

### Human
<!-- No human verification needed for this refactoring -->

## Verification

test -f lib/errors.sh
bash -n lib/errors.sh
source lib/errors.sh && warn 'test warning' 2>/dev/null

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

### 2026-03-10T21:03:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-414-extract-liberrorssh--consistent-diewarne.md
- **Context:** Initial task creation
