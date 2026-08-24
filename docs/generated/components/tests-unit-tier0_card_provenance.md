# tier0_card_provenance

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/tier0_card_provenance.bats`

## What It Does

T-3078 — a Tier 0 approval card must record where it came from, derived.
Before T-3078 a pending card carried hash, preview, risk, timestamp, status —
and nothing about origin. Watchtower rendered every one of them under the
literal "Agent blocked — requires your decision". For the cards T-3077's
governance suite filed against the live queue that subtitle was simply false:
no agent was blocked, a test was, and one of those cards read "RECURSIVE
DELETE: Targets root filesystem (/)". The operator opened /approvals, saw it,
and asked why. The surface had no way to know the answer.
── The property under test ──────────────────────────────────────────────────
Provenance is DERIVED, never declared. No caller passes `--is-a-test`, because

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-tier0_card_provenance.yaml`*
*Last verified: 2026-08-19*
