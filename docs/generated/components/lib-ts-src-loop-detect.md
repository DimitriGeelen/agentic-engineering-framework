# loop-detect

> TypeScript PostToolUse loop detector — reads hook JSON on stdin, detects repetitive tool call patterns (generic_repeat, ping_pong, no_progress), and emits additionalContext or blocks at critical threshold. Compiled to lib/ts/dist/loop-detect.js. Origin: T-586 Phase 2 prototype, T-594 production port.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/ts/src/loop-detect.ts`

**Tags:** `typescript`, `hook`, `loop-detection`, `post-tool-use`

## What It Does

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `.context/working/.loop-detect.json` | writes |
| `transcript` | reads |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/context/loop-detect.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-ts-src-loop-detect.yaml`*
*Last verified: 2026-04-14*
