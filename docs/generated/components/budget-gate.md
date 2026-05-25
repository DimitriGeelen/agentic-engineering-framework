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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-status](/docs/generated/budget-status) | reads | Cached budget level for fast PreToolUse decisions. Avoids re-reading JSONL transcript on every tool call. |
| `budget-gate-counter` | reads | — |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | triggers | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |

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
