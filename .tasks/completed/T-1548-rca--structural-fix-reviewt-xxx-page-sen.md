---
id: T-1548
name: "RCA + structural fix: /review/T-XXX page sends human elsewhere to review (treasure hunt anti-pattern across all Human ACs)"
description: >
  RCA + structural fix: /review/T-XXX page sends human elsewhere to review (treasure hunt anti-pattern across all Human ACs)

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T15:41:44Z
last_update: 2026-04-27T15:48:36Z
date_finished: 2026-04-27T15:48:36Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1548: RCA + structural fix: /review/T-XXX page sends human elsewhere to review (treasure hunt anti-pattern across all Human ACs)

## Problem Statement

The triggering incident (`/review/T-XXX` page sends human elsewhere to verify) is a *symptom*. The actual problem is meta: **the agent keeps responding at symptom altitude despite G-019 being registered as `[high]` for months and CLAUDE.md §"Post-Fix Root Cause Escalation" being explicit guidance.** When the user said "RCA + INCEPTION + STRUCTURAL REMEDIATION", the agent's first move was to `curl /review/T-1448` and inspect HTML — which is the very behavior G-019 names. G-019 is advisory text, not a structural gate. It has been observable but unenforceable for months.

Full RCA + evidence + spike plan in `docs/reports/T-1548-rca-escalation-structural.md`. Read that first.

**Scoped to (c) — both layers** (per dialogue with user):
- **Layer B** (observability sweep) — make symptom-fixing detectable
- **Layer A** (structural gate) — act on B's signal

## Assumptions

- A1: The pattern is detectable from existing data (commit messages, task structure, dialogue corrections) without instrumentation
- A2: A small set of heuristics (≤3) covers ≥70% of true symptom-fix incidents without flagging routine work
- A3: A pre-completion gate or commit trailer can enforce RCA-first without forcing churn on legitimately-tactical fixes
- A4: Layer A applied to T-1548 itself flags the recursion case correctly (the spike validates by self-application)

## Exploration Plan

Three time-boxed spikes, total ~1.5h. All spikes write findings into `docs/reports/T-1548-rca-escalation-structural.md`. No production code.

- **Spike 1 — Layer B heuristics** (~45 min): scan completed tasks last 30 days for symptom-fix candidates by 2-3 simple heuristics (no `## RCA` section on bug-class task, fix-commit within N min of correction phrase in user message, repeated learning IDs across N tasks). Report counts + false-positive sample.
- **Spike 2 — Layer A gate sketch** (~30 min): show diff for `update-task.sh` pre-completion check + a commit-msg trailer check. Don't ship.
- **Spike 3 — recursion test** (~15 min): apply Spike 1's signal to T-1548 itself. If it doesn't flag, the heuristic is wrong.

## Technical Constraints

- Layer B must be cron-runnable and read-only (no completion blocking)
- Layer A must support `--force` with Tier-2 logging (legitimate tactical fixes exist)
- Self-application: any solution must withstand the recursion case (must not be a symptom fix to symptom-fixing)

## Scope Fence

**IN:**
- RCA on G-019's persistence (why advisory text failed)
- Layer A + B design (sketch only, not build)
- Recursion safety check

**OUT:**
- Fixing `/review/T-XXX` page UX (downstream task once Layer B flags the human-AC navigation pattern)
- Any other specific symptom-fix arc currently in flight
- New CLAUDE.md text as primary remediation (text-as-control is the failed mechanism)

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
- Spike 1 produces ≤3 heuristics that flag ≥70% of mined symptom-fix incidents with <30% FP
- Spike 2 produces a gate sketch that fits in `update-task.sh` + commit-msg hook (≤80 LOC delta)
- Spike 3 confirms self-application: the heuristic flags T-1548 itself (recursion-safe)

**NO-GO if:**
- Spike 1 heuristics are too noisy (FP > 50%) — observability layer would itself become noise
- Spike 2 shows the gate would block legitimately-tactical fixes >20% of the time
- Spike 3 fails: solution can't see itself = solution is a symptom fix to symptom-fixing

**DEFER if:**
- Spikes show the right altitude is even higher (e.g. agent self-prompt restructuring) and needs separate scoping

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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

## Reviewer Verdict (v1.5)

- **Scan ID:** R-038f3a24
- **Timestamp:** 2026-06-02T14:58:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T15:48:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
