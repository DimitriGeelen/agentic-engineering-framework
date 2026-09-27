# inception-readiness

> lib/inception-readiness.sh — SHARED decision-readiness predicates for inception tasks.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/inception-readiness.sh`

## What It Does

lib/inception-readiness.sh — SHARED decision-readiness predicates for inception tasks.
T-3279 (G-102). Origin: the T-2190 disposition predicate lived only inside
update-task.sh:check_disposition_gate — the completion ENFORCEMENT point — while
the surfaces that INVITE completion (do_inception_decide's T-1503 preflight,
lib/review.sh emission, the Watchtower decide form behind them) had no way to ask
the same question. Result, measured 2026-09-05 on T-3278: operator records GO,
decision is written, the completion side-effect refuses, task sticks in the
class-2 state (decision recorded, status started-work), and the operator is shown
the gate's agent-facing stderr — Tier-2 bypass flags included — as the response.
THE RULE THIS FILE EMBODIES: a completion-gate predicate lives in ONE shared

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [inception](/docs/generated/lib-inception) | called_by | fw inception - Inception phase workflow |
| [review](/docs/generated/lib-review) | called_by | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

---
*Auto-generated from Component Fabric. Card: `lib-inception-readiness.yaml`*
*Last verified: 2026-09-05*
