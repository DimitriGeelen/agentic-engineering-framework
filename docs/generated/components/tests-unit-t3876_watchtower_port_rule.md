# t3876_watchtower_port_rule

> T-3876: ONE port rule for Watchtower start and restart (bin/watchtower.sh choose_port): explicit --port > configured PORT (free or ours) > the last port this project ran on (free or ours) > allocate.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3876_watchtower_port_rule.bats`

## What It Does

T-3876: ONE port rule for Watchtower start and restart (bin/watchtower.sh
choose_port): explicit --port > configured PORT (free or ours) > the last port
this project ran on (free or ours) > allocate. Before, do_start ignored the
last port and do_restart (T-2598) put it ABOVE the configured PORT, so after
the 2026-10-05 reboot AEF moved 3002 -> 3000 and 055 lost 3050, and 055's
`fw config set PORT 3050` was ignored by a bare restart.
choose_port is extracted from bin/watchtower.sh itself and run against stubs
for the port probes, so the test follows the real function.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3876_watchtower_port_rule.yaml`*
*Last verified: 2026-10-05*
