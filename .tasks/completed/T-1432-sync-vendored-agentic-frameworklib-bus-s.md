---
id: T-1432
name: "sync vendored .agentic-framework/lib/ bus scripts (publish-learning-to-bus, subscribe-learnings-from-bus) — subscribe is v1 stale after T-1219 fix"
description: >
  sync vendored .agentic-framework/lib/ bus scripts (publish-learning-to-bus, subscribe-learnings-from-bus) — subscribe is v1 stale after T-1219 fix

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-24T15:44:43Z
last_update: 2026-04-24T15:45:43Z
date_finished: 2026-04-24T15:45:43Z
---

# T-1432: sync vendored .agentic-framework/lib/ bus scripts (publish-learning-to-bus, subscribe-learnings-from-bus) — subscribe is v1 stale after T-1219 fix

## Context

Prior session (T-1168 → T-1217 → T-1219) created the learning-bus publisher/subscriber but the vendored copies in `.agentic-framework/lib/` drifted:

- `publish-learning-to-bus.sh` — vendored matches source (OK)
- `subscribe-learnings-from-bus.sh` — vendored is T-1217 **v1** (`termlink event collect`, which missed cross-session traffic). Source is T-1219 **v2** (`termlink event poll <session> --since <cursor>`).

Both files are currently untracked (`git status` shows `??`). Consumers pulling via `fw upgrade` would get the stale v1 subscriber. Sync and track.

## Acceptance Criteria

### Agent
- [x] `.agentic-framework/lib/publish-learning-to-bus.sh` == `lib/publish-learning-to-bus.sh`
- [x] `.agentic-framework/lib/subscribe-learnings-from-bus.sh` == `lib/subscribe-learnings-from-bus.sh`
- [x] Both vendored files are tracked (no `??` status)
- [x] Vendored subscribe uses `event poll` not `event collect` (T-1219 v2)

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

diff -q .agentic-framework/lib/publish-learning-to-bus.sh lib/publish-learning-to-bus.sh
diff -q .agentic-framework/lib/subscribe-learnings-from-bus.sh lib/subscribe-learnings-from-bus.sh
grep -q 'termlink event poll' .agentic-framework/lib/subscribe-learnings-from-bus.sh
git ls-files --error-unmatch .agentic-framework/lib/publish-learning-to-bus.sh
git ls-files --error-unmatch .agentic-framework/lib/subscribe-learnings-from-bus.sh

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

### 2026-04-24T15:44:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1432-sync-vendored-agentic-frameworklib-bus-s.md
- **Context:** Initial task creation

### 2026-04-24T15:45:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ce5483ba
- **Timestamp:** 2026-06-02T14:57:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
