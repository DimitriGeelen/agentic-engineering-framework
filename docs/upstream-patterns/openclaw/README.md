# Extracted Patterns from OpenClaw

Standalone, zero-dependency TypeScript modules extracted from OpenClaw's codebase.
Each file is self-contained with full source, usage examples, and origin attribution.

Source: [OpenClaw](https://github.com/openclaw/openclaw) (MIT License)
Evaluation: See `docs/reports/EVALUATION-SUMMARY.md` for full analysis.

## Tier 1: Steal Now

| File | Origin | LOC | Value |
|------|--------|-----|-------|
| [`keyed-async-queue.ts`](keyed-async-queue.ts) | `src/plugin-sdk/keyed-async-queue.ts` | 50 | Serialize per key, parallelize across keys |
| [`dm-access-policy.ts`](dm-access-policy.ts) | `src/security/dm-policy-shared.ts` | 160 | Multi-source ACL merge + evaluation with policy modes |
| [`session-key-utils.ts`](session-key-utils.ts) | `src/sessions/session-key-utils.ts` | 110 | Hierarchical session key parsing for multi-agent isolation |
| [`skills-budget.ts`](skills-budget.ts) | `src/agents/skills/workspace.ts` | 90 | 3-tier token budget with binary search fitting |
| [`config-diff.ts`](config-diff.ts) | `src/gateway/config-reload.ts` + `config-reload-plan.ts` | 120 | Deep config diffing + reload plan builder |
| [`tool-loop-detection.ts`](tool-loop-detection.ts) | `src/agents/tool-loop-detection.ts` | 300 | Detect stuck agent loops (repeat, poll, ping-pong) |
| [`dedupe-cache.ts`](dedupe-cache.ts) | `src/infra/dedupe.ts` | 100 | TTL + LRU deduplication cache for event idempotency |

## How to Use

Each file is a standalone ES module. Copy into your project and import:

```typescript
import { KeyedAsyncQueue } from "./keyed-async-queue";
import { createDedupeCache } from "./dedupe-cache";
import { detectToolCallLoop, recordToolCall } from "./tool-loop-detection";
import { applyBudget } from "./skills-budget";
import { diffConfigPaths, buildReloadPlan } from "./config-diff";
import { parseAgentSessionKey, deriveSessionChatType } from "./session-key-utils";
import { resolveDmGroupAccessDecision } from "./dm-access-policy";
```

## Dependencies

- `keyed-async-queue.ts` — zero deps
- `dm-access-policy.ts` — zero deps
- `session-key-utils.ts` — zero deps
- `skills-budget.ts` — zero deps
- `config-diff.ts` — zero deps
- `tool-loop-detection.ts` — `node:crypto` (Node.js built-in)
- `dedupe-cache.ts` — zero deps

## Adaptation Notes

These are extracted patterns, not drop-in copies. Key differences from OpenClaw originals:

1. **Removed internal imports** — All OpenClaw-specific types (`OpenClawConfig`, `SessionState`, `ChannelId`) replaced with self-contained types
2. **Simplified interfaces** — Kept the core algorithm, removed framework-specific wiring
3. **Generalized** — `skills-budget.ts` works with any content items, not just skills; `config-diff.ts` works with any config objects; `dm-access-policy.ts` works with any multi-source allowlists
4. **Type-safe** — Full TypeScript with no `any` casts
