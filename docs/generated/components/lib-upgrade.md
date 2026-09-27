# upgrade

> fw upgrade - Sync framework improvements to a consumer project

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/upgrade.sh`

## What It Does

fw upgrade - Sync framework improvements to a consumer project
Runs in a consumer project directory, reads .framework.yaml to find the
framework, then updates governance sections, templates, hooks, and seeds.
Project-specific content is preserved.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [version-relation](/docs/generated/lib-version-relation) | calls | T-2713 — one truthful answer to "is this consumer ahead or behind?". |
| [hook_portability](/docs/generated/lib-hook_portability) | calls | Single source of truth for "is this hook command host-portable?" (T-2709). |

## Used By (28)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_upgrade](/docs/generated/tests-unit-lib_upgrade) | called-by | Unit tests for lib/upgrade.sh |
| [lib_upgrade](/docs/generated/tests-unit-lib_upgrade) | called_by | Unit tests for lib/upgrade.sh |
| [hook_absolute_paths](/docs/generated/tests-unit-hook_absolute_paths) | called_by | Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts. |
| [lib_upgrade](/docs/generated/tests-unit-lib_upgrade) | tests_by | Unit tests for lib/upgrade.sh |
| [upgrade_dedupe_user_hooks](/docs/generated/tests-unit-upgrade_dedupe_user_hooks) | called_by | T-1481 — `fw upgrade --dedupe-user-hooks` opt-in remediation. Removes framework hooks from $HOME/.claude/settings.json that duplicate the project-level config; always backs up first. |
| [upgrade_dedupe_user_hooks](/docs/generated/tests-unit-upgrade_dedupe_user_hooks) | tests_by | T-1481 — `fw upgrade --dedupe-user-hooks` opt-in remediation. Removes framework hooks from $HOME/.claude/settings.json that duplicate the project-level config; always backs up first. |
| [upgrade_duplicate_hook_detection](/docs/generated/tests-unit-upgrade_duplicate_hook_detection) | called_by | T-1479 — fw upgrade detects when framework hooks are registered at both user-level (~/.claude/settings.json) and project-level (.claude/settings.json), warning the consumer (does NOT auto-remove user state). |
| [upgrade_duplicate_hook_detection](/docs/generated/tests-unit-upgrade_duplicate_hook_detection) | tests_by | T-1479 — fw upgrade detects when framework hooks are registered at both user-level (~/.claude/settings.json) and project-level (.claude/settings.json), warning the consumer (does NOT auto-remove user state). |
| [test_upgrade_downgrade_guard](/docs/generated/tests-unit-test_upgrade_downgrade_guard) | called_by | T-1839 — fw upgrade silent-downgrade guard. |
| [test_upgrade_downgrade_guard](/docs/generated/tests-unit-test_upgrade_downgrade_guard) | tests_by | T-1839 — fw upgrade silent-downgrade guard. |
| [upgrade_fresh_machine_simulation](/docs/generated/tests-unit-upgrade_fresh_machine_simulation) | tests_by | T-1635: fresh-machine simulation guard for fw upgrade. |
| [test_self_vendor_agents_md_filter](/docs/generated/tests-unit-test_self_vendor_agents_md_filter) | tests_by | T-2304 (OBS-068): regression test for _self_vendor_agents .md filter |
| [test_self_vendor_libs_md_filter](/docs/generated/tests-unit-test_self_vendor_libs_md_filter) | called_by | T-2307 (T-2304 follow-on): `_self_vendor_libs` extended to recursive + `*.md` filter. |
| [test_self_vendor_libs_md_filter](/docs/generated/tests-unit-test_self_vendor_libs_md_filter) | tests_by | T-2307 (T-2304 follow-on): `_self_vendor_libs` extended to recursive + `*.md` filter. |
| [hook_parity](/docs/generated/lib-hook_parity) | called_by | Hook-set extraction and comparison — ONE definition, every caller (T-3112/T-3113). |
| [self_vendor_parity](/docs/generated/tests-unit-self_vendor_parity) | called_by | T-2711: the self-vendor PRODUCER and the audit GATE must cover the same files. |
| [self_vendor_parity](/docs/generated/tests-unit-self_vendor_parity) | tests_by | T-2711: the self-vendor PRODUCER and the audit GATE must cover the same files. |
| [t2759_upgrade_target_dir_shadowing](/docs/generated/tests-unit-t2759_upgrade_target_dir_shadowing) | tests_by | T-2759: `fw upgrade` must never write a consumer's files somewhere else and then report success. |
| [t2912_upgrade_hook_regen_convergence](/docs/generated/tests-unit-t2912_upgrade_hook_regen_convergence) | tests_by | End-to-end (real fw init'd consumer, env -i) proof that fw upgrade's hook-regeneration step reports its own verified effect instead of the pre-write trigger — a regen that cannot supply a detected-missing hook must report FAILED/PARTIAL, not UPDATED, on every run, and must not write a fresh .bak for a no-op. |
| [t3112_worktree_hook_parity](/docs/generated/tests-unit-t3112_worktree_hook_parity) | tests_by | T-3112: fw doctor audits linked worktrees for enforcement drift (R7 leg L3). |
| [t3113_upgrade_worktree_advisory](/docs/generated/tests-unit-t3113_upgrade_worktree_advisory) | tests_by | T-3113: `fw upgrade` names which linked worktrees are behind (R7 leg L4). |
| [version_relation](/docs/generated/tests-unit-version_relation) | tests_by | T-2713: consumer-vs-framework version relation must come from git ancestry, never from `sort -V` over the VERSION counter. |
| [t2912_upgrade_hook_regen_convergence](/docs/generated/tests-unit-t2912_upgrade_hook_regen_convergence) | called_by | End-to-end (real fw init'd consumer, env -i) proof that fw upgrade's hook-regeneration step reports its own verified effect instead of the pre-write trigger — a regen that cannot supply a detected-missing hook must report FAILED/PARTIAL, not UPDATED, on every run, and must not write a fresh .bak for a no-op. |
| [t3113_upgrade_worktree_advisory](/docs/generated/tests-unit-t3113_upgrade_worktree_advisory) | called_by | T-3113: `fw upgrade` names which linked worktrees are behind (R7 leg L4). |
| [test_self_vendor_agents_md_filter](/docs/generated/tests-unit-test_self_vendor_agents_md_filter) | called_by | T-2304 (OBS-068): regression test for _self_vendor_agents .md filter |
| [hook_portability](/docs/generated/lib-hook_portability) | called_by | Single source of truth for "is this hook command host-portable?" (T-2709). |
| [upgrade_marked_region](/docs/generated/tests-unit-upgrade_marked_region) | tests_by | T-3150 — `fw upgrade` step [1/10] rebuilt a consumer's CLAUDE.md as (everything above `## Core Principle`) + (framework governance). |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-857: fw upgrade sync gap — lib/, agents/task-create/, agents/handover/, agents/git/ not vendored to consumer projects
- T-858: Update fw upgrade help text with new sync targets
- T-859: Fix fw upgrade VERSION file sync to vendored .agentic-framework/
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `lib-upgrade.yaml`*
*Last verified: 2026-02-20*
