---
id: T-2505
name: "Worktree usage policy — refine per-task default (when to use a worktree vs not)"
description: >
  Inception: Worktree usage policy — refine per-task default (when to use a worktree vs not)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-01T11:31:04Z
last_update: 2026-07-01T11:32:11Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
---

# T-2505: Worktree usage policy — refine per-task default (when to use a worktree vs not)

## Problem Statement

The framework hardened worktree *reliability* (T-2464 → T-2465/2466/2469) but never codified a worktree *usage/lifecycle* policy. Worktrees become long-lived, shared, multi-task catch-alls, producing two structurally-linked difficulties seen live this session: (1) all-or-nothing landing — a long-lived worktree branch accumulates unrelated tasks' commits, so FF merge-back of one task carries all beneath it (T-2502 land bundled 9 commits); (2) stranded divergence — MAIN and the worktree drift apart with real uncommitted work stuck on the wrong side (MAIN has 267 uncommitted files incl. T-2353's audit `--emit-tasks`, committed nowhere, blocking host go-live). Only D-026 exists (audit-specific). Full evidence + candidates: `docs/reports/T-2505-worktree-usage-policy.md`.

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

- **IW-1: Should the default be "no worktree for small/mechanical tasks" (C1), reserving worktrees for genuine parallel isolation?**
  confidence: 1
  disposition: deferred
  rationale: matches operator intuition; not yet weighed against isolation benefits / harness default

- **IW-2: If worktrees are kept, what lifecycle discipline prevents long-lived shared catch-alls (C2: one-task-per-worktree + land-and-prune)?**
  confidence: 1
  disposition: deferred
  rationale: 9-commit bundled land + stranded MAIN divergence both trace to missing lifecycle

- **IW-3: Should a doctor/audit advisory flag long-lived worktrees (>N tasks / >D days) and MAIN-vs-worktree divergence with stranded uncommitted source (C3)?**
  confidence: 1
  disposition: deferred
  rationale: guardrail vs policy; would have surfaced this session's MAIN divergence earlier

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

**Rationale:**

Freshly opened exploration triggered by this session's worktree difficulties. Policy candidates (no-worktree-for-small-mechanical-tasks; one-per-task + land-and-prune lifecycle; worktree-usage gate) not yet evaluated; recommendation follows the exploration dialogue and episodic evidence mining.

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

### 2026-07-01T11:32:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
