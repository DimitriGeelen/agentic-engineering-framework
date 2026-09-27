# hooks

> Git Agent - Hook installation subcommand

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/hooks.sh`

## What It Does

Git Agent - Hook installation subcommand

## Dependencies (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | calls | agents/git/lib/secret-scan.sh — Secret-scan library for the pre-commit hook (T-1844). |
| [dup-task-scan](/docs/generated/agents-git-lib-dup-task-scan) | calls | T-1863: Duplicate task-ID scanner (G-052 prevention). |
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | calls | agents/git/lib/large-file-scan.sh — Large-file gate for the pre-commit hook (T-1845). |
| [manifest](/docs/generated/agents-mcp-manifest) | calls | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [master-guard](/docs/generated/agents-git-lib-master-guard) | calls | master-guard.sh — Master-as-merge-only pre-commit guard (T-2396, inception T-2394 G1) |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [episodic_footprint](/docs/generated/lib-episodic_footprint) | calls | Re-mine an episodic's git footprint AFTER the completion commit exists (T-3130). |
| [prepush-lock-wait](/docs/generated/lib-prepush-lock-wait) | calls | lib/prepush-lock-wait.sh — T-3421: derive the pre-push audit-lock wait from the measured audit, instead of asserting it. |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | called_by | Git Agent - Structural Enforcement for Git Operations |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | Invariant: gate scripts must not emit bare 'fw' COMMANDS — use bin/fw, or the _emit_user_command/_fw_cmd helpers that resolve the right path per project. Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007. |
| [inception_commit_counter](/docs/generated/tests-unit-inception_commit_counter) | called_by | Unit tests for _count_inception_exploration_commits (T-2195) |
| [inception_commit_counter](/docs/generated/tests-unit-inception_commit_counter) | tests_by | Unit tests for _count_inception_exploration_commits (T-2195) |
| [hook_version_marker_parity](/docs/generated/tests-unit-hook_version_marker_parity) | tests_by | T-2852 — install-hooks must compare the installed commit-msg hook's `# VERSION=` marker against the TEMPLATE's version, not against the git agent's own version. |
| [episodic_footprint_refresh](/docs/generated/tests-unit-episodic_footprint_refresh) | tests_by | T-3130 — the episodic's git footprint is mined before the commit it describes. |
| [t3421_prepush_lock_wait](/docs/generated/tests-unit-t3421_prepush_lock_wait) | tests_by | T-3421 — the pre-push audit-lock wait is derived from the measured audit. |

## Related

### Tasks
- T-862: Fix audit performance for pre-push — fast path for push hook
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-hooks.yaml`*
*Last verified: 2026-02-20*
