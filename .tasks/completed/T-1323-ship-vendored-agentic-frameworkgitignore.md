---
id: T-1323
name: "Ship vendored .agentic-framework/.gitignore + upgrade hint for stale pyc (T-1321 GO)"
description: >
  Ship vendored .agentic-framework/.gitignore + upgrade hint for stale pyc (T-1321 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-18T22:26:09Z
last_update: 2026-04-18T22:30:04Z
date_finished: 2026-04-18T22:30:04Z
---

# T-1323: Ship vendored .agentic-framework/.gitignore + upgrade hint for stale pyc (T-1321 GO)

## Context

Build sibling to T-1321 (GO). Source: termlink T-1130 pickup (P-038). Two surgical changes: (1) `do_vendor` writes `.gitignore` into the vendored `.agentic-framework/` directory; (2) `lib/upgrade.sh` warns the consumer if their git index already tracks `.agentic-framework/**/__pycache__/` files. Research artifact: `docs/reports/T-1321-vendored-pycache-noise.md`.

## Acceptance Criteria

### Agent
- [x] `do_vendor` (bin/fw) writes a `.gitignore` to the vendored directory containing `__pycache__/`, `*.pyc`, `*.pyo`, `.DS_Store`
- [x] `lib/upgrade.sh` prints a one-line WARN with cleanup command when stale tracked pyc files are detected in `.agentic-framework/`
- [x] Bats regression in `tests/unit/vendor_gitignore.bats` covers: vendored .gitignore exists, has right entries, vendor output mentions it, git check-ignore proves a real .pyc would be ignored — 4 tests
- [x] `bats tests/unit/vendor_gitignore.bats` passes (4/4)
- [x] `bash -n` syntax check passes for both bin/fw and lib/upgrade.sh

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

cd "$PROJECT_ROOT" && grep -q 'gitignore' bin/fw
cd "$PROJECT_ROOT" && bats tests/unit/vendor_gitignore.bats

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

### 2026-04-18T22:26:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1323-ship-vendored-agentic-frameworkgitignore.md
- **Context:** Initial task creation

### 2026-04-18T22:30:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
