# init

> fw init - Bootstrap a new project with the Agentic Engineering Framework

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/init.sh`

## What It Does

fw init - Bootstrap a new project with the Agentic Engineering Framework
Creates the directory structure, config files, and git hooks needed
for a project to use the framework.

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [validate-init](/docs/generated/lib-validate-init) | calls | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [preflight](/docs/generated/lib-preflight) | calls | fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations. |
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [git-identity](/docs/generated/lib-git-identity) | calls | TODO: describe what this component does |

## Used By (24)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [setup](/docs/generated/lib-setup) | called_by | fw setup - Guided onboarding wizard for new projects |
| [validate-init](/docs/generated/lib-validate-init) | reads_tags | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [upstream](/docs/generated/lib-upstream) | read_by | Safe issue creation from field installations to framework upstream repo. Resolves upstream repo from .framework.yaml or git remotes. Supports dry-run, confirmation, fw doctor attachment, patch attachment, and sent-file tracking. |
| [validate-init](/docs/generated/lib-validate-init) | read_by | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [lib_init](/docs/generated/tests-unit-lib_init) | called-by | TODO: describe what this component does |
| [lib_init](/docs/generated/tests-unit-lib_init) | called_by | TODO: describe what this component does |
| [hook_absolute_paths](/docs/generated/tests-unit-hook_absolute_paths) | called_by | Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts. |
| [focus_drift_gate](/docs/generated/tests-unit-focus_drift_gate) | called_by | TODO: describe what this component does |
| [focus_drift_gate](/docs/generated/tests-unit-focus_drift_gate) | tests_by | TODO: describe what this component does |
| [hook_absolute_paths](/docs/generated/tests-unit-hook_absolute_paths) | tests_by | Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts. |
| [hook_enable_absolute_path](/docs/generated/tests-unit-hook_enable_absolute_path) | tests_by | TODO: describe what this component does |
| [lib_init](/docs/generated/tests-unit-lib_init) | tests_by | TODO: describe what this component does |
| [settings_merge](/docs/generated/lib-settings_merge) | called_by | TODO: describe what this component does |
| [git_identity_check](/docs/generated/tests-unit-git_identity_check) | tests_by | TODO: describe what this component does |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | called_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | tests_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |
| [init_project_shape_detection](/docs/generated/tests-unit-init_project_shape_detection) | tests_by | TODO: describe what this component does |
| [init_seed_guard](/docs/generated/tests-unit-init_seed_guard) | called_by | TODO: describe what this component does |
| [init_seed_guard](/docs/generated/tests-unit-init_seed_guard) | tests_by | TODO: describe what this component does |
| [init_strips_upstream_credentials](/docs/generated/tests-unit-init_strips_upstream_credentials) | tests_by | TODO: describe what this component does |
| [t2912_upgrade_hook_regen_convergence](/docs/generated/tests-unit-t2912_upgrade_hook_regen_convergence) | tests_by | End-to-end (real fw init'd consumer, env -i) proof that fw upgrade's hook-regeneration step reports its own verified effect instead of the pre-write trigger — a regen that cannot supply a detected-missing hook must report FAILED/PARTIAL, not UPDATED, on every run, and must not write a fresh .bak for a no-op. |
| [hook_producer_site_parity](/docs/generated/tests-unit-hook_producer_site_parity) | read_by | Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous. |
| [t2912_upgrade_hook_regen_convergence](/docs/generated/tests-unit-t2912_upgrade_hook_regen_convergence) | called_by | End-to-end (real fw init'd consumer, env -i) proof that fw upgrade's hook-regeneration step reports its own verified effect instead of the pre-write trigger — a regen that cannot supply a detected-missing hook must report FAILED/PARTIAL, not UPDATED, on every run, and must not write a fresh .bak for a no-op. |

## Related

### Tasks
- T-796: Fix remaining single-warning shellcheck issues in agent scripts
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-850: Fix session metrics — per-session deltas instead of cumulative transcript analysis
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `lib-init.yaml`*
*Last verified: 2026-02-20*
