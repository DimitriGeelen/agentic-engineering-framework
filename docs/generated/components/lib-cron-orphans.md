# cron-orphans

> lib/cron-orphans.sh — detect deployed cron entries whose declared PROJECT_ROOT is gone (T-3281).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/cron-orphans.sh`

## What It Does

lib/cron-orphans.sh — detect deployed cron entries whose declared PROJECT_ROOT
is gone (T-3281).
The framework already tracks three cron drift classes along the chain
registry → generated → deployed (CLAUDE.md §Verification Gate, T-1942/T-1771).
All three compare a project's own registry against its own deployed file, so
all three are blind to the same thing: a deployed entry with NO registry
behind it at all, belonging to a project that no longer exists.
Those entries are not inert. `bin/fw` treats a vanished PROJECT_ROOT as stale
(`_project_root_is_stale`), re-resolves, and — with cron supplying no usable
cwd — falls back to FRAMEWORK_ROOT. The job then audits the *framework repo*

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t3281_cron_orphan_scan](/docs/generated/tests-unit-t3281_cron_orphan_scan) | tests_by | T-3281: orphaned cron.d entries — deployed jobs whose declared PROJECT_ROOT is gone. |

---
*Auto-generated from Component Fabric. Card: `lib-cron-orphans.yaml`*
*Last verified: 2026-09-05*
