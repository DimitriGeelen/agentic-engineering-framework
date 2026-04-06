# fw-shim

> Project-detecting fw shim: resolves framework root from .framework.yaml or bin/ location. Replaces global install symlink (T-664).

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

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |

---
*Auto-generated from Component Fabric. Card: `bin-fw-shim.yaml`*
*Last verified: 2026-03-28*
