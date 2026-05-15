---
id: T-1860
name: "episodic-gen forensic log overwrites previous invocation — defeats T-1371/G-054 intent"
description: >
  agents/task-create/update-task.sh:1429 truncates .context/working/.last-episodic-gen.log on every invocation (single `>`). T-1371/G-054 added this log to capture forensic context for silent episodic-gen failures, but the truncation guarantees you only ever see the last (usually successful) run — meaning when the next failure occurs, the previous failure's diagnostic context is already gone. Origin: T-1859 backfilled T-1829/T-1830/T-1831 episodics; the log only contained T-1858's successful run, so the actual silent-failure context is unrecoverable.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, fix, forensic-logging, silent-failure, follow-up]
components: [agents/task-create/update-task.sh]
related_tasks: [T-1859, T-1371]
created: 2026-05-15T18:25:00Z
last_update: 2026-05-15T18:24:34Z
date_finished: null
---

# T-1860: episodic-gen forensic log overwrites previous invocation — defeats T-1371/G-054 intent

## Context

`agents/task-create/update-task.sh:1429` writes the episodic-gen forensic header with `> "$EPISODIC_LOG"` (single redirect — truncates). T-1371 / G-054 added this log to capture forensic context for silent episodic-gen failures (PROJECT_ROOT, CONTEXT_DIR, env, exit code). But the truncation means each invocation wipes prior runs.

T-1859 surfaced this: three completed tasks (T-1829/T-1830/T-1831) had missing episodics with no surviving log to diagnose why. The next failure will also be uninspectable — the auto-trigger's diagnostic mechanism is broken in exactly the failure mode it was added to support.

## Acceptance Criteria

### Agent
- [x] **A1** `update-task.sh` no longer truncates; chose per-task log files at `.context/working/episodic-gen/<T-XXX>.log` with append (`>>`). One task's log retains all invocations of that task; cross-task forensics are stable since each task's history is in its own file.
- [x] **A2** Log accumulates across consecutive invocations — pinned by `tests/unit/update_task_episodic_gen.bats` T-1860 test #1 (per-task path + header) and direct shell verification in `/tmp/T-1860-verify.sh` (two appended invocations both visible in log).
- [x] **A3** Per-task files are inherently bounded (most tasks generate episodic once; pathological re-completion still produces a small file). No rotation needed — chose per-task isolation over rolling-log + rotation for simplicity.
- [ ] **A4** Audit/Watchtower surface for "last 5 episodic-gen failures" — DEFERRED. Out of scope; T-1860's primary deliverable is data preservation, not a UI surface. Existing audit warning class ("Completed task T-XXX has no episodic summary") remains the failure indicator; the new per-task logs are the drill-down evidence.
- [x] **A5** Source-of-truth bats pin (`tests/unit/update_task_episodic_gen.bats` test #2): `update-task.sh` references new path AND uses `>>`; old `.last-episodic-gen.log` path does not reappear.

## Verification

bats tests/unit/update_task_episodic_gen.bats -f "T-1860"
grep -q 'EPISODIC_LOG=.*working/episodic-gen/\$TASK_ID\.log' agents/task-create/update-task.sh
grep -E 'echo "--- context.sh output ---"' -A 1 agents/task-create/update-task.sh | grep -q '>>\s*"\$EPISODIC_LOG"'
! grep -q '\.last-episodic-gen\.log' agents/task-create/update-task.sh

## RCA

**Symptom:** T-1859 backfilled 3 missing episodics. Could not RCA the original silent failure because the forensic log retained only the most recent (successful) T-1858 run.

**Root cause:** `> "$EPISODIC_LOG"` (line 1429) truncates the log on every invocation.

**Why structurally allowed:** T-1371 introduced the log with the right intent (capture forensic context on silent failure) but with the wrong file mode (truncate). The log "worked" in tests because tests verify single-invocation behaviour. The multi-invocation history requirement was implicit and untested.

**Prevention:** Chose per-task log files at `.context/working/episodic-gen/<TASK_ID>.log` with append. Per-task isolation means cross-task work never overwrites a failing task's diagnostic context; append within a task preserves re-run history. Source-of-truth bats pin in `tests/unit/update_task_episodic_gen.bats` test #2 — any regression that restores the single rolling-log + truncate pattern fails CI.

## Evolution

## Decisions

## Decision

## Updates

### 2026-05-15T18:25:00Z — task-created [filed-from-T-1859-rca]
- **Action:** Filed during T-1859 to honour "one bug = one task" rule
- **Context:** RCA finding from T-1859: the forensic log mechanism defeats itself by truncating.

### 2026-05-15T18:24:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
