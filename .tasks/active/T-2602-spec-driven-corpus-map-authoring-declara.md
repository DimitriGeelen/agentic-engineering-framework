---
id: T-2602
name: "Spec-driven corpus map authoring: declarative spec -> deterministic BPMN generation
  -> delete/recreate repeatability proof"
description: >
  Inception: Spec-driven corpus map authoring: declarative spec -> deterministic BPMN
  generation -> delete/recreate repeatability proof

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-22T10:42:06Z
last_update: '2026-07-22T10:45:05Z'
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
  - ts: '2026-07-22T10:43:57Z'
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
  - ts: '2026-07-22T10:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2602: Spec-driven corpus map authoring: declarative spec -> deterministic BPMN generation -> delete/recreate repeatability proof

## Problem Statement

Corpus workflow maps are authored and fixed by ad-hoc XML surgery with no source of truth, no contract enforcement, and no regeneration path. Operator steer (2026-07-22): what matters is a **repeatable, reliable, transferable process**, not any particular workflow — "fine with deleting it and then recreating; that would actually prove repeatable, consistent, correct and reliable." Same-day evidence: T-2600 authored a contract-violating ref form and a duplicate node under live verification (RCA: T-2601); the corpus carries a typed event nothing emits, invisible because nothing lints the corpus as a system. Research artifact: `docs/reports/T-2602-spec-driven-corpus-authoring.md`.

## Assumptions

- A1: 832 bundle round-trips generator-produced XML without normalizing it (→ IW-2)
- A2: post-GO editing model is decidable — spec-authoritative vs canvas-authoritative with reverse path (→ IW-1, operator design call)
- A3: "identical" is definable as canonical-form comparison despite server-stamped fields (→ IW-3)

## Open Questions

- **IW-1: Who is authoritative after GO — the spec or the designer canvas?**
  confidence: 1
  disposition:
  rationale: Operator design call. Spec-authoritative (designer read/annotate only) makes recreate-proof trivial but constrains visual editing; canvas-authoritative needs a reverse path (export → spec update) to keep the proof honest.

- **IW-2: Does the 832 bundle round-trip generator-produced XML without normalizing it?**
  confidence: 1
  disposition:
  rationale: A1 in the research artifact — if first manual save in the designer reshapes the XML, spec and reality drift on first edit; S1 spike answers this against the live bundle.

- **IW-3: What does "identical" mean for the recreate proof, given server-stamped versions/timestamps?**
  confidence: 2
  disposition:
  rationale: S2 spike — canonical-form comparison (strip stamped fields, normalize order) vs byte-identity; the T-100191 corpus lint and 832 S5a parity guard are prior art for key-set parity checks.

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

- **S1** (2h): reverse-derive a spec from served `aef-dispatch-loop` + `aef-task-lifecycle`; prove the spec can express everything the maps carry (lanes, typed events, handoff pairs, positions, notes). Answers IW-2 prerequisite.
- **S2** (1h): canonical-form comparator — define "semantically identical" for the recreate proof (strip server-stamped fields, normalize ordering). Answers IW-3.
- **S3** (1h): lint rule inventory mapped 1:1 to observed defect classes (T-2600 legacy-ref, T-2600 duplicate-handoff, T-2551 emitterless event, T-2584 ghost refs). No speculative rules.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** spec format for corpus maps; deterministic generator writing through `/api/save`; corpus lint (per-map + cross-map); delete/recreate proof harness; dispatch-loop recreate as first proof (subsumes the paused T-2601 fix Options A/B/C).
**OUT:** any 832 bundle/editor changes (their T-234/T-237/0.3.1 track); the typed-event *consumption* build (T-2551, blocked on T-213 kind= ruling); migrating non-corpus scratch maps (t2584-scratch, t25xx-verify); building ANY of it before the operator's GO.

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
- S1 shows a spec can faithfully express the existing corpus maps (no lossy corners)
- IW-1 (spec vs canvas authority) gets an operator answer
- The recreate proof is definable (S2 comparator exists)

**NO-GO if:**
- The 832 bundle normalizes XML so round-trip identity is unachievable (IW-2 fails) — pivot to lint-only as a smaller separate task
- Spec fidelity requires mirroring the entire BPMN surface (spec becomes XML-in-YAML — no gain over the artifact)

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

Operator steer 2026-07-22: repeatable/reliable/transferable process over artifact-fixing. Evidence base: T-2600/T-2601 RCA proved ad-hoc XML surgery produces contract violations (legacy ref form) and duplicate nodes even under live verification; corpus has no regeneration path. Acceptance test operator-defined: delete aef-dispatch-loop and recreate from spec, correct and identical. Builds on existing substrate: /api/save, T-2552 compile WARN lint leg, sha-pinned fixture discipline from 832 seam.

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

### 2026-07-22T10:43:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
