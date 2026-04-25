# loop-detect

> PostToolUse hook: detect repetitive tool call patterns — warns when agent appears stuck in a loop (same tool+args repeated).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/loop-detect.sh`

## What It Does

PostToolUse loop detector — shell wrapper for TypeScript implementation
Called via: fw hook loop-detect
Reads PostToolUse JSON from stdin, outputs additionalContext on stderr
Exit: 0=ok/warning, 2=block

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/ts/src/loop-detect.ts` | calls |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/context/error-watchdog.sh` | complements |

---
*Auto-generated from Component Fabric. Card: `agents-context-loop-detect.yaml`*
*Last verified: 2026-03-27*
