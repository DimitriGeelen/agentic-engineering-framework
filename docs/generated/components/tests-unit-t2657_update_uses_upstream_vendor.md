# t2657_update_uses_upstream_vendor

> T-2657 — `fw update` ran the RUNNING (old) bin/fw's do_vendor against the fetched upstream, so an include the new version added (832: policy/) never arrived on the upgrade that introduced it.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2657_update_uses_upstream_vendor.bats`

## What It Does

T-2657 — `fw update` ran the RUNNING (old) bin/fw's do_vendor against the fetched
upstream, so an include the new version added (832: policy/) never arrived on the
upgrade that introduced it. The update must vendor with the upstream's own bin/fw.
Fixtures: the upstream's bin/fw is a stub that differs from the running one, which
is the version skew no earlier update test could express.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2657_update_uses_upstream_vendor.yaml`*
*Last verified: 2026-10-21*
