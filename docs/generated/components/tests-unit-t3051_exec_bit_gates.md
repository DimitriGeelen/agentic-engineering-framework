# t3051_exec_bit_gates

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3051_exec_bit_gates.bats`

## What It Does

T-3051 — repo-tracked helper scripts must not be gated on their exec bit.
git records only one permission bit, and it was recorded wrong for three
helpers. Every gate of the form `[ -x "$helper" ]` therefore evaluated false
on any install derived from a clone, and because all three call sites are
deliberately non-fatal, a skipped helper is indistinguishable from a
successful one. That is why this went two months unreported.
The behavioural test below is written the only way that proves anything: the
exec bit is REMOVED and the helper must still run. Asserting it runs while the
bit is present passes against the broken code too.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3051_exec_bit_gates.yaml`*
*Last verified: 2026-08-16*
