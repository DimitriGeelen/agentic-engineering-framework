# fabric

> Fabric Agent - Component topology system for codebase self-awareness

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/fabric.sh`

## What It Does

Fabric Agent - Component topology system for codebase self-awareness
Commands:
register <path>     Create component card for a file
scan                Batch-create skeleton cards for unregistered files
search <keyword>    Search components by tags, name, purpose
get <component>     Show full component card
deps <file-path>    Show dependencies for a file (what it uses + what uses it)
impact <file-path>  Full transitive downstream chain
blast-radius [ref]  Downstream impact of a commit (default: HEAD)
ui <route>          Interactive elements on a route

### Framework Reference

The Component Fabric (`.fabric/`) is a structural topology map of every significant file — each component has a YAML card in `.fabric/components/` with id, name, type, subsystem, location, purpose, interfaces, depends_on, depended_by.

**When to use:** before modifying a file → `fw fabric deps <path>`; before committing → `fw fabric blast-radius [ref]`; after creating a new file → `fw fabric register <path>`; periodic health → `fw fabric drift` (detects unregistered/orphaned/stale). Also: `fw fabric overview` for the subsystem summary, `fw fabric impact <path>` for the full downstream chain, `

*(truncated — see CLAUDE.md for full section)*

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [register](/docs/generated/agents-fabric-lib-register) | calls | Fabric Agent - register and scan commands |
| [query](/docs/generated/agents-fabric-lib-query) | calls | Fabric Agent - query commands |
| [traverse](/docs/generated/agents-fabric-lib-traverse) | calls | Fabric Agent - graph traversal commands |
| [ui](/docs/generated/agents-fabric-lib-ui) | calls | Fabric Agent - UI query commands |
| [drift](/docs/generated/agents-fabric-lib-drift) | calls | Fabric Agent - drift detection commands |
| [summary](/docs/generated/agents-fabric-lib-summary) | calls | Fabric Agent - summary and onboarding commands |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | called_by | Session Resume Hook — Reinject structured context on session recovery |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [check-fabric-new-file](/docs/generated/agents-context-check-fabric-new-file) | called_by | PostToolUse hook: detect new files created by Write tool — prompts fabric registration for structural tracking. |
| [fabric](/docs/generated/tests-unit-fabric) | tested_by | Unit tests for agents/fabric/fabric.sh (10 tests) |
| [fabric](/docs/generated/tests-unit-fabric) | called_by | Unit tests for agents/fabric/fabric.sh (10 tests) |
| [fabric](/docs/generated/tests-unit-fabric) | tests_by | Unit tests for agents/fabric/fabric.sh (10 tests) |

## Documentation

- [Deep Dive: Component Fabric](docs/articles/deep-dives/07-component-fabric.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-fabric-fabric.yaml`*
*Last verified: 2026-02-20*
