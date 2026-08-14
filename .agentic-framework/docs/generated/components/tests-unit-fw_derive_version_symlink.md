# fw_derive_version_symlink

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/fw_derive_version_symlink.bats`

## What It Does

T-2450 / F3: bin/fw _derive_version must resolve symlinks before deriving
fw_dir. The global shim ~/.local/bin/fw is a SYMLINK to the framework's
bin/fw; the unresolved BASH_SOURCE[0] used to make fw_dir point at the
symlink's parent (~/.local — no .git, no VERSION), so version derivation
fell through to "dev" and `fw --version` reported `vdev` (T-2441 dogfood F3).
These tests invoke fw via a symlink in a bare directory (no .git, no VERSION)
and assert the reported version matches the direct invocation — i.e. never
degrades to `dev`/`vdev` purely because of how fw was invoked.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-fw_derive_version_symlink.yaml`*
*Last verified: 2026-06-21*
