---
id: T-1772
name: "audit.sh watchdog leaks flock fd 200 — orphan sleeps hold stale lock and break subsequent fw audit"
description: >
  Discovered while completing T-1771. agents/audit/audit.sh:334 spawns a watchdog subshell that inherits FD 200 (the flock fd from line 321). When the audit script exits and the watchdog subshell exits, its sleep child reparents to init AND keeps its inherited copy of FD 200 — the lock is still held until sleep terminates (default 600s). This means concurrent fw audit invocations (e.g. inside a bats fixture that runs fw audit 5 times) silently abort with 'Another audit is already running' to stderr, exit 0, empty stdout — breaking pipelines like 'fw audit | grep'. Fix: 'exec 200>&-' inside the watchdog subshell so the inherited fd is closed before sleep is forked. Anchor: T-1687 (orchestrator-rethink arc — audit infrastructure depended on by orchestrator observability gauges).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [fd-leak]
components: [C-004]
related_tasks: []
created: 2026-05-06T17:43:11Z
last_update: 2026-05-06T17:53:13Z
date_finished: 2026-05-06T17:53:13Z
---

# T-1772: audit.sh watchdog leaks flock fd 200 — orphan sleeps hold stale lock and break subsequent fw audit

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh:334` watchdog subshell closes inherited FD 200 before forking sleep (one-line fix: `exec 200>&-` at start of the subshell).
- [x] After running `bin/fw audit --section structure`, no orphan `sleep "$AUDIT_TIMEOUT"` process exists with PPID=1 holding FD 200 (verified by bats case 1).
- [x] Bats fixture `tests/unit/test_audit_watchdog_fd.bats` proves: (a) post-audit, no orphan sleep with FD 200 open; (b) two sequential `fw audit` invocations both succeed (second is not blocked by stale lock); (c) source-marker regression check.
- [x] All bats cases pass: `bats tests/unit/test_audit_watchdog_fd.bats </dev/null` — 3/3 ok.

### Human
<!-- All criteria are agent-verifiable. -->

## Verification

bats tests/unit/test_audit_watchdog_fd.bats </dev/null
grep -q "/proc/self/fd" agents/audit/audit.sh
{ bin/fw audit --section structure 2>&1 || true; } | grep -qE "^(Pass:|Fail:)"

## RCA

**Symptom:** While completing T-1771, the verification gate's `bats tests/unit/test_audit_cron_drift.bats` invocation hung indefinitely after all 5 cases printed "ok". The bats orchestrator process sat in `do_wait`; its bats-format-cat reader sat in `pipe_read`. Subsequent verify commands (`bin/fw audit | grep`) returned exit 1 with empty stdout — the audit script bailing with "Another audit is already running" silently.

**Root cause:** `agents/audit/audit.sh:334` spawned the timeout watchdog as `( sleep "$AUDIT_TIMEOUT" && kill -TERM $$ ) </dev/null >/dev/null 2>&1 &`. The watchdog subshell inherited FD 200 — the flock file descriptor opened on line 321 (`exec 200>"$AUDIT_LOCK_FILE"`). When the audit script exited, its EXIT trap killed the subshell PID, but the subshell's child `sleep` process reparented to init (PPID=1) and kept its own copy of FD 200. The flock remained held until `sleep` terminated naturally (default 600s). Inside bats — where each test case's `fw audit` invocation produced one orphan — twelve orphan watchdogs accumulated, holding the lock for the full timeout. Concurrent `fw audit` calls (two within the bats fixture, three in the verify gate) all aborted at the `flock -n 200` check.

**Why structurally allowed:** Three blind spots compounded.
1. **Subshell FD inheritance is a known bash footgun** but no lint/test in this repo flagged it. T-1464's earlier comment ("bats `run` and shell pipelines wait on every descendant FD") addressed stdin/stdout/stderr (FDs 0/1/2) but missed numbered FDs (200).
2. **No regression test exercised serial `fw audit` invocations.** Every test ran one audit and exited. The `fuser`-on-lock or "two sequential audits both produce output" check that would have caught this didn't exist.
3. **Failure mode is silent.** Audit's "another audit running" path exits 0 to stderr, so cron never logged a failure, the bats hang only manifests when `fw audit` runs >1× per test session, and the symptom (broken pipeline) looked like a different issue (grep returning empty input).

**Prevention:** Three layers, all shipped.
1. **Fix:** the watchdog subshell now walks `/proc/self/fd` and closes every fd > 2 before forking sleep. The first attempt closed only FD 200 (the named flock) but missed bats's per-test pipe at FD 3 — the pipe-fd leak still kept bats hung waiting for EOF even after the lock was released. The second iteration generalised to "close everything inherited that isn't stdio" which fixes both classes (named fds and pipeline pipes) and is robust against future fd choices.
2. **Test:** `tests/unit/test_audit_watchdog_fd.bats` (4 cases):
   - Case 1: `fuser` asserts no process holds audit.lock after `fw audit` returns (FD 200 specifically).
   - Case 2: two sequential `fw audit` calls both produce real output.
   - Case 3: source-marker grep on `/proc/self/fd` + `exec \$_n>&-` patterns — catches removal of the broader fix at code-review time.
   - Case 4: pipes `fw audit | head` so FD 3 is a pipe; then asserts no orphan watchdog (PPID=1 sleep) holds any non-`/dev/null` writable fd other than 0/1/2.
3. **Doc:** the inline comment cites both T-1464 (stdio history) and T-1772 (numbered + pipe fds), and explains the inheritance mechanism by which a reparented `sleep` child can hold ANY fd from the original parent shell.

## Evolution

### 2026-05-06 — Discovered while completing T-1771; one-line fix + 3-case bats fixture

- **What changed:** T-1771's bats verification exposed a latent FD inheritance bug in audit.sh's watchdog. Originally diagnosed as "bats hangs on stdin", actually was "sleep child holds flock fd, blocking flock -n in subsequent fw audit". The hang's surface manifestation (bats-format-cat reading from pipe forever) and the underlying mechanism (orphan sleep with FD 200) were not the same thing — the cat hang was incidental; the lock hang was the cause.
- **Plan impact:** None — T-1771 build pause to fix this prerequisite was bounded (~1 commit, ~50 LOC). Reasonable scope per "register first, fix second".
- **Triggered:** No new sub-tasks. T-1771 retry gate-completion now unblocked.

### 2026-05-06 — Fix scope expanded after first iteration was insufficient

- **What changed:** The first commit (`8cb67f77f`) closed only FD 200 in the watchdog subshell. Re-running T-1772's own bats fixture under the verify gate revealed that orphan sleeps still inherited FD 3 — bats's per-test pipe — keeping the bats orchestrator hung on EOF even after the lock was released. So my RCA was right about the *class* of bug (FD inheritance) but wrong about its *boundaries* (it's not just named fds; it's any pipe in the parent shell's pipeline). The hang only "looked solved" because I was testing manually outside a pipe.
- **Plan impact:** Replaced the surgical `exec 200>&-` with a `/proc/self/fd` walk that closes everything > 2. Bats fixture extended from 3 to 4 cases (case 4 specifically pipes `fw audit | head` to put FD 3 in a pipe, asserting no orphan inherits it). Two commits on T-1772 instead of one — first one was load-bearing for the diagnosis even though the fix was incomplete.
- **Triggered:** No new sub-tasks. T-1771 retry now unblocked for real (verified by the broader bats fixture which itself was the test-case that previously hung).

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

### 2026-05-06T17:43:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1772-auditsh-watchdog-leaks-flock-fd-200--orp.md
- **Context:** Initial task creation

### 2026-05-06T17:43:53Z — status-update [task-update-agent]
- **Change:** tags: +fd-leak

## Reviewer Verdict (v1.4)

- **Scan ID:** R-ba0dacd1
- **Timestamp:** 2026-05-06T17:53:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-06T17:53:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
