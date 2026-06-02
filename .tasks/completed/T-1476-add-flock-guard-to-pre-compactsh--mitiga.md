---
id: T-1476
name: "Add flock guard to pre-compact.sh — mitigate dual-handover commits from concurrent hook fires (OBS-023)"
description: >
  Add flock guard to pre-compact.sh — mitigate dual-handover commits from concurrent hook fires (OBS-023)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/pre-compact.sh, tests/unit/pre_compact_flock.bats]
related_tasks: []
created: 2026-04-25T21:02:18Z
last_update: 2026-04-25T21:03:43Z
date_finished: 2026-04-25T21:03:43Z
---

# T-1476: Add flock guard to pre-compact.sh — mitigate dual-handover commits from concurrent hook fires (OBS-023)

## Context

OBS-023: every /compact creates two handover commits with the same session ID
because two PreCompact hooks fire — user-level (`~/.claude/settings.json`)
relative-path entry and project-level (`.claude/settings.json`) absolute-path
entry. The existing dedup in `agents/context/pre-compact.sh` (lines 21-35)
checks the last commit message, but appears to race when both hooks invoke
in quick succession.

Add a flock around pre-compact.sh's body so the second invocation either
waits and then sees the first's commit (dedup triggers), or skips entirely
if it can't acquire the lock within a small bound. Either outcome eliminates
the dual-commit symptom.

This is a defensive mitigation, not a root-cause fix. Root-cause work
(removing one hook entry, or making fw upgrade detect+dedupe at install
time) is deferred to a follow-up task.

## Acceptance Criteria

### Agent
- [x] `agents/context/pre-compact.sh` acquires a flock on `.context/working/.pre-compact.lock` before running
- [x] On lock acquisition failure (concurrent hook), exits 0 silently (the other run will produce the handover)
- [x] Lock is released on exit (trap cleanup)
- [x] Flock missing → falls back to existing behaviour (no breakage on systems without flock)
- [x] `bash -n agents/context/pre-compact.sh` parses
- [x] Bats test exercises both branches (lock acquired → runs; lock held → exits silently)

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

bash -n agents/context/pre-compact.sh
bats tests/unit/pre_compact_flock.bats

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

### 2026-04-25T21:02:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1476-add-flock-guard-to-pre-compactsh--mitiga.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5e826e2f
- **Timestamp:** 2026-06-02T14:57:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T21:03:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
