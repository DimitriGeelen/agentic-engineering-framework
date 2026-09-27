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

## Dependencies (104)

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
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | calls | agents/git/lib/large-file-scan.sh — Large-file gate for the pre-commit hook (T-1845). |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | calls | T-1944 — Cron registry → generated dry-run helper. |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | calls | T-1946 — Worker-kinds parity check helper. |
| [manifest](/docs/generated/agents-mcp-manifest) | calls | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [resolver-shim](/docs/generated/lib-resolver-sh) | calls | Thin shell shim that routes `fw resolver` invocations to lib/resolver.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic. |
| [outcome-shim](/docs/generated/lib-outcome-sh) | calls | Thin shell shim that routes `fw outcome` invocations to lib/outcome.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic. |
| [pause](/docs/generated/lib-pause) | calls | Thin shim — routes `fw pause` to lib/pause_cli.py. Origin: T-1809 (dispatch-safety slice 5). |
| [pending](/docs/generated/lib-pending) | calls | fw pending - Pending-updates registry (T-1268 B1) Append-only ledger of cross-project / cross-machine actions an agent could not complete in-session. Resolved entries are flagged, not deleted. |
| [consumer-recover](/docs/generated/lib-consumer-recover) | calls | fw consumer-recover - one-command recovery for legacy vendored consumers |
| [prompt](/docs/generated/lib-prompt) | calls | fw prompt — reusable agent-prompt register. Subcommands: create, list, show, copy (with {{var}} substitutions). Prompt files are markdown with YAML frontmatter stored under prompts/. Single source of truth for cross-machine / cross-agent reusable prompts (fleet upgrade+test+fix, audit dispatch, onboarding, etc.). |
| [hook-telemetry](/docs/generated/lib-hook-telemetry) | calls | lib/hook-telemetry.sh — per-hook fire / failure counters (T-1628, B-2 of T-1626). |
| [verify-acs](/docs/generated/lib-verify-acs) | calls | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [release](/docs/generated/lib-release) | calls | Release tagging + GitHub Release automation (T-1256). Cuts a new annotated tag based on latest v* (patch-bumping by default), pushes to all remotes, and creates a GitHub Release via gh CLI. Idempotent — no-op when HEAD == latest tag. Entrypoint for `fw release` subcommand and weekly cron job release-weekly. |
| [mirror](/docs/generated/lib-mirror) | calls | lib/mirror.sh — Mirror cascade auto-recovery (T-1594, T-1591 Prevention #3). |
| [config-file](/docs/generated/lib-config-file) | calls | Reads and writes persistent project-level settings in .framework.yaml with round-trip YAML editing that preserves comments |
| [version](/docs/generated/lib-version) | calls | fw version subcommand: show framework version, git tag, commit count, paths. Supports --check for update detection. |
| [worktree](/docs/generated/lib-worktree) | calls | lib/worktree.sh — fw worktree topology observability. |
| [branch-hygiene](/docs/generated/lib-branch-hygiene) | calls | lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO) |
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [bvp](/docs/generated/lib-bvp) | calls | lib/bvp.sh — Business Value Points (BVP) read-only CLI |
| [hook-enable](/docs/generated/bin-hook-enable) | calls | Register framework hooks in .claude/settings.json idempotently — adds { type "command", command ".agentic-framework/bin/fw hook <name>" } entries under specified event/matcher pair. Built under T-1189 to repair T-977 false-complete (G-015). |
| [api-usage](/docs/generated/agents-metrics-api-usage) | calls | fw metrics api-usage: tallies per-method TermLink RPC counts from rpc-audit.jsonl and reports the legacy-primitive share used as the T-1166 retirement entry gate (T-1304/T-1308). |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [govd_policy](/docs/generated/lib-govd_policy) | calls | govd_policy — proxy-policy emit / install / drift (arc-013 / T-2432, design §4c). |
| [write_set](/docs/generated/lib-write_set) | calls | Disjoint write-set policy validator (T-2337, arc-011 M1 §3). |
| [integrate](/docs/generated/lib-integrate) | calls | fw integrate — Layer 2 serialized-integration preflight (T-2399, T-2397 slice 1). |
| [orchestrator-graph](/docs/generated/agents-orchestrator-orchestrator-graph) | calls | Orchestrator-graph (arc-011 M1, T-2339): builds a write-set-overlap and dependency graph over active tasks and emits (task_id, parallel\|serial) dispatch decisions; consumes lib.write_set.compare and yield-point.sh. |
| [designer](/docs/generated/agents-designer-designer) | calls | fw designer: vendors and serves a pinned Workflow Designer release build via the Watchtower /designer blueprint (832-Workflow-designer is source of truth; T-2521). |
| [bpmn](/docs/generated/agents-bpmn-bpmn) | calls | fw bpmn agent: BPMN process diagram to AEF task compiler (Child-2 forward bridge); thin wrapper routing compile/promote to tools/bpmn_to_tasks.py and tools/bpmn_promote.py. |
| [corpus_lint](/docs/generated/tools-corpus_lint) | calls | corpus_lint — per-map + cross-map lint for the designer corpus (T-2604). |
| [corpus_explain](/docs/generated/tools-corpus_explain) | calls | T-2622: agent retrieval seam — corpus maps readable without a browser. |
| [corpus_spec](/docs/generated/tools-corpus_spec) | calls | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |
| [version-relation](/docs/generated/lib-version-relation) | calls | T-2713 — one truthful answer to "is this consumer ahead or behind?". |
| [rail-identity](/docs/generated/lib-rail-identity) | calls | rail-identity.sh — project-scoped signing identity for outbound rail posts (T-2904) |
| [hook-parity](/docs/generated/lib-hook-parity) | calls | lib/hook-parity.sh — the enforcement-baseline comparison predicate (T-3112, R7 leg 3) |
| [doctor-upstream](/docs/generated/lib-doctor-upstream) | calls | lib/doctor-upstream.sh — T-2843 |
| [root-pollution](/docs/generated/lib-root-pollution) | calls | T-2990 — root-level pollution detector. |
| [git-identity](/docs/generated/lib-git-identity) | calls | lib/git-identity.sh — one answer to "can this machine commit?" (T-2883) |
| [index-health](/docs/generated/lib-index-health) | calls | Vector-index freshness verdict — T-3013 (T-3005 slice 4). |
| [recall-usage](/docs/generated/lib-recall-usage) | calls | Recall-usage verdict — T-3019 (T-3005 slice 6a, the "Used" signal). |
| [watchtower-staleness](/docs/generated/lib-watchtower-staleness) | calls | T-2938: does the RUNNING Watchtower actually run the code on disk? |
| [worktree-identity](/docs/generated/lib-worktree-identity) | calls | lib/worktree-identity.sh — "is this checkout a replica?" (T-3111, R7) |
| [cron-registry](/docs/generated/lib-cron-registry) | calls | lib/cron-registry.sh — T-2844 |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [resolver](/docs/generated/lib-resolver) | calls | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [message_router](/docs/generated/lib-message_router) | calls | T-3046 — static ``msg_type`` router for recovered hub messages (slice 1 of T-3044). |
| [verify_queue](/docs/generated/lib-verify_queue) | calls | T-2765: re-run stored ## Verification for the human review queue. |
| [vendor-visibility](/docs/generated/lib-vendor-visibility) | calls | T-3144: after vendoring, assert the target's git can SEE what we just wrote. |
| [continuous-mode](/docs/generated/lib-continuous-mode) | calls | Continuous-run counters (T-3169, arc-012 S3). |
| [push-state](/docs/generated/lib-push-state) | calls | lib/push-state.sh — T-3063 (leg 2 of T-3062) |
| [hook_portability](/docs/generated/lib-hook_portability) | calls | Single source of truth for "is this hook command host-portable?" (T-2709). |
| [audit_timing](/docs/generated/lib-audit_timing) | calls | T-3127: classify the persisted full-audit timing record against a warn fraction. |
| [bats-silent-skip-lint](/docs/generated/tools-bats-silent-skip-lint) | calls | Reports bats skips that the P-011 verification idiom cannot see. Static mode flags two guard shapes with no legitimate reading (unconditional, and guards fixed for a deployment rather than probing an optional dependency); --tap mode reports the skips a real run actually fired. Wired into fw test lint. |
| [consolidate](/docs/generated/agents-context-consolidate) | calls | Memory consolidation engine for the Agentic Engineering Framework. |
| [memory-recall](/docs/generated/agents-context-lib-memory-recall) | calls | Memory recall — query project knowledge for relevant prior learnings, patterns, and decisions. |
| [smoke_test](/docs/generated/web-smoke_test) | calls | Watchtower smoke test — runtime route discovery + content validation. |
| [cron-orphans](/docs/generated/lib-cron-orphans) | calls | lib/cron-orphans.sh — detect deployed cron entries whose declared PROJECT_ROOT is gone (T-3281). |
| [exec-bit-drift](/docs/generated/lib-exec-bit-drift) | calls | lib/exec-bit-drift.sh — T-3317 (OBS-336): exec-bit drift detector. |
| [fabric_doctor_facts](/docs/generated/lib-fabric_doctor_facts) | calls | Flatten `underpopulated.py --json` into one tab-separated line for `fw doctor`. |
| [govd_sandbox](/docs/generated/lib-govd_sandbox) | calls | govd_sandbox — OS sandbox profile emit / install / drift (arc-013 / T-2433, design §7a). |
| [aef_provision_log](/docs/generated/lib-aef_provision_log) | calls | T-3313 (arc-020 S7): durable JSONL audit trail for auto-provision events. |

## Used By (434)

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
| [test_pretooluse_gates](/docs/generated/tests-governance-test_pretooluse_gates) | tests_by | T-1606 (T-1601 GO follow-up): red-team harness covering all 7 PreToolUse gates. |
| [test_task_lifecycle_gates](/docs/generated/tests-governance-test_task_lifecycle_gates) | tests_by | T-1608 (T-1601 GO follow-up, Phase 3): red-team harness for task-lifecycle gates. |
| [audit_blocks_review_and_decide](/docs/generated/tests-integration-audit_blocks_review_and_decide) | tests_by | Integration tests for the placeholder audit chokepoint (T-1111/T-1113). |
| [cron_install](/docs/generated/tests-integration-cron_install) | tests_by | Integration tests for fw cron install + fw doctor cron drift check (T-1112/T-1114) |
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
| [fw_pickup](/docs/generated/tests-integration-fw_pickup) | tests_by | Integration tests for fw pickup subcommand |
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
| [audit_task_tools](/docs/generated/tests-unit-audit_task_tools) | tests_by | Unit tests for agents/context/audit-task-tools.sh (T-1118) |
| [block_task_tools](/docs/generated/tests-unit-block_task_tools) | tests_by | Unit tests for agents/context/block-task-tools.sh (T-1117) |
| [context_safe_commands](/docs/generated/tests-unit-context_safe_commands) | tests_by | Unit tests for context safe_commands (35 tests) |
| [cron_flock_parity](/docs/generated/tests-unit-cron_flock_parity) | tests_by | T-1558 — Regression: fw doctor must warn when the cron registry declares more flock-wrapped jobs than the deployed crontab carries (T-1556 prevention #5). |
| [doctor_duplicate_hook_detection](/docs/generated/tests-unit-doctor_duplicate_hook_detection) | tests_by | T-1480 — `fw doctor` surfaces the same duplicate-hook scan as T-1479's `fw upgrade` check. Read-only diagnostic so users see the overlap on every health check, not only when upgrading. |
| [doctor_hook_exercise](/docs/generated/tests-unit-doctor_hook_exercise) | tests_by | T-1629 (B-3a of T-1626) — `fw doctor` actively exercises every configured Claude Code hook from /tmp (foreign CWD that mimics agent cd-drift) and reports any whose path doesn't resolve. |
| [escalation_scan_v05](/docs/generated/tests-unit-escalation_scan_v05) | tests_by | T-1727 — escalation-scan v0.5 unit coverage. |
| [focus_drift_gate](/docs/generated/tests-unit-focus_drift_gate) | tests_by | T-1730: Focus-target drift gate — unit tests |
| [hook_absolute_paths](/docs/generated/tests-unit-hook_absolute_paths) | tests_by | Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts. |
| [hook_enable_absolute_path](/docs/generated/tests-unit-hook_enable_absolute_path) | tests_by | T-1504: fw hook-enable must emit absolute hook commands. |
| [hook_telemetry](/docs/generated/tests-unit-hook_telemetry) | tests_by | T-1628 (B-2 of T-1626) — per-hook fire / failure counters. |
| [pickup_type_routing](/docs/generated/tests-unit-pickup_type_routing) | tests_by | Unit tests for T-1465 — pickup envelope type → task workflow_type routing. Constrained Option A (T-1455 GO): bug-report → build feature-proposal → inception |
| [session_start_hook_warning](/docs/generated/tests-unit-session_start_hook_warning) | tests_by | T-1630 (B-4 of T-1626) — SessionStart resume hook warns on broken hooks. |
| [task_reid](/docs/generated/tests-unit-task_reid) | tests_by | Regression test — fw task reid safely renames a task's ID (handles G-052 duplicate-ID repair). Verifies atomic rename of file + id: frontmatter update, and refusal when NEW-ID already exists. |
| [test_boundary_hook_arguments](/docs/generated/tests-unit-test_boundary_hook_arguments) | tests_by | T-1702 / G-065 — Pattern 4 (read-side outside-path arguments). |
| [test_doctor_litellm_ollama](/docs/generated/tests-unit-test_doctor_litellm_ollama) | tests_by | T-1700 — fw doctor: litellm-proxy + ollama reachability checks. |
| [test_doctor_scope_tags](/docs/generated/tests-unit-test_doctor_scope_tags) | tests_by | T-1707 / G-065 Stream 2 — fw doctor scope tagging. |
| [test_fw_gaps_closure_check](/docs/generated/tests-unit-test_fw_gaps_closure_check) | tests_by | T-1752 — `fw gaps` honours optional closure_check_command field. |
| [test_orchestrator_status_synthetic_filter](/docs/generated/tests-unit-test_orchestrator_status_synthetic_filter) | tests_by | T-1712 — fw orchestrator status: filter T-stress-* synthetic rows from enrichment metric, headline reports real dispatches only. |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | tests_by | T-1708 — worker_kind drift regression test. |
| [upgrade_dedupe_user_hooks](/docs/generated/tests-unit-upgrade_dedupe_user_hooks) | tests_by | T-1481 — `fw upgrade --dedupe-user-hooks` opt-in remediation. Removes framework hooks from $HOME/.claude/settings.json that duplicate the project-level config; always backs up first. |
| [upgrade_duplicate_hook_detection](/docs/generated/tests-unit-upgrade_duplicate_hook_detection) | tests_by | T-1479 — fw upgrade detects when framework hooks are registered at both user-level (~/.claude/settings.json) and project-level (.claude/settings.json), warning the consumer (does NOT auto-remove user state). |
| [verify_acs](/docs/generated/tests-unit-verify_acs) | tests_by | Unit tests for verify acs (6 tests) |
| [doctor-hook-exercise](/docs/generated/lib-doctor-hook-exercise) | called_by | T-1629 (B-3a of T-1626) & T-070 — `fw doctor` active hook probe. |
| [hook-threshold](/docs/generated/lib-hook-threshold) | called_by | T-1631 (B-3b of T-1626) — hook-failure threshold rule. |
| [resolver](/docs/generated/lib-resolver) | called_by | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [test_api_fabric_source](/docs/generated/tests-playwright-test_api_fabric_source) | called_by | Playwright tests for fabric file APIs (T-1025). |
| [test_file_viewer](/docs/generated/tests-playwright-test_file_viewer) | called_by | Playwright tests for /file/<path> viewer endpoint (T-1025). |
| [test_arc_system](/docs/generated/tests-unit-test_arc_system) | called_by | Unit tests for fw arc CLI (T-1661 Phase 1 MVP) — pins create/focus/list/show/tag/close/migrate verbs, anchor handling, and handover injection of ## Current Arc section. |
| [test_audit_arc_completion](/docs/generated/tests-unit-test_audit_arc_completion) | called_by | Unit tests for fw audit --section arc-completion (T-1656, G-062 mechanism #2) — pins WARN at >=80% completion threshold for in-progress arcs, PASS below threshold, and skip behaviour for closed/empty registries. |
| [test_enrich_bats_parser](/docs/generated/tests-unit-test_enrich_bats_parser) | called_by | T-1754 — Regression tests for fabric enrich's .bats parser. |
| [test_fabric_drift_absolute_paths](/docs/generated/tests-unit-test_fabric_drift_absolute_paths) | called_by | T-1673 — fabric drift orphan check honours absolute location paths. |
| [test_fabric_drift_performance](/docs/generated/tests-unit-test_fabric_drift_performance) | called_by | T-1674 — fabric drift completes in O(n) on the live repo. |
| [test_orchestrator_outcome_dedup](/docs/generated/tests-unit-test_orchestrator_outcome_dedup) | called_by | T-1757 — Regression test for orchestrator status outcome dedup. |
| [test_orchestrator_status_outcomes](/docs/generated/tests-unit-test_orchestrator_status_outcomes) | called_by | T-1749 — Regression tests for `fw orchestrator status --outcomes`. |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [cron](/docs/generated/web-blueprints-cron) | called_by | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [classifier](/docs/generated/lib-reviewer-classifier) | called_by | Verification-line classifier (T-1483 v1.5). |
| [drift](/docs/generated/lib-reviewer-drift) | called_by | Pass A drift detection (T-1483 v1.5). |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | called_by | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [test_cron_generate_shape](/docs/generated/tests-unit-test_cron_generate_shape) | tests_by | T-1769 — Pin the shape of `fw cron generate` output. Origin: T-1720 found that the generator silently produced unrunnable lines (no cwd for `python3 -m lib.X` invocations; stderr swallowed by `2>/dev/null`). |
| [test_orchestrator_status_terminal_events](/docs/generated/tests-unit-test_orchestrator_status_terminal_events) | called_by | T-1779 — Regression tests for `fw orchestrator status` terminal_event breakdown. |
| [peer](/docs/generated/lib-peer) | called_by | v2 peer-consult subscriber + responder spawn-bridge. |
| [workflow_lint](/docs/generated/lib-workflow_lint) | called_by | Workflow schema linter for `.context/project/workflows/*.yaml`. |
| [inception_defer_park](/docs/generated/tests-unit-inception_defer_park) | tests_by | T-1865 — DEFER inception decisions park the task instead of leaving it stuck at status=started-work / horizon=now. Two surfaces: 1. do_inception_sweep recovers existing DEFER limbo tasks 2. |
| [test_doctor_consumer_version_ahead](/docs/generated/tests-unit-test_doctor_consumer_version_ahead) | tests_by | T-1838 — fw doctor asymmetric version-skew detection. |
| [test_gaps_missing_title_defaults](/docs/generated/tests-unit-test_gaps_missing_title_defaults) | tests_by | T-1840 — fw gaps defensive .get() for missing 'title' / 'id' fields. |
| [test_peer_subscribe](/docs/generated/tests-unit-test_peer_subscribe) | called_by | Unit tests for lib/peer.py — v2 peer-consult subscriber + responder spawn. |
| [test_workflow_schema_pause_lint](/docs/generated/tests-unit-test_workflow_schema_pause_lint) | called_by | Tests for the workflow schema linter (lib/workflow_lint.py). |
| [upgrade_fresh_machine_simulation](/docs/generated/tests-unit-upgrade_fresh_machine_simulation) | tests_by | T-1635: fresh-machine simulation guard for fw upgrade. |
| [test_orchestrator_routes](/docs/generated/tests-unit-test_orchestrator_routes) | called_by | Pin the `fw orchestrator routes` CLI surface (T-1789): mirror of web /orchestrator's route-cache view. Covers missing-cache, empty model_stats, invalid JSON, candidate sorting, --json shape parity with web _route_cache_learned, last_used surfacing. |
| [audit_ctl013_skip_nested_audit](/docs/generated/tests-unit-audit_ctl013_skip_nested_audit) | tests_by | T-1870 / L-391: CTL-013 must skip verification lines that invoke `bin/fw audit` (or `fw audit`) — running them inside the audit lock always fails (lock held by the outer audit) and produces false-positive WARN. |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | tests_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | T-1766 — render-surface Human-AC gate (P-013). |
| [check-settings-edit](/docs/generated/agents-context-check-settings-edit) | called_by | PostToolUse hook (Write\|Edit matcher) that fires an advisory L-398 reminder when .claude/settings.json is written/edited. Reminds the agent to add `bin/fw enforcement baseline` to the active task's Verification block so the canonical hash refreshes at task-close. Strictly advisory (exit 0).  Origin: T-1886 RCA Candidate B — paired with T-1887 Candidate A (template hint). The enforcement-baseline-drift class accumulated for multiple sessions across T-1849/T-1730/T-1731 before T-1886 cleaned up. |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | called_by | T-1944 — Cron registry → generated dry-run helper. |
| [heredoc_guard](/docs/generated/lib-heredoc_guard) | called_by | T-1945 — Heredoc-in-cmd-substitution detector helper. |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | called_by | T-1946 — Worker-kinds parity check helper. |
| [arc_create_start_flag](/docs/generated/tests-unit-arc_create_start_flag) | tests_by | T-1852 counter-proposal: `fw arc create --start` one-step convenience. Default behaviour writes `status: draft`; --start writes `status: in-progress`. |
| [reviewer_human_ac_mechanical_signal](/docs/generated/tests-unit-reviewer_human_ac_mechanical_signal) | tests_by | T-1896 (T-1878 B): integration coverage for the new reviewer pattern `human-ac-mechanical-signal` — runs `bin/fw reviewer` end-to-end against synthetic task files, asserts the pattern fires (or doesn't) per design. |
| [safe_commands_env_prefix](/docs/generated/tests-unit-safe_commands_env_prefix) | tests_by | T-1908: pin env-var prefix stripping in is_bash_safe_command. |
| [task_archive_eligible](/docs/generated/tests-unit-task_archive_eligible) | tests_by | T-1903 / L-403: `fw task archive-eligible` sweep — detect tasks stuck in .tasks/active/ with status: work-completed + all ACs ticked (the post- re-class trap) and move them to .tasks/completed/. |
| [template_reviewer_prefix_example](/docs/generated/tests-unit-template_reviewer_prefix_example) | tests_by | T-1895 (T-1878 A): template + CLAUDE.md surface [REVIEWER] as a peer of [REVIEW] at AC-author time, not just as a post-hoc conversion rule. |
| [test_audit_cron_registry_generated_drift](/docs/generated/tests-unit-test_audit_cron_registry_generated_drift) | tests_by | T-1943 — Pin fw audit registry → generated cron drift FAIL (audit-side sibling to T-1942's doctor-side WARN). |
| [test_bin_fw_no_heredoc_cmd_sub](/docs/generated/tests-unit-test_bin_fw_no_heredoc_cmd_sub) | tests_by | T-1946 — Structural lint: bin/fw must contain ZERO heredoc-in-cmd-substitution patterns. Third layer of L-332 / L-408 prevention (after the learnings and the T-1945 PreToolUse edit-time WARN). |
| [test_cron_registry_generated_drift](/docs/generated/tests-unit-test_cron_registry_generated_drift) | tests_by | T-1942 — Pin fw doctor registry → generated drift detection. |
| [test_heredoc_cmd_sub_guard](/docs/generated/tests-unit-test_heredoc_cmd_sub_guard) | tests_by | T-1945 — PreToolUse heredoc-in-cmd-sub guard hook tests. |
| [test_reviewer_prose_mismatch](/docs/generated/tests-unit-test_reviewer_prose_mismatch) | tests_by | T-1947 (L-409): integration coverage for `reviewer-prose-mismatch` — the inverse of `human-ac-mechanical-signal`. |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [bvp](/docs/generated/web-blueprints-bvp) | called_by | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [dispatch_cli](/docs/generated/lib-reviewer-dispatch_cli) | called_by | Dispatch mode for the reviewer (T-1951, G-066 prong 3). |
| [ux-review](/docs/generated/agents-ux-review-ux-review) | called_by | UX-review capture engine (T-2002): drives Watchtower render surfaces in a headless browser across every appearance preset and produces visual review artifacts for human review. |
| [test_audit_completable_not_completed](/docs/generated/tests-unit-test_audit_completable_not_completed) | tests_by | T-2055 — Pin CTL-029, the active-side mirror of CTL-028. Catches tasks where Agent ACs are 100% ticked but status remains started-work/issues (shipped-but-unclosed — agent finished the work and forgot to run `--status work-completed`). |
| [test_audit_revert_chain](/docs/generated/tests-unit-test_audit_revert_chain) | tests_by | T-2058 — Pin audit.sh revert-chain suppression. |
| [test_work_on_completed_task](/docs/generated/tests-unit-test_work_on_completed_task) | tests_by | T-2036 — Pin `fw work-on T-XXX` behaviour against the P-002 "completed before commit" deadlock. |
| [review_link_validator](/docs/generated/lib-review_link_validator) | called_by | Validate Watchtower review/inception handoff links at the moment of handoff. |
| [review_link_blocking_gate](/docs/generated/tests-unit-review_link_blocking_gate) | tests_by | T-2139 V1 keystone — emit_review blocking gate on review-link homework. |
| [test_review_link_validator](/docs/generated/tests-unit-test_review_link_validator) | called_by | T-2050 — unit tests for lib/review_link_validator.py. |
| [test_audit_retire_when](/docs/generated/tests-unit-test_audit_retire_when) | tests_by | T-2169 — Pin audit.sh retire_when advisory. Origin: value-drivers.yaml v3 free drivers (F-RECALL, F-ORCH) carry retire_when: text describing when the driver stops being relevant. Without an advisory rail nothing nudges the operator. |
| [g066_readiness](/docs/generated/tests-unit-g066_readiness) | tests_by | T-2198: G-066 closure-readiness gauge — covers READY against live repo, NOT_READY when each wiring leg is absent, and --strict exit-code semantics. |
| [gaps_close](/docs/generated/tests-unit-gaps_close) | tests_by | T-2185 — `fw gaps close <id>` flips gauge-READY gaps to status:closed. |
| [g066-readiness](/docs/generated/tools-g066-readiness) | called_by | G-066 closure-readiness gauge — wiring-presence check. |
| [test_consumer_recover](/docs/generated/tests-unit-test_consumer_recover) | tests_by | T-2235 — fw consumer-recover wrapper (authorised under T-2233 GO). |
| [framework_mcp_server](/docs/generated/agents-mcp-framework_mcp_server) | called_by | Framework MCP server (arc-010 Slice 2, T-2265): reads policy/capability-overlay/tool-set.yaml at startup, emits framework-mcp-manifest.json, and registers an MCP tool per read_only and agent_authority entry. |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | tests_by | T-2265 (arc-010 Slice 2): integration tests for framework MCP server. |
| [test_mcp_wire_fragment](/docs/generated/tests-unit-test_mcp_wire_fragment) | tests_by | T-2272 (arc-010 Slice 2.5): framework-mcp .mcp.json fragment helper. |
| [test_arc010_hm_a_demo_evidence](/docs/generated/tests-integration-test_arc010_hm_a_demo_evidence) | tests_by | T-2268 (arc-010 Slice 3 HM-A): integration contract test for the demo evidence README + traceability shape. |
| [g065_readiness](/docs/generated/tests-unit-g065_readiness) | tests_by | T-2299: G-065 closure-readiness gauge — covers READY against live repo, NOT_READY when each wiring leg is absent, and --strict exit-code semantics. |
| [g065-readiness](/docs/generated/tools-g065-readiness) | called_by | G-065 closure-readiness gauge — wiring-presence check. |
| [t2318_retrofit_injector_append_missing](/docs/generated/tests-unit-t2318_retrofit_injector_append_missing) | tests_by | T-2318: retrofit injector must handle missing-Recommendation-section case (pre-T-1716 backlog inceptions). Pins detector↔corrector symmetry per RCA. |
| [t2331_driver_propose](/docs/generated/tests-unit-t2331_driver_propose) | tests_by | T-2331 (T-2330 S1): `fw bvp driver --propose` non-Sovereign verb. |
| [t2332_bvp_propose_queue](/docs/generated/tests-unit-t2332_bvp_propose_queue) | tests_by | T-2332 (T-2330 S2): Flask helpers + template render for the driver propose-queue. |
| [test_orchestrator_graph](/docs/generated/tests-unit-test_orchestrator_graph) | tests_by | T-2339 (arc-011 M1 §1) — orchestrator-graph dispatch decision. |
| [test_write_set](/docs/generated/tests-unit-test_write_set) | tests_by | T-2337 (arc-011 M1 §3) — disjoint write-set validator. |
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | called_by | T-2364/T-2365 (T-2158 S2+S3) — next-directive injector for post-compact resume. |
| [estimator](/docs/generated/agents-termlink-bvp-estimator-estimator) | called_by | BVP estimator worker implementation (T-1922, v1-heuristic, deterministic): applies a rubric-based classifier to task bodies and writes bvp_scores_proposed under M3 v2-delta semantics. |
| [t2391_project_root_inherited_stale](/docs/generated/tests-unit-t2391_project_root_inherited_stale) | tests_by | T-2391: bin/fw validates an INHERITED (non-empty) PROJECT_ROOT and re-resolves when stale, instead of using it verbatim. |
| [test_inject_next_directive](/docs/generated/tests-unit-test_inject_next_directive) | called_by | T-2364/T-2365 (T-2158 S2+S3) — unit tests for inject-next-directive.py. |
| [manifest](/docs/generated/agents-mcp-manifest) | called_by | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [govd_policy](/docs/generated/lib-govd_policy) | called_by | govd_policy — proxy-policy emit / install / drift (arc-013 / T-2432, design §4c). |
| [fw_derive_version_symlink](/docs/generated/tests-unit-fw_derive_version_symlink) | tests_by | T-2450 / F3: bin/fw _derive_version must resolve symlinks before deriving fw_dir. |
| [t2446_project_root_cwd_consistency](/docs/generated/tests-unit-t2446_project_root_cwd_consistency) | tests_by | T-2446: bin/fw trusts CLAUDE_PROJECT_DIR ONLY when the cwd is not genuinely inside a *different* real project. |
| [t2452_doctor_quick](/docs/generated/tests-unit-t2452_doctor_quick) | tests_by | T-2452 / F6 (T-2441 dogfood) — `fw doctor --quick` project-only fast mode. |
| [t2461_doctor_mcp_consumer_path](/docs/generated/tests-unit-t2461_doctor_mcp_consumer_path) | tests_by | T-2461: fw doctor's framework-MCP-manifest check resolved its asset paths against $PROJECT_ROOT, which is the CONSUMER root in a vendored install — the manifest actually lives under $FRAMEWORK_ROOT (.agentic-framework/agents/mcp/). |
| [watchtower_health_verdict_identity](/docs/generated/tests-unit-watchtower_health_verdict_identity) | tests_by | T-2445 (F9, T-2442 batch): Watchtower HEALTH-VERDICT call-sites must gate on the identity-verified resolver, never on a default-port `/health` curl. |
| [integrate](/docs/generated/lib-integrate) | called_by | fw integrate — Layer 2 serialized-integration preflight (T-2399, T-2397 slice 1). |
| [check_active_task_cwd_resolution](/docs/generated/tests-unit-check_active_task_cwd_resolution) | tests_by | T-2463 (OBS-080) — the check-active-task gate must resolve PROJECT_ROOT from the per-call `cwd` Claude Code passes on stdin, NOT from the hook's process cwd. |
| [t2465_reanchor_from_cwd](/docs/generated/tests-unit-t2465_reanchor_from_cwd) | tests_by | T-2465 — unit tests for lib/paths.sh:fw_reanchor_from_cwd (+ the hook-stdin wrapper). |
| [hook_paths](/docs/generated/lib-hook_paths) | called_by | Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd. |
| [self-audit](/docs/generated/agents-audit-self-audit) | called_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [single-host-parallel-demo](/docs/generated/agents-dispatch-single-host-parallel-demo) | called_by | arc-011 M1 single-host parallel dispatch demo: composes write-set disjointness, orchestrator-graph decisions and yield-point polling into one end-to-end headline-mechanic demo (T-2341). |
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [init](/docs/generated/lib-init) | called_by | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [setup](/docs/generated/lib-setup) | called_by | fw setup - Guided onboarding wizard for new projects |
| [termlink_worker](/docs/generated/lib-termlink_worker) | called_by | TermLinkWorker — subprocess wrapper for `fw termlink dispatch`. |
| [update](/docs/generated/lib-update) | called_by | fw update subcommand: CLI wrapper for framework self-update. Pulls latest, runs upgrade, reports changes. |
| [upgrade](/docs/generated/lib-upgrade) | called_by | fw upgrade - Sync framework improvements to a consumer project |
| [version](/docs/generated/lib-version) | called_by | fw version subcommand: show framework version, git tag, commit count, paths. Supports --check for update detection. |
| [test_pretooluse_gates](/docs/generated/tests-governance-test_pretooluse_gates) | called_by | T-1606 (T-1601 GO follow-up): red-team harness covering all 7 PreToolUse gates. |
| [test_task_lifecycle_gates](/docs/generated/tests-governance-test_task_lifecycle_gates) | called_by | T-1608 (T-1601 GO follow-up, Phase 3): red-team harness for task-lifecycle gates. |
| [audit_blocks_review_and_decide](/docs/generated/tests-integration-audit_blocks_review_and_decide) | called_by | Integration tests for the placeholder audit chokepoint (T-1111/T-1113). |
| [cron_install](/docs/generated/tests-integration-cron_install) | called_by | Integration tests for fw cron install + fw doctor cron drift check (T-1112/T-1114) |
| [fw_pickup](/docs/generated/tests-integration-fw_pickup) | called_by | Integration tests for fw pickup subcommand |
| [test_framework_mcp_server](/docs/generated/tests-integration-test_framework_mcp_server) | called_by | T-2265 (arc-010 Slice 2): integration tests for framework MCP server. |
| [add_learning_id_allocator](/docs/generated/tests-unit-add_learning_id_allocator) | called_by | Regression test — add-learning ID allocator handles BOTH legacy indented format ('  id: L-XXX') and new dash-prefix format ('- id: L-XXX'). Pre-fix grep for '^- id: L-' missed 234 legacy entries, causing new IDs to collide with historical ones. |
| [arc_create_start_flag](/docs/generated/tests-unit-arc_create_start_flag) | called_by | T-1852 counter-proposal: `fw arc create --start` one-step convenience. Default behaviour writes `status: draft`; --start writes `status: in-progress`. |
| [audit_task_tools](/docs/generated/tests-unit-audit_task_tools) | called_by | Unit tests for agents/context/audit-task-tools.sh (T-1118) |
| [cron_flock_parity](/docs/generated/tests-unit-cron_flock_parity) | called_by | T-1558 — Regression: fw doctor must warn when the cron registry declares more flock-wrapped jobs than the deployed crontab carries (T-1556 prevention #5). |
| [doctor_duplicate_hook_detection](/docs/generated/tests-unit-doctor_duplicate_hook_detection) | called_by | T-1480 — `fw doctor` surfaces the same duplicate-hook scan as T-1479's `fw upgrade` check. Read-only diagnostic so users see the overlap on every health check, not only when upgrading. |
| [doctor_hook_exercise](/docs/generated/tests-unit-doctor_hook_exercise) | called_by | T-1629 (B-3a of T-1626) — `fw doctor` actively exercises every configured Claude Code hook from /tmp (foreign CWD that mimics agent cd-drift) and reports any whose path doesn't resolve. |
| [fw_derive_version_symlink](/docs/generated/tests-unit-fw_derive_version_symlink) | called_by | T-2450 / F3: bin/fw _derive_version must resolve symlinks before deriving fw_dir. |
| [gaps_close](/docs/generated/tests-unit-gaps_close) | called_by | T-2185 — `fw gaps close <id>` flips gauge-READY gaps to status:closed. |
| [hook_absolute_paths](/docs/generated/tests-unit-hook_absolute_paths) | called_by | Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts. |
| [hook_telemetry](/docs/generated/tests-unit-hook_telemetry) | called_by | T-1628 (B-2 of T-1626) — per-hook fire / failure counters. |
| [inception_defer_park](/docs/generated/tests-unit-inception_defer_park) | called_by | T-1865 — DEFER inception decisions park the task instead of leaving it stuck at status=started-work / horizon=now. Two surfaces: 1. do_inception_sweep recovers existing DEFER limbo tasks 2. |
| [reviewer_human_ac_mechanical_signal](/docs/generated/tests-unit-reviewer_human_ac_mechanical_signal) | called_by | T-1896 (T-1878 B): integration coverage for the new reviewer pattern `human-ac-mechanical-signal` — runs `bin/fw reviewer` end-to-end against synthetic task files, asserts the pattern fires (or doesn't) per design. |
| [t2318_retrofit_injector_append_missing](/docs/generated/tests-unit-t2318_retrofit_injector_append_missing) | called_by | T-2318: retrofit injector must handle missing-Recommendation-section case (pre-T-1716 backlog inceptions). Pins detector↔corrector symmetry per RCA. |
| [t2331_driver_propose](/docs/generated/tests-unit-t2331_driver_propose) | called_by | T-2331 (T-2330 S1): `fw bvp driver --propose` non-Sovereign verb. |
| [t2452_doctor_quick](/docs/generated/tests-unit-t2452_doctor_quick) | called_by | T-2452 / F6 (T-2441 dogfood) — `fw doctor --quick` project-only fast mode. |
| [t2461_doctor_mcp_consumer_path](/docs/generated/tests-unit-t2461_doctor_mcp_consumer_path) | called_by | T-2461: fw doctor's framework-MCP-manifest check resolved its asset paths against $PROJECT_ROOT, which is the CONSUMER root in a vendored install — the manifest actually lives under $FRAMEWORK_ROOT (.agentic-framework/agents/mcp/). |
| [task_archive_eligible](/docs/generated/tests-unit-task_archive_eligible) | called_by | T-1903 / L-403: `fw task archive-eligible` sweep — detect tasks stuck in .tasks/active/ with status: work-completed + all ACs ticked (the post- re-class trap) and move them to .tasks/completed/. |
| [test_audit_completable_not_completed](/docs/generated/tests-unit-test_audit_completable_not_completed) | called_by | T-2055 — Pin CTL-029, the active-side mirror of CTL-028. Catches tasks where Agent ACs are 100% ticked but status remains started-work/issues (shipped-but-unclosed — agent finished the work and forgot to run `--status work-completed`). |
| [test_audit_cron_registry_generated_drift](/docs/generated/tests-unit-test_audit_cron_registry_generated_drift) | called_by | T-1943 — Pin fw audit registry → generated cron drift FAIL (audit-side sibling to T-1942's doctor-side WARN). |
| [test_audit_retire_when](/docs/generated/tests-unit-test_audit_retire_when) | called_by | T-2169 — Pin audit.sh retire_when advisory. Origin: value-drivers.yaml v3 free drivers (F-RECALL, F-ORCH) carry retire_when: text describing when the driver stops being relevant. Without an advisory rail nothing nudges the operator. |
| [test_audit_revert_chain](/docs/generated/tests-unit-test_audit_revert_chain) | called_by | T-2058 — Pin audit.sh revert-chain suppression. |
| [test_bin_fw_no_heredoc_cmd_sub](/docs/generated/tests-unit-test_bin_fw_no_heredoc_cmd_sub) | called_by | T-1946 — Structural lint: bin/fw must contain ZERO heredoc-in-cmd-substitution patterns. Third layer of L-332 / L-408 prevention (after the learnings and the T-1945 PreToolUse edit-time WARN). |
| [test_cron_generate_shape](/docs/generated/tests-unit-test_cron_generate_shape) | called_by | T-1769 — Pin the shape of `fw cron generate` output. Origin: T-1720 found that the generator silently produced unrunnable lines (no cwd for `python3 -m lib.X` invocations; stderr swallowed by `2>/dev/null`). |
| [test_cron_registry_generated_drift](/docs/generated/tests-unit-test_cron_registry_generated_drift) | called_by | T-1942 — Pin fw doctor registry → generated drift detection. |
| [test_doctor_litellm_ollama](/docs/generated/tests-unit-test_doctor_litellm_ollama) | called_by | T-1700 — fw doctor: litellm-proxy + ollama reachability checks. |
| [test_doctor_scope_tags](/docs/generated/tests-unit-test_doctor_scope_tags) | called_by | T-1707 / G-065 Stream 2 — fw doctor scope tagging. |
| [test_mcp_wire_fragment](/docs/generated/tests-unit-test_mcp_wire_fragment) | called_by | T-2272 (arc-010 Slice 2.5): framework-mcp .mcp.json fragment helper. |
| [test_orchestrator_graph](/docs/generated/tests-unit-test_orchestrator_graph) | called_by | T-2339 (arc-011 M1 §1) — orchestrator-graph dispatch decision. |
| [test_orchestrator_status_synthetic_filter](/docs/generated/tests-unit-test_orchestrator_status_synthetic_filter) | called_by | T-1712 — fw orchestrator status: filter T-stress-* synthetic rows from enrichment metric, headline reports real dispatches only. |
| [test_reviewer_prose_mismatch](/docs/generated/tests-unit-test_reviewer_prose_mismatch) | called_by | T-1947 (L-409): integration coverage for `reviewer-prose-mismatch` — the inverse of `human-ac-mechanical-signal`. |
| [test_work_on_completed_task](/docs/generated/tests-unit-test_work_on_completed_task) | called_by | T-2036 — Pin `fw work-on T-XXX` behaviour against the P-002 "completed before commit" deadlock. |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | called_by | T-1708 — worker_kind drift regression test. |
| [test_write_set](/docs/generated/tests-unit-test_write_set) | called_by | T-2337 (arc-011 M1 §3) — disjoint write-set validator. |
| [verify_acs](/docs/generated/tests-unit-verify_acs) | called_by | Unit tests for verify acs (6 tests) |
| [watchtower_health_verdict_identity](/docs/generated/tests-unit-watchtower_health_verdict_identity) | called_by | T-2445 (F9, T-2442 batch): Watchtower HEALTH-VERDICT call-sites must gate on the identity-verified resolver, never on a default-port `/health` curl. |
| [designer](/docs/generated/agents-designer-designer) | called_by | fw designer: vendors and serves a pinned Workflow Designer release build via the Watchtower /designer blueprint (832-Workflow-designer is source of truth; T-2521). |
| [doctor_designer_pin_drift](/docs/generated/tests-unit-doctor_designer_pin_drift) | tests_by | T-2524 (T-2521 integration hardening): fw doctor content-compares (sha256, never mtime) the vendored Workflow Designer build against policy/designer-pin.yaml. Sibling of the MCP manifest + cron registry→generated drift checks. |
| [bpmn_promote](/docs/generated/tools-bpmn_promote) | called_by | fw bpmn promote — turn staged BPMN proposals into gated .tasks/ files. |
| [designer_registry](/docs/generated/web-designer_registry) | called_by | Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2). |
| [designer_sync_from_tag](/docs/generated/tests-unit-designer_sync_from_tag) | tests_by | T-2616: fw designer sync --from-tag — pull-at-tag intake contract (T-247/D-335). |
| [corpus_spec](/docs/generated/tools-corpus_spec) | called_by | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |
| [designer](/docs/generated/web-blueprints-designer) | called_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [check-active-task](/docs/generated/agents-context-check-active-task) | called_by | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [cmd_classify](/docs/generated/lib-cmd_classify) | called_by | Decompose-then-judge classifier for the budget gate's at-critical allowlist. |
| [hook_parity](/docs/generated/lib-hook_parity) | called_by | Hook-set extraction and comparison — ONE definition, every caller (T-3112/T-3113). |
| [arc015_capture](/docs/generated/tests-demo-arc015_capture) | called_by | arc-015 (onboarding-shape-detection) — capture the headline mechanic firing. |
| [fw_onboarding_greenfield](/docs/generated/tests-integration-fw_onboarding_greenfield) | tests_by | T-2850 — greenfield onboarding integration coverage. |
| [readme_five_minute_by_hand](/docs/generated/tests-integration-readme_five_minute_by_hand) | tests_by | T-2719 (arc-016) — the README's five-minute walkthrough, run as the BY-HAND persona: a person at a terminal with no AI agent attached. |
| [t2922_greenfield_first_inception](/docs/generated/tests-integration-t2922_greenfield_first_inception) | called_by | T-2922 — a fresh `fw init` project must be able to complete its first inception with no Watchtower running. |
| [t2922_greenfield_first_inception](/docs/generated/tests-integration-t2922_greenfield_first_inception) | tests_by | T-2922 — a fresh `fw init` project must be able to complete its first inception with no Watchtower running. |
| [bvp-help-parity](/docs/generated/tests-lint-bvp-help-parity) | tests_by | T-3069: the bvp verb surface and its documentation must agree. |
| [no-backticks-in-inline-python](/docs/generated/tests-lint-no-backticks-in-inline-python) | tests_by | T-2707: backticks inside a double-quoted `python3 -c "..."` block are COMMAND SUBSTITUTION performed by bash before python ever sees the source. |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | Invariant: gate scripts must not emit bare 'fw' COMMANDS — use bin/fw, or the _emit_user_command/_fw_cmd helpers that resolve the right path per project. Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007. |
| [no-orphaned-test-dirs](/docs/generated/tests-lint-no-orphaned-test-dirs) | tests_by | T-2697 — every tests/<dir>/ holding .bats files must be reachable from a runner. |
| [capture_verbs_nulltask](/docs/generated/tests-unit-capture_verbs_nulltask) | tests_by | T-2878 — the capture verbs must be reachable in the state that completing work creates. |
| [claude_fw_router](/docs/generated/tests-unit-claude_fw_router) | tests_by | Pins bin/claude-fw-router's resolution: routes to a vendored consumer's own claude-fw, walks up from a nested subdirectory, prefers the framework repo's own bin/claude-fw over its self-vendored copy, falls back to plain claude when no project/sibling is found (announced on stderr), and skips an incomplete vendor mid-init. |
| [doctor_hook_counters](/docs/generated/tests-unit-doctor_hook_counters) | called_by | T-2714 (OBS-110): every hook counter in `fw doctor` must state its denominator. |
| [doctor_hook_counters](/docs/generated/tests-unit-doctor_hook_counters) | tests_by | T-2714 (OBS-110): every hook counter in `fw doctor` must state its denominator. |
| [drift_gate_not_shadowed_by_safelist](/docs/generated/tests-unit-drift_gate_not_shadowed_by_safelist) | tests_by | T-2880 — the safe-list early return must not shadow the focus-drift gate. |
| [episodic_yaml_timeline_escape](/docs/generated/tests-unit-episodic_yaml_timeline_escape) | called_by | T-2729 — the episodic generator's git-timeline rows must survive a commit subject containing YAML-hostile characters. |
| [episodic_yaml_timeline_escape](/docs/generated/tests-unit-episodic_yaml_timeline_escape) | tests_by | T-2729 — the episodic generator's git-timeline rows must survive a commit subject containing YAML-hostile characters. |
| [fw_help_watchtower_discoverable](/docs/generated/tests-unit-fw_help_watchtower_discoverable) | tests_by | T-2808 — `fw help` must make the Watchtower port resolvable. |
| [fw_init_atomic](/docs/generated/tests-unit-fw_init_atomic) | tests_by | T-2801 — fw init must leave either nothing or a working project. |
| [fw_vendor_completeness](/docs/generated/tests-unit-fw_vendor_completeness) | tests_by | T-2805 — a partial vendor must not capture the router, and FRAMEWORK.md must be the last thing a vendor writes. |
| [git_identity_check](/docs/generated/tests-unit-git_identity_check) | called_by | T-2883 — "can this machine commit?" must be answered the way git answers it. |
| [git_identity_check](/docs/generated/tests-unit-git_identity_check) | tests_by | T-2883 — "can this machine commit?" must be answered the way git answers it. |
| [handover_digest](/docs/generated/tests-unit-handover_digest) | tests_by | T-3028 (T-3025 GO, option 3): the three state dumps digest to count + regenerating command + top-N; the narrative does not change. |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | called_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | tests_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |
| [init_git_identity_blocker](/docs/generated/tests-unit-init_git_identity_blocker) | tests_by | T-2818 / OBS-170 — `fw init` must not sign off a project that cannot commit. |
| [init_project_shape_detection](/docs/generated/tests-unit-init_project_shape_detection) | called_by | T-2723 (arc-015) — project-shape detection guard for F-10. |
| [init_project_shape_detection](/docs/generated/tests-unit-init_project_shape_detection) | tests_by | T-2723 (arc-015) — project-shape detection guard for F-10. |
| [install_verify_no_cwd_init](/docs/generated/tests-unit-install_verify_no_cwd_init) | tests_by | Regression test (T-2799): runs the real install.sh end to end in an isolated HOME + empty cwd and asserts the cwd is untouched afterward. Guards against the installer's own verify() step silently auto-initialising a project wherever the user happened to invoke curl\|bash from. |
| [learning_application_birth](/docs/generated/tests-unit-learning_application_birth) | tests_by | T-2901: `application:` must not be born populated. |
| [lib_upgrade](/docs/generated/tests-unit-lib_upgrade) | tests_by | Unit tests for lib/upgrade.sh |
| [rail_identity_guard](/docs/generated/tests-unit-rail_identity_guard) | tests_by | T-2904: outbound rail posts must not be signed by the shared host key. |
| [rail_mcp_label_guard](/docs/generated/tests-unit-rail_mcp_label_guard) | tests_by | T-2908: the MCP producer surface (mcp__termlink__termlink_channel_post) reaches the same rail topics as `fw rail post` with neither the T-2904 identity gate nor the T-2905 label gate in scope, because both live inside `do_rail post` in… |
| [reviewer_verdict_replacement_escape](/docs/generated/tests-unit-reviewer_verdict_replacement_escape) | called_by | T-2730 — a rendered verdict is DATA, and must never reach `re.sub` as a replacement *template*. |
| [reviewer_verdict_replacement_escape](/docs/generated/tests-unit-reviewer_verdict_replacement_escape) | tests_by | T-2730 — a rendered verdict is DATA, and must never reach `re.sub` as a replacement *template*. |
| [router_no_global_fallback](/docs/generated/tests-unit-router_no_global_fallback) | tests_by | Pins bin/fw-router's three post-T-2854 properties together (a fix that regressed any one would still pass a narrower test): refuses with no project found and no global consulted, still routes a vendored consumer project correctly, and still finds the project root walking up from a nested subdirectory. Also covers a residue global on the host not being routed to, and the framework repo itself still routing to its own bin/fw. |
| [safe_commands_chain](/docs/generated/tests-unit-safe_commands_chain) | tests_by | T-2834 / OBS-183 — a compound command is safe only if EVERY segment is safe. |
| [self_vendor_parity](/docs/generated/tests-unit-self_vendor_parity) | tests_by | T-2711: the self-vendor PRODUCER and the audit GATE must cover the same files. |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | tests_by | T-2710: a forced .claude/settings.json regenerate must not silently delete hooks that `fw hook-enable` added after init. |
| [t1719_ask_routing](/docs/generated/tests-unit-t1719_ask_routing) | tests_by | T-1719 A3 — `fw ask` routes through the Resolver, with a cloud fallback. |
| [t2759_upgrade_target_dir_shadowing](/docs/generated/tests-unit-t2759_upgrade_target_dir_shadowing) | tests_by | T-2759: `fw upgrade` must never write a consumer's files somewhere else and then report success. |
| [t2762_upgrade_foreign_source_sha](/docs/generated/tests-unit-t2762_upgrade_foreign_source_sha) | tests_by | T-2762: a source repo that cannot resolve the consumer's recorded commit is not a valid upgrade source. |
| [t2862_greenfield_first_inception_e2e](/docs/generated/tests-unit-t2862_greenfield_first_inception_e2e) | called_by | ── What the live run established (2026-08-11, S-2026-0811) ────────────────── On a fresh `fw init` greenfield project, doing only the work the seed asks: 1. AC preflight PASS (T-2862's fix works — no self-gating AC) 2. |
| [t2862_greenfield_first_inception_e2e](/docs/generated/tests-unit-t2862_greenfield_first_inception_e2e) | tests_by | ── What the live run established (2026-08-11, S-2026-0811) ────────────────── On a fresh `fw init` greenfield project, doing only the work the seed asks: 1. AC preflight PASS (T-2862's fix works — no self-gating AC) 2. |
| [t2912_upgrade_hook_regen_convergence](/docs/generated/tests-unit-t2912_upgrade_hook_regen_convergence) | tests_by | End-to-end (real fw init'd consumer, env -i) proof that fw upgrade's hook-regeneration step reports its own verified effect instead of the pre-write trigger — a regen that cannot supply a detected-missing hook must report FAILED/PARTIAL, not UPDATED, on every run, and must not write a fresh .bak for a no-op. |
| [t2919_budget_gate_command_classify](/docs/generated/tests-unit-t2919_budget_gate_command_classify) | tests_by | T-2919 — the budget gate must judge the command's STRUCTURE, not scan it for a substring. |
| [t2920_boundary_heredoc_strip_order](/docs/generated/tests-unit-t2920_boundary_heredoc_strip_order) | tests_by | T-2920 — the project-boundary hook must not read a heredoc BODY as a command. |
| [t2936_bootstrap_quoted_redirect](/docs/generated/tests-unit-t2936_bootstrap_quoted_redirect) | tests_by | T-2936 — the task gate refused both commands its own block message prescribes. |
| [t2945_default_template_recommendation](/docs/generated/tests-unit-t2945_default_template_recommendation) | called_by | T-2945 — default.md shipped no `## Recommendation`, so the section the review gate demands existed in only one of the two templates that reach it. |
| [t2945_default_template_recommendation](/docs/generated/tests-unit-t2945_default_template_recommendation) | tests_by | T-2945 — default.md shipped no `## Recommendation`, so the section the review gate demands existed in only one of the two templates that reach it. |
| [t2948_review_human_ac_comment_aware](/docs/generated/tests-unit-t2948_review_human_ac_comment_aware) | called_by | T-2948 — lib/review.sh's Human-AC counter was comment-immune BY ACCIDENT. |
| [t2948_review_human_ac_comment_aware](/docs/generated/tests-unit-t2948_review_human_ac_comment_aware) | tests_by | T-2948 — lib/review.sh's Human-AC counter was comment-immune BY ACCIDENT. |
| [t2988_grouped_command_classification](/docs/generated/tests-unit-t2988_grouped_command_classification) | tests_by | T-2988: shell grouping punctuation defeated safe-command classification. |
| [t2990_root_pollution](/docs/generated/tests-unit-t2990_root_pollution) | called_by | T-2990: the root-pollution rail, proven in BOTH directions. |
| [t2990_root_pollution](/docs/generated/tests-unit-t2990_root_pollution) | tests_by | T-2990: the root-pollution rail, proven in BOTH directions. |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | tests_by | T-2991: P-011 must never eval a line bash cannot parse. |
| [t3046_message_router](/docs/generated/tests-unit-t3046_message_router) | called_by | T-3046 — static msg_type router for recovered hub messages (slice 1 of T-3044). |
| [t3046_message_router](/docs/generated/tests-unit-t3046_message_router) | tests_by | T-3046 — static msg_type router for recovered hub messages (slice 1 of T-3044). |
| [t3048_bats_leg_guard](/docs/generated/tests-unit-t3048_bats_leg_guard) | tests_by | T-3048 — `fw test unit` and `fw test all` must skip, not hard-error, when the install ships no tests/unit/. |
| [t3050_b005_block_message](/docs/generated/tests-unit-t3050_b005_block_message) | tests_by | T-3050 — the B-005 refusal must name the way forward. |
| [t3051_exec_bit_gates](/docs/generated/tests-unit-t3051_exec_bit_gates) | tests_by | T-3051 — repo-tracked helper scripts must not be gated on their exec bit. |
| [t3073_c001_recommendation_bearing_inceptions](/docs/generated/tests-unit-t3073_c001_recommendation_bearing_inceptions) | called_by | T-3073: C-001 research-artefact rail covers inceptions being DECIDED, not only inceptions being WORKED. |
| [t3073_c001_recommendation_bearing_inceptions](/docs/generated/tests-unit-t3073_c001_recommendation_bearing_inceptions) | tests_by | T-3073: C-001 research-artefact rail covers inceptions being DECIDED, not only inceptions being WORKED. |
| [t3111_worktree_reexec](/docs/generated/tests-unit-t3111_worktree_reexec) | tests_by | T-3111: fw re-execs the AUTHORITY's binary from a linked worktree (R7 leg L2). |
| [t3112_worktree_hook_parity](/docs/generated/tests-unit-t3112_worktree_hook_parity) | tests_by | T-3112: fw doctor audits linked worktrees for enforcement drift (R7 leg L3). |
| [t3113_upgrade_worktree_advisory](/docs/generated/tests-unit-t3113_upgrade_worktree_advisory) | tests_by | T-3113: `fw upgrade` names which linked worktrees are behind (R7 leg L4). |
| [test_fw_json_stdout_purity](/docs/generated/tests-unit-test_fw_json_stdout_purity) | called_by | T-2769 — `fw <cmd> --json` must emit only JSON on stdout. |
| [test_index_doctor_rail](/docs/generated/tests-unit-test_index_doctor_rail) | tests_by | The doctor/audit rail over the vector index — T-3013 (T-3005 slice 4). |
| [test_mirror_sync](/docs/generated/tests-unit-test_mirror_sync) | called_by | T-1594: Mirror cascade auto-recovery (T-1591 Prevention #3) |
| [test_mirror_sync](/docs/generated/tests-unit-test_mirror_sync) | tests_by | T-1594: Mirror cascade auto-recovery (T-1591 Prevention #3) |
| [test_url_credentials](/docs/generated/tests-unit-test_url_credentials) | called_by | T-2693 — lib/url-credentials.sh, the single dialect for URL credential handling. |
| [test_url_credentials](/docs/generated/tests-unit-test_url_credentials) | tests_by | T-2693 — lib/url-credentials.sh, the single dialect for URL credential handling. |
| [tier0_card_provenance](/docs/generated/tests-unit-tier0_card_provenance) | called_by | T-3078 — a Tier 0 approval card must record where it came from, derived. |
| [tier0_card_provenance](/docs/generated/tests-unit-tier0_card_provenance) | tests_by | T-3078 — a Tier 0 approval card must record where it came from, derived. |
| [tier0_grant_ttl](/docs/generated/tests-unit-tier0_grant_ttl) | called_by | T-3080 — the Tier 0 grant TTL is one window, resolved once, for BOTH approval legs. |
| [tier0_grant_ttl](/docs/generated/tests-unit-tier0_grant_ttl) | tests_by | T-3080 — the Tier 0 grant TTL is one window, resolved once, for BOTH approval legs. |
| [upgrade_fresh_machine_simulation](/docs/generated/tests-unit-upgrade_fresh_machine_simulation) | called_by | T-1635: fresh-machine simulation guard for fw upgrade. |
| [validate_init_hook_path_expansion](/docs/generated/tests-unit-validate_init_hook_path_expansion) | tests_by | T-2724 — lib/validate-init.sh must expand ${CLAUDE_PROJECT_DIR} before testing whether a hook script exists. |
| [version_relation](/docs/generated/tests-unit-version_relation) | tests_by | T-2713: consumer-vs-framework version relation must come from git ancestry, never from `sort -V` over the VERSION counter. |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | triggers_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |
| [check-heredoc-cmd-sub](/docs/generated/agents-context-check-heredoc-cmd-sub) | called_by | T-1945 — Heredoc-in-command-substitution edit-time guard. |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | called_by | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [termlink](/docs/generated/agents-termlink-termlink) | called_by | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [arc](/docs/generated/lib-arc) | called_by | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [audit_timing](/docs/generated/lib-audit_timing) | called_by | T-3127: classify the persisted full-audit timing record against a warn fraction. |
| [hook_portability](/docs/generated/lib-hook_portability) | called_by | Single source of truth for "is this hook command host-portable?" (T-2709). |
| [worktree](/docs/generated/lib-worktree) | called_by | lib/worktree.sh — fw worktree topology observability. |
| [bats-silent-skip](/docs/generated/tests-lint-bats-silent-skip) | tests_by | Tests the silent-skip lint. Half the legs are false-positive controls: a detector that reddens legitimate optional-dependency skips gets suppressed wholesale, so the legs asserting it stays quiet are the ones that decide whether it survives. Includes the mutation control and the two heredoc-blindness regressions found by reconciling the census against a naive grep. |
| [t3213_start_event_confirmation](/docs/generated/tests-unit-t3213_start_event_confirmation) | tests_by | End-to-end confirmation suite for the claude-fw start-event ledger: runs the real bin/claude-fw in a scratch git repo with a stubbed claude binary and asserts the start event is written, is idempotent, and degrades correctly when the ledger path is unwritable. |
| [t3221_commit_exemption_clause](/docs/generated/tests-unit-t3221_commit_exemption_clause) | tests_by | Pins the commit-checkpoint exemption in the Bash task gate. Both exemption branches (T-2054 null-focus, T-3179 partial-complete) once admitted any command whose raw text CONTAINED "git commit" — so a trailing `; rm -rf` rode through, a `\| tee` write the gate had already flagged was admitted anyway, and an unknown binary passed because a quoted argument said the words. This suite probes the SHIPPED hook through its real stdin JSON contract rather than re-implementing the predicate, and carries two controls that decide whether a green run means anything: a mutation control that rebuilds the pre-fix hook from live source (so reverting the fix reddens the suite), and a 16-command no-widening sweep asserting the fixed hook admits nothing the pre-fix one blocked. |
| [t3222_fetch_writes_file](/docs/generated/tests-unit-t3222_fetch_writes_file) | tests_by | Pins that curl and wget are admitted by the Bash safe-list only when they do not write a file. Both sat in the list unconditionally, so `curl -o FILE` and `wget -O FILE` — which write with no shell redirect, and are therefore invisible to has_bash_write_pattern — ran with no active task. Covers 22 spellings in both directions, including the stdout forms (`-o -`, `-O -`) that must stay safe and the framework's own documented verification idiom `curl -sf "$(bin/fw watchtower url)/page"`. Two legs carry the design decision: one asserts a commit whose MESSAGE mentions `curl -o` is still admitted (why the check is clause-scoped rather than in the whole-string write scanner), and one asserts a commit chained to a fetch-write is now refused with no change to the T-3221 commit predicate. Mutation control restores the unconditional arm from live source; a no-widening sweep asserts the fix admits nothing the pre-fix version blocked. |
| [t3231_help_exemption_scope](/docs/generated/tests-unit-t3231_help_exemption_scope) | tests_by | T-3231 — the `--help` exemption must not skip every gate. |
| [t3233_arm_bounds](/docs/generated/tests-unit-t3233_arm_bounds) | tests_by | T-3233 — `fw continuous arm` must not report a bound it does not enforce. |
| [t3235_archived_horizon_invariant](/docs/generated/tests-unit-t3235_archived_horizon_invariant) | tests_by | Pins that a task file under .tasks/completed/ carries horizon: null whichever branch archived it. Two branches move a task there and their entry conditions are exact complements, so the null-ing written at the first site (T-2163, widened T-2300 after eight CTL-030 instances) could never reach the partial-complete recheck branch. The sharp end is fw task archive-eligible, which re-invokes --status work-completed and therefore drives exclusively through the branch that was unfixed. Every leg asserts WHICH branch ran before asserting the outcome, because the obvious fixture leaves status started-work and never enters the recheck branch at all — a rig that checks only the outcome goes green against the wrong path. A control pins the deliberate case the fix must NOT break: a partial-complete that stays in active/ keeps its stored horizon, which is why the post-condition keys on location, not status. The mutation control removes the post-condition from a live-derived copy and needs a symlink farm, since update-task.sh derives FRAMEWORK_ROOT from its own location and a dead subject reads exactly like a regressed one. Reported by peer 832-Workflow-designer (their T-654 BUG 1); confirmed in-tree first. |
| [t3254_driver_refusals](/docs/generated/tests-unit-t3254_driver_refusals) | tests_by | T-3254 (arc-012) — the outside driver must refuse on every armed condition. |
| [upgrade_marked_region](/docs/generated/tests-unit-upgrade_marked_region) | tests_by | T-3150 — `fw upgrade` step [1/10] rebuilt a consumer's CLAUDE.md as (everything above `## Core Principle`) + (framework governance). |
| [vendor_visibility](/docs/generated/tests-unit-vendor_visibility) | tests_by | T-3144 — `fw vendor` writes executable code into a consumer tree and never checked that the consumer's git could see it. Reported by 010-termlink for `tools/`; the measured set is wider. |
| [ewcr-arc0-unknown-overlap](/docs/generated/tools-ewcr-arc0-unknown-overlap) | called_by | EWCR Arc 0, falsifier 1 — do the Unknown-subsystem Fabric entries intersect the runtime write set? |
| [gaps-render-agreement](/docs/generated/tools-gaps-render-agreement) | called_by | T-3140: assert `fw gaps` renders exactly the non-terminal half of the register. |
| [t1700-ollama-harness](/docs/generated/tools-t1700-ollama-harness) | called_by | T-1700 ollama-research harness (v2, T-2408) — exercises the v1 dispatch substrate end-to-end through `fw resolver run` onto litellm/ollama. |
| [t1703-probe-matrix](/docs/generated/tools-t1703-probe-matrix) | called_by | T-1703 probe matrix — gemma4 + qwen3.5 against 3 tool catalogues. Uses simple-read prompts only (Read tool sufficient) so the Read-only catalogue cell isn't penalised for prompts that need Bash. |
| [t1704-hermes3-probe](/docs/generated/tools-t1704-hermes3-probe) | called_by | T-1704 hermes3:8b probe — same matrix shape as T-1703, single model. hermes3 is Nous Research's function-calling-tuned line; the v3 hypothesis is that explicit tool-call training fixes what catalogue restriction couldn't. |
| [t3254-livefire](/docs/generated/tools-t3254-livefire) | called_by | T-3254 (arc-012) AC5 + AC6 — live-fire and its negative control. |
| [config](/docs/generated/web-blueprints-config) | called_by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [check-inception-recommendation](/docs/generated/agents-context-check-inception-recommendation-py) | called_by | T-2205 (T-2204 Slice B): PreToolUse Write/Edit hook — refuse save when an inception task has a template-only `## Recommendation` block under |
| [enrich](/docs/generated/agents-fabric-lib-enrich) | called_by | Fabric enrichment engine — auto-detect dependency edges from source analysis. |
| [t2176-corpus-rescan](/docs/generated/tools-t2176-corpus-rescan) | called_by | T-2176: Fresh fw reviewer scan over .tasks/completed/ to refresh stale verdict cache. Writes back ## Reviewer Verdict block per task; logs JSON per task; aggregates FAIL list. |
| [conftest](/docs/generated/web-conftest) | called_by | Pytest configuration for web/ test suite. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [t3281_cron_orphan_scan](/docs/generated/tests-unit-t3281_cron_orphan_scan) | tests_by | T-3281: orphaned cron.d entries — deployed jobs whose declared PROJECT_ROOT is gone. |
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | called_by | Session Resume Hook — Reinject structured context on session recovery |
| [provision](/docs/generated/agents-sessions-antigravity-provision) | called_by | Provisions the Antigravity/OpenGravity (AGY) provider package into a target project (T-2417) |
| [aef_provision_log](/docs/generated/lib-aef_provision_log) | called_by | T-3313 (arc-020 S7): durable JSONL audit trail for auto-provision events. |
| [exec-bit-drift](/docs/generated/lib-exec-bit-drift) | called_by | lib/exec-bit-drift.sh — T-3317 (OBS-336): exec-bit drift detector. |
| [fabric_doctor_facts](/docs/generated/lib-fabric_doctor_facts) | called_by | Flatten `underpopulated.py --json` into one tab-separated line for `fw doctor`. |
| [govd_sandbox](/docs/generated/lib-govd_sandbox) | called_by | govd_sandbox — OS sandbox profile emit / install / drift (arc-013 / T-2433, design §7a). |
| [e2e](/docs/generated/lib-sidecar-e2e) | called_by | arc-011 sidecar — live end-to-end harness (T-3423, slice 9). |
| [sidecar_inbox_hook](/docs/generated/tests-unit-sidecar_inbox_hook) | tests_by | T-3407 — sidecar-inbox UserPromptSubmit hook: silent-when-empty, surfaces when pending, peeks (never consumes), fails open. |
| [t3374_env_prefix_denylist](/docs/generated/tests-unit-t3374_env_prefix_denylist) | tests_by | T-3374 (OBS-423) — the env-prefix stripper must refuse names that decide what the command it strips them from actually RESOLVES to. |
| [t3425_sidecar_read_allowlist](/docs/generated/tests-unit-t3425_sidecar_read_allowlist) | tests_by | T-3425 (OBS-461) — the sidecar's read verbs and TermLink's channel reads are on the task gate's read-only allowlist; their write forms are not. |
| [t3430_fabric_audit_doctor](/docs/generated/tests-unit-t3430_fabric_audit_doctor) | tests_by | T-3430: the audit + doctor surfaces for under-populated fabric cards. |
| [test_govd_sandbox](/docs/generated/tests-unit-test_govd_sandbox) | called_by | T-2433 (arc-013): sandbox profile emit / status / install — the static floor. |

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
