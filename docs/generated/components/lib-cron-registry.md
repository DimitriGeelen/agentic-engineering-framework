# cron-registry

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/cron-registry.sh`

## What It Does

lib/cron-registry.sh — T-2844
How many jobs does a cron registry actually declare?
The registry → generated → deployed drift checks in `fw doctor` and `fw audit`
were gated on the registry FILE EXISTING, never on it declaring any work. But
`fw init` seeds `.context/cron-registry.yaml` with `jobs: []`, and an empty
registry has no generated form — `fw cron generate` correctly produces nothing.
So both surfaces reported "registry present but not generated" on a project
seconds old, which is the framework complaining about a state it created and
which is in fact correct.
The distinction that was missing: "nothing to generate" and "something to

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-cron-registry.yaml`*
*Last verified: 2026-08-06*
