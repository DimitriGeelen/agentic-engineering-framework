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

---
*Auto-generated from Component Fabric. Card: `lib-cron-registry.yaml`*
*Last verified: 2026-08-06*
