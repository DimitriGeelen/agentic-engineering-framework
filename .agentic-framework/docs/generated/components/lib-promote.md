# promote

> Graduation Pipeline — fw promote

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/promote.sh`

## What It Does

Graduation Pipeline — fw promote
Implements the knowledge graduation pipeline from 015-Practices.md:
Task Update → Learning (2+ tasks) → Practice (3+ applications) → Directive
Commands:
suggest     Show learnings ready for promotion (3+ applications)
status      Show all learnings with application counts
L-XXX       Promote a specific learning to practice
Usage:
fw promote suggest
fw promote status

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_promote](/docs/generated/tests-unit-lib_promote) | called-by | TODO: describe what this component does |
| [lib_promote](/docs/generated/tests-unit-lib_promote) | called_by | TODO: describe what this component does |
| [lib_promote](/docs/generated/tests-unit-lib_promote) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-promote.yaml`*
*Last verified: 2026-02-20*
