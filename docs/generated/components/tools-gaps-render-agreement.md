# gaps-render-agreement

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/gaps-render-agreement.py`

## What It Does

Deliberately duplicated from lib.gaps.TERMINAL_GAP_STATUSES rather than
imported. Importing would make both sides of the comparison the same side:
a bug in the constant would move the render and the reference together and
this check would stay green through it. Consolidation buys consistency and
spends the cross-check (L-575); here the cross-check is the point.

---
*Auto-generated from Component Fabric. Card: `tools-gaps-render-agreement.yaml`*
*Last verified: 2026-08-25*
