# continuous-mode

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/continuous-mode.sh`

## What It Does

Continuous-run counters (T-3169, arc-012 S3).
`.continuous-mode.yaml` carries TWO ceilings, counted in different units:
current_iteration / max_iterations  — SESSIONS. Advanced by SessionStart
(agents/context/inject-next-directive.py). Bounds how many context
windows one run may consume.
tasks_completed   / max_tasks       — TASKS. Advanced here, on the
work-completed transition. Bounds how much WORK one run may do.
They are not interchangeable and neither substitutes for the other. Before
T-3164 the two were the same number by accident, because a session could only
take one turn and the run advanced a window per unit of work; `max_iterations: 5`

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | called_by | TODO: describe what this component does |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t3268_continuous_cycling_detector](/docs/generated/tests-unit-t3268_continuous_cycling_detector) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-continuous-mode.yaml`*
*Last verified: 2026-09-03*
