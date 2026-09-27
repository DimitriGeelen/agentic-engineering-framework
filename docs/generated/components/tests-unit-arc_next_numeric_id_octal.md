# arc_next_numeric_id_octal

> T-1877 (T-NEW-13): _arc_next_numeric_id must allocate IDs across the 008/009 boundary without bash octal-parse errors.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/arc_next_numeric_id_octal.bats`

## What It Does

T-1877 (T-NEW-13): _arc_next_numeric_id must allocate IDs across the 008/009
boundary without bash octal-parse errors.
Bug: `max="009"` (string) being fed into `$((max + 1))` errors with "value too
great for base" because bash arithmetic expansion interprets `008`/`009` as
invalid octal. POSIX `[ -gt ]` is leading-zero tolerant; `$(( ))` is not. The
fix normalizes via `10#` prefix.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arc](/docs/generated/lib-arc) | tests | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-arc_next_numeric_id_octal.yaml`*
*Last verified: 2026-05-17*
