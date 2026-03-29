# fw-shim

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `bin/fw-shim`

## What It Does

fw-shim — Project-detecting wrapper for the Agentic Engineering Framework CLI
This shim replaces the symlink to $HOME/.agentic-framework/bin/fw.
Instead of routing all `fw` calls to a global install, it walks up from
CWD to find the project-local fw and execs it.
Resolution order:
1. bin/fw          — framework repo (has FRAMEWORK.md at root)
2. .agentic-framework/bin/fw — consumer project (vendored framework)
Install: copy to ~/.local/bin/fw (or anywhere on PATH)
Origin: T-664 (Phase 2 of T-662: eliminate global install dependency)

## Related

### Tasks
- T-664: Project-detecting fw shim — replace global install symlink

---
*Auto-generated from Component Fabric. Card: `bin-fw-shim.yaml`*
*Last verified: 2026-03-28*
