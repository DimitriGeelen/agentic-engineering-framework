# t5404_inception_sweep_operator_owned

> T-5404: `fw inception sweep` under agent control and an operator-owned inception.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5404_inception_sweep_operator_owned.bats`

## What It Does

T-5404: `fw inception sweep` under agent control and an operator-owned inception.
Origin: 150-skills-manager C-010 (2026-11-24). After a half-done decide, Watchtower
said "the agent session can recover this (fw inception sweep)". For an
`owner: human` task the sweep's close passes --skip-sovereignty, which update-task.sh
refuses under CLAUDECODE=1 (T-3586) — and before refusing, the sweep had already
ticked the ### Human box and written its provenance row under agent control.
Pinned: under CLAUDECODE=1 an operator-owned decided inception is left byte-for-byte
untouched and the operator's one line is printed; outside an agent session the same
task closes; an agent-owned one still closes under the agent; task ids scope the sweep.
Every test runs in a throwaway PROJECT_ROOT.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5404_inception_sweep_operator_owned.yaml`*
*Last verified: 2026-11-25*
