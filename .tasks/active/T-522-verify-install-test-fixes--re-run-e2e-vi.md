---
id: T-522
name: "Verify install test fixes — re-run E2E via TermLink (T-519, T-520, T-521)"
description: >
  Re-run the full TermLink E2E installation test to confirm fixes from T-519 (do_vendor ordering), T-520 (hook FRAMEWORK_ROOT resolution), T-521 (git init in fw init). Previous test found these bugs; this run validates the fixes.

status: work-completed
workflow_type: test
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-17T22:50:32Z
last_update: 2026-03-17T22:56:33Z
date_finished: 2026-03-17T22:56:33Z
---

# T-522: Verify install test fixes — re-run E2E via TermLink (T-519, T-520, T-521)

## Context

Re-run E2E install test via TermLink after T-519/T-520/T-521 fixes. Also verifies full lifecycle (init → doctor → hooks → commit → complete → audit).

## Acceptance Criteria

### Agent
- [x] fw init completes without `do_vendor: command not found` (T-519)
- [x] git repo auto-created by fw init (T-521)
- [x] fw doctor passes (0 failures)
- [x] Commit with task ref succeeds — no `find_task_file: command not found` (T-520)
- [x] Full lifecycle works: task create → commit → complete → audit

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

## Updates

- All 3 fixes verified via TermLink E2E test
- New finding: install.sh `--local` flag doesn't exist (silently ignored), update path always fetches from origin
- New finding: VERSION file (1.0.0) disagrees with FW_VERSION in bin/fw (1.2.6) — causes "updated from v1.2.6 to v1.0.0" regression on fw update

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-17T22:50:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-522-verify-install-test-fixes--re-run-e2e-vi.md
- **Context:** Initial task creation

### 2026-03-17T22:56:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
