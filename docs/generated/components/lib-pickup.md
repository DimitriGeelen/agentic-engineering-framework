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

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [lib_pickup](/docs/generated/tests-unit-lib_pickup) | called-by | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_pickup](/docs/generated/tests-unit-lib_pickup) | called_by | TODO: describe what this component does |
| [pickup-channel-bridge](/docs/generated/lib-pickup-channel-bridge) | called_by_by | One-way bridge from shell pickup to T-1155 channel bus. Invoked by pickup_process_one (lib/pickup.sh) after an envelope moves to processed/. Mirrors the envelope to 'framework:pickup' topic so online bus subscribers observe pickups alongside shell consumers. Non-fatal (exits 0 on any error); capability-probing (prefers termlink channel post; falls back to event broadcast; silent no-op if neither present). T-1165/T-1214 GO Option B: federate, don't converge. |
| [lib_pickup](/docs/generated/tests-unit-lib_pickup) | tests_by | TODO: describe what this component does |
| [pickup_send_remote_session](/docs/generated/tests-unit-pickup_send_remote_session) | called_by | TODO: describe what this component does |
| [pickup_send_remote_session](/docs/generated/tests-unit-pickup_send_remote_session) | tests_by | TODO: describe what this component does |
| [pickup_type_routing](/docs/generated/tests-unit-pickup_type_routing) | called_by | TODO: describe what this component does |
| [pickup_type_routing](/docs/generated/tests-unit-pickup_type_routing) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-pickup.yaml`*
*Last verified: 2026-03-30*
