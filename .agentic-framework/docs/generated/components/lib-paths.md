# paths

> Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/paths.sh`

**Tags:** `shell`, `paths`, `portability`, `core`

## What It Does

lib/paths.sh — Centralized path resolution for the Agentic Engineering Framework
Provides FRAMEWORK_ROOT, PROJECT_ROOT, and common directory variables.
Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern
duplicated across 25+ agent scripts.
Usage (from any agent script):
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/paths.sh"
Or if FRAMEWORK_ROOT is already known:
source "$FRAMEWORK_ROOT/lib/paths.sh"
After sourcing, these variables are set:
FRAMEWORK_ROOT — Absolute path to the framework repo root

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [yaml](/docs/generated/lib-yaml) | calls | YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh. |

## Used By (55)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [healing](/docs/generated/agents-healing-healing) | calls | Healing Agent - Antifragile error recovery and pattern learning |
| [fabric](/docs/generated/agents-fabric-fabric) | calls | Fabric Agent - Component topology system for codebase self-awareness |
| [resume](/docs/generated/agents-resume-resume) | calls | Resume Agent - Post-compaction recovery and state synchronization |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [budget-gate](/docs/generated/budget-gate) | calls | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [ask](/docs/generated/lib-ask) | calls | fw ask subcommand. Provides interactive question/answer prompts for framework configuration and user input collection. |
| [watchtower](/docs/generated/bin-watchtower) | calls | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |
| [plugin-audit](/docs/generated/agents-audit-plugin-audit) | called_by | Scans enabled Claude Code plugins for task-system awareness. Classifies each skill/agent/command as TASK-AWARE, TASK-SILENT, or TASK-OVERRIDING based on framework governance integration. |
| [self-audit](/docs/generated/agents-audit-self-audit) | called_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [bus-handler](/docs/generated/agents-context-bus-handler) | called_by | Processes incoming bus messages from the inbox directory. Triggered by systemd.path when files appear in .context/bus/inbox/. Routes typed YAML envelopes to appropriate handlers for sub-agent result management. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | called_by | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-agent-dispatch](/docs/generated/agents-context-check-agent-dispatch) | called_by | Agent Dispatch Gate — PreToolUse hook for Agent tool. Tracks dispatches per session, blocks 3rd+ unless approved or TermLink not installed. |
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | called_by | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [check-tier0](/docs/generated/agents-context-check-tier0) | called_by | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | called_by | Session Resume Hook — Reinject structured context on session recovery |
| [pre-compact](/docs/generated/agents-context-pre-compact) | called_by | Pre-Compaction Hook — Save structured context before lossy compaction |
| [generate-article](/docs/generated/agents-docgen-generate-article) | called_by | Generates AI-assisted subsystem articles from component fabric cards |
| [generate-component](/docs/generated/agents-docgen-generate-component) | called_by | Generates component reference documentation from fabric cards |
| [fabric](/docs/generated/agents-fabric-fabric) | called_by | Fabric Agent - Component topology system for codebase self-awareness |
| [git](/docs/generated/agents-git-git) | called_by | Git Agent - Structural Enforcement for Git Operations |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [healing](/docs/generated/agents-healing-healing) | called_by | Healing Agent - Antifragile error recovery and pattern learning |
| [observe](/docs/generated/agents-observe-observe) | called_by | Observe Agent - Lightweight observation capture |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [resume](/docs/generated/agents-resume-resume) | called_by | Resume Agent - Post-compaction recovery and state synchronization |
| [create-task](/docs/generated/agents-task-create-create-task) | called_by | Task Creation Agent - Mechanical Operations |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [watchtower](/docs/generated/bin-watchtower) | called_by | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |
| [budget-gate](/docs/generated/budget-gate) | called_by | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [checkpoint](/docs/generated/checkpoint) | called_by | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [context-dispatcher](/docs/generated/context-dispatcher) | called_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [ask](/docs/generated/lib-ask) | called_by | fw ask subcommand. Provides interactive question/answer prompts for framework configuration and user input collection. |
| [lib_paths](/docs/generated/tests-unit-lib_paths) | called-by | Unit tests for paths (5 tests) |
| [session-metrics](/docs/generated/agents-context-session-metrics) | called_by | Extract per-session quality metrics (CPT, error rate, edit bursts) from JSONL transcript |
| [lib_paths](/docs/generated/tests-unit-lib_paths) | called_by | Unit tests for paths (5 tests) |
| [block-task-tools](/docs/generated/agents-context-block-task-tools) | called_by | PreToolUse hook that blocks Claude Code built-in task/todo tools to prevent bypassing framework task governance |
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [lib_paths](/docs/generated/tests-unit-lib_paths) | tests_by | Unit tests for paths (5 tests) |
| [lib_review](/docs/generated/tests-unit-lib_review) | called_by | Unit tests for review (10 tests) |
| [lib_review](/docs/generated/tests-unit-lib_review) | tests_by | Unit tests for review (10 tests) |
| [lib_validate_init](/docs/generated/tests-unit-lib_validate_init) | called_by | Unit tests for lib/validate-init.sh (7 tests) |
| [lib_validate_init](/docs/generated/tests-unit-lib_validate_init) | tests_by | Unit tests for lib/validate-init.sh (7 tests) |
| [test_enrich_bats_parser](/docs/generated/tests-unit-test_enrich_bats_parser) | called_by | TODO: describe what this component does |
| [check-visual-verification](/docs/generated/agents-context-check-visual-verification) | called_by | TODO: describe what this component does |
| [review_link_blocking_gate](/docs/generated/tests-unit-review_link_blocking_gate) | called_by | TODO: describe what this component does |
| [review_link_blocking_gate](/docs/generated/tests-unit-review_link_blocking_gate) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-paths.yaml`*
*Last verified: 2026-03-10*
