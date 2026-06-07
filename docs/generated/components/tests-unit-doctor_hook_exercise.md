# doctor_hook_exercise

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/doctor_hook_exercise.bats`

## What It Does

T-1629 (B-3a of T-1626) — `fw doctor` actively exercises every configured
Claude Code hook from /tmp (foreign CWD that mimics agent cd-drift) and
reports any whose path doesn't resolve.
Companion to T-1628 (passive telemetry): doctor is the active probe. Catches
the T-1626 witness scenario (broken bare-relative `.agentic-framework/bin/fw`
paths) deterministically, not contingent on a real hook firing during the
session.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-doctor_hook_exercise.yaml`*
*Last verified: 2026-05-01*
