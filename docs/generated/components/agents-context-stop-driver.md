# stop-driver

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/stop-driver.sh`

## What It Does

Stop hook — the continuous-run turn driver (T-3164, arc-012 S1).
THE PROBLEM THIS SOLVES. Without a Stop hook, control returns to the idle prompt
after every assistant turn. arc-012 built an entire continuous-run substrate —
budget gauge, auto-handover, restart signal, iteration counter, tier ceiling,
directive injector — on top of a loop that had no driver, so the mechanic never
fired once across 26 tasks. T-2404 named the gap exactly and fixed it by appending
prose asking the agent to invoke /resume: a repair that presumes the very turn it
is trying to cause. This hook is that turn.
THE CONTRACT, MEASURED (T-3163) — do not "simplify" this:
{"decision": "block", "reason": "..."}  -> Claude takes ANOTHER turn.   WORKS.

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [stop_driver](/docs/generated/tests-unit-stop_driver) | tests_by | TODO: describe what this component does |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |

---
*Auto-generated from Component Fabric. Card: `agents-context-stop-driver.yaml`*
*Last verified: 2026-08-26*
