# checkpoint

> Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints.

**Type:** hook | **Subsystem:** budget-management | **Location:** `agents/context/checkpoint.sh`

**Tags:** `budget`, `checkpoint`, `context`, `hook`, `PostToolUse`, `auto-handover`

## What It Does

Context Checkpoint Agent — Token-aware context budget monitor
Reads actual token usage from Claude Code JSONL transcript to warn
before automatic compaction causes context loss.
Primary: Token-based warnings from JSONL transcript (checked every 5 calls)
Fallback: Tool call counter (when transcript unavailable)
Note: Token reading lags by ~1 API call (~10-30K behind actual).
Thresholds are set conservatively to account for this.
Usage:
checkpoint.sh post-tool   — Called by Claude Code PostToolUse hook
checkpoint.sh reset       — Reset tool call counter (on commit)

### Framework Reference

When fixing a bug discovered through real-world usage (user testing, production incident, cross-platform failure):
1. **Classify the bug** — Is this a new failure class, or a repeat of a known pattern?
2. **Check learnings.yaml** — Does a learning already exist for this class?
3. If new class: `fw context add-learning "description" --task T-XXX --source P-001`
4. If systemic (same class hit 2+ times): register in `concerns.yaml`, consider tooling fix (Level C/D)

*(truncated — see CLAUDE.md for full section)*

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-status](/docs/generated/budget-status) | reads | Cached budget level for fast PreToolUse decisions. Avoids re-reading JSONL transcript on every tool call. |
| [budget-status](/docs/generated/budget-status) | writes | Cached budget level for fast PreToolUse decisions. Avoids re-reading JSONL transcript on every tool call. |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (13)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | triggers | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [claude-fw](/docs/generated/bin-claude-fw) | read_by | Claude Code wrapper with auto-restart support. Runs claude normally, then checks for a restart signal file written by checkpoint.sh when auto-handover fires at critical budget. If found and fresh, auto-restarts with claude -c to continue seamlessly. |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [session-metrics](/docs/generated/agents-context-session-metrics) | called-by | Extract per-session quality metrics (CPT, error rate, edit bursts) from JSONL transcript |
| [checkpoint](/docs/generated/tests-unit-checkpoint) | called-by | TODO: describe what this component does |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |
| [checkpoint](/docs/generated/tests-unit-checkpoint) | called_by | TODO: describe what this component does |
| [checkpoint](/docs/generated/tests-unit-checkpoint) | tests_by | TODO: describe what this component does |
| [handover_push_timeout](/docs/generated/tests-unit-handover_push_timeout) | called_by | Unit tests for T-1277 — verify handover.sh wraps git push with timeout so an unreachable remote (e.g. onedev VPN down) cannot stall the auto-handover hook. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT. |
| [handover_push_timeout](/docs/generated/tests-unit-handover_push_timeout) | tests_by | Unit tests for T-1277 — verify handover.sh wraps git push with timeout so an unreachable remote (e.g. onedev VPN down) cannot stall the auto-handover hook. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT. |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-796: Fix remaining single-warning shellcheck issues in agent scripts
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block
- T-834: Fix budget gate false critical — update CONTEXT_WINDOW default 200K to 1M for Opus 4.6

---
*Auto-generated from Component Fabric. Card: `checkpoint.yaml`*
*Last verified: 2026-02-20*
