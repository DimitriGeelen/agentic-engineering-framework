# bats-dead-negation-mutants

> T-3138 AC6: mutate the dead-negation lint, confirm its own suite goes red.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/bats-dead-negation-mutants.py`

## What It Does

(name, anchor-in-source, replacement). Anchors are exact text: a stale anchor
is reported as a failure, not skipped. A skipped mutant is an unmeasured one,
and silently-unmeasured is the exact shape this whole task is about.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bats-dead-negation-lint](/docs/generated/tools-bats-dead-negation-lint) | calls | T-3138: find bats assertions that cannot fail. |

---
*Auto-generated from Component Fabric. Card: `tools-bats-dead-negation-mutants.yaml`*
*Last verified: 2026-08-25*
