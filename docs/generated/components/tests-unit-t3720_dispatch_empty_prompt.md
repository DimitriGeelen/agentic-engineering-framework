# t3720_dispatch_empty_prompt

> T-3720 — a failed prompt write left empty prompt files, and `fw termlink dispatch` spawned workers whose whole prompt was the sidecar consult stanza. Dispatch must refuse an empty or whitespace-only prompt before any worker exists.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3720_dispatch_empty_prompt.bats`

## What It Does

T-3720 — a failed prompt write left empty prompt files, and `fw termlink dispatch`
spawned workers whose whole prompt was the sidecar consult stanza. Dispatch must
refuse an empty or whitespace-only prompt before any worker exists.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3720_dispatch_empty_prompt.yaml`*
*Last verified: 2026-10-20*
