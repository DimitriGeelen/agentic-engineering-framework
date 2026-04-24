---
id: T-1274
name: "Memory writes (claude auto-memory) blocked by onboarding task gate — agent on consumer project couldn't save memory about wrong fw path because T-001-T-005 weren't complete. Memory is the exact mechanism that would prevent recurrence of the problem being observed. Memory should not be gated by task onboarding."
description: >
  Promoted from observation OBS-013

status: captured
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-16T05:29:24Z
last_update: 2026-04-16T05:29:24Z
date_finished: null
---

# T-1274: Memory writes (claude auto-memory) blocked by onboarding task gate — agent on consumer project couldn't save memory about wrong fw path because T-001-T-005 weren't complete. Memory is the exact mechanism that would prevent recurrence of the problem being observed. Memory should not be gated by task onboarding.

## Context

Observation: on a consumer project mid-onboarding (T-001–T-005 not complete, no focus set), Claude auto-memory writes to `/root/.claude/projects/<project>/memory/*.md` were blocked by `check-active-task.sh` because memory paths live outside PROJECT_ROOT and the exempt list is PROJECT_ROOT-anchored.

### Proposed fix (T-1431, 2026-04-24)

T-1431 added a global exempt case for `*/.claude/projects/*/memory/*` in `agents/context/check-active-task.sh` — the pattern matches any user prefix (`/root/`, `/home/alice/`, etc.) and only the auto-memory directory, nothing else under `.claude/`. Six bats regression tests in `tests/unit/check_active_task_memory_exempt.bats` cover:

- memory writes allowed without task (root + non-root user)
- MEMORY.md at root of memory/ allowed
- non-memory writes under /root/.claude/ still blocked
- arbitrary outside-project writes still blocked
- project-root .context/ still allowed

T-1431 is a proposal — this task (T-1274) remains human-owned. Review the fix and decide whether it resolves the observation.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-04-16T05:29:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1274-memory-writes-claude-auto-memory-blocked.md
- **Context:** Initial task creation
