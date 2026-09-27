# audit

> Audit Agent - Mechanical Compliance Checks Evaluates framework compliance against specifications

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

## Dependencies (37)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [watchtower](/docs/generated/lib-watchtower) | calls | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [traceability](/docs/generated/lib-traceability) | calls | lib/traceability.sh — commit-traceability predicates (T-2851) |
| [cron-registry](/docs/generated/lib-cron-registry) | calls | lib/cron-registry.sh — T-2844 |
| [gitignore-register](/docs/generated/lib-gitignore-register) | calls | T-2994 (build slice of T-2992) — .gitignore rules that defer without a register. |
| [continuous-mode](/docs/generated/lib-continuous-mode) | calls | Continuous-run counters (T-3169, arc-012 S3). |
| [inception_recommendation](/docs/generated/lib-inception_recommendation) | calls | Detection helper for the T-679 rule decay pattern (T-1715 meta-RCA, T-1716 implementation). Used by: - agents/audit/audit.sh — C-006 detective check - lib/inception.sh — Stream C sweep (do_inception_sweep --recommendation-fix) |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [branch-hygiene](/docs/generated/lib-branch-hygiene) | calls | lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO) |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | calls | agents/git/lib/secret-scan.sh — Secret-scan library for the pre-commit hook (T-1844). |
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | calls | agents/git/lib/large-file-scan.sh — Large-file gate for the pre-commit hook (T-1845). |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [error-watchdog](/docs/generated/agents-context-error-watchdog) | calls | Error Watchdog — PostToolUse hook for Bash error detection |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | calls | orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641) |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | calls | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [completed-task-scan](/docs/generated/agents-audit-completed-task-scan) | calls | Single-pass scan of completed task files that checks for missing episodic summaries, missing research artifacts, and unchecked acceptance criteria |
| [corpus_lint](/docs/generated/tools-corpus_lint) | calls | corpus_lint — per-map + cross-map lint for the designer corpus (T-2604). |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | calls | T-1944 — Cron registry → generated dry-run helper. |
| [hook-threshold](/docs/generated/lib-hook-threshold) | calls | T-1631 (B-3b of T-1626) — hook-failure threshold rule. |
| [bats_red_attribution](/docs/generated/lib-bats_red_attribution) | calls | T-3126 — attribute each RED bats test to the paths it is about. |
| [corpus_conformance](/docs/generated/tools-corpus_conformance) | calls | Map-conformance rail — corpus map assertions vs the enforced state machine. |
| [verify_queue](/docs/generated/lib-verify_queue) | calls | T-2765: re-run stored ## Verification for the human review queue. |
| [manifest](/docs/generated/agents-mcp-manifest) | calls | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [workflow_coverage](/docs/generated/lib-workflow_coverage) | calls | workflow_coverage — audit-time check for workflow → dispatcher coverage. |
| [watchtower-staleness](/docs/generated/lib-watchtower-staleness) | calls | T-2938: does the RUNNING Watchtower actually run the code on disk? |
| [audit-anchor-task](/docs/generated/lib-audit-anchor-task) | calls | T-1856 anchor_task existence detection — extracted from agents/audit/audit.sh by T-3356 so the check is reachable without running the whole `--section structure` block. |
| [exec-bit-drift](/docs/generated/lib-exec-bit-drift) | calls | lib/exec-bit-drift.sh — T-3317 (OBS-336): exec-bit drift detector. |
| [sidecar-audit](/docs/generated/lib-sidecar-audit) | calls | lib/sidecar-audit.sh — arc-011 sidecar slice 8 (T-3420). |
| [bvp-scorability](/docs/generated/lib-bvp-scorability) | calls | lib/bvp-scorability.sh — T-3428 (OBS-463 leg 3), arc-006. |
| [cron_exec_bit](/docs/generated/lib-cron_exec_bit) | calls | T-3380: scripts a deployed crontab invokes DIRECTLY must be executable. |
| [bats-dead-negation-lint](/docs/generated/tools-bats-dead-negation-lint) | calls | T-3138: find bats assertions that cannot fail. |
| [underpopulated](/docs/generated/agents-fabric-lib-underpopulated) | calls | Scan component cards for the under-populated class — a card that says nothing. |
| [fabric_doctor_facts](/docs/generated/lib-fabric_doctor_facts) | calls | Flatten `underpopulated.py --json` into one tab-separated line for `fw doctor`. |

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
