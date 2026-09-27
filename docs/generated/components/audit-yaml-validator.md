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

## Dependencies (38)

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
| [inception_recommendation](/docs/generated/lib-inception_recommendation) | calls | Detection helper for the T-679 rule decay pattern (T-1715 meta-RCA, T-1716 implementation). Used by: - agents/audit/audit.sh — C-006 detective check - lib/inception.sh — Stream C sweep (do_inception_sweep --recommendation-fix) |
| [hook-threshold](/docs/generated/lib-hook-threshold) | calls | T-1631 (B-3b of T-1626) — hook-failure threshold rule. |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | calls | agents/git/lib/secret-scan.sh — Secret-scan library for the pre-commit hook (T-1844). |
| [large-file-scan](/docs/generated/agents-git-lib-large-file-scan) | calls | agents/git/lib/large-file-scan.sh — Large-file gate for the pre-commit hook (T-1845). |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | calls | T-1944 — Cron registry → generated dry-run helper. |
| [orchestrator-mcp-scan](/docs/generated/agents-audit-orchestrator-mcp-scan) | calls | orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641) |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [manifest](/docs/generated/agents-mcp-manifest) | calls | Manifest emission for the framework MCP server (T-2265): derives framework-mcp-manifest.json from policy/capability-overlay/tool-set.yaml, emitting the {name, gated} contract consumed by orchestrator-mcp-scan. |
| [workflow_coverage](/docs/generated/lib-workflow_coverage) | calls | workflow_coverage — audit-time check for workflow → dispatcher coverage. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [corpus_conformance](/docs/generated/tools-corpus_conformance) | calls | Map-conformance rail — corpus map assertions vs the enforced state machine. |
| [traceability](/docs/generated/lib-traceability) | calls | lib/traceability.sh — commit-traceability predicates (T-2851) |
| [cron-registry](/docs/generated/lib-cron-registry) | calls | lib/cron-registry.sh — T-2844 |
| [branch-hygiene](/docs/generated/lib-branch-hygiene) | calls | lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO) |
| [gitignore-register](/docs/generated/lib-gitignore-register) | calls | T-2994 (build slice of T-2992) — .gitignore rules that defer without a register. |
| [corpus_lint](/docs/generated/tools-corpus_lint) | calls | corpus_lint — per-map + cross-map lint for the designer corpus (T-2604). |
| [verify_queue](/docs/generated/lib-verify_queue) | calls | T-2765: re-run stored ## Verification for the human review queue. |
| [continuous-mode](/docs/generated/lib-continuous-mode) | calls | Continuous-run counters (T-3169, arc-012 S3). |
| [bats_red_attribution](/docs/generated/lib-bats_red_attribution) | calls | T-3126 — attribute each RED bats test to the paths it is about. |
| [watchtower-staleness](/docs/generated/lib-watchtower-staleness) | calls | T-2938: does the RUNNING Watchtower actually run the code on disk? |
| [audit-anchor-task](/docs/generated/lib-audit-anchor-task) | calls | T-1856 anchor_task existence detection — extracted from agents/audit/audit.sh by T-3356 so the check is reachable without running the whole `--section structure` block. |
| [exec-bit-drift](/docs/generated/lib-exec-bit-drift) | calls | lib/exec-bit-drift.sh — T-3317 (OBS-336): exec-bit drift detector. |
| [sidecar-audit](/docs/generated/lib-sidecar-audit) | calls | lib/sidecar-audit.sh — arc-011 sidecar slice 8 (T-3420). |
| [bvp-scorability](/docs/generated/lib-bvp-scorability) | calls | lib/bvp-scorability.sh — T-3428 (OBS-463 leg 3), arc-006. |
| [cron_exec_bit](/docs/generated/lib-cron_exec_bit) | calls | T-3380: scripts a deployed crontab invokes DIRECTLY must be executable. |
| [bats-dead-negation-lint](/docs/generated/tools-bats-dead-negation-lint) | calls | T-3138: find bats assertions that cannot fail. |
| [underpopulated](/docs/generated/agents-fabric-lib-underpopulated) | calls | Scan component cards for the under-populated class — a card that says nothing. |
| [fabric_doctor_facts](/docs/generated/lib-fabric_doctor_facts) | calls | Flatten `underpopulated.py --json` into one tab-separated line for `fw doctor`. |

## Used By (63)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `cron-audit` | triggers | Runs every 30 minutes via cron + on pre-push |
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [audit](/docs/generated/tests-unit-audit) | tested_by | Unit tests for agents/audit/audit.sh (11 tests) |
| [test_git_hooks](/docs/generated/tests-governance-test_git_hooks) | called_by | T-1607 (T-1601 GO follow-up, Phase 2): red-team harness for git hooks. |
| [test_git_hooks](/docs/generated/tests-governance-test_git_hooks) | tests_by | T-1607 (T-1601 GO follow-up, Phase 2): red-team harness for git hooks. |
| [audit](/docs/generated/tests-unit-audit) | called_by | Unit tests for agents/audit/audit.sh (11 tests) |
| [audit](/docs/generated/tests-unit-audit) | tests_by | Unit tests for agents/audit/audit.sh (11 tests) |
| [audit_flock](/docs/generated/tests-unit-audit_flock) | called_by | Unit tests for agents/audit/audit.sh flock guard (T-1464) Verifies foreground audits also flock-protect (lifted T-1162's QUIET-only guard). |
| [audit_flock](/docs/generated/tests-unit-audit_flock) | tests_by | Unit tests for agents/audit/audit.sh flock guard (T-1464) Verifies foreground audits also flock-protect (lifted T-1162's QUIET-only guard). |
| [audit_null_timestamp](/docs/generated/tests-unit-audit_null_timestamp) | called_by | Regression test — audit.sh METRICS_EOF heredoc must not crash when .context/project/metrics-history.yaml contains a null timestamp. Origin: handover S-2026-0423-1623 AttributeError: 'NoneType' at <stdin>:108. |
| [audit_null_timestamp](/docs/generated/tests-unit-audit_null_timestamp) | tests_by | Regression test — audit.sh METRICS_EOF heredoc must not crash when .context/project/metrics-history.yaml contains a null timestamp. Origin: handover S-2026-0423-1623 AttributeError: 'NoneType' at <stdin>:108. |
| [lib_pickup](/docs/generated/tests-unit-lib_pickup) | tests_by | Unit tests for lib/pickup.sh |
| [test_enrich_bats_parser](/docs/generated/tests-unit-test_enrich_bats_parser) | called_by | T-1754 — Regression tests for fabric enrich's .bats parser. |
| [test_arcs_routes](/docs/generated/tests-unit-test_arcs_routes) | called_by | Unit tests for /arcs and /arcs/<id> routes (T-1662) — Flask test_client pins index empty/populated, detail in-progress with three-question check, detail closed without check, 404 for unregistered, missing-task graceful render. |
| [test_pre_push_monotonic_ancestor](/docs/generated/tests-unit-test_pre_push_monotonic_ancestor) | tests_by | T-1843 / T-1829 — pre-push monotonicity gate, ancestor refinement. |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | called_by | T-1870 / CTL-028: completed/ frontmatter status consistency |
| [audit_ctl028_completed_status_consistency](/docs/generated/tests-unit-audit_ctl028_completed_status_consistency) | tests_by | T-1870 / CTL-028: completed/ frontmatter status consistency |
| [audit_ctl013_skip_nested_audit](/docs/generated/tests-unit-audit_ctl013_skip_nested_audit) | called_by | T-1870 / L-391: CTL-013 must skip verification lines that invoke `bin/fw audit` (or `fw audit`) — running them inside the audit lock always fails (lock held by the outer audit) and produces false-positive WARN. |
| [audit_ctl013_skip_nested_audit](/docs/generated/tests-unit-audit_ctl013_skip_nested_audit) | tests_by | T-1870 / L-391: CTL-013 must skip verification lines that invoke `bin/fw audit` (or `fw audit`) — running them inside the audit lock always fails (lock held by the outer audit) and produces false-positive WARN. |
| [arc_create_no_constituent_tasks](/docs/generated/tests-unit-arc_create_no_constituent_tasks) | tests_by | T-1851 (T-NEW-4): constituent_tasks: field deprecated for new arcs. |
| [audit_anchor_task_existence](/docs/generated/tests-unit-audit_anchor_task_existence) | called_by | T-1856 (T-NEW-8): anchor_task existence audit check. |
| [audit_anchor_task_existence](/docs/generated/tests-unit-audit_anchor_task_existence) | tests_by | T-1856 (T-NEW-8): anchor_task existence audit check. |
| [audit_arc_progress_arc_id](/docs/generated/tests-unit-audit_arc_progress_arc_id) | tests_by | T-1875 (T-NEW-11): audit arc-progress fallback unions arc_id frontmatter with legacy arc:<slug> tag scan. |
| [audit_ctl_arc_tag_only_pattern](/docs/generated/tests-unit-audit_ctl_arc_tag_only_pattern) | tests_by | T-1881 (T-NEW-16): pin the ctl-arc-tag-only-pattern audit check. |
| [audit_stale_arc_warning](/docs/generated/tests-unit-audit_stale_arc_warning) | called_by | T-1855 (T-NEW-7): stale-arc audit warning. |
| [audit_stale_arc_warning](/docs/generated/tests-unit-audit_stale_arc_warning) | tests_by | T-1855 (T-NEW-7): stale-arc audit warning. |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | called_by | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | called_by | T-2162 / CTL-030: completed/ stored-horizon drift detection |
| [audit_ctl030_completed_horizon_drift](/docs/generated/tests-unit-audit_ctl030_completed_horizon_drift) | tests_by | T-2162 / CTL-030: completed/ stored-horizon drift detection |
| [watchtower_health_verdict_identity](/docs/generated/tests-unit-watchtower_health_verdict_identity) | called_by | T-2445 (F9, T-2442 batch): Watchtower HEALTH-VERDICT call-sites must gate on the identity-verified resolver, never on a default-port `/health` curl. |
| [watchtower_health_verdict_identity](/docs/generated/tests-unit-watchtower_health_verdict_identity) | tests_by | T-2445 (F9, T-2442 batch): Watchtower HEALTH-VERDICT call-sites must gate on the identity-verified resolver, never on a default-port `/health` curl. |
| [cron_dry_run](/docs/generated/lib-cron_dry_run) | called_by | T-1944 — Cron registry → generated dry-run helper. |
| [comment_strip](/docs/generated/lib-comment_strip) | called_by | Structural HTML-comment stripping — the single canonical rule (T-2954). |
| [audit_corpus_lint_findings](/docs/generated/tests-unit-audit_corpus_lint_findings) | called_by | T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit. |
| [audit_corpus_lint_findings](/docs/generated/tests-unit-audit_corpus_lint_findings) | tests_by | T-2985 (arc-014, designer-corpus): corpus-lint findings reach the daily audit. |
| [audit_graduation_counter](/docs/generated/tests-unit-audit_graduation_counter) | called_by | T-2677 — audit graduation counter shape-agnostic (dead >=20 branch). |
| [audit_graduation_counter](/docs/generated/tests-unit-audit_graduation_counter) | tests_by | T-2677 — audit graduation counter shape-agnostic (dead >=20 branch). |
| [audit_root_commit_traceability](/docs/generated/tests-unit-audit_root_commit_traceability) | tests_by | T-2851 — the audit's commit-traceability check must exempt ROOT commits. |
| [audit_seed_corpus_refs](/docs/generated/tests-unit-audit_seed_corpus_refs) | called_by | T-2980 (arc-017, onboarding-curriculum): seed → corpus-map reference resolution. |
| [audit_seed_corpus_refs](/docs/generated/tests-unit-audit_seed_corpus_refs) | tests_by | T-2980 (arc-017, onboarding-curriculum): seed → corpus-map reference resolution. |
| [fabric_coverage_single_source](/docs/generated/tests-unit-fabric_coverage_single_source) | called_by | T-2735 — "which watched source files have no fabric card?" must have exactly ONE answer in audit.sh, and it must be the canonical expander's. |
| [fabric_coverage_single_source](/docs/generated/tests-unit-fabric_coverage_single_source) | tests_by | T-2735 — "which watched source files have no fabric card?" must have exactly ONE answer in audit.sh, and it must be the canonical expander's. |
| [fabric_watch_pattern_fitness](/docs/generated/tests-unit-fabric_watch_pattern_fitness) | called_by | T-2737 — the watch file is the denominator of every fabric coverage check, and nothing verified it fits the project `fw context init` stamped it into. |
| [fabric_watch_pattern_fitness](/docs/generated/tests-unit-fabric_watch_pattern_fitness) | tests_by | T-2737 — the watch file is the denominator of every fabric coverage check, and nothing verified it fits the project `fw context init` stamped it into. |
| [self_vendor_parity](/docs/generated/tests-unit-self_vendor_parity) | tests_by | T-2711: the self-vendor PRODUCER and the audit GATE must cover the same files. |
| [t2927_observation_inbox_listing](/docs/generated/tests-unit-t2927_observation_inbox_listing) | tests_by | T-2927 — the handover's observation-inbox section listed 1 of 112 pending observations, and said nothing about the other 111. |
| [t3049_fabric_url_location](/docs/generated/tests-unit-t3049_fabric_url_location) | called_by | T-3049 — a card's `location:` is not always a filesystem path. |
| [t3049_fabric_url_location](/docs/generated/tests-unit-t3049_fabric_url_location) | tests_by | T-3049 — a card's `location:` is not always a filesystem path. |
| [t3053_multiref_traceability](/docs/generated/tests-unit-t3053_multiref_traceability) | called_by | T-3053 — a commit subject may name more than one task. The traceability check read only the first ref, so a commit whose leading ref did not resolve was reported orphaned even when a later ref named a real task. |
| [t3053_multiref_traceability](/docs/generated/tests-unit-t3053_multiref_traceability) | tests_by | T-3053 — a commit subject may name more than one task. The traceability check read only the first ref, so a commit whose leading ref did not resolve was reported orphaned even when a later ref named a real task. |
| [test_audit_frontmatter_variants](/docs/generated/tests-unit-test_audit_frontmatter_variants) | called_by | T-2779: the audit's task-frontmatter check must see BOTH halves of the T-2069 class. |
| [test_index_doctor_rail](/docs/generated/tests-unit-test_index_doctor_rail) | called_by | The doctor/audit rail over the vector index — T-3013 (T-3005 slice 4). |
| [test_index_doctor_rail](/docs/generated/tests-unit-test_index_doctor_rail) | tests_by | The doctor/audit rail over the vector index — T-3013 (T-3005 slice 4). |
| [audit_timing](/docs/generated/lib-audit_timing) | called_by | T-3127: classify the persisted full-audit timing record against a warn fraction. |
| [config](/docs/generated/web-blueprints-config) | called_by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [sidecar_audit_rail](/docs/generated/tests-unit-sidecar_audit_rail) | tests_by | T-3420 — arc-011 sidecar slice 8: the audit rail over the consult ledger. |
| [t3421_prepush_lock_wait](/docs/generated/tests-unit-t3421_prepush_lock_wait) | tests_by | T-3421 — the pre-push audit-lock wait is derived from the measured audit. |
| [t3430_fabric_audit_doctor](/docs/generated/tests-unit-t3430_fabric_audit_doctor) | tests_by | T-3430: the audit + doctor surfaces for under-populated fabric cards. |
| [test_t3430_describe](/docs/generated/tests-unit-test_t3430_describe) | called_by | T-3430 — the fabric card deriver: what a file says about itself, or a refusal. |
| [bats-dead-negation-lint](/docs/generated/tools-bats-dead-negation-lint) | called_by | T-3138: find bats assertions that cannot fail. |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-955: Audit loop merge — combine 10 loops into 3 passes (T-860 Phase 1)

---
*Auto-generated from Component Fabric. Card: `audit-yaml-validator.yaml`*
*Last verified: 2026-02-20*
