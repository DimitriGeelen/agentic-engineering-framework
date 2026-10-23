# t4480_pickup_constant_hash

> T-4480 (termlink proposal 350, their T-2687): lib/pickup.sh must refuse the constant sha256("||") dedup hash and content-free "Pickup: (from )" tasks, and leave a refused envelope in the inbox instead of burying it.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4480_pickup_constant_hash.bats`

## What It Does

T-4480 (termlink proposal 350, their T-2687): lib/pickup.sh must refuse the
constant sha256("||") dedup hash and content-free "Pickup:  (from )" tasks,
and leave a refused envelope in the inbox instead of burying it.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4480_pickup_constant_hash.yaml`*
*Last verified: 2026-10-20*
