# conformance-registry

> TODO: describe what this component does

**Type:** config | **Subsystem:** unknown | **Location:** `tools/conformance-registry.yaml`

## What It Does

Conformance registry — which corpus maps have a conformance rail, and what
each conforms against (T-2652 GO, slice 1 / T-2654).
This file is the single place a map opts into a rail. The checker
(tools/corpus_conformance.py) iterates these entries; the audit section
(agents/audit/audit.sh check_map_conformance) reports one line per entry.
Maps absent from this registry are descriptive-only by definition — the
T-2619 transitional rule (CLAUDE.md prose wins) applies to them until an
entry lands AND stays green.
Entry shape:
<map_id>:

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_corpus_conformance_registry](/docs/generated/tests-unit-test_corpus_conformance_registry) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tools-conformance-registry.yaml`*
*Last verified: 2026-07-28*
