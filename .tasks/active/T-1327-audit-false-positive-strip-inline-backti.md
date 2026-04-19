---
id: T-1327
name: "Audit false-positive: strip inline backticks before placeholder pattern match (T-1298 meta-block)"
description: >
  Audit false-positive: strip inline backticks before placeholder pattern match (T-1298 meta-block)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-19T09:12:56Z
last_update: 2026-04-19T09:12:56Z
date_finished: null
---

# T-1327: Audit false-positive: strip inline backticks before placeholder pattern match (T-1298 meta-block)

## Context

`audit_task_placeholders` (lib/task-audit.sh) flags inline-backtick mentions of pattern strings (`` `[TODO]` ``, `` `[Criterion N]` ``, etc.) as unfilled placeholders. T-1298's Recommendation legitimately quotes these patterns and is therefore impossible to decide via Watchtower (10+ HTTP 500 in `.context/working/watchtower.log`). Same trap exists for any future task documenting the placeholder detector. Fix: strip inline backtick spans before pattern match.

## Acceptance Criteria

### Agent
- [ ] `lib/task-audit.sh:audit_task_placeholders` strips inline backtick spans (`` `…` ``) before pattern match
- [ ] New bats test in `tests/unit/lib_task_audit.bats` covers: inline-backticked `[TODO]` is NOT flagged; bare `[TODO]` IS flagged; mixed line with both bare and backticked is flagged
- [ ] Existing bats `tests/unit/lib_task_audit.bats` still passes
- [ ] Running audit against current `.tasks/active/T-1298-pickup-inception-template-gono-go-placeh.md` exits 0

## Verification
bash -c 'source lib/task-audit.sh && audit_task_placeholders .tasks/active/T-1298-pickup-inception-template-gono-go-placeh.md'
bats tests/unit/lib_task_audit.bats

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

### 2026-04-19T09:12:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1327-audit-false-positive-strip-inline-backti.md
- **Context:** Initial task creation
