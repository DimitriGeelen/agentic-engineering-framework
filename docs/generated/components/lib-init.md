# init

> fw init - Bootstrap a new project with the Agentic Engineering Framework

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/init.sh`

## What It Does

fw init - Bootstrap a new project with the Agentic Engineering Framework
Creates the directory structure, config files, and git hooks needed
for a project to use the framework.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [validate-init](/docs/generated/lib-validate-init) | calls | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [preflight](/docs/generated/lib-preflight) | calls | fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations. |
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |

## Used By (13)

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
