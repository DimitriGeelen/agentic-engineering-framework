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

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-status](/docs/generated/budget-status) | reads | Cached budget level for fast PreToolUse decisions. Avoids re-reading JSONL transcript on every tool call. |
| `budget-gate-counter` | reads | — |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [context_tokens](/docs/generated/lib-context_tokens) | calls | Shared "how many tokens does THIS conversation currently hold" scan. |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |

## Used By (13)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | triggers | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | Invariant: gate scripts must not emit bare 'fw' COMMANDS — use bin/fw, or the _emit_user_command/_fw_cmd helpers that resolve the right path per project. Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007. |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [context_tokens](/docs/generated/lib-context_tokens) | called_by | Shared "how many tokens does THIS conversation currently hold" scan. |
| [no-backticks-in-inline-python](/docs/generated/tests-lint-no-backticks-in-inline-python) | tests_by | T-2707: backticks inside a double-quoted `python3 -c "..."` block are COMMAND SUBSTITUTION performed by bash before python ever sees the source. |
| [prescribed-commands-are-allowed](/docs/generated/tests-lint-prescribed-commands-are-allowed) | tests_by | T-2702 — a command one gate PRESCRIBES must be one the budget gate ALLOWS. |
| [t2919_budget_gate_command_classify](/docs/generated/tests-unit-t2919_budget_gate_command_classify) | called_by | T-2919 — the budget gate must judge the command's STRUCTURE, not scan it for a substring. |
| [t2919_budget_gate_command_classify](/docs/generated/tests-unit-t2919_budget_gate_command_classify) | tests_by | T-2919 — the budget gate must judge the command's STRUCTURE, not scan it for a substring. |
| [template_budget_parity](/docs/generated/tests-unit-template_budget_parity) | tests_by | T-3155 — the consumer CLAUDE.md template must not contradict the budget gate. |
| [t3248_useful_headroom](/docs/generated/tests-unit-t3248_useful_headroom) | tests_by | T-3248 — useful-headroom measurement (arc-012 E9). |

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
