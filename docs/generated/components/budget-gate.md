# budget-gate

> Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009.

**Type:** hook | **Subsystem:** budget-management | **Location:** `agents/context/budget-gate.sh`

**Tags:** `budget`, `enforcement`, `context`, `hook`, `PreToolUse`

## What It Does

Budget Gate — PreToolUse hook that enforces context budget limits
BLOCKS tool execution (exit 2) when context tokens exceed critical threshold.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
Architecture (T-138 hybrid):
- This hook is PRIMARY enforcement (PreToolUse = before execution)
- PostToolUse checkpoint.sh is FALLBACK (warnings + auto-handover)
- Optional cron job can write .budget-status externally (future)
Performance target: <100ms per invocation

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `F-003` | reads |
| `budget-gate-counter` | reads |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `C-009` | triggers |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-173: Budget gate: always allow full handover, not just emergency skeleton
- T-176: Adjust budget gate thresholds for no-compaction architecture
- T-182: Reframe handover messaging from emergency panic to calm wrap-up
- T-271: Fix budget-gate stale critical status trap

---
*Auto-generated from Component Fabric. Card: `budget-gate.yaml`*
*Last verified: 2026-02-20*
