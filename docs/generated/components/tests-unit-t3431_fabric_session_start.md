# t3431_fabric_session_start

> T-3431 (D-592): SessionStart hook (post-compact-resume.sh) runs a bounded `fw fabric enrich --describe --quiet` on every start/resume/compact and injects one summary line; `fw resume status` mirrors the cached line rather than re-running…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3431_fabric_session_start.bats`

## What It Does

T-3431 (D-592): SessionStart hook (post-compact-resume.sh) runs a bounded
`fw fabric enrich --describe --quiet` on every start/resume/compact and
injects one summary line; `fw resume status` mirrors the cached line rather
than re-running the scan. Fixture project throughout (T-3326) — the live
corpus's card counts move under a fixed-count assertion for reasons
unrelated to this hook.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | tests | Session Resume Hook — Reinject structured context on session recovery |
| [resume](/docs/generated/agents-resume-resume) | tests | Resume Agent - Post-compaction recovery and state synchronization |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3431_fabric_session_start.yaml`*
*Last verified: 2026-09-22*
