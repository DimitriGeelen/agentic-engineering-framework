# t3247_restart_headless_prompt

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3247_restart_headless_prompt.bats`

## What It Does

T-3247 — the budget-critical RESTART relaunch must carry a prompt under --print.
WHY THIS SUITE EXISTS. `bin/claude-fw` sets CLAUDE_ARGS=() on every budget
restart (T-3166, fresh session not -c) so the resumed session frees context
instead of restoring the transcript that tripped critical in the first place.
That is correct for an interactive terminal — SessionStart injects the
directive and the operator's own turn picks it up. Under `claude --print` a
promptless relaunch has no turn to take: it dies on "Input must be provided
either through stdin or as a prompt argument when using --print" before any
injected context matters, and the loop spends its whole restart budget on
sessions that could never have worked regardless of what was queued for them.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3247_restart_headless_prompt.yaml`*
*Last verified: 2026-09-02*
