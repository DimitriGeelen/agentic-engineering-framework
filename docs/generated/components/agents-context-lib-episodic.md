# episodic

> Context Agent - generate-episodic command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/episodic.sh`

## What It Does

Context Agent - generate-episodic command
Generate rich episodic summary for a completed task
Hybrid approach (D-023): Git owns timeline/metrics/artifacts,
task file owns AC + decisions, episodic merges both automatically.

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `C-001` | called_by |
| `agents/context/context.sh` | called-by |
| `tests/unit/context_episodic.bats` | called_by |
| `tests/unit/context_episodic.bats` | tests_by |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-episodic.yaml`*
*Last verified: 2026-02-20*
