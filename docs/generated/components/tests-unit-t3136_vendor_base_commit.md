# t3136_vendor_base_commit

> T-3136 — `fw update` re-vendors wholesale. Consumer 001-CashWeb (their T-111) lost a carried bin/fw patch and only found out because a gate happened to cover it, and no record of the vendored base commit existed to diff against.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3136_vendor_base_commit.bats`

## What It Does

T-3136 — `fw update` re-vendors wholesale. Consumer 001-CashWeb (their T-111)
lost a carried bin/fw patch and only found out because a gate happened to
cover it, and no record of the vendored base commit existed to diff against.
T-3850 already made the vendor refuse to overwrite a locally edited file
(pinned here for bin/fw specifically). What this task adds: the vendor stamp
records the upstream commit the copy came from, and `fw update` shows it.
Synthetic fixtures only: a tiny git-tracked framework source vendored into a
throwaway consumer.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3136_vendor_base_commit.yaml`*
*Last verified: 2026-10-20*
