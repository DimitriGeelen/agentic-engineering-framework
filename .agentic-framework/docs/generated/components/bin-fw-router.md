# fw-router

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `bin/fw-router`

## What It Does

fw-router — the `fw` entry point on PATH (T-2793, operator decision D-377).
This file contains NO framework logic and has NO version of its own. Its only
job is to answer one question — *which* fw should run here? — and hand over.
── Why this exists ────────────────────────────────────────────────────────────
Before T-2793, `~/.local/bin/fw` was a symlink to a full 7,836-line framework
CLI. That CLI resolved FRAMEWORK_ROOT to the project's vendored copy and then
re-exec'd *itself* (`exec "$0" "$@"`), so a vendored consumer ran:
CLI dispatch  ← the global install   (whatever version that happens to be)
libs + agents ← the project's copy   (the version the project pinned)
Vendoring isolated libraries but not tooling. Every consumer ran an untested

---
*Auto-generated from Component Fabric. Card: `bin-fw-router.yaml`*
*Last verified: 2026-08-04*
