---
id: T-1860
name: "episodic-gen forensic log overwrites previous invocation — defeats T-1371/G-054 intent"
description: >
  agents/task-create/update-task.sh:1429 truncates .context/working/.last-episodic-gen.log on every invocation (single `>`). T-1371/G-054 added this log to capture forensic context for silent episodic-gen failures, but the truncation guarantees you only ever see the last (usually successful) run — meaning when the next failure occurs, the previous failure's diagnostic context is already gone. Origin: T-1859 backfilled T-1829/T-1830/T-1831 episodics; the log only contained T-1858's successful run, so the actual silent-failure context is unrecoverable.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bug, fix, forensic-logging, silent-failure, follow-up]
components: [agents/task-create/update-task.sh]
related_tasks: [T-1859, T-1371]
created: 2026-05-15T18:25:00Z
last_update: 2026-05-15T18:25:00Z
date_finished: null
---

# T-1860: episodic-gen forensic log overwrites previous invocation — defeats T-1371/G-054 intent

## Context

`agents/task-create/update-task.sh:1429` writes the episodic-gen forensic header with `> "$EPISODIC_LOG"` (single redirect — truncates). T-1371 / G-054 added this log to capture forensic context for silent episodic-gen failures (PROJECT_ROOT, CONTEXT_DIR, env, exit code). But the truncation means each invocation wipes prior runs.

T-1859 surfaced this: three completed tasks (T-1829/T-1830/T-1831) had missing episodics with no surviving log to diagnose why. The next failure will also be uninspectable — the auto-trigger's diagnostic mechanism is broken in exactly the failure mode it was added to support.

## Acceptance Criteria

### Agent
- [ ] **A1** `update-task.sh:1429` no longer truncates; either appends (`>>`) with a header demarcator, or writes per-task log files at `.context/working/episodic-gen/<T-XXX>.log`
- [ ] **A2** Log accumulates across at least 2 consecutive invocations (test: run update-task twice, confirm both invocations appear in the log/logs)
- [ ] **A3** If appending: a rotation/size cap is in place (e.g., trim to last 50 invocations or 1MB), OR the log is structured (jsonl) for easy tail
- [ ] **A4** Audit/Watchtower surface for "last 5 episodic-gen failures" (optional — primary win is just not losing the data)

## Verification

# Append two episodic-gen calls and confirm both appear in the log
# (Concrete commands depend on chosen design; written at implementation time.)

## RCA

**Symptom:** T-1859 backfilled 3 missing episodics. Could not RCA the original silent failure because the forensic log retained only the most recent (successful) T-1858 run.

**Root cause:** `> "$EPISODIC_LOG"` (line 1429) truncates the log on every invocation.

**Why structurally allowed:** T-1371 introduced the log with the right intent (capture forensic context on silent failure) but with the wrong file mode (truncate). The log "worked" in tests because tests verify single-invocation behaviour. The multi-invocation history requirement was implicit and untested.

**Prevention:** Append with rotation OR per-task log files. Either way, the data from the failing run survives until the next failure can be diagnosed against it.

## Evolution

## Decisions

## Decision

## Updates

### 2026-05-15T18:25:00Z — task-created [filed-from-T-1859-rca]
- **Action:** Filed during T-1859 to honour "one bug = one task" rule
- **Context:** RCA finding from T-1859: the forensic log mechanism defeats itself by truncating.
