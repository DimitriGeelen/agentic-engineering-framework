# handover

> Handover Agent - Mechanical Operations

**Type:** script | **Subsystem:** handover | **Location:** `agents/handover/handover.sh`

## What It Does

Handover Agent - Mechanical Operations
Creates handover documents for session continuity

### Framework Reference

- **Generate handover AFTER work is done, not before**
- Never generate a skeleton handover "to fill in later" — the session may not survive to fill it
- When generating handover: fill in ALL [TODO] sections immediately in the same operation
- For mid-session checkpoints: `fw handover --checkpoint`

## Dependencies (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [costs](/docs/generated/lib-costs) | calls | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [session-metrics](/docs/generated/agents-context-session-metrics) | calls | Extract per-session quality metrics (CPT, error rate, edit bursts) from JSONL transcript |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [arc_membership-sh](/docs/generated/lib-arc_membership-sh) | calls | Canonical shell helper for arc-membership scans (T-1880 / T-NEW-15). Consolidates the union-of-`arc_id:`-frontmatter + legacy `arc:<slug>`-tag scan that previously lived inline in three shell consumers: lib/arc.sh, agents/handover/handover.sh, lib/evolution_log.sh. Companion to lib/arc_membership.py (which serves the Python/Flask side).  Public API (PROJECT_ROOT must be set):   arc_tasks_with_arc_id <slug>   → T-IDs whose `arc_id:` matches slug   arc_tasks_with_tag <tag>       → T-IDs whose `tags:` includes tag  Origin: silent-corpus #1 (T-1874/75/76/77) and #2 (T-1879) — captured as L-397. Each inline consumer had to be migrated independently after the T-1850 tags-to-arc_id storage migration; consolidation prevents the next storage-format migration from leaking through nine sites again. |

## Used By (20)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pre-compact](/docs/generated/agents-context-pre-compact) | called_by | Pre-Compaction Hook — Save structured context before lossy compaction |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [checkpoint](/docs/generated/checkpoint) | called_by | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [checkpoint](/docs/generated/checkpoint) | called-by | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [handover](/docs/generated/tests-unit-handover) | tested_by | Unit tests for agents/handover/handover.sh (10 tests) |
| [handover](/docs/generated/tests-unit-handover) | called_by | Unit tests for agents/handover/handover.sh (10 tests) |
| [session_capture_agent](/docs/generated/agents-session-capture) | triggers_by | Session capture checklist — ensures all work, decisions, and learnings are recorded before session end |
| [handover_push_timeout](/docs/generated/tests-unit-handover_push_timeout) | called_by | Unit tests for T-1277 — verify handover.sh wraps git push with timeout so an unreachable remote (e.g. onedev VPN down) cannot stall the auto-handover hook. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT. |
| [session-end](/docs/generated/agents-context-session-end) | called_by | SessionEnd hook — S1 reason logger + S2 handover trigger. Always exits 0. S1: appends {ts, session_id, reason} JSON line to .context/working/.session-end-log. S2: if no handover exists for current session_id, runs `fw handover` in the background (fast return, some end-reasons like API 500 give little grace). Fallback: session-silent-scanner via cron every 15 min catches sessions where this hook never fired. |
| [session-silent-scanner](/docs/generated/agents-context-session-silent-scanner) | called_by | Silent-session scanner — S3 antifragility fallback for SessionEnd. Cron-invoked every 15 min. Walks $HOME/.claude/projects/*/<session>.jsonl, finds sessions older than SESSION_SILENT_THRESHOLD_MIN (default 30) whose session_id does NOT appear under .context/handovers/. For matches runs `fw handover` with RECOVERED=1. Closes SessionEnd gap (/exit skips hook, API 500 kills before hook fires). T-1222 cap prevents commit storms. |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |
| [handover](/docs/generated/tests-unit-handover) | tests_by | Unit tests for agents/handover/handover.sh (10 tests) |
| [handover_push_no_origin](/docs/generated/tests-unit-handover_push_no_origin) | called_by | TODO: describe what this component does |
| [handover_push_no_origin](/docs/generated/tests-unit-handover_push_no_origin) | tests_by | TODO: describe what this component does |
| [handover_push_timeout](/docs/generated/tests-unit-handover_push_timeout) | tests_by | Unit tests for T-1277 — verify handover.sh wraps git push with timeout so an unreachable remote (e.g. onedev VPN down) cannot stall the auto-handover hook. Default bound 15s, override via FW_HANDOVER_PUSH_TIMEOUT. |
| [handover_t012_active_only](/docs/generated/tests-unit-handover_t012_active_only) | called_by | TODO: describe what this component does |
| [handover_t012_active_only](/docs/generated/tests-unit-handover_t012_active_only) | tests_by | TODO: describe what this component does |
| [test_arc_system](/docs/generated/tests-unit-test_arc_system) | called_by | Unit tests for fw arc CLI (T-1661 Phase 1 MVP) — pins create/focus/list/show/tag/close/migrate verbs, anchor handling, and handover injection of ## Current Arc section. |
| [arc_membership_agent_surfaces](/docs/generated/tests-unit-arc_membership_agent_surfaces) | tests_by | TODO: describe what this component does |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-829: Input/output token breakdown — enrich handover frontmatter and timeline display
- T-831: Session quality metrics — session-metrics.sh JSONL analyzer + handover integration
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-850: Fix session metrics — per-session deltas instead of cumulative transcript analysis
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `agents-handover-handover.yaml`*
*Last verified: 2026-02-20*
