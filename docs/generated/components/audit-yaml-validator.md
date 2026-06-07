# audit-yaml-validator

> Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption.

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/audit.sh`

**Tags:** `audit`, `yaml`, `validation`, `regression`, `structure`

## What It Does

Audit Agent - Mechanical Compliance Checks
Evaluates framework compliance against specifications
Usage:
audit.sh                              # Full audit with terminal output
audit.sh --section structure,quality   # Run only specified sections
audit.sh --output /path/to/dir        # Write YAML report to custom dir
audit.sh --quiet                      # Suppress terminal output (cron-friendly)
audit.sh --cron                       # Shorthand for --output .context/audits/cron --quiet
audit.sh schedule install|remove|status  # Manage cron schedule
Sections: structure, compliance, quality, traceability, enforcement,

## Dependencies (15)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-data](/docs/generated/learnings-data) | reads | Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command. |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [error-watchdog](/docs/generated/agents-context-error-watchdog) | calls | Error Watchdog — PostToolUse hook for Bash error detection |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | calls | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | calls | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [watchtower](/docs/generated/lib-watchtower) | calls | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [inception_recommendation](/docs/generated/lib-inception_recommendation) | calls | TODO: describe what this component does |
| [hook-threshold](/docs/generated/lib-hook-threshold) | calls | TODO: describe what this component does |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | calls | TODO: describe what this component does |
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | calls | TODO: describe what this component does |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | calls | TODO: describe what this component does |

## Used By (32)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `cron-audit` | triggers | Runs every 30 minutes via cron + on pre-push |
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [audit](/docs/generated/tests-unit-audit) | tested_by | Unit tests for agents/audit/audit.sh (11 tests) |
| [test_git_hooks](/docs/generated/tests-governance-test_git_hooks) | called_by | TODO: describe what this component does |
| [test_git_hooks](/docs/generated/tests-governance-test_git_hooks) | tests_by | TODO: describe what this component does |
| [audit](/docs/generated/tests-unit-audit) | called_by | Unit tests for agents/audit/audit.sh (11 tests) |
| [audit](/docs/generated/tests-unit-audit) | tests_by | Unit tests for agents/audit/audit.sh (11 tests) |
| [audit_flock](/docs/generated/tests-unit-audit_flock) | called_by | TODO: describe what this component does |
| [audit_flock](/docs/generated/tests-unit-audit_flock) | tests_by | TODO: describe what this component does |
| [audit_null_timestamp](/docs/generated/tests-unit-audit_null_timestamp) | called_by | Regression test — audit.sh METRICS_EOF heredoc must not crash when .context/project/metrics-history.yaml contains a null timestamp. Origin: handover S-2026-0423-1623 AttributeError: 'NoneType' at <stdin>:108. |
| [audit_null_timestamp](/docs/generated/tests-unit-audit_null_timestamp) | tests_by | Regression test — audit.sh METRICS_EOF heredoc must not crash when .context/project/metrics-history.yaml contains a null timestamp. Origin: handover S-2026-0423-1623 AttributeError: 'NoneType' at <stdin>:108. |
| [lib_pickup](/docs/generated/tests-unit-lib_pickup) | tests_by | TODO: describe what this component does |
| [test_enrich_bats_parser](/docs/generated/tests-unit-test_enrich_bats_parser) | called_by | TODO: describe what this component does |
| [test_arcs_routes](/docs/generated/tests-unit-test_arcs_routes) | called_by | Unit tests for /arcs and /arcs/<id> routes (T-1662) — Flask test_client pins index empty/populated, detail in-progress with three-question check, detail closed without check, 404 for unregistered, missing-task graceful render. |
| [test_pre_push_monotonic_ancestor](/docs/generated/tests-unit-test_pre_push_monotonic_ancestor) | tests_by | TODO: describe what this component does |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | called_by | TODO: describe what this component does |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | tests_by | TODO: describe what this component does |
| [audit_ctl013_skip_nested_audit](/docs/generated/tests-unit-audit_ctl013_skip_nested_audit) | called_by | TODO: describe what this component does |
| [audit_ctl013_skip_nested_audit](/docs/generated/tests-unit-audit_ctl013_skip_nested_audit) | tests_by | TODO: describe what this component does |
| [arc_create_no_constituent_tasks](/docs/generated/tests-unit-arc_create_no_constituent_tasks) | tests_by | TODO: describe what this component does |
| [audit_anchor_task_existence](/docs/generated/tests-unit-audit_anchor_task_existence) | called_by | TODO: describe what this component does |
| [audit_anchor_task_existence](/docs/generated/tests-unit-audit_anchor_task_existence) | tests_by | TODO: describe what this component does |
| [audit_arc_progress_arc_id](/docs/generated/tests-unit-audit_arc_progress_arc_id) | tests_by | TODO: describe what this component does |
| [audit_ctl_arc_tag_only_pattern](/docs/generated/tests-unit-audit_ctl_arc_tag_only_pattern) | tests_by | TODO: describe what this component does |
| [audit_stale_arc_warning](/docs/generated/tests-unit-audit_stale_arc_warning) | called_by | TODO: describe what this component does |
| [audit_stale_arc_warning](/docs/generated/tests-unit-audit_stale_arc_warning) | tests_by | TODO: describe what this component does |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | called_by | TODO: describe what this component does |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | called_by | TODO: describe what this component does |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-955: Audit loop merge — combine 10 loops into 3 passes (T-860 Phase 1)

---
*Auto-generated from Component Fabric. Card: `audit-yaml-validator.yaml`*
*Last verified: 2026-02-20*
