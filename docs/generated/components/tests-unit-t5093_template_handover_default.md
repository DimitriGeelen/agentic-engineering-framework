# t5093_template_handover_default

> T-5093 (GitHub #113) — the consumer CLAUDE.md template called plain `handover.sh` a "manual commit", while handover.sh commits AND pushes by default (AUTO_COMMIT=true; --no-commit turns it off).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5093_template_handover_default.bats`

## What It Does

T-5093 (GitHub #113) — the consumer CLAUDE.md template called plain `handover.sh` a "manual
commit", while handover.sh commits AND pushes by default (AUTO_COMMIT=true; --no-commit turns
it off). An agent that followed the template got a skeleton handover pushed before it could
fill the [TODO] sections. Pin the template to the script's real behaviour.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5093_template_handover_default.yaml`*
*Last verified: 2026-11-12*
