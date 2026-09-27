# driver-scoring-example

> policy/driver-scoring-example.yaml — T-3428 (OBS-463 leg 2), arc-006.

**Type:** config | **Subsystem:** governance | **Location:** `policy/driver-scoring-example.yaml`

## What It Does

policy/driver-scoring-example.yaml — T-3428 (OBS-463 leg 2), arc-006.
A worked, VALID declarative scoring spec for a BVP value driver. This file is
reference material and starter clay: nothing reads it at runtime. Copy it,
adapt it, then run the three authoring verbs against your copy.
fw bvp driver --validate-scoring policy/driver-scoring-example.yaml
fw bvp driver --explain F-RECALL T-3428 --scoring-file policy/driver-scoring-example.yaml
fw bvp driver --add "Evidence Quality" --weight 4 --rationale "..." \
--scoring-file policy/driver-scoring-example.yaml
The second command is the one worth reaching for first: it scores a REAL task
against the draft and prints the level ladder, without writing anything to

---
*Auto-generated from Component Fabric. Card: `policy-driver-scoring-example.yaml`*
*Last verified: 2026-09-22*
