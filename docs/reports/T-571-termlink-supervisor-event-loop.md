# T-571: TermLink Supervisor Event Loop — Reliable Bidirectional Signaling

## Status: Not Yet Explored

This inception task has not been explored yet. The template in `.tasks/active/` is still blank.

## Problem Statement (from task description)

Design a reliable bidirectional signaling mechanism between a supervisor process and dispatched TermLink agents. Current dispatch is fire-and-forget with polling for completion. Need: heartbeat monitoring, graceful shutdown signaling, result notification, crash recovery.

## Next Steps

1. Fill in the inception template in the task file
2. Research TermLink event primitives (emit/wait/poll)
3. Design supervisor event loop with heartbeat + crash recovery
4. Go/No-Go decision
