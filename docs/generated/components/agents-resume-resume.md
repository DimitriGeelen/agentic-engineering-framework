# resume

> Resume Agent - Post-compaction recovery and state synchronization

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/resume/resume.sh`

## What It Does

Resume Agent - Post-compaction recovery and state synchronization
Synthesizes current state from handover, working memory, git, and tasks

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [bvp-estimator](/docs/generated/agents-termlink-bvp-estimator-bvp-estimator) | calls | TermLink worker entry point for the BVP estimator (T-1922): thin shell wrapper forwarding to estimator.py per the agents/<name>/<name>.sh convention. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [resume](/docs/generated/tests-unit-resume) | tested_by | Unit tests for agents/resume/resume.sh (12 tests) |
| [resume](/docs/generated/tests-unit-resume) | called_by | Unit tests for agents/resume/resume.sh (12 tests) |
| [resume](/docs/generated/tests-unit-resume) | tests_by | Unit tests for agents/resume/resume.sh (12 tests) |
| [t3431_fabric_session_start](/docs/generated/tests-unit-t3431_fabric_session_start) | tests_by | T-3431 (D-592): SessionStart hook (post-compact-resume.sh) runs a bounded `fw fabric enrich --describe --quiet` on every start/resume/compact and injects one summary line; `fw resume status` mirrors the cached line rather than re-running… |

## Related

### Tasks
- T-794: Fix shellcheck SC2155 warnings in resume.sh — split declare and assign
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-resume-resume.yaml`*
*Last verified: 2026-02-20*
