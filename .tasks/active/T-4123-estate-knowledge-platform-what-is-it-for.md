---
id: T-4123
name: "Estate knowledge platform: what is it for and what must it do? Requirements
  (role chain step 1: requirements collector) across content, curation (prune/collapse/combine),
  retrieval, fabric solution-finding and model selection"
description: >
  Inception: Estate knowledge platform: what is it for and what must it do? Requirements
  (role chain step 1: requirements collector) across content, curation (prune/collapse/combine),
  retrieval, fabric solution-finding and model selection

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-12T18:22:09Z
last_update: '2026-10-12T18:30:32Z'
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
  - ts: '2026-10-12T18:23:10Z'
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
  - ts: '2026-10-12T18:30:32Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=152,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4123: Estate knowledge platform: what is it for and what must it do? Requirements (role chain step 1: requirements collector) across content, curation (prune/collapse/combine), retrieval, fabric solution-finding and model selection

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

- **IW-1: Content — which kinds of knowledge belong in the estate store, from which sources, and which never?**
  confidence: 2
  disposition: answered
  rationale: R-1..R-5, R-33, R-37 in the requirements doc; operator 2026-10-13: feed from each project's local index; which categories is the operator's pick (numbered list sent)
- **IW-2: Curation — how are items pruned, collapsed and combined across projects, and who decides each act?**
  confidence: 2
  disposition: deferred
  rationale: operator 2026-10-13 "start feeding, later see if we need to aggregate or rationalize"; R-6..R-11, R-39 drafted and all three external models agree (owner decides, no auto-collapse, §6.1.a) — built after the pilot
- **IW-3: Retrieval — how does an agent ask, what comes back (scope, ranking, provenance, trust), and how is quality measured?**
  confidence: 2
  disposition: answered
  rationale: R-12..R-17, R-33..R-36 (provenance, scope, two ranking modes, fixed question set, degradation, trust tier)
- **IW-4: Fabric — can component fabric cards serve as a cross-project solution finder, and what must a card carry for that?**
  confidence: 2
  disposition: answered
  rationale: yes at module level, not per component (operator 2026-10-13); card fields from three stakeholders (R-18); quality work split out as inception T-4142
- **IW-5: Model selection — default plus configurable from what Ollama offers; where does embedding happen and how is mixing prevented?**
  confidence: 2
  disposition: answered
  rationale: R-19..R-21; operator 2026-10-13: recompute vectors centrally for the pilot (also allows different tagging); per-project embedding deferred
- **IW-6: Error resolution — how are error classes, their resolutions (or lack of one) and occurrence counts shared across projects, and what stays with healing patterns, the host error service and telemetry?**
  confidence: 2
  disposition: deferred
  rationale: R-22..R-24, R-40 drafted (occurrences stay local, the class goes to the store); not in the first pilot's categories — added after the pilot runs

## Exploration Plan

1. Requirements collector (ring20 role chain step 1), interactive with the operator, in this session.
2. Five stakeholder consults (dimitri-mint-dev, ring20-manager, 832, 055, 010), same brief, answers stored unedited in the research artefact.
3. Synthesis into glossary, R-n with acceptance criteria, conflicts; then the operator's review and recommendation.

Time-box: consults answered within a day; synthesis in one session.

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

**Rationale:**

The requirements are collected well enough to start: draft v0.3 holds R-1..R-40 with acceptance criteria from three of five stakeholders, three external models agree unanimously on the hardest calls (no outside fallback, roles instead of hostnames, owner-decided curation, no auto-collapse), and the operator set the direction on 2026-10-13: feed the central store from each project's local index now and rationalise later; recompute vectors centrally; capability cards at module level as a separate high-priority task (T-4142). GO means: finish v0.4 with the operator's rulings and the remaining answers (010, 1409, 055), then unblock T-4091 (the push pipe) for a pilot — one project writing, one reading — limited to the raw layer and the categories the operator picks. Curation (prune/collapse/combine) and per-project embedding come later.

**Evidence:**

- `docs/reports/T-4123-estate-knowledge-requirements.md` — R-1..R-40, CF-1..CF-11, §6.1.a external comparison table, D-1..D-3, Dialogue Log with the operator's direction.
- `docs/reports/T-4123-inputs/` — stakeholder answers (dimitri-mint-dev, ring20-manager, 832 + correction) and `external/` (gemini-2.5-pro, gpt-5, grok-4.7), all unedited.
- Measured: every project's local index uses the same path-based categories (web/search_utils.py:19); 9 of 27 modules here have no description, none has a capabilities field (→ T-4142).
- Open for the operator before v0.4: which categories to feed (numbered list sent 2026-10-13), CF-1/2/5/7 rulings (external views now in hand).

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

### 2026-10-12T18:23:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
