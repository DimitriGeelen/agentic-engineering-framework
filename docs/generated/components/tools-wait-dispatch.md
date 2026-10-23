# wait-dispatch

> tools/wait-dispatch.sh — wait for a dispatched TermLink worker to be DONE.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/wait-dispatch.sh`

## What It Does

tools/wait-dispatch.sh — wait for a dispatched TermLink worker to be DONE.
Usage: tools/wait-dispatch.sh <TASK-ID> <SESSION-NAME> [MAX_SECONDS]
── WHY THIS EXISTS (OBS-557, OBS-563) ──────────────────────────────────────────
Twice in one day an orchestrator gated the next step on a signal the worker
passes THROUGH on its way to finishing, and read whatever it happened to
observe at that moment as a permanent state:
1. OBS-557 — waited on the FIRST `{"type":"result"}` line. A result line is a
YIELD, not completion; round 1 of a four-round run emitted 11 of them. Round
3 overlapped round 2 by ~50s.
2. OBS-563 — waited on the task file appearing in `.tasks/completed/`. That

---
*Auto-generated from Component Fabric. Card: `tools-wait-dispatch.yaml`*
*Last verified: 2026-09-27*
