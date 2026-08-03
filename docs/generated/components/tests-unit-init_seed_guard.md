# init_seed_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/init_seed_guard.bats`

## What It Does

T-2712: fw init's "is this project fresh?" test must consider completed/ too.
lib/init.sh gates onboarding-task seeding on has_existing_tasks, which checked
only .tasks/active/. Completing a task MOVES it to .tasks/completed/, so a project
that finished onboarding shows an empty active/, reads as fresh, and gets
T-001..T-005 (greenfield) or T-001..T-006 (existing-project) written over IDs it
already used and committed against.
The guard's comment says "idempotent on --force re-init". It was idempotent only
for projects that had made no progress.
Test 4 is the NEGATIVE CONTROL: it asserts the fixture state (empty active/,
populated completed/) is genuinely the state the old guard mis-read. Without it,

---
*Auto-generated from Component Fabric. Card: `tests-unit-init_seed_guard.yaml`*
*Last verified: 2026-08-01*
