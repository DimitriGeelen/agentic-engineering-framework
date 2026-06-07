# hooks

> Git Agent - Hook installation subcommand

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/hooks.sh`

## What It Does

Git Agent - Hook installation subcommand

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | calls | TODO: describe what this component does |
| [dup-task-scan](/docs/generated/agents-git-lib-dup-task-scan) | calls | TODO: describe what this component does |
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | calls | TODO: describe what this component does |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | called_by | Git Agent - Structural Enforcement for Git Operations |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |
| [inception_commit_counter](/docs/generated/tests-unit-inception_commit_counter) | called_by | TODO: describe what this component does |
| [inception_commit_counter](/docs/generated/tests-unit-inception_commit_counter) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-862: Fix audit performance for pre-push — fast path for push hook
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-hooks.yaml`*
*Last verified: 2026-02-20*
