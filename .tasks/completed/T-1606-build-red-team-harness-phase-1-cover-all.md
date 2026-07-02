---
id: T-1606
name: "Build red-team harness Phase 1: cover all 7 PreToolUse gates (T-1601 GO follow-up)"
description: >
  Build red-team harness Phase 1: cover all 7 PreToolUse gates (T-1601 GO follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-29T20:59:52Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T21:02:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1606: Build red-team harness Phase 1: cover all 7 PreToolUse gates (T-1601 GO follow-up)

## Context

T-1601 GO decided by human via Watchtower 2026-04-29T20:58:25Z. Inception scoped a 3-4h build covering all 15 governance gates (7 PreToolUse + 4 git hooks + 4 task lifecycle). This task is **Phase 1 of 3**: extend the prototype harness (`tests/governance/test_gates_prototype.bats` — 3 gates) to cover all 7 PreToolUse gates (rename to `test_pretooluse_gates.bats`). Phases 2 and 3 (git hooks, task lifecycle) follow as separate tasks.

Gates currently covered by prototype: block-plan-mode, block-task-tools, check-active-task.
Gates added by this task: check-tier0, check-agent-dispatch, check-project-boundary, budget-gate.

Per T-1601 design: each gate gets at least one positive case (gate fires on bad input → exit 2) and where state-dependent, save/restore pattern preserves environment.

## Acceptance Criteria

### Agent
- [x] `tests/governance/test_pretooluse_gates.bats` exists and contains tests for all 7 PreToolUse gates
- [x] All tests pass when run via `bats tests/governance/test_pretooluse_gates.bats` (13/13 pass)
- [x] Each new gate has a positive (block) test demonstrating exit 2
- [x] State-dependent tests save/restore environment (no permanent mutation)
- [x] Old prototype file removed or migrated (no stale duplicates)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

test -f tests/governance/test_pretooluse_gates.bats
bats tests/governance/test_pretooluse_gates.bats
# Old prototype removed — no stale duplicate tests remain
test ! -f tests/governance/test_gates_prototype.bats

#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## Recommendation

- **Recommendation:** GO
- **Rationale:** T-1601 inception's bash-only design proven correct. All 7 PreToolUse gates now have automated block-tests; check-tier0 uses save/restore so a live approval doesn't block test isolation; agent-dispatch test handles both BLOCK and TermLink-not-installed paths. Phases 2 (git hooks) and 3 (task lifecycle) follow as separate tasks per inception sizing.
- **Evidence:**
  - `tests/governance/test_pretooluse_gates.bats` — 13 tests, 13/13 pass
  - 7/7 PreToolUse gates covered (block-plan-mode, block-task-tools, check-active-task, check-tier0, check-agent-dispatch, check-project-boundary, budget-gate)
  - State-dependent tests use save/restore (focus.yaml, .tier0-approval, .agent-dispatch-counter)
  - Prototype file removed (no stale duplicates)
  - Pattern works as predicted: `echo '<json>' | bin/fw hook <name>` + `[ status -eq 2 ]` + stderr keyword

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-29T20:59:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1606-build-red-team-harness-phase-1-cover-all.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-527252a9
- **Timestamp:** 2026-06-02T14:58:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T21:02:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
