# doctor-upstream

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/doctor-upstream.sh`

## What It Does

lib/doctor-upstream.sh — T-2843
Predicate for `fw doctor` check 2: is there a genuine ambiguity between the
framework a project is PINNED to (`upstream_repo:` in .framework.yaml) and the
framework it is actually RUNNING (`FRAMEWORK_ROOT`)?
The two fields answer different questions. `upstream_repo` names where updates
are pulled FROM; `FRAMEWORK_ROOT` names the copy currently executing. They
coincide only in shared-tooling mode, where a project is served by a framework
checkout living elsewhere on disk. Under D-377 (total isolation) the default is
vendored mode, where the running fw is the project's own `.agentic-framework/`
— so the two CANNOT be equal, and inequality carries no information.

---
*Auto-generated from Component Fabric. Card: `lib-doctor-upstream.yaml`*
*Last verified: 2026-08-06*
