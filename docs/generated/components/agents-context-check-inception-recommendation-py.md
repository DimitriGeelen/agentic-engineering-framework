# check-inception-recommendation

> T-2205 (T-2204 Slice B): PreToolUse Write/Edit hook — refuse save when an inception task has a template-only `## Recommendation` block under

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-inception-recommendation.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook_paths](/docs/generated/lib-hook_paths) | calls | Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd. |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [hook_paths](/docs/generated/lib-hook_paths) | uses | Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-inception-recommendation](/docs/generated/agents-context-check-inception-recommendation) | called_by | T-2205: PreToolUse Write/Edit hook — refuse save when inception task has template-only ## Recommendation block under $CLAUDECODE=1. |
| [check-onboarding-gate](/docs/generated/agents-context-check-onboarding-gate-py) | called_by | T-2815: refuse Write/Edit that adds an agent-unresolvable task to the gated onboarding set (T-532's check-active-task.sh onboarding block). |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-inception-recommendation-py.yaml`*
*Last verified: 2026-09-03*
