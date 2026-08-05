# fw_init_atomic

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/fw_init_atomic.bats`

## What It Does

T-2801 — fw init must leave either nothing or a working project.
do_vendor's include list copies `bin` FIRST and FRAMEWORK.md eighth, and
.framework.yaml is not written until ~120 lines after the vendor call. So from
roughly one second into an init until it finishes, the target directory holds
an executable .agentic-framework/bin/fw belonging to a framework that is not
all there yet.
bin/fw-router routed on `[ -x <dir>/.agentic-framework/bin/fw ]` alone, so it
exec'd that partial CLI, which failed "Cannot find framework installation" —
for every verb, INCLUDING fw init. The tool could not repair the directory it
had just created; only `rm -rf` did. Hit live 2026-08-04 in

---
*Auto-generated from Component Fabric. Card: `tests-unit-fw_init_atomic.yaml`*
*Last verified: 2026-08-04*
