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

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [yaml](/docs/generated/lib-yaml) | calls | YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh. |
| [worktree-identity](/docs/generated/lib-worktree-identity) | calls | lib/worktree-identity.sh — "is this checkout a replica?" (T-3111, R7) |

## Used By (92)

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
| [test_enrich_bats_parser](/docs/generated/tests-unit-test_enrich_bats_parser) | called_by | T-1754 — Regression tests for fabric enrich's .bats parser. |
| [check-visual-verification](/docs/generated/agents-context-check-visual-verification) | called_by | Visual Verification Hook — PreToolUse Bash gate Blocks `git commit` when staged changes include .css/.html files unless the active task body contains a `## Visual Verification` section with at least one image-file reference… |
| [review_link_blocking_gate](/docs/generated/tests-unit-review_link_blocking_gate) | called_by | T-2139 V1 keystone — emit_review blocking gate on review-link homework. |
| [review_link_blocking_gate](/docs/generated/tests-unit-review_link_blocking_gate) | tests_by | T-2139 V1 keystone — emit_review blocking gate on review-link homework. |
| [discard-manifest](/docs/generated/agents-handover-discard-manifest) | called_by | discard-manifest.sh — Category-level compaction discard manifest (T-2366, arc-012 S4) |
| [JSONL Transcript Reader](/docs/generated/capture-reader) | called_by | Extracts human/agent conversation turns from the current Claude Code session's JSONL transcript. Used by the /capture skill to save volatile conversation content to disk before it is lost. |
| [t2380_transcript_dir_encoding](/docs/generated/tests-unit-t2380_transcript_dir_encoding) | tests_by | T-2380 — the three transcript-dir read-surfaces (fw costs, discard-manifest, read-transcript.py) must encode the ~/.claude/projects/<dir> name the way Claude Code does: EVERY non-alnum char → '-'. |
| [t2465_reanchor_from_cwd](/docs/generated/tests-unit-t2465_reanchor_from_cwd) | called_by | T-2465 — unit tests for lib/paths.sh:fw_reanchor_from_cwd (+ the hook-stdin wrapper). |
| [t2465_reanchor_from_cwd](/docs/generated/tests-unit-t2465_reanchor_from_cwd) | tests_by | T-2465 — unit tests for lib/paths.sh:fw_reanchor_from_cwd (+ the hook-stdin wrapper). |
| [hook_paths](/docs/generated/lib-hook_paths) | called_by | Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd. |
| [bpmn_promote](/docs/generated/tools-bpmn_promote) | called_by | fw bpmn promote — turn staged BPMN proposals into gated .tasks/ files. |
| [check-rail-mcp-label](/docs/generated/agents-context-check-rail-mcp-label) | called_by | T-2908: PreToolUse label gate for the MCP rail-post producer surface. |
| [test_pretooluse_gates](/docs/generated/tests-governance-test_pretooluse_gates) | tests_by | T-1606 (T-1601 GO follow-up): red-team harness covering all 7 PreToolUse gates. |
| [drift_gate_not_shadowed_by_safelist](/docs/generated/tests-unit-drift_gate_not_shadowed_by_safelist) | tests_by | T-2880 — the safe-list early return must not shadow the focus-drift gate. |
| [episodic_frontmatter_extraction](/docs/generated/tests-unit-episodic_frontmatter_extraction) | tests_by | T-2731 — frontmatter extraction must be scoped to the frontmatter and must not truncate multi-line scalars. |
| [handover_digest](/docs/generated/tests-unit-handover_digest) | tests_by | T-3028 (T-3025 GO, option 3): the three state dumps digest to count + regenerating command + top-N; the narrative does not change. |
| [harvest_indent_agnostic](/docs/generated/tests-unit-harvest_indent_agnostic) | called_by | T-2676 — harvest.sh indent-agnostic entry greps (dead learnings/patterns sub-stages). Third instance of the indentation-assumption class (T-2672 resolve.sh emit-indent, 832 T-295 field report). |
| [harvest_indent_agnostic](/docs/generated/tests-unit-harvest_indent_agnostic) | tests_by | T-2676 — harvest.sh indent-agnostic entry greps (dead learnings/patterns sub-stages). Third instance of the indentation-assumption class (T-2672 resolve.sh emit-indent, 832 T-295 field report). |
| [note_capture_guard](/docs/generated/tests-unit-note_capture_guard) | tests_by | T-2867 — `fw note` must refuse arguments it cannot use, never discard them. |
| [note_exit_status](/docs/generated/tests-unit-note_exit_status) | tests_by | T-2868 — `fw note` must exit 0 when it has written the note. |
| [t3038_session_scoped_focus](/docs/generated/tests-unit-t3038_session_scoped_focus) | called_by | T-3038 (OBS-291) — focus is per-session, not per-project, for dispatched workers. |
| [t3038_session_scoped_focus](/docs/generated/tests-unit-t3038_session_scoped_focus) | tests_by | T-3038 (OBS-291) — focus is per-session, not per-project, for dispatched workers. |
| [t3053_multiref_traceability](/docs/generated/tests-unit-t3053_multiref_traceability) | tests_by | T-3053 — a commit subject may name more than one task. The traceability check read only the first ref, so a commit whose leading ref did not resolve was reported orphaned even when a later ref named a real task. |
| [t3111_worktree_reexec](/docs/generated/tests-unit-t3111_worktree_reexec) | tests_by | T-3111: fw re-execs the AUTHORITY's binary from a linked worktree (R7 leg L2). |
| [worktree-corpus-guard](/docs/generated/agents-git-lib-worktree-corpus-guard) | called_by | T-3110 — L1 of R7: task-corpus commit guard for the SHARED pre-commit hook. |
| [costs](/docs/generated/lib-costs) | called_by | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [inception](/docs/generated/lib-inception) | called_by | fw inception - Inception phase workflow |
| [review](/docs/generated/lib-review) | called_by | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [t2380_transcript_dir_encoding](/docs/generated/tests-unit-t2380_transcript_dir_encoding) | called_by | T-2380 — the three transcript-dir read-surfaces (fw costs, discard-manifest, read-transcript.py) must encode the ~/.claude/projects/<dir> name the way Claude Code does: EVERY non-alnum char → '-'. |
| [check-worktree-governance-write](/docs/generated/agents-context-check-worktree-governance-write) | called_by | T-3098 — Refuse governance writes from a linked git worktree. |
| [no-project-markers-above-bats-tmpdir](/docs/generated/tests-lint-no-project-markers-above-bats-tmpdir) | tests_by | Corpus-level invariant: no .framework.yaml or .tasks may sit on the path from the bats temp base up to "/". Nearly every hook suite builds its fixture under BATS_TEST_TMPDIR, and the hooks call lib/paths.sh:fw_reanchor_from_cwd, which walks that ancestry for exactly those markers — so the ambient project is an undeclared input to all of them. When an fw init ran with cwd=/tmp on this host (OBS-358), fixtures re-anchored to /tmp and read its null focus: one suite went red with a message that read like a code regression, and any suite whose fixture lacks markers of its own could equally have gone GREEN for a reason unrelated to its subject. The walk mirrors the resolver including its stop-before-"/" condition, and two legs grep the resolver so the mirror cannot drift. A third leg proves the detector fires, since a guard that cannot fail proves nothing; TMPDIR is the lever for the whole-suite red, because bats overwrites BATS_TMPDIR from it at startup. |
| [t3219_verification_count_reconciliation](/docs/generated/tests-unit-t3219_verification_count_reconciliation) | tests_by | Pins the P-011 verification gate against unreconciled counts: a stdin-reading verification command must not swallow the rest of the block, and pass+fail must equal total or the close is refused. Runs mutated copies of update-task.sh from a symlink farm because FRAMEWORK_ROOT is derived from script location. |
| [t3220_verification_gate_exits](/docs/generated/tests-unit-t3220_verification_gate_exits) | tests_by | Pins that every failure path in run_verification_commands exits rather than returns, and that the choice does not depend on set -euo pipefail 1700 lines away. Four measured cells (exit/return x errexit present/absent) isolate the dependency; the two control cells stop the suite passing against anything. |
| [no-project-markers-above-bats-tmpdir](/docs/generated/tests-lint-no-project-markers-above-bats-tmpdir) | mirrors_by | Corpus-level invariant: no .framework.yaml or .tasks may sit on the path from the bats temp base up to "/". Nearly every hook suite builds its fixture under BATS_TEST_TMPDIR, and the hooks call lib/paths.sh:fw_reanchor_from_cwd, which walks that ancestry for exactly those markers — so the ambient project is an undeclared input to all of them. When an fw init ran with cwd=/tmp on this host (OBS-358), fixtures re-anchored to /tmp and read its null focus: one suite went red with a message that read like a code regression, and any suite whose fixture lacks markers of its own could equally have gone GREEN for a reason unrelated to its subject. The walk mirrors the resolver including its stop-before-"/" condition, and two legs grep the resolver so the mirror cannot drift. A third leg proves the detector fires, since a guard that cannot fail proves nothing; TMPDIR is the lever for the whole-suite red, because bats overwrites BATS_TMPDIR from it at startup. |
| [check-arc-id](/docs/generated/agents-context-check-arc-id-py) | called_by | T-1849: arc_id task-frontmatter validation hook (T-NEW-2). |
| [check-inception-recommendation](/docs/generated/agents-context-check-inception-recommendation-py) | called_by | T-2205 (T-2204 Slice B): PreToolUse Write/Edit hook — refuse save when an inception task has a template-only `## Recommendation` block under |
| [check-inception-schema](/docs/generated/agents-context-check-inception-schema-py) | called_by | T-2188: PreToolUse hook validating inception frontmatter schema. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [checkpoint](/docs/generated/checkpoint) | called_by | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [termlink](/docs/generated/agents-termlink-termlink) | called_by | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [t3422_dispatch_seeds_focus](/docs/generated/tests-unit-t3422_dispatch_seeds_focus) | tests_by | T-3422 — dispatch pre-seeds the worker's session-scoped focus file. |

---
*Auto-generated from Component Fabric. Card: `lib-paths.yaml`*
*Last verified: 2026-03-10*
