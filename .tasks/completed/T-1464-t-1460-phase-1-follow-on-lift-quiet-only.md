---
id: T-1464
name: "T-1460 Phase 1 follow-on: lift QUIET-only flock guard so foreground audits
  also flock-protect"
description: >
  T-1460 Phase 1 follow-on: lift QUIET-only flock guard so foreground audits also
  flock-protect

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-25T15:28:03Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T16:13:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a3133ea6
- **Timestamp:** 2026-06-02T14:57:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `! grep -B0 -A1 'flock guard.*cron mode' agents/audit/audit.sh | grep -q 'if \[ "\$QUIET" = true \]'`
### 2026-04-25T16:13:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Lifted QUIET-only flock guard; foreground audits now flock-protect with stderr message; watchdog FD detached; .context/locks/ added to session-state filter; 8/8 verify tests pass
