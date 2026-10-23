# t3586_skip_flag_policy

> T-3586 — the completion gate's --skip-* flags.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3586_skip_flag_policy.bats`

## What It Does

T-3586 — the completion gate's --skip-* flags.
Origin: T-3583's dispatched worker closed its task with --skip-acceptance-criteria
and an EMPTY reason, leaving two criteria unbuilt against its prompt. The flag was
accepted with no reason and no agent check. Policy now (update-task.sh
enforce_bypass_policy): every CONSUMED --skip-* needs a reason; the flags whose gate
protects a criterion or ownership are refused under CLAUDECODE=1 unless --i-am-human.
Each refusal test is paired with a control that differs by exactly one input, so a
gate that refuses everything (or nothing) fails at least one of them.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3586_skip_flag_policy.yaml`*
*Last verified: 2026-09-30*
