# no-project-markers-above-bats-tmpdir

> Corpus-level invariant: no .framework.yaml or .tasks may sit on the path from the bats temp base up to "/". Nearly every hook suite builds its fixture under BATS_TEST_TMPDIR, and the hooks call lib/paths.sh:fw_reanchor_from_cwd, which walks that ancestry for exactly those markers — so the ambient project is an undeclared input to all of them. When an fw init ran with cwd=/tmp on this host (OBS-358), fixtures re-anchored to /tmp and read its null focus: one suite went red with a message that read like a code regression, and any suite whose fixture lacks markers of its own could equally have gone GREEN for a reason unrelated to its subject. The walk mirrors the resolver including its stop-before-"/" condition, and two legs grep the resolver so the mirror cannot drift. A third leg proves the detector fires, since a guard that cannot fail proves nothing; TMPDIR is the lever for the whole-suite red, because bats overwrites BATS_TMPDIR from it at startup.


**Type:** script | **Subsystem:** testing | **Location:** `tests/lint/no-project-markers-above-bats-tmpdir.bats`

**Tags:** `invariant`, `lint`, `test-isolation`, `host-state`, `false-green`, `T-3234`, `OBS-358`

## What It Does

T-3234 — no project marker may sit on the path from the bats temp base up to "/".
WHY THIS IS AN INVARIANT AND NOT A TEST OF OUR CODE. Nearly every hook suite
builds its fixture root under BATS_TEST_TMPDIR, i.e. under BATS_TMPDIR (/tmp
by default). The hooks call lib/paths.sh:fw_reanchor_from_cwd, which walks UP
from the per-call stdin `cwd` looking for .framework.yaml or .tasks and stops
before "/". So the fixture's ancestry is part of every one of those tests'
inputs, and it is host state that no suite declares, asserts, or controls.
ORIGIN (OBS-358, measured 2026-08-31): a full `fw init` ran with cwd=/tmp on
this host — /tmp/.framework.yaml, /tmp/.tasks with six seed tasks, /tmp/.context,
/tmp/.agentic-framework, /tmp/.claude with hooks pointing into /tmp — with a

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | mirrors | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check_active_task_cwd_resolution](/docs/generated/tests-unit-check_active_task_cwd_resolution) | diagnoses | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-lint-no-project-markers-above-bats-tmpdir.yaml`*
*Last verified: 2026-08-31*
