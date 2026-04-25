# patterns

> Healing Agent - patterns command

**Type:** script | **Subsystem:** healing | **Location:** `agents/healing/lib/patterns.sh`

## What It Does

Healing Agent - patterns command
Show known failure patterns and mitigations

### Framework Reference

- **Parallel investigation / audit / enrichment:** 3-5 Task agents scan independent aspects; each writes findings to disk, returns path + summary. Cap at 5 parallel. Use `fw bus post` for formal tracking.
- **Sequential TDD:** Fresh agent per implementation task with review between.
- **TermLink parallel workers:** Spawn TermLink sessions for isolated heavy work. `termlink interact --json` for sync commands, `termlink pty inject/output` for interactive control. Cleanup with `termlink signal SIGTERM` + `termlink clean`. Preferred over Task agents when context isolation matters.

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/healing/healing.sh` | called_by |

## Documentation

- [Deep Dive: The Healing Loop](docs/articles/deep-dives/05-healing-loop.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-healing-lib-patterns.yaml`*
*Last verified: 2026-02-20*
