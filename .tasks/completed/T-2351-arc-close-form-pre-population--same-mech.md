---
id: T-2351
name: "Arc close form pre-population — same mechanic as task/inception ## Recommendation
  block (Defect D from T-2347)"
description: >
  T-2347 RCA missed Defect D. The /arcs/<slug>/close form has slots for demo_value,
  decision, justification but on GET only pre-populates demo_value from anchor task's
  ## Recommendation -> Suggested demo: field (web/blueprints/arcs.py:1318). prev_decision
  and prev_justification are hardcoded empty strings on GET (line 1335). When agent
  surfaces an arc for closure with a recommendation in hand, the operator faces an
  empty form and must hand-type demo path + decision narrative — even though the same
  agent could have written all of it. Tasks/inceptions don't have this gap: ## Recommendation
  block renders, operator confirms or amends. The arc YAML has decision:/demo_evidence:
  fields (currently set ONLY by fw arc close itself) — by design they could be agent-set
  pre-handoff. Three viable approaches: (X) extend anchor task ## Recommendation parser
  with Suggested decision: + Suggested justification: fields and wire form. (Y) Add
  proposed_decision: / proposed_demo: fields to arc YAML schema. (Z) Hybrid — read
  arc YAML fields if present, fall back to anchor task block.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [watchtower, arc-mechanics, ux, inception-rca]
components: []
related_tasks: [T-2347, T-2348, T-2349, T-2350]
created: 2026-06-12T10:49:57Z
last_update: '2026-08-16T22:25:03Z'
date_finished: 2026-06-12T10:55:44Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:03Z'
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
---

# T-2351: Arc close form pre-population — same mechanic as task/inception ## Recommendation block (Defect D from T-2347)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Anchor-task-block (X), arc-YAML-fields (Y), or hybrid (Z) — which carrier surface does the agent write to?**
  confidence: 2
  disposition: answered
  rationale: Hybrid Z — extend `_anchor_recommendation` parser (arcs.py:556-606) with `Suggested decision:` + `Suggested justification:` siblings to existing `Suggested demo:`. Anchor-task is the agent's pre-existing recommendation surface (T-679 parity). Arc YAML `decision:`/`demo_evidence:` stay POST-CLOSE-WRITE only (what `fw arc close` records). Backward-compatible: form falls back to empty if Suggested-* absent.

- **IW-2: Form pre-pop UX — checkbox toggle or default-text-overwritable?**
  confidence: 2
  disposition: answered
  rationale: Default text the operator can overwrite. Mirrors existing `suggested_demo` flow. Adding a checkbox adds UI for a non-decision (agent's recommendation is advisory; operator authority is intrinsic via Submit). Keep UI minimal.

- **IW-3: When does the agent write Suggested-* fields — before chat handoff, or lazily at close?**
  confidence: 2
  disposition: answered
  rationale: Before the chat handoff URL. Extension of §Arc Action Handoffs (T-2347 C1) rule. Lazy population would race the operator's click. Memory + CLAUDE.md update flows together with the form code change.

- **IW-4: Backward compatibility for already-closed arcs?**
  confidence: 3
  disposition: dissolved
  rationale: Non-issue. `arc_close_surface:1262-1263` redirects closed/abandoned arcs to `/arcs/<slug>` (form unreachable). New pre-pop only affects in-progress arcs about to be closed.

- **IW-5: Add `proposed_decision:` to arc YAML schema for arcs whose anchor is missing/malformed?**
  confidence: 1
  disposition: deferred
  rationale: Edge case. If anchor parse fails, form falls back to empty (current behavior). File follow-up only if recurrence observed.

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

**Rationale:** Three concrete defect classes already evidenced at file:line. (A) web/blueprints/arcs.py:1318 reads ONLY suggested_demo, never reads arc.demo_evidence or anchor Suggested decision:. (B) line 1335 hardcodes prev_decision='' on GET. (C) _anchor_recommendation parser at arcs.py:556-606 only extracts one field (suggested_demo). Each is a small change; together they close the parity gap with task/inception review. High value: arc closure UX presently demands operator hand-typing data the agent already has. Recommendation GO with rationale walked.

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

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Three concrete defect classes already evidenced at file:line. (A) web/blueprints/arcs.py:1318 reads ONLY suggested_demo, never reads arc.demo_evidence or anchor Suggested decision:. (B) line 1335 hardcodes prev_decision='' on GET. (C) _anchor_recommendation parser at arcs.py:556-606 only extracts one field (suggested_demo). Each is a small change; together they close the parity gap with task/inception review. High value: arc closure UX presently demands operator hand-typing data the agent already has. Recommendation GO with rationale walked.

**Date**: 2026-06-12T10:55:44Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-12T10:55:44Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Three concrete defect classes already evidenced at file:line. (A) web/blueprints/arcs.py:1318 reads ONLY suggested_demo, never reads arc.demo_evidence or anchor Suggested decision:. (B) line 1335 hardcodes prev_decision='' on GET. (C) _anchor_recommendation parser at arcs.py:556-606 only extracts one field (suggested_demo). Each is a small change; together they close the parity gap with task/inception review. High value: arc closure UX presently demands operator hand-typing data the agent already has. Recommendation GO with rationale walked.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c031b55d
- **Timestamp:** 2026-06-12T10:55:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

### 2026-06-12T10:55:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
