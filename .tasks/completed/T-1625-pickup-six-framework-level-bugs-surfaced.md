---
id: T-1625
name: "Pickup: Six framework-level bugs surfaced as long-watching concerns in 003-NTB-ATC-Plugin. Project is decide-deferring all six locally and forwarding upstream so framework-agent can prioritize fixes. (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-271. Type: bug-report.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-30T21:07:01Z
last_update: 2026-05-01T10:03:34Z
date_finished: 2026-05-01T10:03:34Z
source_task_id_in_origin: T-271
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1625: Pickup: Six framework-level bugs surfaced as long-watching concerns in 003-NTB-ATC-Plugin. Project is decide-deferring all six locally and forwarding upstream so framework-agent can prioritize fixes. (from 003-NTB-ATC-Plugin)

## Context

Pickup envelope `P-045-from-ntb-atc-bug-report.yaml` from 003-NTB-ATC-Plugin describes six framework-level concerns deferred locally and forwarded upstream for triage. Per "one bug = one task" (CLAUDE.md Task Sizing Rules) and Pickup Message Handling (G-020), this task is an **inception that triages the bundle**, not a single fix-it-all build.

**Source envelope:** `.context/pickup/processed/P-045-from-ntb-atc-bug-report.yaml`

**Bugs in scope:**

| Tag | Concern | Severity | Fix locus | Complexity |
|-----|---------|----------|-----------|------------|
| C-006 | R-033 sovereignty dual-fire on inception completion | low | `lib/inception.sh` decide path + `update-task.sh` work-completed coordinate so sovereignty fires once per arc | small (~half day) |
| C-009 | Watchtower `/inception/decide` HTTP 500 on partial-complete | medium | `web/blueprints/inception.py` exception handler + recovery when P-010 raises mid-flow | medium (~day) |
| C-010 | Project-level agent extensions homeless | medium | Convention design — `.fabric/agents/` or `.claude/agents/` + agent loader updates | medium-large (design + implementation) |
| C-011 | `fw task review` silent exit-1 with no Recommendation | low | T-1545 partially fixed for inception; verify + extend to non-inception build/refactor tasks | small (~half day) |
| C-012 | `update-task.sh` flock leaks FD to .NET VBCSCompiler | medium | `O_CLOEXEC` on flock FD; only affects .NET-toolchain consumers | small (~half day, hard to test without .NET host) |
| C-018 | partial-complete recheck ignores `--skip-acceptance-criteria` | medium | `update-task.sh` recheck branch must propagate the flag | small (~half day) |

## Acceptance Criteria

### Agent
- [x] Pickup envelope located, parsed, and bugs catalogued individually (above table)
- [x] Each bug assessed: severity, fix locus, complexity estimate
- [x] Recommendation written: priority order + decomposition plan into individual follow-up tasks

## Verification

# Inception (decompose-and-decide) task. No build verification — the decision IS the deliverable.
test -f .context/pickup/processed/P-045-from-ntb-atc-bug-report.yaml
grep -q "C-006\|C-009\|C-010\|C-011\|C-012\|C-018" .tasks/active/T-1625-pickup-six-framework-level-bugs-surfaced.md

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

## Recommendation

**Recommendation:** GO — decompose into 6 individual bug tasks; ship in priority order

**Rationale:** The envelope bundles 6 distinct bugs from 003-NTB-ATC-Plugin's `decided-defer` register. Each has a different fix locus and risk profile. Per the "one bug = one task" rule, they cannot be a single build task — each needs its own RCA, fix, and regression test. The right move is decomposition into 6 follow-up build tasks, prioritized by leverage:

**Suggested priority order (smallest blast → highest leverage):**
1. **C-018 partial-complete recheck flag drop** (correctness bug; flag-respect is load-bearing for autonomous flows)
2. **C-011 silent exit-1 on missing Recommendation** (likely already fixed for inception by T-1545; verify and extend to non-inception)
3. **C-006 sovereignty dual-fire** (annoyance; fires `--skip-sovereignty` bypass twice per inception close-out — pollutes bypass log)
4. **C-009 Watchtower HTTP 500 on partial-complete decide** (UX correctness; CLI fallback exists but Watchtower is the canonical path)
5. **C-012 flock FD leak to VBCSCompiler** (correctness; only fires for .NET-toolchain consumers — hard to regression-test without a .NET host, but `O_CLOEXEC` fix is small)
6. **C-010 project-level agent home convention** (design + implementation; needs its own inception to choose between `.fabric/agents/`, `.claude/agents/`, or shim convention)

**Evidence:**
- Envelope source verified: `.context/pickup/processed/P-045-from-ntb-atc-bug-report.yaml` (84 lines, 6 distinct concerns referenced by line numbers in the consumer's concerns.yaml)
- All 6 bugs have documented workarounds in 003-NTB-ATC-Plugin (per envelope) — no consumer is blocked, this is friction reduction
- C-011 has prior framework work (T-1545); fix may already be complete for the inception path — first task should verify-and-extend rather than rebuild
- C-010 is design, not bug — should be its own inception task (workflow_type: inception), not a build

**Decomposition plan:**
On GO decision, framework-agent creates:
- T-1633 (build): C-018 partial-complete recheck flag propagation
- T-1634 (build): C-011 verify T-1545 fix + extend to non-inception
- T-1635 (build): C-006 sovereignty single-fire across inception arc
- T-1636 (build): C-009 Watchtower HTTP 500 recovery
- T-1637 (build): C-012 flock FD `O_CLOEXEC`
- T-1638 (inception): C-010 project-level agent home convention

T-1625 closes once the six follow-ups are filed.

**Out of scope for this inception:**
- Actually shipping any of the six fixes (each gets its own task and RCA)
- Reopening the consumer's `decided-defer` entries (consumer will reopen on framework-side fix landing)

## Decisions

### 2026-05-01 — Decompose vs single-task fix
- **Chose:** Decompose into 6 individual tasks, prioritized.
- **Why:** "One bug = one task" rule. Each concern has a different fix locus, risk profile, and regression-test surface. Bundling them would destroy causality traceability and make commit messages multi-purpose.
- **Rejected:** Single sweeping "fix all six" build task — would violate Task Sizing Rules and create an all-or-nothing PR.
- **Rejected:** Defer all six — consumer has documented this is cumulative friction; each individual fix is small and worth doing.

## Updates

### 2026-04-30T21:07:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1625-pickup-six-framework-level-bugs-surfaced.md
- **Context:** Initial task creation

### 2026-05-01T10:00:52Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-05-01T10:02:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-05-01T10:03:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — decompose into 6 individual bug tasks; ship in priority order

Rationale: The envelope bundles 6 distinct bugs from 003-NTB-ATC-Plugin's `decided-defer` register. Each has a different fix locus and risk profile. Per the "one bug = one task" rule, they cannot be a single build task — each needs its own RCA, fix, and regression test. The right move is decomposition into 6 follow-up build tasks, prioritized by leverage:

Suggested priority order (smallest blast → highest leverage):
1. C-018 partial-complete recheck flag drop (correctness bug; flag-respect is load-bearing for autonomous flows)
2. C-011 silent exit-1 on missing Recommendation (likely already fixed for inception by T-1545; verify and extend to non-inception)
3. C-006 sovereignty dual-fire (annoyance; fires `--skip-sovereignty` bypass twice per inception close-out — pollutes bypass log)
4. C-009 Watchtower HTTP 500 on partial-complete decide (UX correctness; CLI fallback exists but Watchtower is the canonical path)
5. C-012 flock FD leak to VBCSCompiler (correctness; only fires for .NET-toolchain consumers — hard to regression-test without a .NET host, but `O_CLOEXEC` fix is small)
6. C-010 project-level agent home convention (design + implementation; needs its own inception to choose between `.fabric/agents/`, `.claude/agents/`, or shim convention)

Evidence:
- Envelope source verified: `.context/pickup/processed/P-045-from-ntb-atc-bug-report.yaml` (84 lines, 6 distinct concerns referenced by line numbers in the consumer's concerns.yaml)
- All 6 bugs have documented workarounds in 003-NTB-ATC-Plugin (per envelope) — no consumer is blocked, this is friction reduction
- C-011 has prior framework work (T-1545); fix may already be complete for the inception path — first task should verify-and-extend rather than rebuild
- C-010 is design, not bug — should be its own inception task (workflow_type: inception), not a build

Decomposition plan:
On GO decision, framework-agent creates:
- T-1633 (build): C-018 partial-complete recheck flag propagation
- T-1634 (build): C-011 verify T-1545 fix + extend to non-inception
- T-1635 (build): C-006 sovereignty single-fire across inception arc
- T-1636 (build): C-009 Watchtower HTTP 500 recovery
- T-1637 (build): C-012 flock FD `O_CLOEXEC`
- T-1638 (inception): C-010 project-level agent home convention

T-1625 closes once the six follow-ups are filed.

Out of scope for this inception:
- Actually shipping any of the six fixes (each gets its own task and RCA)
- Reopening the consumer's `decided-defer` entries (consumer will reopen on framework-side fix landing)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-dc348914
- **Timestamp:** 2026-05-01T10:03:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-01T10:03:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
