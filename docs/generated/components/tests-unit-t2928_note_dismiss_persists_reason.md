# t2928_note_dismiss_persists_reason

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2928_note_dismiss_persists_reason.bats`

## What It Does

T-2928 — `fw note dismiss OBS-NNN --reason "..."` accepted the reason,
printed it, and discarded it.
do_dismiss parsed --reason into a local, used it in exactly one place (the
confirmation echo) and wrote:
_sed_i "/id: $obs_id/,/promoted_to:/{s/status: pending/status: dismissed/}"
`status: dismissed` and nothing else. The reason went to a terminal nobody
archives while the success line quoted it back on the way out — which
manufactures confidence at exactly the moment someone is being careful.
The cost is not lost prose. A dismissed observation with no reason cannot
answer the only question anyone asks of one: was this judged and closed, or

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [observe](/docs/generated/agents-observe-observe) | calls | Observe Agent - Lightweight observation capture |
| [observe](/docs/generated/agents-observe-observe) | tests | Observe Agent - Lightweight observation capture |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2928_note_dismiss_persists_reason.yaml`*
*Last verified: 2026-08-11*
