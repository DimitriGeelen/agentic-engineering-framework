# T-1601: Red-team self-test harness for governance gates — Design Report

**Status:** Inception complete. Recommendation: **GO** (bash-only harness, scoped follow-up).
**Date:** 2026-04-29
**Trigger:** T-1597 sweep showed extensive evidence of gates working in normal flow, but no negative-path coverage. A silent regression (a hook returning exit 0 when it should return 2) would be invisible until a real incident exposes it.

---

## Problem Statement

The framework has 7 PreToolUse hooks + 3 git hooks + 4 task-lifecycle gates that block bad behavior. We assert these work, but we have no systematic test that fires each gate with a known-bad input and verifies the block.

A silent regression would surface only when a human commits a force-push, a placeholder-AC task, or a TodoWrite call — *after* the failure mode has already shipped to consumer projects.

---

## Spike 1: Gate Inventory

| # | Gate | Trigger | Hook script | Exit on block |
|---|------|---------|-------------|---------------|
| 1 | block-plan-mode | EnterPlanMode tool | `agents/context/block-plan-mode.sh` | 2 |
| 2 | check-active-task (G-013) | Write/Edit without focus.yaml task | `agents/context/check-active-task.sh` | 2 |
| 3 | check-tier0 (Tier 0) | Bash with destructive command + no approval hash | `agents/context/check-tier0.sh` | 2 |
| 4 | check-agent-dispatch | Agent tool exceeding `FW_DISPATCH_LIMIT` | `agents/context/check-agent-dispatch.sh` | 2 |
| 5 | check-project-boundary | Write/Edit/Bash editing files outside PROJECT_ROOT | `agents/context/check-project-boundary.sh` | 2 |
| 6 | budget-gate | Write/Edit/Bash at ≥285K tokens | `agents/context/budget-gate.sh` | 2 |
| 7 | block-task-tools (G-022) | TodoWrite/TaskCreate/TaskUpdate/TaskList/TaskGet | `agents/context/block-task-tools.sh` | 2 |
| 8 | git commit-msg | Commit message missing `T-XXX` reference | `agents/git/lib/hooks.sh` (heredoc) | 1 |
| 9 | git pre-push (audit) | Audit FAIL severity | `agents/git/lib/hooks.sh` (heredoc) | 1 |
| 10 | git pre-push (VERSION) | VERSION rollback (T-1603) | `agents/git/lib/hooks.sh` (heredoc) | 1 |
| 11 | git pre-push (lightweight tag) | Pushing lightweight tag | `agents/git/lib/hooks.sh` (heredoc) | 1 |
| 12 | P-010 unchecked AC | `--status work-completed` with unchecked Agent ACs | `agents/task-create/update-task.sh` | 1 |
| 13 | P-011 verification | `--status work-completed` with failing `## Verification` command | `agents/task-create/update-task.sh` | 1 |
| 14 | RCA gate (T-1550) | Bug-class task `--status work-completed` with empty `## RCA` | `agents/task-create/update-task.sh` | 1 |
| 15 | inception-decide CLAUDECODE | `fw inception decide` from agent context (T-1259) | `lib/inception.sh` | 1 |

**Total:** 15 gates. **Bash-coverable:** 15/15 (every gate is a script invokable from a shell with simulated stdin or constructed CLI args).

## Spike 2: Prototype Harness

Pinned at `tests/governance/test_gates_prototype.bats` — 5 tests, 100% pass:

```bats
@test "plan-mode hook blocks EnterPlanMode tool" {
    INPUT='{"tool_name":"EnterPlanMode","tool_input":{}}'
    run bash -c "echo '$INPUT' | '$HOOK_BIN' hook block-plan-mode"
    [ "$status" -eq 2 ]
}
```

Pattern proven:
1. Construct the JSON envelope Claude Code sends to `PreToolUse` hooks (one-line, no escaping issues).
2. Pipe via `echo | bin/fw hook <name>`.
3. Assert `$status -eq 2` and stderr keyword via `[[ "$output" == *"keyword"* ]]`.

For check-active-task (state-dependent), the prototype shows the save/restore pattern: backup focus.yaml → mutate → run → restore. No collateral damage.

For git hooks (already covered separately): `tests/unit/pre_push_version_monotonicity.bats` (T-1603) and `tests/unit/hook_dispatcher.bats` already use this pattern. The new harness extends, doesn't replace.

## Spike 3: Bash Coverage Gaps

**None.** Every gate is shell-invokable with constructed input. The only marginal case — `check-agent-dispatch` — counts dispatches against a counter file that the harness can pre-populate.

The earlier inception assumption "1-2 gates may require a real Claude worker" was wrong. Direct hook invocation covers everything because the gates ARE shell scripts, not Claude-Code-specific runtime behaviour. Claude Code only chooses *which* hook to invoke and *when* — the decision logic itself is pure shell.

## Decision Artifact

### Recommendation: GO

**Shape:** bash-only harness at `tests/governance/test_gates.bats` (and possibly split per gate-class for readability: `test_pretooluse_gates.bats`, `test_git_hooks.bats`, `test_task_lifecycle_gates.bats`).

**Cron suitability:** YES. Tests are idempotent (state mutation is save/restored, no real destructive ops). Add to `bin/fw test` and to the existing `fw audit` cron path so a regression appears as an audit FAIL.

**Sized follow-up build task:** ~3-4 hours.
- 1h: write `tests/governance/test_pretooluse_gates.bats` covering all 7 PreToolUse gates (1 positive + 1 negative case each).
- 1h: write `tests/governance/test_git_hooks.bats` for commit-msg + pre-push (audit, VERSION already covered, lightweight-tag).
- 1h: write `tests/governance/test_task_lifecycle_gates.bats` for P-010, P-011, RCA, inception-decide.
- 30min: wire into `bin/fw test governance` subcommand + `fw audit` cron.
- 30min: write learning + commit.

### NO-GO criteria not met
- Bash coverage is 100% — no scope blow-out.
- Each gate is small, testable, and reversible — no fundamental redesign needed.
- Cost (3-4h) << benefit (silent-regression detection across 15 gates).

### Out of scope (deferred, not required)
- Cross-platform testing of hooks (macOS bash 3.2 — addressed by T-518 separately).
- Watchtower API gate testing (T-1600 covers click-flow contracts).
- SessionStart / PreCompact hook testing (different lifecycle, harder to harness — accept the gap; these are non-blocking).

## Dialogue Log

This inception ran in autonomous mode without human dialogue. The recommendation rests on:
- Direct evidence from Spike 1 (15 gates inventoried, all shell-invokable)
- Direct evidence from Spike 2 (5/5 prototype tests pass)
- Direct evidence from Spike 3 (no bash gaps identified)

If the human wants a different shape (TermLink-based vs bash-only, or per-gate test files vs single suite), record via `/inception/T-1601/decide` with rationale.
