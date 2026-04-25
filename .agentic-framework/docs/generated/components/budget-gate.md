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

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `F-003` | reads |
| `budget-gate-counter` | reads |
| `lib/paths.sh` | calls |
| `lib/config.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `C-009` | triggers |
| `agents/onboarding-test/test-onboarding.sh` | called_by |
| `agents/audit/self-audit.sh` | read_by |
| `C-009` | triggers_by |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-795: Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block
- T-834: Fix budget gate false critical — update CONTEXT_WINDOW default 200K to 1M for Opus 4.6

---
*Auto-generated from Component Fabric. Card: `budget-gate.yaml`*
*Last verified: 2026-02-20*
