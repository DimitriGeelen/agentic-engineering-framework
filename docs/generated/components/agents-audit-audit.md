# audit

> TODO: describe what this component does

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/audit.sh`

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

## Dependencies (28)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [watchtower](/docs/generated/lib-watchtower) | calls | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [traceability](/docs/generated/lib-traceability) | calls | TODO: describe what this component does |
| [cron-registry](/docs/generated/lib-cron-registry) | calls | TODO: describe what this component does |
| [gitignore-register](/docs/generated/lib-gitignore-register) | calls | TODO: describe what this component does |
| [continuous-mode](/docs/generated/lib-continuous-mode) | calls | TODO: describe what this component does |
| [inception_recommendation](/docs/generated/lib-inception_recommendation) | calls | TODO: describe what this component does |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [branch-hygiene](/docs/generated/lib-branch-hygiene) | calls | TODO: describe what this component does |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | calls | TODO: describe what this component does |
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | calls | TODO: describe what this component does |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [error-watchdog](/docs/generated/agents-context-error-watchdog) | calls | Error Watchdog — PostToolUse hook for Bash error detection |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | calls | TODO: describe what this component does |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | calls | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | calls | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [corpus_lint](/docs/generated/tools-corpus_lint) | calls | TODO: describe what this component does |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | calls | TODO: describe what this component does |
| [hook-threshold](/docs/generated/lib-hook-threshold) | calls | TODO: describe what this component does |
| [bats_red_attribution](/docs/generated/lib-bats_red_attribution) | calls | TODO: describe what this component does |
| [corpus_conformance](/docs/generated/tools-corpus_conformance) | calls | TODO: describe what this component does |
| [verify_queue](/docs/generated/lib-verify_queue) | calls | TODO: describe what this component does |
| [manifest](/docs/generated/agents-mcp-manifest) | calls | TODO: describe what this component does |
| [workflow_coverage](/docs/generated/lib-workflow_coverage) | calls | TODO: describe what this component does |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit](/docs/generated/tests-unit-audit) | called_by | Unit tests for agents/audit/audit.sh (11 tests) |
| [audit_d10_html_comment_blindness](/docs/generated/tests-unit-audit_d10_html_comment_blindness) | tests_by | Bats unit tests pinning D10 audit ("Decision-without-Dialogue") behaviour against HTML-comment-blindness false positives (T-1889). 4 cases verify: template-stub-only Human section is silent, real unchecked AC outside comments fires, checked AC is silent, mixed comments+real AC doesn't double-count. Forward-pins the strip-comments call added to audit.sh D10 block — future refactors that remove it fail test #1. |
| [audit_null_timestamp](/docs/generated/tests-unit-audit_null_timestamp) | called_by | Regression test — audit.sh METRICS_EOF heredoc must not crash when .context/project/metrics-history.yaml contains a null timestamp. Origin: handover S-2026-0423-1623 AttributeError: 'NoneType' at <stdin>:108. |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-955: Audit loop merge — combine 10 loops into 3 passes (T-860 Phase 1)

---
*Auto-generated from Component Fabric. Card: `agents-audit-audit.yaml`*
*Last verified: 2026-09-04*
