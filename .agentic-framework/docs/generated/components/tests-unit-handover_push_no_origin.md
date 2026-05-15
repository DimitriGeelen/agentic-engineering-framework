# handover_push_no_origin

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/handover_push_no_origin.bats`

## What It Does

T-1474 — handover.sh mirror-skip must guard on origin presence.
Bug: `if [ "$_remote_count" -gt 1 ] && [ "$remote_name" != "origin" ]` skips
every remote when no remote is named `origin`. Symptom: `fw handover --commit`
in the framework repo (which has `github` + `onedev`, no `origin`) skips both
every time. Fix: gate the skip on `_has_origin = true`.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/handover/handover.sh` | calls |
| `agents/handover/handover.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_push_no_origin.yaml`*
*Last verified: 2026-04-25*
