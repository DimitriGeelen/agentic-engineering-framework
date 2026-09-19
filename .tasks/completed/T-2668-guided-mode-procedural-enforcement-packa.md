---
id: T-2668
name: "guided-mode procedural enforcement (package Lock 6) inside mirror+rails"
description: >
  Should the framework build procedure-level enforcement — fw workflow bind/advance,
  caged instance state (package Q10 autonomy-integrity constraint), human-gate protection
  at map userTask nodes — inside the delivered mirror+rails architecture? The package's
  central structural promise (P3), wholly unbuilt (T-2662 gap 4). One question, one
  go/no-go.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [process-layer]
components: []
related_tasks: [T-2662, T-2663]
arc_id: designer-corpus
created: 2026-07-28T16:21:44Z
last_update: 2026-09-19T16:05:09Z
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
  - ts: '2026-07-28T16:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T16:30:09Z'
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

# T-2668: guided-mode procedural enforcement (package Lock 6) inside mirror+rails

## Problem Statement

The 2026-07-02 Workflow Process Layer package promised procedure-level
enforcement (P3: "workflows enforce at the procedure level what verb gates enforce
at the action level") via Lock 6 — `fw workflow bind/advance`, caged instance
state (Q10), human-gate protection at `userTask` nodes. T-2662 found it wholly
unbuilt (gap 4); SD-1 (T-2663, GO) ratified mirror+rails and *parked* guided mode
here as the named future arc. This inception decides whether that parked promise
should become build slices inside mirror+rails. **Why now:** the two dependencies
the DEFER named (T-2663, T-2664) landed the same day it was filed, and a successor
programme — arc-019 EWCR — has since been operator-ratified (2026-08-20) and has
landed its Arc 0. Research artefact:
`docs/reports/T-2668-guided-mode-supersession-review.md`.

## Assumptions

Registered and disposed via `fw assumption` (see artefact §4):

- **A-054** — SD-1 retired guided mode outright → **invalidated** (T-2663 GO criteria: "or park it as a named future arc"; T-2662 SD-8: "parked in T-2668").
- **A-055** — the P4 test shows the tier0 map+rail reduced regressions → **invalidated as stated** (post-rail 0 Cluster-A regressions in 53 days, but the interim pre-rail window was already 1 commit in 88 days: not disproven, unattributable).
- **A-056** — arc-019 already specifies bind/advance, instance cage, human gates → **validated** (architecture c9070637 §7.2, §7.3, §9, §11; contracts v1).

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

- **IW-1: Did the SD-1 disposition (T-2663) ratify mirror+rails WITH guided-mode procedural enforcement in scope, or without it?**
  confidence: 3
  disposition: answered
  rationale: Without — parked, not retired. T-2663 `## Decision` GO 2026-07-28T17:10Z; its GO criterion reads "retire guided-mode/YAML-canonical form, or park it as a named future arc"; T-2662 §4 SD-8 row: "guided/strict parked in T-2668".

- **IW-2: Did the P4 falsifiability test (T-2664) run, and does its result show map-level structure reducing regression enough to justify procedure-level machinery?**
  confidence: 2
  disposition: answered
  rationale: Ran (T-2664 closed 2026-07-28T19:59Z, map + rail shipped). Result inconclusive by construction — git log agents/context/check-tier0.sh: baseline 20 commits/6 regressions, interim (pre-rail) 1 commit, post-rail 3 commits/0 regressions; the rate collapsed before the rail existed (artefact §2).

- **IW-3: Has arc-019 (EWCR — executable workflow contract runtime) since taken up this exact question — procedure binding/advance, caged instance state, human-gate protection — such that T-2668 is superseded rather than pending?**
  confidence: 3
  disposition: dissolved
  rationale: Yes. architecture-c9070637.md §7.2 bind→instance, §7.3 instance state machine, §9 isolation, §11 slice 1 item 4 (human gate) + slice 2 (agent cannot edit ledger/state); line 322 "this dossier extends that thinking"; operator GO 2026-08-20; contracts v1 frozen (T-3385–T-3388). The question dissolves into arc-019's roadmap (artefact §3).

## Exploration Plan

Read-only research, no spikes (executed 2026-09-19, ~1 session-unit):

1. Read T-2663's decision record and GO criteria; T-2662 §3–§4 for SD-8 / gap 4 → IW-1.
2. Read T-2664's falsifiability anchor; measure the prediction from git history of `agents/context/check-tier0.sh` across baseline / interim / post-rail windows → IW-2.
3. Map T-2668's three mechanisms onto `architecture-c9070637.md` §7.2, §7.3, §9, §11 and contracts v1; check the operator decision (§18) and roadmap sequencing → IW-3.
4. Dispose assumptions through `fw assumption validate|invalidate`; write the artefact; recommend; hand the go/no-go to the operator via `fw task review`.

## Technical Constraints

None for the exploration (documents and git history only). For any build a GO
would have authorised: the 2026-08-20 EWCR decision forbids agent-prompt
execution or autonomy expansion until the boundary-isolation slice passes — a
constraint that would apply equally to Lock 6 and is the reason guided execution
sits at Arc 5 of the EWCR roadmap.

## Scope Fence

**IN:** whether T-2668 should authorise build slices for procedure-level
enforcement; disposition of its three IW questions; what transfers to arc-019.
**OUT:** reopening SD-1 or the enforcement-direction keystone (T-2619); the
EWCR architecture's shape (operator-owned, 2026-08-20); T-2669 / T-2670 — each
gets its own supersession check, one task each (artefact §6).

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
- `fw workflow bind/advance`, caged instance state and human-gate protection are unowned by any ratified programme, and a bounded slice inside mirror+rails could deliver them

**NO-GO if:**
- Authorising build slices here would duplicate or fork a ratified programme that already owns those mechanisms

**DEFER if:**
- A genuine evidence gap remains on either dependency the original DEFER named (T-2663, T-2664)

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

**Recommendation:** NO-GO

**Rationale:** Dissolved by supersession. Both dependencies the 2026-07-28 DEFER named have landed: SD-1 (T-2663, GO) *parked* guided mode here rather than retiring it, and the P4 test (T-2664) ran but cannot attribute its result — the Tier-0 hook's regression rate had already collapsed before the map/rail existed (baseline 20 commits/6 regressions; interim 1; post-rail 3/0). The decisive fact is newer than both: arc-019 EWCR, operator-ratified 2026-08-20, specifies every mechanism this inception asks about — bind task → create instance (§7.2), runner-owned instance state machine (§7.3), human gate with compare-and-append refusal (§11 slice 1), agent-cannot-edit-ledger proof (§11 slice 2) — names the Process Layer proposal as the thinking it extends (line 322), and has frozen its Arc 0 contracts (T-3385–T-3388). A GO here would authorise a second procedure runtime beside a ratified one, against a Sovereign sequencing decision. DEFER is no longer an evidence gap; it would be a hedge.

**Evidence:**
- `docs/reports/T-2668-guided-mode-supersession-review.md` — §1 dependency table, §2 P4 measurement (git log windows), §3 EWCR coverage table, §5 criteria evaluation
- Assumptions A-054 invalidated, A-055 invalidated, A-056 validated (`fw assumption list`)
- T-2663 `## Decision` GO 2026-07-28T17:10:41Z; T-2662 §4 SD-8 row; T-2664 §Falsifiability anchor
- `docs/research/executable-workflow/architecture-c9070637.md` §7.2, §7.3, §9, §11, §18 (2026-08-20 decision); `contracts/v1/` (refusal `human_gate_skipped`, `instance.schema.json`, `transition-envelope.schema.json`)

**Transfers to arc-019 (not decided here):** Q10 instance-state cage → answered by EWCR Arc 2 boundary-isolation proof; the P4 non-falsification → input for an attributable evidence design. **Sibling check suggested, one task each:** T-2670's subject (Workflow Fabric derived index) appears in EWCR §8.3 / Arc 4–5; T-2669 (audience lenses) does not obviously.

## Decisions

### 2026-09-19 — recommendation shape
- **Chose:** NO-GO with disposition *dissolved by supersession*, transfers named explicitly.
- **Why:** the mechanisms are owned by a ratified programme; the only honest alternative to NO-GO was a third DEFER, which T-2144 classifies as a hedge once the evidence is walked.
- **Rejected:** GO-folded-into-arc-019 (would imply this inception authorises EWCR slices — it does not; EWCR's authority is its own 2026-08-20 decision); DEFER pending T-2669/T-2670 (independent questions, one task each).

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-19T16:05:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d778ef9b
- **Timestamp:** 2026-09-19T16:10:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-1870220d
- **Timestamp:** 2026-09-19T16:10:16Z
- **Overall:** CONFIRMED
- **Claims:** 9

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-2668-guided-mode-supersession-review.md` | file | ✓ pass |
| `docs/research/executable-workflow/architecture-c9070637.md` | file | ✓ pass |
| `T-2663` | task | ✓ pass |
| `T-2664` | task | ✓ pass |
| `T-3385` | task | ✓ pass |
| `T-3388` | task | ✓ pass |
| `T-2662` | task | ✓ pass |
| `T-2670` | task | ✓ pass |
| `T-2669` | task | ✓ pass |
