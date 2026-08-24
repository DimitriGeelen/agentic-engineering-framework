# hook-config

> Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns.

**Type:** config | **Subsystem:** enforcement | **Location:** `.claude/settings.json`

**Tags:** `hooks`, `enforcement`, `PreToolUse`, `PostToolUse`, `configuration`

## What It Does

## Dependencies (33)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | triggers | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools — _PreToolUse hook on Write\|Edit_ |
| [check-tier0](/docs/generated/agents-context-check-tier0) | triggers | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool — _PreToolUse hook on Bash_ |
| [budget-gate](/docs/generated/budget-gate) | triggers | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. — _PreToolUse hook on Write\|Edit\|Bash (budget-gate.sh)_ |
| [checkpoint](/docs/generated/checkpoint) | triggers | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. — _PostToolUse hook on all tools (checkpoint.sh)_ |
| [error-watchdog](/docs/generated/agents-context-error-watchdog) | triggers | Error Watchdog — PostToolUse hook for Bash error detection — _PostToolUse hook on Bash_ |
| [check-dispatch](/docs/generated/agents-context-check-dispatch) | triggers | Dispatch Guard — PostToolUse hook for Task/TaskOutput result size. Warns when sub-agent results exceed safe thresholds (G-008 enforcement). — _PostToolUse hook on Task\|TaskOutput_ |
| [pre-compact](/docs/generated/agents-context-pre-compact) | triggers | Pre-Compaction Hook — Save structured context before lossy compaction — _PreCompact lifecycle hook_ |
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | triggers | Session Resume Hook — Reinject structured context on session recovery — _SessionStart lifecycle hook (compact, resume)_ |
| [pre-compact](/docs/generated/agents-context-pre-compact) | calls | Pre-Compaction Hook — Save structured context before lossy compaction |
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | calls | Session Resume Hook — Reinject structured context on session recovery |
| [block-plan-mode](/docs/generated/agents-context-block-plan-mode) | calls | PreToolUse hook that blocks EnterPlanMode tool calls. Enforces D-027 (plan mode prohibition) by returning exit code 2 when agent attempts to use built-in plan mode. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-human-ac-tick](/docs/generated/agents-context-check-human-ac-tick) | calls | TODO: describe what this component does |
| [check-arc-id](/docs/generated/agents-context-check-arc-id) | calls | TODO: describe what this component does |
| [check-inception-decisions](/docs/generated/agents-context-check-inception-decisions) | calls | TODO: describe what this component does |
| [check-heredoc-cmd-sub](/docs/generated/agents-context-check-heredoc-cmd-sub) | calls | TODO: describe what this component does |
| [check-inception-schema](/docs/generated/agents-context-check-inception-schema) | calls | TODO: describe what this component does |
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [check-agent-dispatch](/docs/generated/agents-context-check-agent-dispatch) | calls | Agent Dispatch Gate — PreToolUse hook for Agent tool. Tracks dispatches per session, blocks 3rd+ unless approved or TermLink not installed. |
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | calls | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [budget-gate](/docs/generated/budget-gate) | calls | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [block-task-tools](/docs/generated/agents-context-block-task-tools) | calls | PreToolUse hook that blocks Claude Code built-in task/todo tools to prevent bypassing framework task governance |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [error-watchdog](/docs/generated/agents-context-error-watchdog) | calls | Error Watchdog — PostToolUse hook for Bash error detection |
| [check-dispatch](/docs/generated/agents-context-check-dispatch) | calls | Dispatch Guard — PostToolUse hook for Task/TaskOutput result size. Warns when sub-agent results exceed safe thresholds (G-008 enforcement). |
| [loop-detect](/docs/generated/agents-context-loop-detect) | calls | PostToolUse hook: detect repetitive tool call patterns — warns when agent appears stuck in a loop (same tool+args repeated). |
| [check-fabric-new-file](/docs/generated/agents-context-check-fabric-new-file) | calls | PostToolUse hook: detect new files created by Write tool — prompts fabric registration for structural tracking. |
| [commit-cadence](/docs/generated/agents-context-commit-cadence) | calls | PostToolUse hook: monitor time since last commit — warns when commit cadence exceeds threshold (P-009 budget management). |
| [audit-task-tools](/docs/generated/agents-context-audit-task-tools) | calls | PostToolUse hook detecting TodoWrite/TaskCreate bypass (T-1115/T-1118). Advisory — warns agent when banned task tools are used. |
| [check-settings-edit](/docs/generated/agents-context-check-settings-edit) | calls | PostToolUse hook (Write\|Edit matcher) that fires an advisory L-398 reminder when .claude/settings.json is written/edited. Reminds the agent to add `bin/fw enforcement baseline` to the active task's Verification block so the canonical hash refreshes at task-close. Strictly advisory (exit 0).  Origin: T-1886 RCA Candidate B — paired with T-1887 Candidate A (template hint). The enforcement-baseline-drift class accumulated for multiple sessions across T-1849/T-1730/T-1731 before T-1886 cleaned up. |
| [check-active-completed-dup-sh](/docs/generated/agents-context-check-active-completed-dup-sh) | calls | Thin wrapper (T-2517) the fw hook dispatcher loads for the active/completed duplicate write-time guard. Execs check-active-completed-dup.py; the shell layer exists only because bin/fw's hook loader globs .sh files. |
| [check-onboarding-gate](/docs/generated/agents-context-check-onboarding-gate) | calls | T-2815 PreToolUse Write/Edit hook — refuses adding an agent-unresolvable task (owner != human but agent-unresolvable: inception workflow_type or an unticked ### Human AC) to the T-532 gated onboarding set. Bash wrapper exec's the real logic in check-onboarding-gate.py. |
| [check-rail-mcp-label](/docs/generated/agents-context-check-rail-mcp-label) | calls | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [enforcement](/docs/generated/web-blueprints-enforcement) | called_by | Flask blueprint: Enforcement |

---
*Auto-generated from Component Fabric. Card: `hook-config.yaml`*
*Last verified: 2026-02-20*
