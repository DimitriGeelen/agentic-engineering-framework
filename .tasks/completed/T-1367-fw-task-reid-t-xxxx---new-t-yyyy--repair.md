---
id: T-1367
name: "fw task reid T-XXXX --new T-YYYY — repair duplicate-ID pairs safely"
description: >
  Repair command for duplicate task IDs. Updates filename + frontmatter + commit references atomically. Deferred from T-1279 — the audit check now surfaces dups; manual rename is sufficient for rare case, but a command would be safer/faster.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-20T19:38:27Z
last_update: 2026-04-20T20:11:42Z
date_finished: 2026-04-20T20:11:42Z
---

# T-1367: fw task reid T-XXXX --new T-YYYY — repair duplicate-ID pairs safely

## Context

Deferred from T-1279. When the audit duplicate-ID check surfaces two files sharing `id: T-NNNN`, the human has to: rename the file, edit the frontmatter `id:` line, and hope nothing else breaks. A `fw task reid` command does this safely: single atomic operation, validates inputs, logs the rename.

## Acceptance Criteria

### Agent
- [x] `fw task reid <OLD-ID> <NEW-ID>` — renames file + frontmatter
- [x] Finds the task in both `.tasks/active/` AND `.tasks/completed/`
- [x] Refuses if NEW-ID already exists as a file
- [x] Appends a rename entry to the task's `## Updates` section
- [x] Errors clearly when inputs are invalid (missing old, missing new, wrong format)
- [x] Bats test `tests/unit/task_reid.bats` — 6 cases (success active, success completed, missing OLD, NEW exists, invalid format, no args). All pass.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Must pass before work-completed.
bats tests/unit/task_reid.bats
grep -qE "^        reid\)" bin/fw

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

### 2026-04-20T19:38:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1367-fw-task-reid-t-xxxx---new-t-yyyy--repair.md
- **Context:** Initial task creation

### 2026-04-20T20:07:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-20T20:11:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a3dd4d07
- **Timestamp:** 2026-06-02T14:56:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
