# python-deps

> T-4238: Python dependency checks shared by `fw doctor`, `fw preflight` and bin/fw.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/python-deps.sh`

## What It Does

T-4238: Python dependency checks shared by `fw doctor`, `fw preflight` and bin/fw.
The install hint never says a bare `pip install`: PEP 668 interpreters
(Debian 12, Ubuntu 24.04, Mint 22, Homebrew) refuse it with
"externally-managed-environment". On Debian-likes the hint names the apt
packages; elsewhere it is a venv (same path bin/watchtower.sh, T-4304, names).
install.sh runs before the framework is fetched, so it cannot source this
file and carries its own copy of the module lists. The copies are pinned
equal by tests/unit/t4238_python_deps_hint.bats.

---
*Auto-generated from Component Fabric. Card: `lib-python-deps.yaml`*
*Last verified: 2026-10-21*
