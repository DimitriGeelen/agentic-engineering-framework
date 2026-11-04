# guest-run

> guest-run.sh INPUT-DIR OUTPUT-DIR — what the test VM's boot service runs (T-5009 phase 3).

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/testhost/guest-run.sh`

## What It Does

guest-run.sh INPUT-DIR OUTPUT-DIR — what the test VM's boot service runs (T-5009 phase 3).
INPUT-DIR holds pr.bundle (made by the controller: refs/heads/base and refs/heads/head).
This script and pr-checks.sh come from AEF's own released copy (the template / the
controller's input disk), NEVER from the bundle. The bundle is cloned into a work dir
(as the unprivileged user `testhost` when running as root and that user exists) and the
only thing run from it is the checks themselves, via pr-checks.sh.
stdout is the serial console: progress goes there. OUTPUT-DIR receives:
result.json  {version:1, status: passed|failed, phases:[{name, rc, seconds}], started, finished}
checks.log   the checks' output, capped at TESTHOST_GUEST_LOG_CAP bytes (default 1 MiB)
The controller treats both as hostile data and decides the run's state itself.

---
*Auto-generated from Component Fabric. Card: `agents-testhost-guest-run.yaml`*
*Last verified: 2026-11-03*
