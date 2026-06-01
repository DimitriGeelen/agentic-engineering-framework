---
id: T-1464
name: "T-1460 Phase 1 follow-on: lift QUIET-only flock guard so foreground audits also flock-protect"
description: >
  T-1460 Phase 1 follow-on: lift QUIET-only flock guard so foreground audits also flock-protect

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-25T15:28:03Z
last_update: 2026-04-25T16:13:34Z
date_finished: 2026-04-25T16:13:34Z
---

# T-1464: T-1460 Phase 1 follow-on: lift QUIET-only flock guard so foreground audits also flock-protect

## Context

T-1460 inception (GO recorded last session) found `agents/audit/audit.sh:306` wraps the entire flock guard in `if [ "$QUIET" = true ]`. That means foreground `fw audit` invocations get zero protection — two parallel foreground audits both run, racing on shared output files (audits/YYYY-MM-DD.yaml, history). Phase 1 fix: lift the guard so flock applies always; foreground prints "Another audit is running — exiting" instead of the silent cron-mode `exit 0`.

## Acceptance Criteria

### Agent
- [x] `if [ "$QUIET" = true ]` wrapper at audit.sh:306 lifted; flock guard applies to all invocations
- [x] Foreground (non-quiet) collision prints `Another audit is already running — exiting` to stderr; cron-mode (quiet) stays silent
- [x] Bats test: two parallel `fw audit` calls — exactly one runs, exactly one prints the "already running" message (tests/unit/audit_flock.bats — 5/5 pass)
- [x] Existing audit invocations still pass (39/39 audit bats pass after watchdog FD detach + locks/ added to noise filter)

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

# Guard wrapper removed (no `if [ "$QUIET" = true ]` immediately before the AUDIT_LOCK_DIR block)
! grep -B0 -A1 'flock guard.*cron mode' agents/audit/audit.sh | grep -q 'if \[ "\$QUIET" = true \]'
# Foreground collision message present in source
grep -q 'Another audit is already running' agents/audit/audit.sh
# Syntax valid
bash -n agents/audit/audit.sh
# Bats test passes
bats tests/unit/audit_flock.bats

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

### 2026-04-25T15:28:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1464-t-1460-phase-1-follow-on-lift-quiet-only.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-bb98c606
- **Timestamp:** 2026-04-25T16:13:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-25T16:13:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Lifted QUIET-only flock guard; foreground audits now flock-protect with stderr message; watchdog FD detached; .context/locks/ added to session-state filter; 8/8 verify tests pass
