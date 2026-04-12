# colors

> Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/colors.sh`

## What It Does

lib/colors.sh — Shared color variables for the Agentic Engineering Framework
Provides TTY-aware, NO_COLOR-respecting color variables.
Replaces inline color definitions duplicated across 20+ scripts.
Usage: source "$FRAMEWORK_ROOT/lib/colors.sh"
Variables: RED, GREEN, YELLOW, CYAN, BOLD, NC
Automatically sourced via lib/errors.sh → lib/paths.sh chain.
Scripts that source lib/paths.sh get colors for free.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/colors.sh` | calls |

## Used By (8)

| Component | Relationship |
|-----------|-------------|
| `lib/colors.sh` | called-by |
| `lib/costs.sh` | called-by |
| `tests/unit/lib_colors.bats` | called-by |
| `agents/handover/handover.sh` | called_by |
| `bin/fw` | called_by |
| `lib/colors.sh` | called_by |
| `lib/costs.sh` | called_by |
| `tests/unit/lib_colors.bats` | called_by |

## Related

### Tasks
- T-760: Fix shellcheck warnings in core lib scripts (bus.sh, dispatch.sh, colors.sh)
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-colors.yaml`*
*Last verified: 2026-03-11*
