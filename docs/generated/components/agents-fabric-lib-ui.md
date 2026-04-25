# ui

> Fabric Agent - UI query commands

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/lib/ui.sh`

## What It Does

Fabric Agent - UI query commands
Implements: fw fabric ui

### Framework Reference

| Factor | Rule |
|--------|------|
| Max parallel agents | **5** (T-073 used 9 → context explosion; T-061 used 4, T-086 used 5 → fine) |
| Token headroom | Leave **40K tokens** free for result ingestion before dispatching |
| When parallel | Tasks are independent, no shared files, no sequential dependency |
| When sequential | Tasks depend on prior results, or editing same files |
| Background agents | Use `run_in_background: true` for agents >2K tokens expected output |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/fabric/fabric.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-ui.yaml`*
*Last verified: 2026-02-20*
