# healing

> Healing Agent - Antifragile error recovery and pattern learning

**Type:** script | **Subsystem:** healing | **Location:** `agents/healing/healing.sh`

## What It Does

Healing Agent - Antifragile error recovery and pattern learning
Commands:
diagnose T-XXX    Analyze task issues, suggest recovery
resolve T-XXX     Mark issue resolved, log pattern
patterns          Show known failure patterns
suggest           Get suggestions for current issues
Usage:
./agents/healing/healing.sh diagnose T-015
./agents/healing/healing.sh resolve T-015 --mitigation "Added retry logic"
./agents/healing/healing.sh patterns

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [diagnose](/docs/generated/agents-healing-lib-diagnose) | calls | Healing Agent - diagnose command |
| [resolve](/docs/generated/agents-healing-lib-resolve) | calls | Healing Agent - resolve command |
| [patterns](/docs/generated/agents-healing-lib-patterns) | calls | Healing Agent - patterns command |
| [suggest](/docs/generated/agents-healing-lib-suggest) | calls | Healing Agent - suggest command |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [healing_diagnose](/docs/generated/tests-unit-healing_diagnose) | called-by | Unit tests for healing diagnose (26 tests) |
| [healing_suggest](/docs/generated/tests-unit-healing_suggest) | called-by | Unit tests for healing suggest (9 tests) |
| [healing_diagnose](/docs/generated/tests-unit-healing_diagnose) | called_by | Unit tests for healing diagnose (26 tests) |
| [healing_suggest](/docs/generated/tests-unit-healing_suggest) | called_by | Unit tests for healing suggest (9 tests) |

## Documentation

- [Deep Dive: The Healing Loop](docs/articles/deep-dives/05-healing-loop.md) (deep-dive)

## Related

### Tasks
- T-796: Fix remaining single-warning shellcheck issues in agent scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-871: Fix unbound PATTERNS_FILE variable in healing agent
- T-872: Sync vendored healing.sh with T-871 fix

---
*Auto-generated from Component Fabric. Card: `agents-healing-healing.yaml`*
*Last verified: 2026-02-20*
