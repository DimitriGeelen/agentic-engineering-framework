# fw

> Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes.

**Type:** script | **Subsystem:** framework-core | **Location:** `bin/fw`

## What It Does

fw - Agentic Engineering Framework CLI
Single entry point for all framework operations.
Reads .framework.yaml from the project directory to resolve
FRAMEWORK_ROOT, then routes commands to the appropriate agent.
When run from a project that uses the framework as shared tooling,
fw reads .framework.yaml to find the framework install path.
When run from inside the framework repo itself, it auto-detects.

### Framework Reference

`fw` is the single entry point for all framework operations — it resolves paths, sets env vars, and routes to agents. Discover commands via `fw help`, `fw <cmd> --help`, or the Quick Reference section below.

**Path resolution:** `fw` finds the framework via `bin/fw`'s location (inside framework repo) or via `.framework.yaml` in the project root (shared tooling mode).

*(truncated — see CLAUDE.md for full section)*

## Dependencies (46)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [plugin-audit](/docs/generated/agents-audit-plugin-audit) | calls | Scans enabled Claude Code plugins for task-system awareness. Classifies each skill/agent/command as TASK-AWARE, TASK-SILENT, or TASK-OVERRIDING based on framework governance integration. |
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [fabric](/docs/generated/agents-fabric-fabric) | calls | Fabric Agent - Component topology system for codebase self-awareness |
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [healing](/docs/generated/agents-healing-healing) | calls | Healing Agent - Antifragile error recovery and pattern learning |
| [resume](/docs/generated/agents-resume-resume) | calls | Resume Agent - Post-compaction recovery and state synchronization |
| [mcp-reaper](/docs/generated/agents-mcp-mcp-reaper) | calls | Detects and kills orphaned MCP server processes (playwright-mcp, context7-mcp) left behind when Claude Code sessions crash. Identifies orphans via PPID=1, MCP command pattern, age threshold, and dead PGID leader. |
| [observe](/docs/generated/agents-observe-observe) | calls | Observe Agent - Lightweight observation capture |
| [inception](/docs/generated/lib-inception) | calls | fw inception - Inception phase workflow |
| [promote](/docs/generated/lib-promote) | calls | Graduation Pipeline — fw promote |
| [assumption](/docs/generated/lib-assumption) | calls | fw assumption - Assumption tracking |
| [bus](/docs/generated/lib-bus) | calls | fw bus - Task-scoped result ledger for sub-agent communication |
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [setup](/docs/generated/lib-setup) | calls | fw setup - Guided onboarding wizard for new projects |
| [harvest](/docs/generated/lib-harvest) | calls | fw harvest - Collect learnings from projects back into the framework |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [self-audit](/docs/generated/agents-audit-self-audit) | calls | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | calls | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [generate-article](/docs/generated/agents-docgen-generate-article) | calls | Generates AI-assisted subsystem articles from component fabric cards |
| [generate-component](/docs/generated/agents-docgen-generate-component) | calls | Generates component reference documentation from fabric cards |
| [termlink](/docs/generated/agents-termlink-termlink) | calls | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [compat](/docs/generated/lib-compat) | calls | Compatibility shims: bash 3.2 (macOS) POSIX-safe replacements for declare -A and other bashisms. |
| [review](/docs/generated/lib-review) | calls | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [ask](/docs/generated/lib-ask) | calls | fw ask subcommand. Provides interactive question/answer prompts for framework configuration and user input collection. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [dispatch](/docs/generated/lib-dispatch) | calls | fw dispatch subcommand: cross-machine SSH-based result dispatch. Serializes bus envelopes and pipes via SSH to remote fw bus receive. |
| [upstream](/docs/generated/lib-upstream) | calls | Safe issue creation from field installations to framework upstream repo. Resolves upstream repo from .framework.yaml or git remotes. Supports dry-run, confirmation, fw doctor attachment, patch attachment, and sent-file tracking. |
| [preflight](/docs/generated/lib-preflight) | calls | fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations. |
| [validate-init](/docs/generated/lib-validate-init) | calls | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [update](/docs/generated/lib-update) | calls | fw update subcommand: CLI wrapper for framework self-update. Pulls latest, runs upgrade, reports changes. |
| [watchtower](/docs/generated/bin-watchtower) | calls | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |
| [build](/docs/generated/lib-build) | calls | fw build subcommand: placeholder for future build orchestration. Currently unused. |
| [pickup](/docs/generated/lib-pickup) | calls | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [costs](/docs/generated/lib-costs) | calls | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [task-audit](/docs/generated/lib-task-audit) | calls | Scans task files for literal placeholder content that should have been replaced during authoring, blocking review and inception decisions until resolved |
| [watchtower](/docs/generated/lib-watchtower) | calls | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | calls | TODO: describe what this component does |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | calls | TODO: describe what this component does |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | calls | TODO: describe what this component does |

## Used By (211)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [upstream](/docs/generated/lib-upstream) | called_by | Safe issue creation from field installations to framework upstream repo. Resolves upstream repo from .framework.yaml or git remotes. Supports dry-run, confirmation, fw doctor attachment, patch attachment, and sent-file tracking. |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | called_by | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [fw_work_on](/docs/generated/tests-integration-fw_work_on) | called-by | Integration tests for fw work-on CLI — 5 tests covering create+focus, resume, nonexistent ID, and help. |
| [fw_init](/docs/generated/tests-integration-fw_init) | called-by | Integration tests for fw init CLI. |
| [fw_handover](/docs/generated/tests-integration-fw_handover) | called-by | Integration tests for fw handover CLI — 4 tests covering help, file creation, sections, and output. |
| [fw_decisions](/docs/generated/tests-integration-fw_decisions) | called-by | Integration tests for fw decisions CLI. |
| [fw_learnings](/docs/generated/tests-integration-fw_learnings) | called-by | Integration tests for fw learnings CLI. |
| [fw_help](/docs/generated/tests-integration-fw_help) | called-by | Integration tests for fw help CLI. |
| [fw_preflight](/docs/generated/tests-integration-fw_preflight) | called-by | Integration tests for fw preflight CLI. |
| [fw-shim](/docs/generated/bin-fw-shim) | called-by | Project-detecting fw shim: resolves framework root from .framework.yaml or bin/ location. Replaces global install symlink (T-664). |
| [fw_fabric](/docs/generated/tests-integration-fw_fabric) | called-by | Integration tests for fw fabric CLI — 10 tests covering help, overview, stats, deps, search, and get. |
| [fw_vendor](/docs/generated/tests-integration-fw_vendor) | called-by | Integration tests for fw vendor CLI. |
| [fw_approvals](/docs/generated/tests-integration-fw_approvals) | called-by | Integration tests for fw approvals CLI. |
| [fw_version](/docs/generated/tests-integration-fw_version) | called-by | Integration tests for fw version CLI. |
| [fw_resume](/docs/generated/tests-integration-fw_resume) | called-by | Integration tests for fw resume CLI — 5 tests covering help, quick, status, sync, and session file. |
| [fw_cron](/docs/generated/tests-integration-fw_cron) | called-by | Integration tests for fw cron CLI — 9 tests covering help, status, list, invalid subcommand, run/pause/resume without job-id. |
| [fw_inception](/docs/generated/tests-integration-fw_inception) | called-by | Integration tests for fw inception CLI — 5 tests covering help, status, start, workflow type, and status listing. |
| [fw_gaps](/docs/generated/tests-integration-fw_gaps) | called-by | Integration tests for fw gaps CLI. |
| [fw_assumption](/docs/generated/tests-integration-fw_assumption) | called-by | Integration tests for fw assumption CLI. |
| [fw_metrics](/docs/generated/tests-integration-fw_metrics) | called-by | Integration tests for fw metrics CLI — 4 tests covering dashboard, task counts, and predict. |
| [fw_promote](/docs/generated/tests-integration-fw_promote) | called-by | Integration tests for fw promote CLI. |
| [fw_audit](/docs/generated/tests-integration-fw_audit) | called-by | Integration tests for fw audit CLI — 3 tests covering help, section run, and YAML output. |
| [fw_git](/docs/generated/tests-integration-fw_git) | called-by | Integration tests for fw git CLI — 6 tests covering help, status, and commit with task reference validation. |
| [fw_bus](/docs/generated/tests-integration-fw_bus) | called-by | Integration tests for fw bus CLI. |
| [fw_healing](/docs/generated/tests-integration-fw_healing) | called-by | Integration tests for fw healing CLI — 6 tests covering help, patterns, diagnose, and suggest. |
| [fw_fix_learned](/docs/generated/tests-integration-fw_fix_learned) | called-by | Integration tests for fw fix_learned CLI. |
| [fw_notify](/docs/generated/tests-integration-fw_notify) | called-by | Integration tests for fw notify CLI — 10 tests covering help, status, enable, disable, toggle, test-disabled, invalid subcommand, setup. |
| [fw_task](/docs/generated/tests-integration-fw_task) | called-by | Integration tests for fw task CLI — 7 tests covering create, placeholder rejection, ID increment, status update, update fail, help, list. |
| [fw_patterns](/docs/generated/tests-integration-fw_patterns) | called-by | Integration tests for fw patterns CLI. |
| [fw_search](/docs/generated/tests-integration-fw_search) | called-by | Integration tests for fw search CLI. |
| [fw_practices](/docs/generated/tests-integration-fw_practices) | called-by | Integration tests for fw practices CLI. |
| [fw_validate_init](/docs/generated/tests-integration-fw_validate_init) | called-by | Integration tests for fw validate_init CLI. |
| [fw_upstream](/docs/generated/tests-integration-fw_upstream) | called-by | Integration tests for fw upstream CLI. |
| [fw_harvest](/docs/generated/tests-integration-fw_harvest) | called-by | Integration tests for fw harvest CLI. |
| [fw_tier0](/docs/generated/tests-integration-fw_tier0) | called-by | Integration tests for fw tier0 CLI. |
| [fw_doctor](/docs/generated/tests-integration-fw_doctor) | called-by | Integration tests for fw doctor CLI — 4 tests covering health check, installation, config, and status markers. |
| [fw_timeline](/docs/generated/tests-integration-fw_timeline) | called-by | Integration tests for fw timeline CLI. |
| [fw_context](/docs/generated/tests-integration-fw_context) | called-by | Integration tests for fw context CLI — 6 tests covering status, init, focus, and help. |
| [fw_onboarding](/docs/generated/tests-integration-fw_onboarding) | called-by | Integration tests for fw onboarding CLI. |
| [fw_hook](/docs/generated/tests-integration-fw_hook) | called-by | Integration tests for fw hook CLI. |
| [fw_traceability](/docs/generated/tests-integration-fw_traceability) | called-by | Integration tests for fw traceability CLI. |
| [fw_costs](/docs/generated/tests-integration-fw_costs) | tested_by | Integration tests for fw costs CLI (4 tests) |
| [fw_self_test](/docs/generated/tests-integration-fw_self_test) | tested_by | Integration tests for fw self-test (4 tests) |
| [fw_config](/docs/generated/tests-integration-fw_config) | tested_by | Integration tests for fw config CLI (9 tests) |
| [fw-shim](/docs/generated/bin-fw-shim) | called_by | Project-detecting fw shim: resolves framework root from .framework.yaml or bin/ location. Replaces global install symlink (T-664). |
| [fw_approvals](/docs/generated/tests-integration-fw_approvals) | called_by | Integration tests for fw approvals CLI. |
| [fw_assumption](/docs/generated/tests-integration-fw_assumption) | called_by | Integration tests for fw assumption CLI. |
| [fw_audit](/docs/generated/tests-integration-fw_audit) | called_by | Integration tests for fw audit CLI — 3 tests covering help, section run, and YAML output. |
| [fw_bus](/docs/generated/tests-integration-fw_bus) | called_by | Integration tests for fw bus CLI. |
| [fw_config](/docs/generated/tests-integration-fw_config) | called_by | Integration tests for fw config CLI (9 tests) |
| [fw_context](/docs/generated/tests-integration-fw_context) | called_by | Integration tests for fw context CLI — 6 tests covering status, init, focus, and help. |
| [fw_costs](/docs/generated/tests-integration-fw_costs) | called_by | Integration tests for fw costs CLI (4 tests) |
| [fw_cron](/docs/generated/tests-integration-fw_cron) | called_by | Integration tests for fw cron CLI — 9 tests covering help, status, list, invalid subcommand, run/pause/resume without job-id. |
| [fw_decisions](/docs/generated/tests-integration-fw_decisions) | called_by | Integration tests for fw decisions CLI. |
| [fw_doctor](/docs/generated/tests-integration-fw_doctor) | called_by | Integration tests for fw doctor CLI — 4 tests covering health check, installation, config, and status markers. |
| [fw_fabric](/docs/generated/tests-integration-fw_fabric) | called_by | Integration tests for fw fabric CLI — 10 tests covering help, overview, stats, deps, search, and get. |
| [fw_fix_learned](/docs/generated/tests-integration-fw_fix_learned) | called_by | Integration tests for fw fix_learned CLI. |
| [fw_gaps](/docs/generated/tests-integration-fw_gaps) | called_by | Integration tests for fw gaps CLI. |
| [fw_git](/docs/generated/tests-integration-fw_git) | called_by | Integration tests for fw git CLI — 6 tests covering help, status, and commit with task reference validation. |
| [fw_handover](/docs/generated/tests-integration-fw_handover) | called_by | Integration tests for fw handover CLI — 4 tests covering help, file creation, sections, and output. |
| [fw_harvest](/docs/generated/tests-integration-fw_harvest) | called_by | Integration tests for fw harvest CLI. |
| [fw_healing](/docs/generated/tests-integration-fw_healing) | called_by | Integration tests for fw healing CLI — 6 tests covering help, patterns, diagnose, and suggest. |
| [fw_help](/docs/generated/tests-integration-fw_help) | called_by | Integration tests for fw help CLI. |
| [fw_hook](/docs/generated/tests-integration-fw_hook) | called_by | Integration tests for fw hook CLI. |
| [fw_inception](/docs/generated/tests-integration-fw_inception) | called_by | Integration tests for fw inception CLI — 5 tests covering help, status, start, workflow type, and status listing. |
| [fw_init](/docs/generated/tests-integration-fw_init) | called_by | Integration tests for fw init CLI. |
| [fw_learnings](/docs/generated/tests-integration-fw_learnings) | called_by | Integration tests for fw learnings CLI. |
| [fw_metrics](/docs/generated/tests-integration-fw_metrics) | called_by | Integration tests for fw metrics CLI — 4 tests covering dashboard, task counts, and predict. |
| [fw_notify](/docs/generated/tests-integration-fw_notify) | called_by | Integration tests for fw notify CLI — 10 tests covering help, status, enable, disable, toggle, test-disabled, invalid subcommand, setup. |
| [fw_onboarding](/docs/generated/tests-integration-fw_onboarding) | called_by | Integration tests for fw onboarding CLI. |
| [fw_patterns](/docs/generated/tests-integration-fw_patterns) | called_by | Integration tests for fw patterns CLI. |
| [fw_practices](/docs/generated/tests-integration-fw_practices) | called_by | Integration tests for fw practices CLI. |
| [fw_preflight](/docs/generated/tests-integration-fw_preflight) | called_by | Integration tests for fw preflight CLI. |
| [fw_promote](/docs/generated/tests-integration-fw_promote) | called_by | Integration tests for fw promote CLI. |
| [fw_resume](/docs/generated/tests-integration-fw_resume) | called_by | Integration tests for fw resume CLI — 5 tests covering help, quick, status, sync, and session file. |
| [fw_search](/docs/generated/tests-integration-fw_search) | called_by | Integration tests for fw search CLI. |
| [fw_self_test](/docs/generated/tests-integration-fw_self_test) | called_by | Integration tests for fw self-test (4 tests) |
| [fw_task](/docs/generated/tests-integration-fw_task) | called_by | Integration tests for fw task CLI — 7 tests covering create, placeholder rejection, ID increment, status update, update fail, help, list. |
| [fw_tier0](/docs/generated/tests-integration-fw_tier0) | called_by | Integration tests for fw tier0 CLI. |
| [fw_timeline](/docs/generated/tests-integration-fw_timeline) | called_by | Integration tests for fw timeline CLI. |
| [fw_traceability](/docs/generated/tests-integration-fw_traceability) | called_by | Integration tests for fw traceability CLI. |
| [fw_upstream](/docs/generated/tests-integration-fw_upstream) | called_by | Integration tests for fw upstream CLI. |
| [fw_validate_init](/docs/generated/tests-integration-fw_validate_init) | called_by | Integration tests for fw validate_init CLI. |
| [fw_vendor](/docs/generated/tests-integration-fw_vendor) | called_by | Integration tests for fw vendor CLI. |
| [fw_version](/docs/generated/tests-integration-fw_version) | called_by | Integration tests for fw version CLI. |
| [fw_work_on](/docs/generated/tests-integration-fw_work_on) | called_by | Integration tests for fw work-on CLI — 5 tests covering create+focus, resume, nonexistent ID, and help. |
| [release](/docs/generated/lib-release) | called_by_by | Release tagging + GitHub Release automation (T-1256). Cuts a new annotated tag based on latest v* (patch-bumping by default), pushes to all remotes, and creates a GitHub Release via gh CLI. Idempotent — no-op when HEAD == latest tag. Entrypoint for `fw release` subcommand and weekly cron job release-weekly. |
| [pl007-scanner](/docs/generated/agents-context-pl007-scanner) | called_by | PostToolUse hook scanning Bash output for bare-command leakage patterns (PL-007); injects reminder when agent risks relaying raw commands to user instead of using fw task review / termlink inject push-channels |
| [subagent-stop](/docs/generated/agents-context-subagent-stop) | called_by | SubagentStop hook — captures sub-agent returns. Reads sub-agent transcript from payload.transcript_path, appends telemetry line to .context/working/subagent-returns.jsonl, and if bytes > THRESHOLD posts the full message to fw bus as a blob so later turns can read via R-NNN without re-ingesting. Exits 0 always (capture-and-log, not interceptor). |
| [task_reid](/docs/generated/tests-unit-task_reid) | called_by | Regression test — fw task reid safely renames a task's ID (handles G-052 duplicate-ID repair). Verifies atomic rename of file + id: frontmatter update, and refusal when NEW-ID already exists. |
| [test_pretooluse_gates](/docs/generated/tests-governance-test_pretooluse_gates) | tests_by | TODO: describe what this component does |
| [test_task_lifecycle_gates](/docs/generated/tests-governance-test_task_lifecycle_gates) | tests_by | TODO: describe what this component does |
| [audit_blocks_review_and_decide](/docs/generated/tests-integration-audit_blocks_review_and_decide) | tests_by | TODO: describe what this component does |
| [cron_install](/docs/generated/tests-integration-cron_install) | tests_by | TODO: describe what this component does |
| [fw_approvals](/docs/generated/tests-integration-fw_approvals) | tests_by | Integration tests for fw approvals CLI. |
| [fw_assumption](/docs/generated/tests-integration-fw_assumption) | tests_by | Integration tests for fw assumption CLI. |
| [fw_audit](/docs/generated/tests-integration-fw_audit) | tests_by | Integration tests for fw audit CLI — 3 tests covering help, section run, and YAML output. |
| [fw_bus](/docs/generated/tests-integration-fw_bus) | tests_by | Integration tests for fw bus CLI. |
| [fw_config](/docs/generated/tests-integration-fw_config) | tests_by | Integration tests for fw config CLI (9 tests) |
| [fw_context](/docs/generated/tests-integration-fw_context) | tests_by | Integration tests for fw context CLI — 6 tests covering status, init, focus, and help. |
| [fw_costs](/docs/generated/tests-integration-fw_costs) | tests_by | Integration tests for fw costs CLI (4 tests) |
| [fw_cron](/docs/generated/tests-integration-fw_cron) | tests_by | Integration tests for fw cron CLI — 9 tests covering help, status, list, invalid subcommand, run/pause/resume without job-id. |
| [fw_decisions](/docs/generated/tests-integration-fw_decisions) | tests_by | Integration tests for fw decisions CLI. |
| [fw_doctor](/docs/generated/tests-integration-fw_doctor) | tests_by | Integration tests for fw doctor CLI — 4 tests covering health check, installation, config, and status markers. |
| [fw_fabric](/docs/generated/tests-integration-fw_fabric) | tests_by | Integration tests for fw fabric CLI — 10 tests covering help, overview, stats, deps, search, and get. |
| [fw_fix_learned](/docs/generated/tests-integration-fw_fix_learned) | tests_by | Integration tests for fw fix_learned CLI. |
| [fw_gaps](/docs/generated/tests-integration-fw_gaps) | tests_by | Integration tests for fw gaps CLI. |
| [fw_git](/docs/generated/tests-integration-fw_git) | tests_by | Integration tests for fw git CLI — 6 tests covering help, status, and commit with task reference validation. |
| [fw_handover](/docs/generated/tests-integration-fw_handover) | tests_by | Integration tests for fw handover CLI — 4 tests covering help, file creation, sections, and output. |
| [fw_harvest](/docs/generated/tests-integration-fw_harvest) | tests_by | Integration tests for fw harvest CLI. |
| [fw_healing](/docs/generated/tests-integration-fw_healing) | tests_by | Integration tests for fw healing CLI — 6 tests covering help, patterns, diagnose, and suggest. |
| [fw_help](/docs/generated/tests-integration-fw_help) | tests_by | Integration tests for fw help CLI. |
| [fw_hook](/docs/generated/tests-integration-fw_hook) | tests_by | Integration tests for fw hook CLI. |
| [fw_inception](/docs/generated/tests-integration-fw_inception) | tests_by | Integration tests for fw inception CLI — 5 tests covering help, status, start, workflow type, and status listing. |
| [fw_init](/docs/generated/tests-integration-fw_init) | tests_by | Integration tests for fw init CLI. |
| [fw_learnings](/docs/generated/tests-integration-fw_learnings) | tests_by | Integration tests for fw learnings CLI. |
| [fw_metrics](/docs/generated/tests-integration-fw_metrics) | tests_by | Integration tests for fw metrics CLI — 4 tests covering dashboard, task counts, and predict. |
| [fw_notify](/docs/generated/tests-integration-fw_notify) | tests_by | Integration tests for fw notify CLI — 10 tests covering help, status, enable, disable, toggle, test-disabled, invalid subcommand, setup. |
| [fw_onboarding](/docs/generated/tests-integration-fw_onboarding) | tests_by | Integration tests for fw onboarding CLI. |
| [fw_patterns](/docs/generated/tests-integration-fw_patterns) | tests_by | Integration tests for fw patterns CLI. |
| [fw_pickup](/docs/generated/tests-integration-fw_pickup) | tests_by | TODO: describe what this component does |
| [fw_practices](/docs/generated/tests-integration-fw_practices) | tests_by | Integration tests for fw practices CLI. |
| [fw_preflight](/docs/generated/tests-integration-fw_preflight) | tests_by | Integration tests for fw preflight CLI. |
| [fw_promote](/docs/generated/tests-integration-fw_promote) | tests_by | Integration tests for fw promote CLI. |
| [fw_resume](/docs/generated/tests-integration-fw_resume) | tests_by | Integration tests for fw resume CLI — 5 tests covering help, quick, status, sync, and session file. |
| [fw_search](/docs/generated/tests-integration-fw_search) | tests_by | Integration tests for fw search CLI. |
| [fw_self_test](/docs/generated/tests-integration-fw_self_test) | tests_by | Integration tests for fw self-test (4 tests) |
| [fw_task](/docs/generated/tests-integration-fw_task) | tests_by | Integration tests for fw task CLI — 7 tests covering create, placeholder rejection, ID increment, status update, update fail, help, list. |
| [fw_tier0](/docs/generated/tests-integration-fw_tier0) | tests_by | Integration tests for fw tier0 CLI. |
| [fw_timeline](/docs/generated/tests-integration-fw_timeline) | tests_by | Integration tests for fw timeline CLI. |
| [fw_traceability](/docs/generated/tests-integration-fw_traceability) | tests_by | Integration tests for fw traceability CLI. |
| [fw_upstream](/docs/generated/tests-integration-fw_upstream) | tests_by | Integration tests for fw upstream CLI. |
| [fw_validate_init](/docs/generated/tests-integration-fw_validate_init) | tests_by | Integration tests for fw validate_init CLI. |
| [fw_vendor](/docs/generated/tests-integration-fw_vendor) | tests_by | Integration tests for fw vendor CLI. |
| [fw_version](/docs/generated/tests-integration-fw_version) | tests_by | Integration tests for fw version CLI. |
| [fw_work_on](/docs/generated/tests-integration-fw_work_on) | tests_by | Integration tests for fw work-on CLI — 5 tests covering create+focus, resume, nonexistent ID, and help. |
| [add_learning_id_allocator](/docs/generated/tests-unit-add_learning_id_allocator) | tests_by | Regression test — add-learning ID allocator handles BOTH legacy indented format ('  id: L-XXX') and new dash-prefix format ('- id: L-XXX'). Pre-fix grep for '^- id: L-' missed 234 legacy entries, causing new IDs to collide with historical ones. |
| [audit_task_tools](/docs/generated/tests-unit-audit_task_tools) | tests_by | TODO: describe what this component does |
| [block_task_tools](/docs/generated/tests-unit-block_task_tools) | tests_by | TODO: describe what this component does |
| [context_safe_commands](/docs/generated/tests-unit-context_safe_commands) | tests_by | Unit tests for context safe_commands (35 tests) |
| [cron_flock_parity](/docs/generated/tests-unit-cron_flock_parity) | tests_by | TODO: describe what this component does |
| [doctor_duplicate_hook_detection](/docs/generated/tests-unit-doctor_duplicate_hook_detection) | tests_by | TODO: describe what this component does |
| [doctor_hook_exercise](/docs/generated/tests-unit-doctor_hook_exercise) | tests_by | TODO: describe what this component does |
| [escalation_scan_v05](/docs/generated/tests-unit-escalation_scan_v05) | tests_by | TODO: describe what this component does |
| [focus_drift_gate](/docs/generated/tests-unit-focus_drift_gate) | tests_by | TODO: describe what this component does |
| [hook_absolute_paths](/docs/generated/tests-unit-hook_absolute_paths) | tests_by | Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts. |
| [hook_enable_absolute_path](/docs/generated/tests-unit-hook_enable_absolute_path) | tests_by | TODO: describe what this component does |
| [hook_telemetry](/docs/generated/tests-unit-hook_telemetry) | tests_by | TODO: describe what this component does |
| [pickup_type_routing](/docs/generated/tests-unit-pickup_type_routing) | tests_by | TODO: describe what this component does |
| [session_start_hook_warning](/docs/generated/tests-unit-session_start_hook_warning) | tests_by | TODO: describe what this component does |
| [task_reid](/docs/generated/tests-unit-task_reid) | tests_by | Regression test — fw task reid safely renames a task's ID (handles G-052 duplicate-ID repair). Verifies atomic rename of file + id: frontmatter update, and refusal when NEW-ID already exists. |
| [test_boundary_hook_arguments](/docs/generated/tests-unit-test_boundary_hook_arguments) | tests_by | TODO: describe what this component does |
| [test_doctor_litellm_ollama](/docs/generated/tests-unit-test_doctor_litellm_ollama) | tests_by | TODO: describe what this component does |
| [test_doctor_scope_tags](/docs/generated/tests-unit-test_doctor_scope_tags) | tests_by | TODO: describe what this component does |
| [test_fw_gaps_closure_check](/docs/generated/tests-unit-test_fw_gaps_closure_check) | tests_by | TODO: describe what this component does |
| [test_orchestrator_status_synthetic_filter](/docs/generated/tests-unit-test_orchestrator_status_synthetic_filter) | tests_by | TODO: describe what this component does |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | tests_by | TODO: describe what this component does |
| [upgrade_dedupe_user_hooks](/docs/generated/tests-unit-upgrade_dedupe_user_hooks) | tests_by | TODO: describe what this component does |
| [upgrade_duplicate_hook_detection](/docs/generated/tests-unit-upgrade_duplicate_hook_detection) | tests_by | TODO: describe what this component does |
| [verify_acs](/docs/generated/tests-unit-verify_acs) | tests_by | Unit tests for verify acs (6 tests) |
| [doctor-hook-exercise](/docs/generated/lib-doctor-hook-exercise) | called_by | TODO: describe what this component does |
| [hook-threshold](/docs/generated/lib-hook-threshold) | called_by | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | called_by | TODO: describe what this component does |
| [test_api_fabric_source](/docs/generated/tests-playwright-test_api_fabric_source) | called_by | Playwright tests for fabric file APIs (T-1025). |
| [test_file_viewer](/docs/generated/tests-playwright-test_file_viewer) | called_by | Playwright tests for /file/<path> viewer endpoint (T-1025). |
| [test_arc_system](/docs/generated/tests-unit-test_arc_system) | called_by | Unit tests for fw arc CLI (T-1661 Phase 1 MVP) — pins create/focus/list/show/tag/close/migrate verbs, anchor handling, and handover injection of ## Current Arc section. |
| [test_audit_arc_completion](/docs/generated/tests-unit-test_audit_arc_completion) | called_by | Unit tests for fw audit --section arc-completion (T-1656, G-062 mechanism #2) — pins WARN at >=80% completion threshold for in-progress arcs, PASS below threshold, and skip behaviour for closed/empty registries. |
| [test_enrich_bats_parser](/docs/generated/tests-unit-test_enrich_bats_parser) | called_by | TODO: describe what this component does |
| [test_fabric_drift_absolute_paths](/docs/generated/tests-unit-test_fabric_drift_absolute_paths) | called_by | TODO: describe what this component does |
| [test_fabric_drift_performance](/docs/generated/tests-unit-test_fabric_drift_performance) | called_by | TODO: describe what this component does |
| [test_orchestrator_outcome_dedup](/docs/generated/tests-unit-test_orchestrator_outcome_dedup) | called_by | TODO: describe what this component does |
| [test_orchestrator_status_outcomes](/docs/generated/tests-unit-test_orchestrator_status_outcomes) | called_by | TODO: describe what this component does |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [cron](/docs/generated/web-blueprints-cron) | called_by | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [classifier](/docs/generated/lib-reviewer-classifier) | called_by | TODO: describe what this component does |
| [drift](/docs/generated/lib-reviewer-drift) | called_by | TODO: describe what this component does |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | called_by | TODO: describe what this component does |
| [test_cron_generate_shape](/docs/generated/tests-unit-test_cron_generate_shape) | tests_by | TODO: describe what this component does |
| [test_orchestrator_status_terminal_events](/docs/generated/tests-unit-test_orchestrator_status_terminal_events) | called_by | TODO: describe what this component does |
| [peer](/docs/generated/lib-peer) | called_by | TODO: describe what this component does |
| [workflow_lint](/docs/generated/lib-workflow_lint) | called_by | TODO: describe what this component does |
| [inception_defer_park](/docs/generated/tests-unit-inception_defer_park) | tests_by | TODO: describe what this component does |
| [test_doctor_consumer_version_ahead](/docs/generated/tests-unit-test_doctor_consumer_version_ahead) | tests_by | TODO: describe what this component does |
| [test_gaps_missing_title_defaults](/docs/generated/tests-unit-test_gaps_missing_title_defaults) | tests_by | TODO: describe what this component does |
| [test_peer_subscribe](/docs/generated/tests-unit-test_peer_subscribe) | called_by | TODO: describe what this component does |
| [test_workflow_schema_pause_lint](/docs/generated/tests-unit-test_workflow_schema_pause_lint) | called_by | TODO: describe what this component does |
| [upgrade_fresh_machine_simulation](/docs/generated/tests-unit-upgrade_fresh_machine_simulation) | tests_by | TODO: describe what this component does |
| [test_orchestrator_routes](/docs/generated/tests-unit-test_orchestrator_routes) | called_by | Pin the `fw orchestrator routes` CLI surface (T-1789): mirror of web /orchestrator's route-cache view. Covers missing-cache, empty model_stats, invalid JSON, candidate sorting, --json shape parity with web _route_cache_learned, last_used surfacing. |
| [audit_ctl013_skip_nested_audit](/docs/generated/tests-unit-audit_ctl013_skip_nested_audit) | tests_by | TODO: describe what this component does |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | tests_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | TODO: describe what this component does |
| [check-settings-edit](/docs/generated/agents-context-check-settings-edit) | called_by | PostToolUse hook (Write\|Edit matcher) that fires an advisory L-398 reminder when .claude/settings.json is written/edited. Reminds the agent to add `bin/fw enforcement baseline` to the active task's Verification block so the canonical hash refreshes at task-close. Strictly advisory (exit 0).  Origin: T-1886 RCA Candidate B — paired with T-1887 Candidate A (template hint). The enforcement-baseline-drift class accumulated for multiple sessions across T-1849/T-1730/T-1731 before T-1886 cleaned up. |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | called_by | TODO: describe what this component does |
| [heredoc_guard](/docs/generated/lib-heredoc_guard) | called_by | TODO: describe what this component does |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | called_by | TODO: describe what this component does |
| [arc_create_start_flag](/docs/generated/tests-unit-arc_create_start_flag) | tests_by | TODO: describe what this component does |
| [reviewer_human_ac_mechanical_signal](/docs/generated/tests-unit-reviewer_human_ac_mechanical_signal) | tests_by | TODO: describe what this component does |
| [safe_commands_env_prefix](/docs/generated/tests-unit-safe_commands_env_prefix) | tests_by | TODO: describe what this component does |
| [task_archive_eligible](/docs/generated/tests-unit-task_archive_eligible) | tests_by | TODO: describe what this component does |
| [template_reviewer_prefix_example](/docs/generated/tests-unit-template_reviewer_prefix_example) | tests_by | TODO: describe what this component does |
| [test_audit_cron_registry_generated_drift](/docs/generated/tests-unit-test_audit_cron_registry_generated_drift) | tests_by | TODO: describe what this component does |
| [test_bin_fw_no_heredoc_cmd_sub](/docs/generated/tests-unit-test_bin_fw_no_heredoc_cmd_sub) | tests_by | TODO: describe what this component does |
| [test_cron_registry_generated_drift](/docs/generated/tests-unit-test_cron_registry_generated_drift) | tests_by | TODO: describe what this component does |
| [test_heredoc_cmd_sub_guard](/docs/generated/tests-unit-test_heredoc_cmd_sub_guard) | tests_by | TODO: describe what this component does |
| [test_reviewer_prose_mismatch](/docs/generated/tests-unit-test_reviewer_prose_mismatch) | tests_by | TODO: describe what this component does |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [bvp](/docs/generated/web-blueprints-bvp) | called_by | TODO: describe what this component does |
| [dispatch_cli](/docs/generated/lib-reviewer-dispatch_cli) | called_by | TODO: describe what this component does |

## Documentation

- [Deep Dive: Tier 0 Protection](docs/articles/deep-dives/02-tier0-protection.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-874: Sync vendored bin/fw with T-873 approvals fix
- T-889: fw config set/get — read and write persistent settings in .framework.yaml
- T-890: Add fw config to help output and CLAUDE.md quick reference
- T-898: Fix _derive_version — use framework git repo, not cwd
- T-969: Playwright test infrastructure — tests/playwright/ + fw test playwright + conftest.py (T-968 Phase 1)

---
*Auto-generated from Component Fabric. Card: `bin-fw.yaml`*
*Last verified: 2026-02-20*
