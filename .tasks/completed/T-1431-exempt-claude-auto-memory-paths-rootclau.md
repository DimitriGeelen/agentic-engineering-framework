---
id: T-1431
name: "exempt claude auto-memory paths (/root/.claude/projects/*/memory/) in check-active-task.sh hook — addresses T-1274"
description: >
  exempt claude auto-memory paths (/root/.claude/projects/*/memory/) in check-active-task.sh hook — addresses T-1274

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-24T15:37:53Z
last_update: 2026-04-24T15:40:06Z
date_finished: 2026-04-24T15:40:06Z
---

# T-1431: exempt claude auto-memory paths (/root/.claude/projects/*/memory/) in check-active-task.sh hook — addresses T-1274

## Context

Addresses the root cause behind T-1274 (human-owned, `captured`). Claude Code's auto-memory system writes to `/root/.claude/projects/<project-path>/memory/*.md` — **outside** the project tree. `check-active-task.sh` exempts only paths anchored to `$PROJECT_ROOT` (`/.context/`, `/.tasks/`, `/.claude/`, `/.git/`), so memory writes fall through to the no-task block.

**Symptom:** On a consumer project mid-onboarding (T-001–T-005 not yet complete, no focus set), the agent cannot save auto-memory — which is exactly the mechanism meant to prevent recurrence of the problem being observed. This is a self-defeating gate.

**Fix:** Add a global exempt for `/root/.claude/projects/*/memory/*` (and, defensively, any path containing `/.claude/projects/*/memory/` since the system may run as a non-root user on macOS). This is additive and narrow — it exempts only the auto-memory directory, nothing else under `/root/.claude/` or `~/.claude/`.

## Acceptance Criteria

### Agent
- [x] `check-active-task.sh` exempts `/root/.claude/projects/*/memory/*` paths
- [x] Exempt rule matches any user prefix (not just /root) — pattern covers `*/.claude/projects/*/memory/*`
- [x] New bats test asserts the hook returns 0 for a memory path when no task is active
- [x] New bats test asserts the hook still returns 2 for non-memory paths when no task is active (regression guard)
- [x] T-1274 references this task as the proposed fix (no ownership change)

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

bats tests/unit/check_active_task_memory_exempt.bats
grep -q 'claude/projects/.*/memory' agents/context/check-active-task.sh

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

### 2026-04-24T15:37:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1431-exempt-claude-auto-memory-paths-rootclau.md
- **Context:** Initial task creation

### 2026-04-24T15:40:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1c0c317e
- **Timestamp:** 2026-06-02T14:57:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
