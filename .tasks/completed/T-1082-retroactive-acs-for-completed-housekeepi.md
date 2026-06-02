---
id: T-1082
name: "Retroactive ACs for completed housekeeping tasks T-1072/T-1074 (CTL-012 warns)"
description: >
  Retroactive ACs for completed housekeeping tasks T-1072/T-1074 (CTL-012 warns)

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-11T08:38:37Z
last_update: 2026-04-11T08:40:54Z
date_finished: 2026-04-11T08:40:54Z
---

# T-1082: Retroactive ACs for completed housekeeping tasks T-1072/T-1074 (CTL-012 warns)

## Context

Audit CTL-012 warns that completed tasks T-1072 and T-1074 still contain `[First criterion]` placeholder ACs. Both were refactor-type housekeeping tasks created and completed within minutes without real ACs — the build-readiness gate only fires on `type: build`, so refactor housekeeping slipped through. Replace placeholders with retroactive ACs reflecting what was actually committed.

## Acceptance Criteria

### Agent
- [x] T-1072 has real ACs describing what was committed (no placeholder text)
- [x] T-1074 has real ACs describing what was committed (no placeholder text)
- [x] `fw audit` no longer warns CTL-012 for T-1072 or T-1074

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
! grep -q '\[First criterion\]' .tasks/completed/T-1072-commit-generated-docs-audit-results-and-.md
! grep -q '\[First criterion\]' .tasks/completed/T-1074-session-housekeeping--commit-working-sta.md

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

### 2026-04-11T08:38:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1082-retroactive-acs-for-completed-housekeepi.md
- **Context:** Initial task creation

### 2026-04-11T08:40:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-901d6751
- **Timestamp:** 2026-06-02T14:55:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
