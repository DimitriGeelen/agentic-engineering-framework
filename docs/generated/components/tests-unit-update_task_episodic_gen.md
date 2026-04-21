# update_task_episodic_gen

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/update_task_episodic_gen.bats`

## What It Does

T-1368: Regression test for episodic auto-gen silent failure.
Four tasks in one session (T-1363, T-1364, T-1366, T-1367) transitioned to
work-completed via update-task.sh (evidenced by date_finished set and the
[task-update-agent] Updates entry), yet no episodic was generated. Sandbox
reproduction with the exact real task files DOES generate the episodic, so
the code path works. This test pins the happy path so any regression in
auto-gen (code-side) surfaces immediately.
Does NOT reproduce the real-world silent failure (environmental, unknown
trigger) — tracked separately in concerns.yaml.

---
*Auto-generated from Component Fabric. Card: `tests-unit-update_task_episodic_gen.yaml`*
*Last verified: 2026-04-20*
