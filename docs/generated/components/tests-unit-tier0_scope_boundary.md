# tier0_scope_boundary

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/tier0_scope_boundary.bats`

## What It Does

T-2742: Tier 0 inspects the command STRING only — characterization test.
This is not a test of desired behaviour. It pins the gate's actual reach so
that the claim written in check-tier0.sh's header, CLAUDE.md §Enforcement
Tiers and FRAMEWORK.md is falsifiable rather than folklore. If anyone later
extends Tier 0 to inspect script contents, the ALLOWED tests below go red and
force those three documents to change in the same commit.
The boundary: check-tier0.sh reads `tool_input.command` from the PreToolUse
JSON and matches that string. It never opens a file the command refers to.
So `bash ./build.sh` is opaque no matter what build.sh does.
Origin: 832 lost a working tree to exactly this shape — a mutated build script

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [check-tier0](/docs/generated/agents-context-check-tier0) | tests | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |

---
*Auto-generated from Component Fabric. Card: `tests-unit-tier0_scope_boundary.yaml`*
*Last verified: 2026-08-02*
