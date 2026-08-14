# update_mode_routing

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/update_mode_routing.bats`

## What It Does

T-2853 — `fw update` must route by what the framework copy IS, not by which
branch happens to be tested first.
A global install (~/.agentic-framework, a `git clone`) has the same LAYOUT as a
consumer's vendored copy: a directory of that name beside a project root, with
a VERSION file. The vendored branch was tested first, matched the global
install, and demanded `upstream_repo` — a key install.sh never writes, because
the clone's own `origin` is already the answer. The git-based update branch
(`_do_update_git`) was unreachable for it.
T-2854/D-377: `_do_update_git` and its dispatch are gone — global installs
have no producer since T-2800, so there is nothing left to update in place

---
*Auto-generated from Component Fabric. Card: `tests-unit-update_mode_routing.yaml`*
*Last verified: 2026-08-07*
