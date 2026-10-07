---
id: WM-003
name: "Session lifecycle — init, resume, handover, cleanup"
description: >
  Standing workflow-management task. Focus here for session-boundary work that
  by definition runs when no task is active. Never closes. Fenced: no source writes.
status: standing
workflow_type: workflow-management
owner: agent
fence: no-source-writes
created: 2026-09-28
---

# WM-003: Session lifecycle

## What this is for

Session-boundary work, which runs precisely when no task is active:

- `fw context init` at session start
- `fw resume status` / `fw resume sync` after compaction
- `fw handover --commit` at session end
- `fw termlink cleanup` before ending

Some of these are already individually allowlisted in
`agents/context/lib/safe-commands.sh` (`handover`, `note`) — each added by a
separate task after a separate deadlock (T-2878 and siblings). WM-003 gives that
class one home instead of a growing list of one-off exemptions, each of which had
to be discovered by being blocked first.

## The fence

**No source writes.** Session lifecycle writes `.context/` and `.git/`, never
source. If a handover needs a code change, that is a task.

## Log

<!-- ### YYYY-MM-DDTHH:MMZ — <session id>: <what ran> -->
