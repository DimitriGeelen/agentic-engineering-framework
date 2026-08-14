# gaps_close

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/gaps_close.bats`

## What It Does

T-2185 — `fw gaps close <id>` flips gauge-READY gaps to status:closed.
Contract:
- Happy path: gap with status:watching + gauge=READY → status flips,
closed_date set, closure_notes inserted, JSONL audit appended.
- Refuse 404 when gap_id is absent.
- Refuse 409 when gap is not status:watching (already closed).
- Refuse 412 when gauge is NOT_READY or UNKNOWN (no command).
- Override path: 412 + --override --rationale "..." closes the gap and
writes the rationale into closure_notes + audit log.
- Atomic write does not corrupt sibling gap entries.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-gaps_close.yaml`*
*Last verified: 2026-06-03*
