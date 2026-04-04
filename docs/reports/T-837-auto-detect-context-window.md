# T-837: Auto-Detect Context Window from Model

## Problem

The `CONTEXT_WINDOW` default was hardcoded to 200K, causing false critical budget gate
triggers on Opus 4.6 (1M context). User had to manually discover and fix (T-834).

## Research Finding

The JSONL transcript contains the model name in assistant message entries:
```json
{"message": {"model": "claude-opus-4-6", ...}, ...}
```

We can extract this and map it to known context windows.

## Proposed Approach

Add model detection to `budget-gate.sh`:

1. On first call (or when status file is stale), read the first assistant entry from JSONL
2. Extract `model` field
3. Look up in a hardcoded table:

| Model Pattern | Context Window |
|--------------|---------------|
| `claude-opus-4-6` | 1,000,000 |
| `claude-sonnet-4-6` | 200,000 |
| `claude-haiku-4-5` | 200,000 |
| (unknown) | 300,000 (safe default) |

4. `FW_CONTEXT_WINDOW` env var still overrides (user preference trumps detection)

## Resolution: 3-tier still wins, detection is Tier 4

The 3-tier config already handles this:
- **Tier 1 (explicit):** CLI flag
- **Tier 2 (env):** `FW_CONTEXT_WINDOW=300000`
- **Tier 3 (default):** 300000

Auto-detection would be a Tier 3.5 — between env var and default. But:
- It adds complexity (JSONL parsing on every cold start)
- The user explicitly said they want 300K, NOT 1M — quality+cost control
- The env var is the right escape hatch for users who want different values
- Model detection could be wrong (Anthropic changes windows without notice)

## Recommendation

**NO-GO.** The 300K default (T-834) is the right fix. Auto-detection adds complexity
for a problem that's already solved by `FW_CONTEXT_WINDOW`. If a user wants 1M:
```bash
export FW_CONTEXT_WINDOW=1000000
```

The real lesson: defaults should be conservative (300K), not optimistic (1M).
