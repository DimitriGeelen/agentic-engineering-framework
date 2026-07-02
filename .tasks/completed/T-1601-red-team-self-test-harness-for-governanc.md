---
id: T-1601
name: "Red-team self-test harness for governance gates (inception)"
description: >
  Inception: design a self-test harness that exercises the framework's PreToolUse
  hooks by attempting to violate them — Tier 0 hash mismatch, G-020 placeholder ACs,
  G-022 task-tool ban, task-gate without active task, lightweight-tag push, --no-verify
  bypass without Tier 2 logging. For each gate, the harness should attempt the action
  and verify exit code != 0 + the right error message. Open question: is this best
  as a bash test suite invoking hooks directly with simulated stdin, or a TermLink
  Claude worker red-teaming via real tool calls? Inception goal: pick the right shape,
  scope the smallest viable harness.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-29T07:47:45Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T20:58:25Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1601: Red-team self-test harness for governance gates (inception)

## Problem Statement

The framework has 6+ structural enforcement gates (Tier 0 hash matching, G-020 placeholder ACs, G-022 task-tool ban, task gate, lightweight-tag pre-push hook, P-011 verification gate, RCA gate). We assert these block bad behavior, but we have no systematic test that fires each one and verifies the block. A silent regression — say, a hook that exits 0 instead of 2 — would be invisible until a real incident exposes the gap. We need a self-test that exercises every gate with a known-bad input and asserts the gate fires.

Trigger: T-1597 sweep showed extensive evidence of gates working in normal flow, but no negative-path coverage. This inception decides the right shape for negative-path tests.

## Assumptions

A1. Each gate is invokable from a shell context that simulates the trigger (e.g. `echo '<json>' | bin/fw hook check-active-task`) — no need to spawn a real Claude session for most.

A2. A bash-test harness can cover ≥80% of gates via direct hook invocation; only 1-2 gates may require a real Claude worker (e.g. G-022 task-tool ban which is enforced via PreToolUse hook intercepting tool calls — but the underlying matcher script can still be tested directly).

A3. Adding gate-tests that get RUN regularly (not just on-demand) catches regressions cheaply. Cron-able.

## Exploration Plan

Spike 1 (1h): inventory the gates. List each PreToolUse hook + check script, the trigger condition, the expected exit code, and an example of a known-bad input that should fire it.

Spike 2 (1h): prototype a bash test harness. For 2-3 representative gates (Tier 0 mismatch, task-gate-without-task, lightweight-tag-push), write a `tests/governance/test_gates.bats` with one test per gate. Verify exit code + stderr message.

Spike 3 (30m): identify the gates that bash can't cover (if any) and decide: TermLink Claude worker, manual smoke test, or accept the gap.

Decision artifact: `docs/reports/T-1601-redteam-design.md` with: gate inventory, harness shape (bash vs TermLink vs hybrid), cron suitability, and a sized follow-up build task estimate.

## Technical Constraints

- Bash-only tests in `tests/governance/test_gates.bats` (no Python deps for the harness)
- Hooks read JSON from stdin in Claude Code's PreToolUse format — harness must construct valid JSON envelopes
- Some hooks have side effects (e.g. write `.context/working/` state) — harness must run in isolated `$WORK_TMPDIR` or accept state mutation
- No actual destructive ops triggered (e.g. no real `rm -rf`, even in sandboxed test) — only the gates that BLOCK destructive ops

## Scope Fence

**IN:**
- Gates implemented as PreToolUse/PostToolUse hooks in `agents/*/hook-*.sh`
- Direct hook invocation with simulated stdin
- bats-formatted test suite that can be cron-driven
- Exit-code + stderr-message assertions

**OUT:**
- Testing the SessionStart / PreCompact hooks (different lifecycle, harder to harness)
- Testing Watchtower API endpoints (different surface, T-1600 covers this)
- Testing actual Claude Code UI behavior (would need full claude session, out of scope for inception)
- Behavioral changes to the gates themselves (this inception is about test coverage, not gate redesign)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

- **Recommendation:** GO
- **Rationale:** Spike 1 inventoried 15 governance gates (7 PreToolUse + 4 git hooks + 4 task lifecycle); Spike 2 shipped a 5-test bash prototype that exercises 3 representative gates with 100% pass; Spike 3 found zero bash-coverage gaps (every gate is a shell script invokable with constructed JSON stdin or CLI args). The harness shape is **bash-only** (`tests/governance/test_*.bats`), wired into `bin/fw test governance` and the existing audit cron. Sized 3-4 hours of build work covering all 15 gates with positive + negative cases each. Cost is bounded; benefit is silent-regression detection across the entire enforcement surface.
- **Evidence:**
  - Inventory: 15 gates tabled in [docs/reports/T-1601-redteam-design.md](../../docs/reports/T-1601-redteam-design.md)
  - Prototype: `tests/governance/test_gates_prototype.bats` — 5 tests, all pass (`bats tests/governance/test_gates_prototype.bats` → `1..5 / ok 1..5`)
  - Pattern proven: `echo '<json>' | bin/fw hook <name>` + assert exit 2 + stderr keyword
  - State-dependent gates (e.g. check-active-task) use save/restore pattern — no collateral damage
  - No TermLink-Claude worker needed — initial assumption was wrong; gates ARE shell scripts

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Spike 1 inventoried 15 governance gates (7 PreToolUse + 4 git hooks + 4 task lifecycle); Spike 2 shipped a 5-test bash prototype that exercises 3 representative gates with 100% pass; Spike 3 found zero bash-coverage gaps (every gate is a shell script invokable with constructed JSON stdin or CLI args). The harness shape is **bash-only** (`tests/governance/test_*.bats`), wired into `bin/fw test governance` and the existing audit cron. Sized 3-4 hours of build work covering all 15 gates with positive + negative cases each. Cost is bounded; benefit is silent-regression detection across the entire enforcement surface.

**Date**: 2026-04-29T20:58:25Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-29T07:51:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-29T19:40:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-29T20:58:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Spike 1 inventoried 15 governance gates (7 PreToolUse + 4 git hooks + 4 task lifecycle); Spike 2 shipped a 5-test bash prototype that exercises 3 representative gates with 100% pass; Spike 3 found zero bash-coverage gaps (every gate is a shell script invokable with constructed JSON stdin or CLI args). The harness shape is **bash-only** (`tests/governance/test_*.bats`), wired into `bin/fw test governance` and the existing audit cron. Sized 3-4 hours of build work covering all 15 gates with positive + negative cases each. Cost is bounded; benefit is silent-regression detection across the entire enforcement surface.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-df2bd3bd
- **Timestamp:** 2026-06-02T14:58:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T20:58:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
