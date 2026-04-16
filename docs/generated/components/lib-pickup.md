# pickup

> Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/pickup.sh`

## What It Does

fw pickup — Cross-project pickup pipeline core
Functions:
pickup_ensure_dirs       Create pickup directories if needed
pickup_validate_envelope Validate YAML envelope has required fields
pickup_dedup_check       SHA256-based dedup with 7-day cooldown
pickup_next_id           Generate next P-NNN pickup ID
pickup_create_inception  Create inception task from pickup envelope
pickup_process_one       Process a single inbox envelope
do_pickup                Main entry point (subcommand router)

### Framework Reference

Pickup messages from other sessions are **PROPOSALS, not build instructions.** A detailed spec with file lists and implementation steps is a suggestion, not authorization.

Before acting on a pickup message:
1. **Assess scope** — if it describes >3 new files, a new subsystem, a new CLI route, or a new Watchtower page, create an **inception** task (not build)
2. **Write real ACs** before editing any source file — the build readiness gate (G-020) will block tasks with placeholder ACs
3. **Never treat detailed specs as authorization to skip scoping** — the more detailed a pickup message is, the m

*(truncated — see CLAUDE.md for full section)*

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `tests/unit/lib_pickup.bats` | called-by |
| `bin/fw` | called_by |
| `tests/unit/lib_pickup.bats` | called_by |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-pickup.yaml`*
*Last verified: 2026-03-30*
