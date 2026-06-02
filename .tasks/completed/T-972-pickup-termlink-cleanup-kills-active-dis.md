---
id: T-972
name: "Pickup: TermLink cleanup kills active dispatch workers — fw termlink cleanup treats running workers as orphans because they lack exit_code file (from 999-Agentic-Engineering-Framework)"
description: >
  Auto-created from pickup envelope. Source: 999-Agentic-Engineering-Framework, task T-843. Type: bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [pickup, bug-report]
components: [agents/termlink/termlink.sh]
related_tasks: []
created: 2026-04-06T19:42:04Z
last_update: 2026-04-06T20:47:14Z
date_finished: 2026-04-06T20:47:14Z
---

# T-972: Pickup: TermLink cleanup kills active dispatch workers — fw termlink cleanup treats running workers as orphans because they lack exit_code file (from 999-Agentic-Engineering-Framework)

## Context

Bug: `fw termlink cleanup` kills active dispatch workers. Root cause: `ps aux | grep "$wdir"` only matches `run.sh` (whose args contain `$wdir`), not the `claude -p` child process (whose args contain the prompt text, not the path). The T-843 check at line 159-173 then correctly doesn't find "claude" in `run.sh`'s args, so it treats the worker as orphaned and kills it — which cascades to kill the claude child.

Fix: Also check child processes of matched PIDs for "claude".

## Acceptance Criteria

### Agent
- [x] `cmd_cleanup()` checks child processes via `ps --ppid` for active claude processes
- [x] Active workers with running claude child processes are skipped during cleanup
- [x] Verification commands pass

## Verification

grep -q 'ppid\|children\|child' agents/termlink/termlink.sh

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-06T20:44:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T20:47:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Fixed child process detection in cleanup

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fc57cc6e
- **Timestamp:** 2026-06-02T15:05:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
