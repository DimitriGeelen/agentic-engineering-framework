# t4473_arc_scoring_file_persist

> T-4473 (010-termlink proposal 341, their T-3472): approve-driver --scoring-file must STORE the spec inline.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4473_arc_scoring_file_persist.bats`

## What It Does

T-4473 (010-termlink proposal 341, their T-3472): approve-driver --scoring-file
must STORE the spec inline. The estimator reads only an inline `scoring:` block
(estimator.load_scoring_spec), so a spec handed to the reviewer and then dropped
scored nothing. These tests pin the writer -> estimator round trip.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4473_arc_scoring_file_persist.yaml`*
*Last verified: 2026-10-20*
