---
id: T-100139
name: "branch/worktree lifecycle policy — prevent merged-debris + divergent-strand
  accumulation"
description: >
  Inception: branch/worktree lifecycle policy — prevent merged-debris + divergent-strand
  accumulation

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-04T10:00:54Z
last_update: '2026-07-04T10:15:02Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-04T10:02:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F-AUTONOMY: 2
      audit_severity: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F-AUTONOMY=2 
      (no-signal); audit_severity=2 (no-signal); F3=2 (no-signal); F1=2 
      (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-04T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100139: branch/worktree lifecycle policy — prevent merged-debris + divergent-strand accumulation

## Problem Statement

The repo accumulates branch/worktree pollution with no lifecycle governance: merged
branches are never deleted (29/36 at review time), long-lived session branches diverge
silently from master (up to +139/−248), and worktrees outlive their merged branches
carrying unlanded artifacts in dirty files. For the operator this reads as an
untrustworthy repo surface; for agents it creates merge-conflict debt and silent-loss
risk. Full evidence: `docs/reports/T-100139-branch-worktree-lifecycle.md`.

## Assumptions

- Merged-branch deletion is always information-free when `ahead:0` vs origin/master (validated during T-100138 — per-branch check before every deletion).
- `fw integrate run` is the single landing path for strands, so a delete-on-landing hook there closes the debris tap (to validate in C1 slice — direct `git merge` bypasses would escape it).
- Divergence observability (C2/C3) changes behavior without a blocking gate — WARN-first is enough (test after a few weeks of live counts).

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

- **IW-1: Should `fw integrate run` delete the landed source branch by default (opt-out) or opt-in?**
  confidence: 2
  disposition: answered
  rationale: default-delete with `--keep-branch` opt-out — debris tap evidence (29/36 merged-undeleted, docs/reports/T-100139-branch-worktree-lifecycle.md F1); opt-in flags never get adopted (T-1878 adoption-gap precedent)

- **IW-2: Which branch-hygiene signals belong in doctor vs audit, and at what thresholds?**
  confidence: 1
  disposition: deferred
  rationale: candidate set listed in artifact C2 (merged-undeleted, behind>50, merged-branch worktree, dirty-worktree age, ahead:0 remote refs); threshold calibration needs a few weeks of live counts — defer to the C2 build slice

- **IW-3: What is the master-sync cadence rule for long-lived branches (merge master in vs rebase vs land-early)?**
  confidence: 1
  disposition: deferred
  rationale: strands are 215-248 behind (artifact F2); answer interacts with the C4 merge-back sequencing — decide during first strand landing (t2353, smallest)

- **IW-4: Does session handover belong on the current branch at all, or should handover auto-commit target a dedicated ref?**
  confidence: 0
  disposition: deferred
  rationale: root-cause 2 (session branches become accidental trunks) — needs design dialogue; touches handover agent + claude-fw wrapper

## Exploration Plan

Evidence phase already executed inline (2026-07-04 session dialogue) — measurements in
docs/reports/T-100139-branch-worktree-lifecycle.md. Remaining: human GO/NO-GO on
candidates C1-C3, then slice into build tasks.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** lifecycle policy for branches + worktrees (creation→landing→deletion), doctor/audit observability of branch hygiene, handover divergence surfacing, disposition plan for the 8 open strands.
**OUT:** executing the strand merge-backs themselves (C4 — separate build tasks post-GO); changing the worktree isolation mechanism; TermLink session lifecycle (separate concern, noted in artifact F3); github mirror ref cleanup (follows origin automatically via PushRepository).

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

**Recommendation:** GO

**Rationale:**

Evidence complete from 2026-07-04 hygiene review: 29/36 local branches were merged debris (now cleaned, T-100138); 4 divergent strands sit 22-139 ahead / 215-248 behind master; worktrees outlive merged branches with dirty files; zero observability in doctor/audit. Structural gaps identified, candidates concrete (integrate-deletes-on-landing, doctor branch-hygiene section, handover divergence surfacing). Build slices are well-scoped.

**Evidence:**

- Full findings + candidate matrix: `docs/reports/T-100139-branch-worktree-lifecycle.md`
- Cleanup executed and verified: T-100138 (28 local + 4 remote merged branches deleted, arc012 worktree torn down, 4 handover records + T-2401 metadata rescued; local branch count 36 → 8)
- Divergence table (F2): t2416 +139/−248, t2417 +58/−215, rca-strand +37/−215, t2353 +22/−248 vs origin/master — all touching audit.sh / bin/fw / lib/
- Proposed GO scope: C1 (integrate deletes landed branch, `--keep-branch` opt-out), C2 (doctor/audit branch-hygiene WARNs), C3 (handover prints ahead/behind + merge-back-overdue nudge); C4 merge-back schedule follows as separate tasks; C5 (branch freeze) rejected

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

### 2026-07-04T10:02:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
