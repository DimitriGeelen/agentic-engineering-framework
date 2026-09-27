# t3248_useful_headroom

> T-3248 — useful-headroom measurement (arc-012 E9).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3248_useful_headroom.bats`

## What It Does

T-3248 — useful-headroom measurement (arc-012 E9). The budget gauge reports
tokens against WINDOW, but the work a session can actually do per iteration is
WINDOW - BASELINE: the floor a fresh session pays for CLAUDE.md, hooks and the
injected handover before its first useful turn, re-paid in full on every
restart. E9 measured a 52.6k floor against a 58000 cap — ~4% of the window
available to work in — with no gauge anywhere showing it.
What ships: BASELINE derived from the session's OWN transcript (first in-scope
usage entry of the dominant model since the last compact_boundary — mirror of
lib/context_tokens.py's scoping, which takes the LAST entry for current usage);
baseline_tokens / headroom_tokens / headroom_ratio ride along in the

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [checkpoint](/docs/generated/checkpoint) | tests | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [budget-gate](/docs/generated/budget-gate) | tests | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [context_tokens](/docs/generated/lib-context_tokens) | tests | Shared "how many tokens does THIS conversation currently hold" scan. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3248_useful_headroom.yaml`*
*Last verified: 2026-09-07*
