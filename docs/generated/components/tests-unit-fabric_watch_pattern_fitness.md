# fabric_watch_pattern_fitness

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/fabric_watch_pattern_fitness.bats`

## What It Does

T-2737 — the watch file is the denominator of every fabric coverage check,
and nothing verified it fits the project `fw context init` stamped it into.
832 (rail-398) measured the untailored default on their tree: it expands to
ZERO files, so both coverage checks compared an empty set against the registry
and printed complete coverage. Their real population was 115 files, 15 carded
— 13%, reported as 100%. The reassuring "(15 cards)" was the card count being
read as a count of files checked.
Our shape differs: our watch file is tailored (this repo authored it) and
expands to 339 files. But 600+ cards point at files no pattern covers — the
registry has already decided those are components and the drift check cannot

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-fabric_watch_pattern_fitness.yaml`*
*Last verified: 2026-08-02*
