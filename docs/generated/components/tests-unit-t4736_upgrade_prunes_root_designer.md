# t4736_upgrade_prunes_root_designer

> T-4736: `fw upgrade` prunes superseded Workflow Designer builds from the consumer ROOT vendor/designer/, but only the ones it can prove are AEF's own.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4736_upgrade_prunes_root_designer.bats`

## What It Does

T-4736: `fw upgrade` prunes superseded Workflow Designer builds from the
consumer ROOT vendor/designer/, but only the ones it can prove are AEF's own.
050 be.16 report: the root kept an untracked 0.25.0 and a tracked 0.14.0 next
to the current 0.26.0, ~1.2 MB per pin bump. _self_vendor_designer prunes the
vendored tree; nothing pruned the installed copy.
Rule under test: delete a superseded root build only when it is untracked in
the consumer's git AND byte-identical to the same-named build in the framework
source's vendor/designer/. Tracked or unknown builds are listed and kept.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4736_upgrade_prunes_root_designer.yaml`*
*Last verified: 2026-10-25*
