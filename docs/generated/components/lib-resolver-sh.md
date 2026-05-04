# resolver-shim

> Thin shell shim that routes `fw resolver` invocations to lib/resolver.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/resolver.sh`

**Tags:** `orchestrator-arc`, `shim`, `T-1696`

## What It Does

Thin shim — routes `fw resolver` to lib/resolver.py.
Origin: T-1696 (production port of T-1689 inception spike).
Per D-073: single Python module + thin shell shim — no script-level logic
beyond PROJECT_ROOT export and argv passthrough.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/resolver.py` | calls |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `lib-resolver-sh.yaml`*
