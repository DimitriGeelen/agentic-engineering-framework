# t3257-build-order-gate

> T-3257 build-order gate: may real live-fire work proceed?

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/t3257-build-order-gate.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [concerns](/docs/generated/context-project-concerns) | calls | Unified concerns register (gaps + risks) tracking spec-reality gaps, identified risks, severity, mitigation plans, and resolution status. Consolidated from gaps.yaml, issues.yaml, and risks.yaml by T-397. |
| [t3250-transport-probe](/docs/generated/tools-t3250-transport-probe) | calls | T-3250 / G-097 re-measurement — can a turn be DELIVERED into a live Claude TUI? |
| [continuous-driver](/docs/generated/agents-context-continuous-driver) | calls | T-3254 (arc-012) — drive the loop from OUTSIDE when the agent stops early. |

---
*Auto-generated from Component Fabric. Card: `tools-t3257-build-order-gate.yaml`*
*Last verified: 2026-09-05*
