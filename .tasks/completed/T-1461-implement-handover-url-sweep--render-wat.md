---
id: T-1461
name: "Implement handover URL sweep — render Watchtower URLs in handover.sh for [REVIEW] tasks, inception decisions, and observation listings (T-1451 GO)"
description: >
  Implement handover URL sweep — render Watchtower URLs in handover.sh for [REVIEW] tasks, inception decisions, and observation listings (T-1451 GO)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/handover/handover.sh]
related_tasks: []
created: 2026-04-25T14:01:46Z
last_update: 2026-04-25T14:19:51Z
date_finished: 2026-04-25T14:19:51Z
---

# T-1461: Implement handover URL sweep — render Watchtower URLs in handover.sh for [REVIEW] tasks, inception decisions, and observation listings (T-1451 GO)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/handover/handover.sh` resolves `WT_URL` once at top via `bin/fw watchtower url`
- [x] "Awaiting Human Review" listing renders `[T-XXX](${WT_URL}/review/T-XXX)` markdown links
- [x] "Awaiting Your Action (Human)" section renders the same review URLs
- [x] Inception Phases listing renders `[T-XXX](${WT_URL}/inception/T-XXX)` for `workflow_type: inception`
- [x] Latest generated handover contains at least 3 markdown links to /review or /inception (verification command)
- [x] Existing handover bats tests still pass

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

bash -n agents/handover/handover.sh
bin/fw handover --checkpoint
grep -qE '\]\(http://[^)]+/review/T-[0-9]+\)' .context/handovers/LATEST.md
bats tests/unit/handover.bats
# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-25T14:01:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1461-implement-handover-url-sweep--render-wat.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-78703e9d
- **Timestamp:** 2026-04-25T14:20:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-25T14:19:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
