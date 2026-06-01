---
id: T-1324
name: "fw inception decide auto-ticks the REVIEW/RUBBER-STAMP Human AC"
description: >
  Surgical edit to lib/inception.sh do_inception_decide so that after writing the Decision block it ticks the inception template's [REVIEW] Review exploration findings and approve go/no-go decision (or [RUBBER-STAMP] Record decision) Human AC. Idempotent. Closes the structural gap discovered in T-1322 inception (P-039 from termlink).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-18T22:53:49Z
last_update: 2026-04-18T22:58:45Z
date_finished: 2026-04-18T22:58:45Z
---

# T-1324: fw inception decide auto-ticks the REVIEW/RUBBER-STAMP Human AC

## Context

Build sibling for T-1322 inception (P-039 from termlink). The inception established that `do_inception_decide` writes a Decision block but never ticks the templated `[REVIEW]` Human AC, leaving every decided inception in partial-complete forever (10+ stuck tasks T-947–T-959 cited; G-008 contributor). Build plan is in `docs/reports/T-1322-inception-decide-rubber-stamp.md`.

## Acceptance Criteria

### Agent
- [x] `lib/inception.sh` defines `tick_inception_decide_acs <task_file>` (helper function, sourceable)
- [x] `do_inception_decide` calls `tick_inception_decide_acs` after writing the Decision block, before invoking `update-task.sh --status work-completed`
- [x] Helper ticks `### Human` ACs whose text matches `[REVIEW].*go/?no-go decision` (case-insensitive) OR `[RUBBER-STAMP].*[Rr]ecord.*decision`
- [x] Helper is idempotent: already-ticked ACs unchanged, no errors
- [x] Helper does NOT touch `### Agent` ACs or unmatched custom Human ACs
- [x] New bats file `tests/unit/inception_decide_ac_tick.bats` covers: tick template `[REVIEW]`, tick `[RUBBER-STAMP]` variant, idempotent, no over-match on custom ACs, leaves Agent section alone
- [x] All bats in `tests/unit/lib_inception.bats` and the new file pass

## Verification

bats tests/unit/lib_inception.bats
bats tests/unit/inception_decide_ac_tick.bats

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

### 2026-04-18T22:53:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1324-fw-inception-decide-auto-ticks-the-revie.md
- **Context:** Initial task creation

### 2026-04-18T22:58:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Helper added, wired into do_inception_decide, 10/10 unit tests pass, 16/16 existing inception tests still pass
