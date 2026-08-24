# revisit_signal_untracked

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/revisit_signal_untracked.bats`

## What It Does

T-2866 — the revisit signal files must never be tracked by git.
Both signals rely on an absent==empty contract: revisit-due-scan.sh REMOVES its
output file when the set is empty, and handover.sh prints nothing when the file
is absent. A tracked file cannot be absent after a checkout — git restores it —
so a stale committed copy would be reported as current on any fresh clone.
That is the same failure shape T-2865 fixed (a signal whose truth value is
decided by something other than the present state of the corpus), and it arrived
via T-2865's own closing commit, where `git add -A` swept the generated file in.
.revisits-due.txt has been untracked for the project's whole history, but by luck
rather than by rule — nothing stopped the same accident. Both are pinned here.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [revisit-due-scan](/docs/generated/agents-context-revisit-due-scan) | calls | TODO: describe what this component does |
| [revisit-due-scan](/docs/generated/agents-context-revisit-due-scan) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-revisit_signal_untracked.yaml`*
*Last verified: 2026-08-08*
