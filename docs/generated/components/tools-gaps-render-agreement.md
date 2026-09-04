# gaps-render-agreement

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/gaps-render-agreement.py`

## What It Does

Deliberately duplicated from lib.gaps.TERMINAL_GAP_STATUSES rather than
imported. Importing would make both sides of the comparison the same side:
a bug in the constant would move the render and the reference together and
this check would stay green through it. Consolidation buys consistency and
spends the cross-check (L-575); here the cross-check is the point.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tools-gaps-render-agreement.yaml`*
*Last verified: 2026-08-25*
