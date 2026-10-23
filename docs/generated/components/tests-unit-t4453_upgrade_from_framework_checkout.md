# t4453_upgrade_from_framework_checkout

> T-4453: `<framework checkout>/bin/fw upgrade <consumer>` must vendor THAT checkout.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4453_upgrade_from_framework_checkout.bats`

## What It Does

T-4453: `<framework checkout>/bin/fw upgrade <consumer>` must vendor THAT checkout.
Field instance (dimitri-mint-dev T-158): a v1.8.14-be.1 clone's bin/fw, run from
inside the consumer, resolved FRAMEWORK_ROOT to the consumer's vendored copy
(bin/fw resolve_framework, T-498 rule), so lib/upgrade.sh took the bare-from-consumer
branch, cloned upstream_repo (master) and vendored that. The -be fix never landed.
Hermetic: private TMPDIR, file:// upstream, env -i, cwd = consumer. The checkout is
a clone of FRAMEWORK_ROOT carrying the working-tree bin/fw + lib/upgrade.sh under
test (override with T4453_BIN_FW / T4453_UPGRADE_SH to rehearse the unfixed files),
plus a marker commit tagged v9.9.9-be.1 that upstream does not have.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4453_upgrade_from_framework_checkout.yaml`*
*Last verified: 2026-10-20*
