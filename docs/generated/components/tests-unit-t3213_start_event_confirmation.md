# t3213_start_event_confirmation

> End-to-end confirmation suite for the claude-fw start-event ledger: runs the real bin/claude-fw in a scratch git repo with a stubbed claude binary and asserts the start event is written, is idempotent, and degrades correctly when the ledger path is unwritable.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3213_start_event_confirmation.bats`

**Tags:** `tests`, `bats`, `claude-fw`, `continuous-run`, `T-3213`

## What It Does

T-3213 (arc-012 IW-6) — CONFIRM the start event by running the wrapper.
WHAT WAS MISSING, AND WHY IT MATTERED.
T-3206 shipped a `start` event so the loop could say it is ARMED. T-3209 then
taught `fw doctor` to attribute an absent ledger to "the supervisor predates the
recorder" rather than blaming the operator. Both shipped on an explanation that
fit every observation and that nobody had confirmed — while T-3209's own reason
for existing is the distinction between a supported hypothesis and a measured
fact. Neither suite ever invoked the wrapper: t3206 asserts the call site is
defined and called, t3209 drives doctor's block against synthetic ledgers it
writes itself. Both are correct and neither can see whether claude-fw, run,

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [claude-fw](/docs/generated/bin-claude-fw) | tests | Claude Code wrapper with auto-restart support. Runs claude normally, then checks for a restart signal file written by checkpoint.sh when auto-handover fires at critical budget. If found and fresh, auto-restarts with claude -c to continue seamlessly. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3213_start_event_confirmation.yaml`*
*Last verified: 2026-08-29*
