# harvest

> fw harvest - Collect learnings from projects back into the framework

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/harvest.sh`

## What It Does

fw harvest - Collect learnings from projects back into the framework
Reads a project's .context/ directory and identifies patterns, learnings,
and decisions that could be promoted to the framework level.
Graduation pipeline:
1 project  = local (stays in project)
2+ projects = candidate (proposed for framework)
3+ projects = practice (promoted to framework)

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_harvest](/docs/generated/tests-unit-lib_harvest) | called-by | Unit tests for lib/harvest.sh |
| [lib_harvest](/docs/generated/tests-unit-lib_harvest) | called_by | Unit tests for lib/harvest.sh |
| [lib_harvest](/docs/generated/tests-unit-lib_harvest) | tests_by | Unit tests for lib/harvest.sh |
| [harvest_indent_agnostic](/docs/generated/tests-unit-harvest_indent_agnostic) | called_by | T-2676 — harvest.sh indent-agnostic entry greps (dead learnings/patterns sub-stages). Third instance of the indentation-assumption class (T-2672 resolve.sh emit-indent, 832 T-295 field report). |
| [harvest_indent_agnostic](/docs/generated/tests-unit-harvest_indent_agnostic) | tests_by | T-2676 — harvest.sh indent-agnostic entry greps (dead learnings/patterns sub-stages). Third instance of the indentation-assumption class (T-2672 resolve.sh emit-indent, 832 T-295 field report). |
| [t2927_observation_inbox_listing](/docs/generated/tests-unit-t2927_observation_inbox_listing) | tests_by | T-2927 — the handover's observation-inbox section listed 1 of 112 pending observations, and said nothing about the other 111. |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-harvest.yaml`*
*Last verified: 2026-02-20*
