---
id: T-4998
name: "Backlog triage in the framework: a fw verb and a Watchtower /backlog page (010
  + 055 proposal)"
description: >
  010-termlink (msg f6aa307a, their operator): triage of their 343 open tasks (their
  T-3648, docs/reports/T-3648-backlog-triage.md): 109 done-not-closed, 122 parked
  >=60 days with no reason now, 47 live, 65 needing the operator or a reviewer. 055
  is building, with 010, a check for outstanding tasks plus a Watchtower page; proposal:
  take the result into the framework. Framework findings: (1) a task file's git date
  is unreliable as activity because the BVP estimator rewrites files; the last commit
  NAMING the task is the better signal; (2) counting Human ACs must skip the template's
  example checkboxes inside HTML comments, or every task looks human-blocked. Related:
  AEF's own answer to 055 (T-4982): the core problem is a backlog with no pruning
  owner.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-11-01T23:39:30Z
last_update: '2026-11-01T23:45:22Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-11-01T23:45:22Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=124,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4998: Backlog triage in the framework: a fw verb and a Watchtower /backlog page (010 + 055 proposal)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->
Backlogs only grow: capturing a task has an owner and a moment, pruning has neither. Two projects measured it: 010 found 109 of 343 open tasks done but never closed, and 055 found the same pattern (their T-107). AEF has the same disease (510 open tasks; see T-4982).

**Evidence so far (2026-11-02):**
- **055 (msg 8c77b97f; their inception T-681, page T-682).** Their operator ruled that 055 and 010 each build a triage page, exchange experiences and feed back what works.
  - The shape: batches of about 10 tasks, each with a summary, evidence and the agent's proposal. The operator answers with six permanent choices: Prioritize, Keep, Park, Drop, Close (finished work), Tell me more.
  - In batch 1 the operator overrode the agent on 5 of 7 questions (three tasks the agent proposed to drop or park were prioritized). So proposals are never applied automatically, and no expiry may drop a task silently.
- **010 (msg 10650d93; their T-3649).** Their page is built as a registered local change to our `web/` (a triage blueprint and template, plus one registration line), so AEF can lift it as-is. They will send the done-not-closed pattern (which evidence held, which gates refused, why) once their closers finish 56 agent-closable tasks.
- **Framework gaps found:**
  1. Tasks have no honest non-completed end. The only statuses are captured, started-work, issues and work-completed; about 121 of 055's completed tasks say in their text that they were superseded, obsolete or dropped. A `dropped`/`superseded` ending (with a reason) is likely needed.
  2. `revisit_at` exists, but no 055 task used it, and no CLI verb sets it (T-2865).
  3. A task file's date is noise, because the estimator rewrites files; the last commit naming the task is the better activity signal (010).
  4. Human-AC counters must skip the template's commented example checkboxes (010; AEF's tick guard already does, T-2954; the other counters are to be checked).

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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

**Recommendation:** DEFER

**Rationale:** Proposal with evidence from two projects (010 triage of 343 tasks, 055 building a check and page); the operator decides whether AEF owns a backlog-triage surface, and 055/010's result should be seen first.

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
