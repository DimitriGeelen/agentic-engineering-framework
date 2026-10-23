# t4094_close_stages_untracked

> T-4094 (peer dimitri-mint-dev G-012): a task created and closed between two commits was never committed.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4094_close_stages_untracked.bats`

## What It Does

T-4094 (peer dimitri-mint-dev G-012): a task created and closed between two
commits was never committed. The archive move uses `git mv` only for a TRACKED
file; an untracked one falls back to plain `mv` and nothing staged the
completed/ file or its episodic, so both stayed untracked for weeks.
Postcondition pinned here: after --status work-completed moves a task into
completed/, that file and its episodic are in the index, whatever their
tracking state before the close.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4094_close_stages_untracked.yaml`*
*Last verified: 2026-10-20*
