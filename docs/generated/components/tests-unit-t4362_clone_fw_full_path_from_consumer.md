# t4362_clone_fw_full_path_from_consumer

> T-4362 (GitHub #105): a clone's bin/fw, called by full path from inside a vendored consumer, must run ITSELF for `upgrade` — not the consumer's .agentic-framework copy.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4362_clone_fw_full_path_from_consumer.bats`

## What It Does

T-4362 (GitHub #105): a clone's bin/fw, called by full path from inside a vendored
consumer, must run ITSELF for `upgrade` — not the consumer's .agentic-framework copy.
Field report (v1.8.11): `cd $PROJECT && $CLONE/bin/fw upgrade $PROJECT --dry-run`
printed "Bare-from-consumer detected — auto-cloning upstream": resolve_framework's
T-498 rule picked $PROJECT/.agentic-framework, so lib/upgrade.sh saw source == target.
T-4453 fixed the clean-env case. This file pins #105's exact table, plus the case a
consumer's own agent session produces: FRAMEWORK_ROOT (and PROJECT_ROOT) already
exported as the consumer's vendored copy, which T-4453's `-z FRAMEWORK_ROOT` guard
skipped.
Hermetic: private TMPDIR, file:// upstream, env -i, cwd = consumer.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4362_clone_fw_full_path_from_consumer.yaml`*
*Last verified: 2026-10-20*
