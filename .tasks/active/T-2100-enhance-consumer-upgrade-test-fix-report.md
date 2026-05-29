---
id: T-2100
name: "Enhance consumer-upgrade-test-fix-report prompt: panic-stop + dry-run + recursion
  sentinel + upstream-check + playwright disambig + fork-bomb fields"
description: >
  User asked: 'do we need to adjust/enhance instructions?' for prompts/consumer-upgrade-test-fix-report.md
  after the SEV-1 fork-bomb incident on /opt/termlink. The prompt is shape-aware but
  did not CONTAIN the fork-bomb when it fired. 6 enhancement candidates identified.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [prompt-library, fw-upgrade, reliability, T-2078-cluster]
components: []
related_tasks: [T-2078, T-2099, T-2097, T-2098]
created: 2026-05-29T14:22:31Z
last_update: '2026-05-29T14:30:02Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-29T14:30:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T14:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2100: Enhance consumer-upgrade-test-fix-report prompt: panic-stop + dry-run + recursion sentinel + upstream-check + playwright disambig + fork-bomb fields

## Problem Statement

`prompts/consumer-upgrade-test-fix-report.md` (this framework's canonical fleet upgrade prompt) is shape-aware but failure-silent. The SEV-1 fork-bomb on /opt/termlink (T-2099) exposed six containment gaps. User asked: "do we need to adjust/enhance instructions?"

Full research artifact + 6 enhancement candidates (E1–E6) in `docs/reports/T-2100-prompt-fork-bomb-containment.md`.

## Assumptions

- The prompt source IS in this framework repo (confirmed: `prompts/consumer-upgrade-test-fix-report.md`, registered in fabric).
- Consumer agents will read the prompt at upgrade-time → text additions ship via subsequent upgrades, no behavioural side-effects on the framework itself.
- All 6 enhancements are mutually reinforcing → single PR makes sense.

## Exploration Plan

Research complete in `docs/reports/T-2100-prompt-fork-bomb-containment.md`. Six candidates (E1 panic-stop, E2 dry-run gate, E3 recursion sentinel, E4 upstream-check, E5 playwright disambig, E6 fork-bomb fields). Recommendation: GO all six as a single PR.

## Technical Constraints

- Pure prompt-text edits. No `bin/fw` or `lib/` changes.
- Must not conflict with existing shape-detection / failure-envelope structure.
- Bash snippets in the prompt must be copy-pasteable (single line where possible, fully self-contained).

## Scope Fence

**In:** E1–E6 enhancements to `prompts/consumer-upgrade-test-fix-report.md`; fanout of E1/E2/E6 to other upgrade-relevant prompts on V2.

**Out:** changes to `bin/fw` / `lib/upgrade.sh` (those are T-2099/T-2092); structural prompt-library testing (V3 follow-up).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** GO — land all six enhancements (E1–E6) as a single PR.

**Rationale:** Each closes a containment gap exposed by T-2099. They are pure prompt-text additions with no framework behavioural impact. Cost is bounded (~80 lines). Benefit is structural: every future consumer that receives this prompt has containment inline, even if the underlying recursion ever regresses. Same G-019 silent-quality-decay class as T-2097/T-2098.

**Evidence:**
- T-2099 fork-bomb incident: 2 hits in 1 hour on /opt/termlink, no consumer-side panic-stop available → required dispatcher intervention.
- Prompt is well-structured (shape-detect → upgrade → doctor → test → fix → report) but failure-silent.
- T-2099 fix (`be72baa5`) shipped to GitHub; but the prompt should not assume every consumer pulls before running.
- Pattern is established in the library — `prompts/escalation-triage.md` already has panic-stop guidance.
- Full research: `docs/reports/T-2100-prompt-fork-bomb-containment.md`

**Suggested follow-ups (on GO):**
- T-2100-V1: apply E1–E6 to `prompts/consumer-upgrade-test-fix-report.md`.
- T-2100-V2: mirror E1/E2/E6 to other upgrade-relevant prompts.
- T-2100-V3: bats coverage for prompt-library structural guarantees.

**Rejected:** piecemeal landing (review overhead, no benefit), minimal set E3/E6 only (leaves E1/E2 gaps in agent panic-stop awareness).

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
