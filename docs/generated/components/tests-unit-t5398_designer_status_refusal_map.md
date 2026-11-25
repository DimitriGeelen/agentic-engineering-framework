# t5398_designer_status_refusal_map

> T-5398: `fw designer status` checks that the validator refusal mapping names the pinned validator.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5398_designer_status_refusal_map.bats`

## What It Does

T-5398: `fw designer status` checks that the validator refusal mapping names the
pinned validator. T-5390 re-pinned 0.47.0 -> 0.48.1 without the mapping edit and every
pickup check stayed green; test_t5189 went red later, at an unrelated close.
Hermetic: a throwaway project root with its own pin, build and mapping.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5398_designer_status_refusal_map.yaml`*
*Last verified: 2026-11-24*
