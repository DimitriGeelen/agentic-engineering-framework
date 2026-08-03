# version_relation

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/version_relation.bats`

## What It Does

T-2713: consumer-vs-framework version relation must come from git ancestry,
never from `sort -V` over the VERSION counter.
VERSION is a tag counter that RESETS. This repo's tags run v1.6.763, v1.6.762,
v1.6.761, then v1.6.10, v1.6.9; VERSION itself went 1.6.354 -> 1.6.121 -> 1.6.176.
`sort -V` therefore answers a question nobody asked ("which string sorts higher")
and three call sites treated the answer as "which code is newer".
Field consequence: a consumer pinned 1.6.264 read as AHEAD of a framework at
1.6.163, so `fw upgrade` refused — to protect it — and it sat frozen for weeks
with no governance or security fixes. Test 1 is that exact case.
Test 6 is the NEGATIVE CONTROL: it asserts the fixture pair genuinely fools

---
*Auto-generated from Component Fabric. Card: `tests-unit-version_relation.yaml`*
*Last verified: 2026-08-01*
