# init

> Context Agent - init command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/init.sh`

## What It Does

Context Agent - init command
Initializes working memory for a new session

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `C-001` | called_by |
| `agents/context/session-metrics.sh` | used-by |
| `agents/context/context.sh` | called-by |
| `agents/context/session-metrics.sh` | read_by |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

## Related

### Tasks
- T-850: Fix session metrics — per-session deltas instead of cumulative transcript analysis
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-init.yaml`*
*Last verified: 2026-02-20*
