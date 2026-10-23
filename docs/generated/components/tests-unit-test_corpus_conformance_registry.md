# test_corpus_conformance_registry

> T-2654 (T-2652 GO slice 1): registry-driven conformance checker mechanics.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_corpus_conformance_registry.py`

## What It Does

T-4446: the fixtures bound the aef prefix to https://aef.dev/schema/bpmn/1.0, which
is not the AEF namespace. That passed while corpus_spec matched extension children by
local name only; T-4387 keys them by namespace AND local name, so the fixture's
aef:meta became a foreign child and every map here read as "no state-carrier nodes".
They now declare corpus_spec.AEF_NS (pinned by test_fixtures_declare_the_aef_namespace).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_conformance](/docs/generated/tools-corpus_conformance) | calls | Map-conformance rail — corpus map assertions vs the enforced state machine. |
| [conformance-registry](/docs/generated/tools-conformance-registry) | calls | Conformance registry — which corpus maps have a conformance rail, and what each conforms against (T-2652 GO, slice 1 / T-2654). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_corpus_conformance_registry.yaml`*
*Last verified: 2026-07-28*
