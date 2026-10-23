# t4438_install_fetch_cleanup

> T-4438: install.sh must not leak its agentic-fw-fetch-* clone when a run fails or is killed.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4438_install_fetch_cleanup.bats`

## What It Does

T-4438: install.sh must not leak its agentic-fw-fetch-* clone when a run fails
or is killed. install.sh:195 mktemp's INSTALL_DIR, and cleanup_fetch used to run
only at the end of the success path, so any earlier exit left a 350 MB-2 GB
shallow clone in /tmp. The fix registers the cleanup the moment this run
creates the directory; a caller-supplied INSTALL_DIR is never removed.
Failure is forced after the fetch: the fixture clone has no bin/fw, bin/fw-router
or bin/fw-shim, so link_fw hits `fatal` before the explicit cleanup_fetch call.
TMPDIR is private to this test, so the check cannot see the real /tmp.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4438_install_fetch_cleanup.yaml`*
*Last verified: 2026-10-20*
