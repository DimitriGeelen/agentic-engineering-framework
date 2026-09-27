# t3039_write_set_implicit

> T-3039 — the implicit framework write-set, and the false green it closes.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3039_write_set_implicit.bats`

## What It Does

T-3039 — the implicit framework write-set, and the false green it closes.
`fw write-set check` is what CLAUDE.md §Execution Model tells an agent to run
before parallelising two tasks. Before T-3039 it compared ONLY the declared
`write_set:` frontmatter, so `disjoint` meant "your two lists do not
intersect" while reading as "these can run concurrently".
Those are not the same claim. Every framework task also writes state no task
declares — inbox.yaml, learnings.yaml, concerns.yaml, focus.yaml,
session.yaml — because the framework writes them on the task's behalf. Two
tasks with genuinely disjoint declared sets still collide there, in the
27-site shared read-modify-write set measured by

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [write_set](/docs/generated/lib-write_set) | calls | Disjoint write-set policy validator (T-2337, arc-011 M1 §3). |
| [write_set](/docs/generated/lib-write_set) | tests | Disjoint write-set policy validator (T-2337, arc-011 M1 §3). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3039_write_set_implicit.yaml`*
*Last verified: 2026-08-16*
