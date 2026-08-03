# t2457_fabric_atomic_card_write

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2457_fabric_atomic_card_write.bats`

## What It Does

T-2457 / OBS-080: fabric card writes must be atomic.
Bug: both card writers truncated-then-streamed the destination card:
- register.sh:266  `cat > "$card_file" << EOF`
- enrich.py:34     `with open(path, "w") as f:`
A concurrent reader — notably `fw fabric drift` building its registered set
via `grep "^location:" "$COMPONENTS_DIR"/*.yaml` — could observe a card after
truncation but before the `location:` line was written. That card's source
path then dropped out of the registered set, so the file it points to was
reported "unregistered" — a spurious FP that cleared on immediate re-run once
the write completed (observed 2x during T-2440, which was actively

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [register](/docs/generated/agents-fabric-lib-register) | calls | Fabric Agent - register and scan commands |
| [register](/docs/generated/agents-fabric-lib-register) | tests | Fabric Agent - register and scan commands |
| [pickup](/docs/generated/lib-pickup) | tests | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2457_fabric_atomic_card_write.yaml`*
*Last verified: 2026-06-22*
