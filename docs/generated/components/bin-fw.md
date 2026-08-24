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

## Dependencies (90)

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
| [manifest](/docs/generated/agents-mcp-manifest) | calls | TODO: describe what this component does |
| [resolver-shim](/docs/generated/lib-resolver-sh) | calls | Thin shell shim that routes `fw resolver` invocations to lib/resolver.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic. |
| [outcome-shim](/docs/generated/lib-outcome-sh) | calls | Thin shell shim that routes `fw outcome` invocations to lib/outcome.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic. |
| [pause](/docs/generated/lib-pause) | calls | TODO: describe what this component does |
| [pending](/docs/generated/lib-pending) | calls | TODO: describe what this component does |
| [consumer-recover](/docs/generated/lib-consumer-recover) | calls | TODO: describe what this component does |
| [prompt](/docs/generated/lib-prompt) | calls | fw prompt — reusable agent-prompt register. Subcommands: create, list, show, copy (with {{var}} substitutions). Prompt files are markdown with YAML frontmatter stored under prompts/. Single source of truth for cross-machine / cross-agent reusable prompts (fleet upgrade+test+fix, audit dispatch, onboarding, etc.). |
| [hook-telemetry](/docs/generated/lib-hook-telemetry) | calls | TODO: describe what this component does |
| [verify-acs](/docs/generated/lib-verify-acs) | calls | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [release](/docs/generated/lib-release) | calls | Release tagging + GitHub Release automation (T-1256). Cuts a new annotated tag based on latest v* (patch-bumping by default), pushes to all remotes, and creates a GitHub Release via gh CLI. Idempotent — no-op when HEAD == latest tag. Entrypoint for `fw release` subcommand and weekly cron job release-weekly. |
| [mirror](/docs/generated/lib-mirror) | calls | TODO: describe what this component does |
| [config-file](/docs/generated/lib-config-file) | calls | Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments |
| [version](/docs/generated/lib-version) | calls | fw version subcommand: show framework version, git tag, commit count, paths. Supports --check for update detection. |
| [worktree](/docs/generated/lib-worktree) | calls | TODO: describe what this component does |
| [branch-hygiene](/docs/generated/lib-branch-hygiene) | calls | TODO: describe what this component does |
| [arc](/docs/generated/lib-arc) | calls | TODO: describe what this component does |
| [bvp](/docs/generated/lib-bvp) | calls | TODO: describe what this component does |
| [hook-enable](/docs/generated/bin-hook-enable) | calls | Register framework hooks in .claude/settings.json idempotently — adds { type "command", command ".agentic-framework/bin/fw hook <name>" } entries under specified event/matcher pair. Built under T-1189 to repair T-977 false-complete (G-015). |
| [api-usage](/docs/generated/agents-metrics-api-usage) | calls | TODO: describe what this component does |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [govd_policy](/docs/generated/lib-govd_policy) | calls | TODO: describe what this component does |
| [write_set](/docs/generated/lib-write_set) | calls | TODO: describe what this component does |
| [integrate](/docs/generated/lib-integrate) | calls | TODO: describe what this component does |
| [orchestrator-graph](/docs/generated/agents-orchestrator-orchestrator-graph) | calls | TODO: describe what this component does |
| [designer](/docs/generated/agents-designer-designer) | calls | TODO: describe what this component does |
| [bpmn](/docs/generated/agents-bpmn-bpmn) | calls | TODO: describe what this component does |
| [corpus_lint](/docs/generated/tools-corpus_lint) | calls | TODO: describe what this component does |
| [corpus_explain](/docs/generated/tools-corpus_explain) | calls | TODO: describe what this component does |
| [corpus_spec](/docs/generated/tools-corpus_spec) | calls | TODO: describe what this component does |
| [version-relation](/docs/generated/lib-version-relation) | calls | TODO: describe what this component does |
| [rail-identity](/docs/generated/lib-rail-identity) | calls | TODO: describe what this component does |
| [hook-parity](/docs/generated/lib-hook-parity) | calls | TODO: describe what this component does |
| [doctor-upstream](/docs/generated/lib-doctor-upstream) | calls | TODO: describe what this component does |
| [root-pollution](/docs/generated/lib-root-pollution) | calls | TODO: describe what this component does |
| [git-identity](/docs/generated/lib-git-identity) | calls | TODO: describe what this component does |
| [index-health](/docs/generated/lib-index-health) | calls | TODO: describe what this component does |
| [recall-usage](/docs/generated/lib-recall-usage) | calls | TODO: describe what this component does |
| [watchtower-staleness](/docs/generated/lib-watchtower-staleness) | calls | TODO: describe what this component does |
| [worktree-identity](/docs/generated/lib-worktree-identity) | calls | TODO: describe what this component does |
| [cron-registry](/docs/generated/lib-cron-registry) | calls | TODO: describe what this component does |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [resolver](/docs/generated/lib-resolver) | calls | TODO: describe what this component does |
| [message_router](/docs/generated/lib-message_router) | calls | TODO: describe what this component does |
| [verify_queue](/docs/generated/lib-verify_queue) | calls | TODO: describe what this component does |

## Used By (392)

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
| [ux-review](/docs/generated/agents-ux-review-ux-review) | called_by | TODO: describe what this component does |
| [test_audit_completable_not_completed](/docs/generated/tests-unit-test_audit_completable_not_completed) | tests_by | TODO: describe what this component does |
| [test_audit_revert_chain](/docs/generated/tests-unit-test_audit_revert_chain) | tests_by | TODO: describe what this component does |
| [test_work_on_completed_task](/docs/generated/tests-unit-test_work_on_completed_task) | tests_by | TODO: describe what this component does |
| [review_link_validator](/docs/generated/lib-review_link_validator) | called_by | TODO: describe what this component does |
| [review_link_blocking_gate](/docs/generated/tests-unit-review_link_blocking_gate) | tests_by | TODO: describe what this component does |
| [test_review_link_validator](/docs/generated/tests-unit-test_review_link_validator) | called_by | TODO: describe what this component does |
| [test_audit_retire_when](/docs/generated/tests-unit-test_audit_retire_when) | tests_by | TODO: describe what this component does |
| [g066_readiness](/docs/generated/tests-unit-g066_readiness) | tests_by | TODO: describe what this component does |
| [gaps_close](/docs/generated/tests-unit-gaps_close) | tests_by | TODO: describe what this component does |
| [g066-readiness](/docs/generated/tools-g066-readiness) | called_by | TODO: describe what this component does |
| [test_consumer_recover](/docs/generated/tests-unit-test_consumer_recover) | tests_by | TODO: describe what this component does |
| [framework_mcp_server](/docs/generated/agents-mcp-framework_mcp_server) | called_by | TODO: describe what this component does |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | tests_by | TODO: describe what this component does |
| [test_mcp_wire_fragment](/docs/generated/tests-unit-test_mcp_wire_fragment) | tests_by | TODO: describe what this component does |
| [test_arc010_hm_a_demo_evidence](/docs/generated/tests-integration-test_arc010_hm_a_demo_evidence) | tests_by | TODO: describe what this component does |
| [g065_readiness](/docs/generated/tests-unit-g065_readiness) | tests_by | TODO: describe what this component does |
| [g065-readiness](/docs/generated/tools-g065-readiness) | called_by | TODO: describe what this component does |
| [t2318_retrofit_injector_append_missing](/docs/generated/tests-unit-t2318_retrofit_injector_append_missing) | tests_by | TODO: describe what this component does |
| [t2331_driver_propose](/docs/generated/tests-unit-t2331_driver_propose) | tests_by | TODO: describe what this component does |
| [t2332_bvp_propose_queue](/docs/generated/tests-unit-t2332_bvp_propose_queue) | tests_by | TODO: describe what this component does |
| [test_orchestrator_graph](/docs/generated/tests-unit-test_orchestrator_graph) | tests_by | TODO: describe what this component does |
| [test_write_set](/docs/generated/tests-unit-test_write_set) | tests_by | TODO: describe what this component does |
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | called_by | TODO: describe what this component does |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | called_by | TODO: describe what this component does |
| [t2391_project_root_inherited_stale](/docs/generated/tests-unit-t2391_project_root_inherited_stale) | tests_by | TODO: describe what this component does |
| [test_inject_next_directive](/docs/generated/tests-unit-test_inject_next_directive) | called_by | TODO: describe what this component does |
| [manifest](/docs/generated/agents-mcp-manifest) | called_by | TODO: describe what this component does |
| [govd_policy](/docs/generated/lib-govd_policy) | called_by | TODO: describe what this component does |
| [fw_derive_version_symlink](/docs/generated/tests-unit-fw_derive_version_symlink) | tests_by | TODO: describe what this component does |
| [t2446_project_root_cwd_consistency](/docs/generated/tests-unit-t2446_project_root_cwd_consistency) | tests_by | TODO: describe what this component does |
| [t2452_doctor_quick](/docs/generated/tests-unit-t2452_doctor_quick) | tests_by | TODO: describe what this component does |
| [t2461_doctor_mcp_consumer_path](/docs/generated/tests-unit-t2461_doctor_mcp_consumer_path) | tests_by | TODO: describe what this component does |
| [watchtower_health_verdict_identity](/docs/generated/tests-unit-watchtower_health_verdict_identity) | tests_by | TODO: describe what this component does |
| [integrate](/docs/generated/lib-integrate) | called_by | TODO: describe what this component does |
| [check_active_task_cwd_resolution](/docs/generated/tests-unit-check_active_task_cwd_resolution) | tests_by | TODO: describe what this component does |
| [t2465_reanchor_from_cwd](/docs/generated/tests-unit-t2465_reanchor_from_cwd) | tests_by | TODO: describe what this component does |
| [hook_paths](/docs/generated/lib-hook_paths) | called_by | TODO: describe what this component does |
| [self-audit](/docs/generated/agents-audit-self-audit) | called_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [single-host-parallel-demo](/docs/generated/agents-dispatch-single-host-parallel-demo) | called_by | TODO: describe what this component does |
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [init](/docs/generated/lib-init) | called_by | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [setup](/docs/generated/lib-setup) | called_by | fw setup - Guided onboarding wizard for new projects |
| [termlink_worker](/docs/generated/lib-termlink_worker) | called_by | TODO: describe what this component does |
| [update](/docs/generated/lib-update) | called_by | fw update subcommand: CLI wrapper for framework self-update. Pulls latest, runs upgrade, reports changes. |
| [upgrade](/docs/generated/lib-upgrade) | called_by | fw upgrade - Sync framework improvements to a consumer project |
| [version](/docs/generated/lib-version) | called_by | fw version subcommand: show framework version, git tag, commit count, paths. Supports --check for update detection. |
| [test_pretooluse_gates](/docs/generated/tests-governance-test_pretooluse_gates) | called_by | TODO: describe what this component does |
| [test_task_lifecycle_gates](/docs/generated/tests-governance-test_task_lifecycle_gates) | called_by | TODO: describe what this component does |
| [audit_blocks_review_and_decide](/docs/generated/tests-integration-audit_blocks_review_and_decide) | called_by | TODO: describe what this component does |
| [cron_install](/docs/generated/tests-integration-cron_install) | called_by | TODO: describe what this component does |
| [fw_pickup](/docs/generated/tests-integration-fw_pickup) | called_by | TODO: describe what this component does |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | called_by | TODO: describe what this component does |
| [add_learning_id_allocator](/docs/generated/tests-unit-add_learning_id_allocator) | called_by | Regression test — add-learning ID allocator handles BOTH legacy indented format ('  id: L-XXX') and new dash-prefix format ('- id: L-XXX'). Pre-fix grep for '^- id: L-' missed 234 legacy entries, causing new IDs to collide with historical ones. |
| [arc_create_start_flag](/docs/generated/tests-unit-arc_create_start_flag) | called_by | TODO: describe what this component does |
| [audit_task_tools](/docs/generated/tests-unit-audit_task_tools) | called_by | TODO: describe what this component does |
| [cron_flock_parity](/docs/generated/tests-unit-cron_flock_parity) | called_by | TODO: describe what this component does |
| [doctor_duplicate_hook_detection](/docs/generated/tests-unit-doctor_duplicate_hook_detection) | called_by | TODO: describe what this component does |
| [doctor_hook_exercise](/docs/generated/tests-unit-doctor_hook_exercise) | called_by | TODO: describe what this component does |
| [fw_derive_version_symlink](/docs/generated/tests-unit-fw_derive_version_symlink) | called_by | TODO: describe what this component does |
| [gaps_close](/docs/generated/tests-unit-gaps_close) | called_by | TODO: describe what this component does |
| [hook_absolute_paths](/docs/generated/tests-unit-hook_absolute_paths) | called_by | Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts. |
| [hook_telemetry](/docs/generated/tests-unit-hook_telemetry) | called_by | TODO: describe what this component does |
| [inception_defer_park](/docs/generated/tests-unit-inception_defer_park) | called_by | TODO: describe what this component does |
| [reviewer_human_ac_mechanical_signal](/docs/generated/tests-unit-reviewer_human_ac_mechanical_signal) | called_by | TODO: describe what this component does |
| [t2318_retrofit_injector_append_missing](/docs/generated/tests-unit-t2318_retrofit_injector_append_missing) | called_by | TODO: describe what this component does |
| [t2331_driver_propose](/docs/generated/tests-unit-t2331_driver_propose) | called_by | TODO: describe what this component does |
| [t2452_doctor_quick](/docs/generated/tests-unit-t2452_doctor_quick) | called_by | TODO: describe what this component does |
| [t2461_doctor_mcp_consumer_path](/docs/generated/tests-unit-t2461_doctor_mcp_consumer_path) | called_by | TODO: describe what this component does |
| [task_archive_eligible](/docs/generated/tests-unit-task_archive_eligible) | called_by | TODO: describe what this component does |
| [test_audit_completable_not_completed](/docs/generated/tests-unit-test_audit_completable_not_completed) | called_by | TODO: describe what this component does |
| [test_audit_cron_registry_generated_drift](/docs/generated/tests-unit-test_audit_cron_registry_generated_drift) | called_by | TODO: describe what this component does |
| [test_audit_retire_when](/docs/generated/tests-unit-test_audit_retire_when) | called_by | TODO: describe what this component does |
| [test_audit_revert_chain](/docs/generated/tests-unit-test_audit_revert_chain) | called_by | TODO: describe what this component does |
| [test_bin_fw_no_heredoc_cmd_sub](/docs/generated/tests-unit-test_bin_fw_no_heredoc_cmd_sub) | called_by | TODO: describe what this component does |
| [test_cron_generate_shape](/docs/generated/tests-unit-test_cron_generate_shape) | called_by | TODO: describe what this component does |
| [test_cron_registry_generated_drift](/docs/generated/tests-unit-test_cron_registry_generated_drift) | called_by | TODO: describe what this component does |
| [test_doctor_litellm_ollama](/docs/generated/tests-unit-test_doctor_litellm_ollama) | called_by | TODO: describe what this component does |
| [test_doctor_scope_tags](/docs/generated/tests-unit-test_doctor_scope_tags) | called_by | TODO: describe what this component does |
| [test_mcp_wire_fragment](/docs/generated/tests-unit-test_mcp_wire_fragment) | called_by | TODO: describe what this component does |
| [test_orchestrator_graph](/docs/generated/tests-unit-test_orchestrator_graph) | called_by | TODO: describe what this component does |
| [test_orchestrator_status_synthetic_filter](/docs/generated/tests-unit-test_orchestrator_status_synthetic_filter) | called_by | TODO: describe what this component does |
| [test_reviewer_prose_mismatch](/docs/generated/tests-unit-test_reviewer_prose_mismatch) | called_by | TODO: describe what this component does |
| [test_work_on_completed_task](/docs/generated/tests-unit-test_work_on_completed_task) | called_by | TODO: describe what this component does |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | called_by | TODO: describe what this component does |
| [test_write_set](/docs/generated/tests-unit-test_write_set) | called_by | TODO: describe what this component does |
| [verify_acs](/docs/generated/tests-unit-verify_acs) | called_by | Unit tests for verify acs (6 tests) |
| [watchtower_health_verdict_identity](/docs/generated/tests-unit-watchtower_health_verdict_identity) | called_by | TODO: describe what this component does |
| [designer](/docs/generated/agents-designer-designer) | called_by | TODO: describe what this component does |
| [doctor_designer_pin_drift](/docs/generated/tests-unit-doctor_designer_pin_drift) | tests_by | TODO: describe what this component does |
| [bpmn_promote](/docs/generated/tools-bpmn_promote) | called_by | TODO: describe what this component does |
| [designer_registry](/docs/generated/web-designer_registry) | called_by | TODO: describe what this component does |
| [designer_sync_from_tag](/docs/generated/tests-unit-designer_sync_from_tag) | tests_by | TODO: describe what this component does |
| [corpus_spec](/docs/generated/tools-corpus_spec) | called_by | TODO: describe what this component does |
| [designer](/docs/generated/web-blueprints-designer) | called_by | TODO: describe what this component does |
| [check-active-task](/docs/generated/agents-context-check-active-task) | called_by | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [cmd_classify](/docs/generated/lib-cmd_classify) | called_by | TODO: describe what this component does |
| [hook_parity](/docs/generated/lib-hook_parity) | called_by | TODO: describe what this component does |
| [arc015_capture](/docs/generated/tests-demo-arc015_capture) | called_by | TODO: describe what this component does |
| [fw_onboarding_greenfield](/docs/generated/tests-integration-fw_onboarding_greenfield) | tests_by | TODO: describe what this component does |
| [readme_five_minute_by_hand](/docs/generated/tests-integration-readme_five_minute_by_hand) | tests_by | TODO: describe what this component does |
| [t2922_greenfield_first_inception](/docs/generated/tests-integration-t2922_greenfield_first_inception) | called_by | TODO: describe what this component does |
| [t2922_greenfield_first_inception](/docs/generated/tests-integration-t2922_greenfield_first_inception) | tests_by | TODO: describe what this component does |
| [bvp-help-parity](/docs/generated/tests-lint-bvp-help-parity) | tests_by | TODO: describe what this component does |
| [no-backticks-in-inline-python](/docs/generated/tests-lint-no-backticks-in-inline-python) | tests_by | TODO: describe what this component does |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |
| [no-orphaned-test-dirs](/docs/generated/tests-lint-no-orphaned-test-dirs) | tests_by | TODO: describe what this component does |
| [capture_verbs_nulltask](/docs/generated/tests-unit-capture_verbs_nulltask) | tests_by | TODO: describe what this component does |
| [claude_fw_router](/docs/generated/tests-unit-claude_fw_router) | tests_by | Pins bin/claude-fw-router's resolution: routes to a vendored consumer's own claude-fw, walks up from a nested subdirectory, prefers the framework repo's own bin/claude-fw over its self-vendored copy, falls back to plain claude when no project/sibling is found (announced on stderr), and skips an incomplete vendor mid-init. |
| [doctor_hook_counters](/docs/generated/tests-unit-doctor_hook_counters) | called_by | TODO: describe what this component does |
| [doctor_hook_counters](/docs/generated/tests-unit-doctor_hook_counters) | tests_by | TODO: describe what this component does |
| [drift_gate_not_shadowed_by_safelist](/docs/generated/tests-unit-drift_gate_not_shadowed_by_safelist) | tests_by | TODO: describe what this component does |
| [episodic_yaml_timeline_escape](/docs/generated/tests-unit-episodic_yaml_timeline_escape) | called_by | TODO: describe what this component does |
| [episodic_yaml_timeline_escape](/docs/generated/tests-unit-episodic_yaml_timeline_escape) | tests_by | TODO: describe what this component does |
| [fw_help_watchtower_discoverable](/docs/generated/tests-unit-fw_help_watchtower_discoverable) | tests_by | TODO: describe what this component does |
| [fw_init_atomic](/docs/generated/tests-unit-fw_init_atomic) | tests_by | TODO: describe what this component does |
| [fw_vendor_completeness](/docs/generated/tests-unit-fw_vendor_completeness) | tests_by | TODO: describe what this component does |
| [git_identity_check](/docs/generated/tests-unit-git_identity_check) | called_by | TODO: describe what this component does |
| [git_identity_check](/docs/generated/tests-unit-git_identity_check) | tests_by | TODO: describe what this component does |
| [handover_digest](/docs/generated/tests-unit-handover_digest) | tests_by | TODO: describe what this component does |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | called_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | tests_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |
| [init_git_identity_blocker](/docs/generated/tests-unit-init_git_identity_blocker) | tests_by | TODO: describe what this component does |
| [init_project_shape_detection](/docs/generated/tests-unit-init_project_shape_detection) | called_by | TODO: describe what this component does |
| [init_project_shape_detection](/docs/generated/tests-unit-init_project_shape_detection) | tests_by | TODO: describe what this component does |
| [install_verify_no_cwd_init](/docs/generated/tests-unit-install_verify_no_cwd_init) | tests_by | Regression test (T-2799): runs the real install.sh end to end in an isolated HOME + empty cwd and asserts the cwd is untouched afterward. Guards against the installer's own verify() step silently auto-initialising a project wherever the user happened to invoke curl\|bash from. |
| [learning_application_birth](/docs/generated/tests-unit-learning_application_birth) | tests_by | TODO: describe what this component does |
| [lib_upgrade](/docs/generated/tests-unit-lib_upgrade) | tests_by | TODO: describe what this component does |
| [rail_identity_guard](/docs/generated/tests-unit-rail_identity_guard) | tests_by | TODO: describe what this component does |
| [rail_mcp_label_guard](/docs/generated/tests-unit-rail_mcp_label_guard) | tests_by | TODO: describe what this component does |
| [reviewer_verdict_replacement_escape](/docs/generated/tests-unit-reviewer_verdict_replacement_escape) | called_by | TODO: describe what this component does |
| [reviewer_verdict_replacement_escape](/docs/generated/tests-unit-reviewer_verdict_replacement_escape) | tests_by | TODO: describe what this component does |
| [router_no_global_fallback](/docs/generated/tests-unit-router_no_global_fallback) | tests_by | Pins bin/fw-router's three post-T-2854 properties together (a fix that regressed any one would still pass a narrower test): refuses with no project found and no global consulted, still routes a vendored consumer project correctly, and still finds the project root walking up from a nested subdirectory. Also covers a residue global on the host not being routed to, and the framework repo itself still routing to its own bin/fw. |
| [safe_commands_chain](/docs/generated/tests-unit-safe_commands_chain) | tests_by | TODO: describe what this component does |
| [self_vendor_parity](/docs/generated/tests-unit-self_vendor_parity) | tests_by | TODO: describe what this component does |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | tests_by | TODO: describe what this component does |
| [t1719_ask_routing](/docs/generated/tests-unit-t1719_ask_routing) | tests_by | TODO: describe what this component does |
| [t2759_upgrade_target_dir_shadowing](/docs/generated/tests-unit-t2759_upgrade_target_dir_shadowing) | tests_by | TODO: describe what this component does |
| [t2762_upgrade_foreign_source_sha](/docs/generated/tests-unit-t2762_upgrade_foreign_source_sha) | tests_by | TODO: describe what this component does |
| [t2862_greenfield_first_inception_e2e](/docs/generated/tests-unit-t2862_greenfield_first_inception_e2e) | called_by | TODO: describe what this component does |
| [t2862_greenfield_first_inception_e2e](/docs/generated/tests-unit-t2862_greenfield_first_inception_e2e) | tests_by | TODO: describe what this component does |
| [t2912_upgrade_hook_regen_convergence](/docs/generated/tests-unit-t2912_upgrade_hook_regen_convergence) | tests_by | End-to-end (real fw init'd consumer, env -i) proof that fw upgrade's hook-regeneration step reports its own verified effect instead of the pre-write trigger — a regen that cannot supply a detected-missing hook must report FAILED/PARTIAL, not UPDATED, on every run, and must not write a fresh .bak for a no-op. |
| [t2919_budget_gate_command_classify](/docs/generated/tests-unit-t2919_budget_gate_command_classify) | tests_by | TODO: describe what this component does |
| [t2920_boundary_heredoc_strip_order](/docs/generated/tests-unit-t2920_boundary_heredoc_strip_order) | tests_by | TODO: describe what this component does |
| [t2936_bootstrap_quoted_redirect](/docs/generated/tests-unit-t2936_bootstrap_quoted_redirect) | tests_by | TODO: describe what this component does |
| [t2945_default_template_recommendation](/docs/generated/tests-unit-t2945_default_template_recommendation) | called_by | TODO: describe what this component does |
| [t2945_default_template_recommendation](/docs/generated/tests-unit-t2945_default_template_recommendation) | tests_by | TODO: describe what this component does |
| [t2948_review_human_ac_comment_aware](/docs/generated/tests-unit-t2948_review_human_ac_comment_aware) | called_by | TODO: describe what this component does |
| [t2948_review_human_ac_comment_aware](/docs/generated/tests-unit-t2948_review_human_ac_comment_aware) | tests_by | TODO: describe what this component does |
| [t2988_grouped_command_classification](/docs/generated/tests-unit-t2988_grouped_command_classification) | tests_by | TODO: describe what this component does |
| [t2990_root_pollution](/docs/generated/tests-unit-t2990_root_pollution) | called_by | TODO: describe what this component does |
| [t2990_root_pollution](/docs/generated/tests-unit-t2990_root_pollution) | tests_by | TODO: describe what this component does |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | tests_by | TODO: describe what this component does |
| [t3046_message_router](/docs/generated/tests-unit-t3046_message_router) | called_by | TODO: describe what this component does |
| [t3046_message_router](/docs/generated/tests-unit-t3046_message_router) | tests_by | TODO: describe what this component does |
| [t3048_bats_leg_guard](/docs/generated/tests-unit-t3048_bats_leg_guard) | tests_by | TODO: describe what this component does |
| [t3050_b005_block_message](/docs/generated/tests-unit-t3050_b005_block_message) | tests_by | TODO: describe what this component does |
| [t3051_exec_bit_gates](/docs/generated/tests-unit-t3051_exec_bit_gates) | tests_by | TODO: describe what this component does |
| [t3073_c001_recommendation_bearing_inceptions](/docs/generated/tests-unit-t3073_c001_recommendation_bearing_inceptions) | called_by | TODO: describe what this component does |
| [t3073_c001_recommendation_bearing_inceptions](/docs/generated/tests-unit-t3073_c001_recommendation_bearing_inceptions) | tests_by | TODO: describe what this component does |
| [t3111_worktree_reexec](/docs/generated/tests-unit-t3111_worktree_reexec) | tests_by | TODO: describe what this component does |
| [t3112_worktree_hook_parity](/docs/generated/tests-unit-t3112_worktree_hook_parity) | tests_by | TODO: describe what this component does |
| [t3113_upgrade_worktree_advisory](/docs/generated/tests-unit-t3113_upgrade_worktree_advisory) | tests_by | TODO: describe what this component does |
| [test_fw_json_stdout_purity](/docs/generated/tests-unit-test_fw_json_stdout_purity) | called_by | TODO: describe what this component does |
| [test_index_doctor_rail](/docs/generated/tests-unit-test_index_doctor_rail) | tests_by | TODO: describe what this component does |
| [test_mirror_sync](/docs/generated/tests-unit-test_mirror_sync) | called_by | TODO: describe what this component does |
| [test_mirror_sync](/docs/generated/tests-unit-test_mirror_sync) | tests_by | TODO: describe what this component does |
| [test_url_credentials](/docs/generated/tests-unit-test_url_credentials) | called_by | TODO: describe what this component does |
| [test_url_credentials](/docs/generated/tests-unit-test_url_credentials) | tests_by | TODO: describe what this component does |
| [tier0_card_provenance](/docs/generated/tests-unit-tier0_card_provenance) | called_by | TODO: describe what this component does |
| [tier0_card_provenance](/docs/generated/tests-unit-tier0_card_provenance) | tests_by | TODO: describe what this component does |
| [tier0_grant_ttl](/docs/generated/tests-unit-tier0_grant_ttl) | called_by | TODO: describe what this component does |
| [tier0_grant_ttl](/docs/generated/tests-unit-tier0_grant_ttl) | tests_by | TODO: describe what this component does |
| [upgrade_fresh_machine_simulation](/docs/generated/tests-unit-upgrade_fresh_machine_simulation) | called_by | TODO: describe what this component does |
| [validate_init_hook_path_expansion](/docs/generated/tests-unit-validate_init_hook_path_expansion) | tests_by | TODO: describe what this component does |
| [version_relation](/docs/generated/tests-unit-version_relation) | tests_by | TODO: describe what this component does |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | triggers_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |

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
