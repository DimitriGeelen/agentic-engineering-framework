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

| Target | Relationship |
|--------|-------------|
| `agents/fabric/lib/register.sh` | calls |
| `agents/fabric/lib/query.sh` | calls |
| `agents/fabric/lib/traverse.sh` | calls |
| `agents/fabric/lib/ui.sh` | calls |
| `agents/fabric/lib/drift.sh` | calls |
| `agents/fabric/lib/summary.sh` | calls |
| `lib/paths.sh` | calls |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `agents/context/post-compact-resume.sh` | called_by |
| `bin/fw` | called_by |
| `agents/context/check-fabric-new-file.sh` | called_by |
| `tests/unit/fabric.bats` | tested_by |
| `tests/unit/fabric.bats` | called_by |

## Documentation

- [Deep Dive: Component Fabric](docs/articles/deep-dives/07-component-fabric.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-fabric-fabric.yaml`*
*Last verified: 2026-02-20*
