# loop-detect

> PostToolUse hook: detect repetitive tool call patterns — warns when agent appears stuck in a loop (same tool+args repeated).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/loop-detect.sh`

## What It Does

PostToolUse loop detector — shell wrapper for TypeScript implementation
Called via: fw hook loop-detect
Reads PostToolUse JSON from stdin, outputs additionalContext on stderr
Exit: 0=ok/warning, 2=block

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [loop-detect](/docs/generated/lib-ts-src-loop-detect) | calls | TypeScript PostToolUse loop detector — reads hook JSON on stdin, detects repetitive tool call patterns (generic_repeat, ping_pong, no_progress), and emits additionalContext or blocks at critical threshold. Compiled to lib/ts/dist/loop-detect.js. Origin: T-586 Phase 2 prototype, T-594 production port. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [error-watchdog](/docs/generated/agents-context-error-watchdog) | complements | Error Watchdog — PostToolUse hook for Bash error detection |

---
*Auto-generated from Component Fabric. Card: `agents-context-loop-detect.yaml`*
*Last verified: 2026-03-27*
