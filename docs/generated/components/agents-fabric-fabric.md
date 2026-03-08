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

The Component Fabric (`.fabric/`) is a structural topology map of every significant file in the framework. It enables impact analysis, dependency tracking, and onboarding.

### When to Use

- **Before modifying a file:** `fw fabric deps <path>` — see what depends on it and what it depends on
- **Before committing:** `fw fabric blast-radius` — see downstream impact of your changes
- **After creating new files:** `fw fabric register <path>` — create a component card
- **Periodic health check:** `fw fabric drift` — detect unregistered, orphaned, or stale components

### Key Commands

*(truncated — see CLAUDE.md for full section)*

## Dependencies (6)

| Target | Relationship |
|--------|-------------|
| `agents/fabric/lib/register.sh` | calls |
| `agents/fabric/lib/query.sh` | calls |
| `agents/fabric/lib/traverse.sh` | calls |
| `agents/fabric/lib/ui.sh` | calls |
| `agents/fabric/lib/drift.sh` | calls |
| `agents/fabric/lib/summary.sh` | calls |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `agents/context/post-compact-resume.sh` | called_by |
| `bin/fw` | called_by |

## Documentation

- [Deep Dive: Component Fabric](docs/articles/deep-dives/07-component-fabric.md) (deep-dive)

## Related

### Tasks
- T-208: Component Fabric — agent structure and fw routing

---
*Auto-generated from Component Fabric. Card: `agents-fabric-fabric.yaml`*
*Last verified: 2026-02-20*
