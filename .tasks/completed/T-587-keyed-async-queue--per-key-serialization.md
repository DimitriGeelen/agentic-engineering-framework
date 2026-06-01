---
id: T-587
name: "Keyed async queue — per-key serialization primitive for concurrent operations"
description: >
  OpenClaw keyed-async-queue.ts (50 LOC): per-key serialization with cross-key parallelism. Map<string, Promise<void>> chains tasks per key. Rejection in one doesnt block next. Use cases: serialize task operations per task-id (prevent concurrent completion by TermLink workers), serialize hook execution per hook-name, serialize healing operations per error-class. Bash equivalent: flock-based per-key locking (~30 LOC). Implementation language pending T-586 (TypeScript strategy). If TS: direct port from OpenClaw. If bash: flock wrapper. Research source: /opt/openclaw-evaluation/.context/working/round2-T-022.md (Pattern 2, rated 5 stars most reusable primitive). OpenClaw source: src/util/keyed-async-queue.ts. Related: T-586 (language strategy), T-582 (session isolation — concurrent agent operations).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh, lib/keylock.sh, lib/upgrade.sh]
related_tasks: []
created: 2026-03-23T21:35:21Z
last_update: 2026-03-28T12:27:42Z
date_finished: 2026-03-28T12:27:42Z
---

# T-587: Keyed async queue — per-key serialization primitive for concurrent operations

## Context

Per-key serialization primitive for concurrent framework operations. When multiple TermLink workers or parallel agents operate on the same task/resource simultaneously, YAML file corruption and race conditions can occur. The bus already has atomic ID generation (T-605 `mkdir` lock in `lib/bus.sh:119-137`), but no per-key serialization exists for task updates, focus changes, or healing operations. The primitive: given a key (e.g., task ID `T-042`), serialize all operations on that key while allowing operations on different keys to proceed in parallel. Bash implementation uses `flock` on per-key lock files. Related: T-586 (language strategy), T-582 (session isolation).

## Acceptance Criteria

### Agent

- [x] A shell library `lib/keylock.sh` exists providing `keylock_acquire <key>` and `keylock_release <key>` functions that serialize operations per key using `flock` on files in `$PROJECT_ROOT/.context/locks/`
- [x] Cross-key parallelism works: two concurrent processes holding locks on different keys (e.g., `T-001` and `T-002`) do not block each other — verified by a test that acquires both in parallel and checks both complete within 2 seconds
- [x] Same-key serialization works: two concurrent processes acquiring the same key execute sequentially — verified by a test that writes timestamps from two parallel workers to a shared file and confirms non-overlapping execution windows
- [x] Stale lock cleanup: locks older than a configurable timeout (default 5 minutes) are automatically released on next acquisition attempt, preventing deadlocks from crashed processes
- [x] `update-task.sh` uses `keylock_acquire $TASK_ID` / `keylock_release $TASK_ID` around the task file read-modify-write sequence to prevent concurrent task updates from corrupting YAML frontmatter

## Verification

# Library exists and sources without error
bash -c "source lib/keylock.sh"
# Lock directory is created on first use
bash -c "source lib/keylock.sh && keylock_acquire test-verify && keylock_release test-verify && [ -d .context/locks ]"
# Stale lock detection works (create a lock > 5min old, verify re-acquisition succeeds)
bash -c "source lib/keylock.sh && mkdir -p .context/locks && touch -t 202601010000 .context/locks/stale-test.lock && keylock_acquire stale-test && keylock_release stale-test"

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

### 2026-03-23T21:35:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-587-keyed-async-queue--per-key-serialization.md
- **Context:** Initial task creation

### 2026-03-28T12:23:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T12:27:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
