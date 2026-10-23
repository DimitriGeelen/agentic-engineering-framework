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
| Token headroom | Keep the **spawn reserve** free before dispatching: 20K at a 200K window, rising 5% of the window above 200K, capped at 50K (§Parallelism limits, T-4225) |
| When parallel | Tasks are independent, no shared files, no sequential dependency |
| When sequential | Tasks depend on prior results, or editing same files |
| Background agents | Use `run_in_background: true` for agents >2K tokens expected output |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fabric](/docs/generated/agents-fabric-fabric) | called_by | Fabric Agent - Component topology system for codebase self-awareness |

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-ui.yaml`*
*Last verified: 2026-02-20*
