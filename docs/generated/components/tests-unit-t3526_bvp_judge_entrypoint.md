# t3526_bvp_judge_entrypoint

> T-3526 — end-to-end reachability of `fw bvp judge` on the real entry point.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3526_bvp_judge_entrypoint.bats`

## What It Does

T-3526 — end-to-end reachability of `fw bvp judge` on the real entry point.
AC: "Reachable on the path an agent actually takes. Verified by running the
real entry point with no override flags, not with --i-am-human." Twice in
this session a guard was written that no live path reached; a pass obtained
with an override flag proved nothing. These tests run the actual `bin/fw bvp
judge` command — no --i-am-human, no FW_ALLOW_*, no mocks — against real
probe task files dropped into .tasks/active/, mirroring the existing
convention in tests/unit/bvp_auto_promote.bats.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3526_bvp_judge_entrypoint.yaml`*
*Last verified: 2026-09-27*
