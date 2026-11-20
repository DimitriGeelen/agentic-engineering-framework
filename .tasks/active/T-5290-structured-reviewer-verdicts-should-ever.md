---
id: T-5290
name: "Structured reviewer verdicts: should every reviewer verdict (pass, fail, amber)
  follow one fixed structure, adopted from 1409-sprind's protocol, so a wrong verdict
  can be checked and refuted from its own content, and delivered to all consumer projects?"
description: >
  Inception: Structured reviewer verdicts: should every reviewer verdict (pass, fail,
  amber) follow one fixed structure, adopted from 1409-sprind's protocol, so a wrong
  verdict can be checked and refuted from its own content, and delivered to all consumer
  projects?

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
waiting_on: agent
revisit_at: 2026-11-27
created: 2026-11-20T07:11:50Z
last_update: '2026-11-20T07:15:24Z'
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
  - ts: '2026-11-20T07:12:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-11-20T07:15:24Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=130,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5290: Structured reviewer verdicts: should every reviewer verdict (pass, fail, amber) follow one fixed structure, adopted from 1409-sprind's protocol, so a wrong verdict can be checked and refuted from its own content, and delivered to all consumer projects?

## Problem Statement

Reviewer verdicts (`fw reviewer judge`, verdict ledger) are free text: VERDICT / WHY / GUIDANCE. On T-5262 the codex seat gave red twice, claiming icons were missing from a capture where they are pixel-identical to the reference (T-5289). Nothing in the verdict's form let the framework, the other seats or the operator check the claim against the evidence; one wrong seat blocks a unanimous panel and the only exits are a gate bypass or verdict shopping. Operator, 2026-11-20: "we need to enhance the review protocol ... A reviewer, a fail or a pass should have a certain set structure, and 1409 already has defined that structure. And I want us to implement this in the framework so that all the vendor projects also get this." ring20 asked for the same (structured verdict format as a framework option, T-4649 consultation b3). Research: docs/reports/T-5290-structured-reviewer-verdicts.md.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->
- 1409's structure is general enough for AEF's criteria classes (render, deterministic, taste), not only theirs.
- A structured verdict lets a wrong red be refuted mechanically or by a second seat, without a gate bypass.

## Open Questions

- **IW-1: What exactly is 1409's verdict structure (fields, required evidence per claim, how pass and fail differ), and what made them build it?** (consult 1409)
- **IW-2: How does a structured verdict fit the existing ledger (verdicts.jsonl digest, provenance, rung panels) without breaking committed rows?**
- **IW-3: What happens to a verdict whose claim its own evidence refutes (T-5262 case): rejected at record time, sent to another seat, or escalated to the operator?**
- **IW-4: How does it reach consumer projects (vendored reviewer preamble and validator via fw upgrade), and does ring20's request (b3) fit the same shape?**

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

**Recommendation:** EXPLORING

**Rationale:**

Operator 2026-11-20 after T-5262: the codex seat gave red twice on a claim its own evidence refutes; the free-text verdict gave no structure to check it against. 1409 has already defined a verdict structure; ring20 asked for a structured verdict format as a framework option (T-4649 b3). Consult 1409 first.

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

### 2026-11-20T07:12:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
