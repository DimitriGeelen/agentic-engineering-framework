# checkpoint

> Context Checkpoint Agent — Token-aware context budget monitor Reads actual token usage from Claude Code JSONL transcript to warn before automatic compaction causes context loss.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/checkpoint.sh`

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
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [context_tokens](/docs/generated/lib-context_tokens) | calls | Shared "how many tokens does THIS conversation currently hold" scan. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [commit-cadence](/docs/generated/agents-context-commit-cadence) | read_by | PostToolUse hook: monitor time since last commit — warns when commit cadence exceeds threshold (P-009 budget management). |
| [session-metrics](/docs/generated/agents-context-session-metrics) | called_by | Extract per-session quality metrics (CPT, error rate, edit bursts) from JSONL transcript |
| [checkpoint](/docs/generated/tests-unit-checkpoint) | called_by | Unit tests for agents/context/checkpoint.sh |
| [handover_push_timeout](/docs/generated/tests-unit-handover_push_timeout) | called_by | Unit tests for T-1277 — verify handover.sh wraps git push with timeout so an unreachable remote (e.g. onedev VPN down) cannot stall the auto-handover hook. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT. |

## Related

### Tasks
- T-796: Fix remaining single-warning shellcheck issues in agent scripts
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block
- T-834: Fix budget gate false critical — update CONTEXT_WINDOW default 200K to 1M for Opus 4.6

---
*Auto-generated from Component Fabric. Card: `agents-context-checkpoint.yaml`*
*Last verified: 2026-09-05*
