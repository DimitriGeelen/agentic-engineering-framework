# objectives-seed

> lib/objectives-seed.sh — the fw upgrade entry point for project objectives (T-3636).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/objectives-seed.sh`

## What It Does

lib/objectives-seed.sh — the fw upgrade entry point for project objectives (T-3636).
T-3535 IW-3 / rollout ruling 2026-09-30: every project authors
.context/project/objectives.yaml ONCE, through its own entry point. Greenfield and
existing-code onboarding seed that step at `fw init` (lib/seeds/tasks/*/). A consumer
onboarded before the step existed gets it here: `fw upgrade` seeds a one-time
"define objectives" task.
Directive 4: this file never copies an objectives file anywhere. The framework's
own .context/project/objectives.yaml is project state of THIS repo; a consumer gets
a TASK to author its own, drafted from its own material.
Idempotent by construction — the task is seeded only when BOTH hold:

---
*Auto-generated from Component Fabric. Card: `lib-objectives-seed.yaml`*
*Last verified: 2026-10-01*
