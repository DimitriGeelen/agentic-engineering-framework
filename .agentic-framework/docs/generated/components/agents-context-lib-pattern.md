# pattern

> Context Agent - add-pattern command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/pattern.sh`

## What It Does

Context Agent - add-pattern command
Add a pattern to project memory

### Framework Reference

- **Parallel investigation / audit / enrichment:** 3-5 Task agents scan independent aspects; each writes findings to disk, returns path + summary. Cap at 5 parallel. Use `fw bus post` for formal tracking.
- **Sequential TDD:** Fresh agent per implementation task with review between.
- **TermLink parallel workers:** Spawn TermLink sessions for isolated heavy work. `termlink interact --json` for sync commands, `termlink pty inject/output` for interactive control. Cleanup with `termlink signal SIGTERM` + `termlink clean`. Preferred over Task agents when context isolation matters.

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `C-001` | called_by |
| `agents/context/context.sh` | called-by |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-pattern.yaml`*
*Last verified: 2026-02-20*
