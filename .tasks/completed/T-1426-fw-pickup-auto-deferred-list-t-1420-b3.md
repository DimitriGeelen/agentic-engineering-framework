---
id: T-1426
name: "fw pickup auto-deferred list (T-1420 B3)"
description: >
  Operator surface so humans can review what got auto-deferred. Adds 'fw pickup auto-deferred list' subcommand that lists envelopes in .context/pickup/auto-deferred/ with their breadcrumb target T-XXX, reason, and deferred_at timestamp.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-24T13:13:45Z
last_update: 2026-04-24T13:15:49Z
date_finished: 2026-04-24T13:15:49Z
---

# T-1426: fw pickup auto-deferred list (T-1420 B3)

## Context

T-1425 landed triple dedup (G-059) — envelopes that collide with an active inception now land in `.context/pickup/auto-deferred/` with a `.breadcrumb.yaml`. Operators need a way to see what's there without hand-rolling a find. Add `fw pickup auto-deferred list` that prints each deferred envelope with its blocking T-XXX, reason, and deferred_at timestamp. Mirrors the existing `list` and `status` subcommands for consistency.

## Acceptance Criteria

### Agent
- [x] `do_pickup` handles `auto-deferred` subcommand (and accepts `list` or no argument as the default action)
- [x] Output format: one line per envelope with basename, blocking T-XXX, reason, deferred_at
- [x] "Empty — no envelopes auto-deferred" message when the directory is empty
- [x] `pickup status` counts auto-deferred alongside inbox/processed/rejected
- [x] Regression test in `tests/unit/lib_pickup_triple_dedup.bats` covers the list surface (10/10 pass; 3 new B3 tests)
- [x] Vendored copy synced

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

bash -n lib/pickup.sh
grep -q 'auto-deferred)' lib/pickup.sh
bats tests/unit/lib_pickup_triple_dedup.bats
diff -q lib/pickup.sh .agentic-framework/lib/pickup.sh

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

### 2026-04-24T13:13:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1426-fw-pickup-auto-deferred-list-t-1420-b3.md
- **Context:** Initial task creation

### 2026-04-24T13:15:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7e5676cf
- **Timestamp:** 2026-06-02T14:57:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
