# diagnose

> Healing Agent - diagnose command

**Type:** script | **Subsystem:** healing | **Location:** `agents/healing/lib/diagnose.sh`

## What It Does

Healing Agent - diagnose command
Analyze task issues and suggest recovery actions

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ask-py](/docs/generated/lib-ask-py) | calls | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [healing](/docs/generated/agents-healing-healing) | called_by | Healing Agent - Antifragile error recovery and pattern learning |
| [healing_diagnose](/docs/generated/tests-unit-healing_diagnose) | called_by | Unit tests for healing diagnose (26 tests) |
| [healing_diagnose](/docs/generated/tests-unit-healing_diagnose) | tests_by | Unit tests for healing diagnose (26 tests) |

## Documentation

- [Deep Dive: The Healing Loop](docs/articles/deep-dives/05-healing-loop.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-healing-lib-diagnose.yaml`*
*Last verified: 2026-02-20*
