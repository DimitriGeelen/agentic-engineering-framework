---
id: T-4155
name: "Reviewer route for READY TO CLOSE tasks (owner: agent human, zero Human criteria, all Agent ACs ticked, verification green): an independent reviewer closes with recorded provenance instead of the operator rubber-stamping (832 proposal, their T-1127 / PD-357)"
description: >
  832 (msg ec0c9369, operator-prompted): T-1127 shipped, 6/6 Agent ACs, verification 3/3, no ### Human section, owner: human. The agent cannot close it (human-owned), cannot re-own it (--skip-human-ownership refused in agent sessions, T-3586), and fw task delegate has nothing to convert, so it waits for the operator with nothing to judge (AEF's own T-3449 section calls this 'finished work with no route to closure'). Their operator: 'Why do you need me? We've got review agents.' Proposals: (a) a reviewer close: fw reviewer judge/close checks shipped evidence, ACs ticked, verification green, no Human section; PASS closes with reviewer provenance (verdict ledger), owner unchanged; doubt escalates; (b) alternative: owner flips to agent when no Human criteria exist (the operator not writing Human ACs = consent). Touches sovereignty (ownership, closure authority): inception.

status: captured
workflow_type: inception
owner:
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-10-13T14:53:28Z
last_update: 2026-10-13T14:53:28Z
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

# T-4155: Reviewer route for READY TO CLOSE tasks (owner: human, zero Human criteria, all Agent ACs ticked, verification green): an independent reviewer closes with recorded provenance instead of the operator rubber-stamping (832 proposal, their T-1127 / PD-357)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

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

**Recommendation:** GO

**Rationale:** The gap is real and named in AEF's own docs (T-3449 READY TO CLOSE), the operator ruling D-626/T-3557 already routes everything outside the three carve-outs to an independent reviewer, and the verdict ledger (T-3579/T-3581) provides the provenance a reviewer close needs. GO for (a): reviewer acts on the close only, ownership stays as recorded, any doubt escalates; carve-out classes (act-in-the-world, tier-0-or-bypass, sovereignty fields) never qualify. Reject (b): silently flipping ownership changes a sovereignty field without an act.

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
