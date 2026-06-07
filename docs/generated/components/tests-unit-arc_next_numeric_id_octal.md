# arc_next_numeric_id_octal

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/arc_next_numeric_id_octal.bats`

## What It Does

T-1877 (T-NEW-13): _arc_next_numeric_id must allocate IDs across the 008/009
boundary without bash octal-parse errors.
Bug: `max="009"` (string) being fed into `$((max + 1))` errors with "value too
great for base" because bash arithmetic expansion interprets `008`/`009` as
invalid octal. POSIX `[ -gt ]` is leading-zero tolerant; `$(( ))` is not. The
fix normalizes via `10#` prefix.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_next_numeric_id_octal.yaml`*
*Last verified: 2026-05-17*
