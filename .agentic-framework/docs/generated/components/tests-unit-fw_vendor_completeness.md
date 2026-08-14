# fw_vendor_completeness

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/fw_vendor_completeness.bats`

## What It Does

T-2805 — a partial vendor must not capture the router, and FRAMEWORK.md must be
the last thing a vendor writes.
The defect: bin/fw-router accepted `-x .agentic-framework/bin/fw` as proof of a
usable vendor, while bin/fw itself resolves FRAMEWORK_ROOT by FRAMEWORK.md
(bin/fw:96,128,155) and install.sh scans for the same file (install.sh:210).
Two implementations of one predicate, disagreeing — so the router would hand
over to a CLI that was about to reject the very directory it was handed.
What that cost: a directory with a half-copied .agentic-framework/ could not be
repaired by `fw init`, because that call routed into the broken copy and died
"Cannot find framework installation" — whose own advice is "Run 'fw init' in

---
*Auto-generated from Component Fabric. Card: `tests-unit-fw_vendor_completeness.yaml`*
*Last verified: 2026-08-05*
