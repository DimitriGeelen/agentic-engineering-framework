---
id: T-2608
name: "Single stored representation for corpus maps: drop persisted spec YAML, XML
  as sole source, spec as on-demand lens"
description: >
  Inception: Single stored representation for corpus maps: drop persisted spec YAML,
  XML as sole source, spec as on-demand lens

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-07-22T18:58:47Z
last_update: 2026-07-22T19:04:27Z
date_finished: 2026-07-22T19:03:26Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-07-22T19:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-22T19:00:09Z'
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

# T-2608: Single stored representation for corpus maps: drop persisted spec YAML, XML as sole source, spec as on-demand lens

## Problem Statement

T-2603 shipped corpus maps with TWO tracked representations per map: the canvas
BPMN XML (`.context/designer/projects/<id>/vN.bpmn`, the editor's contract) and a
derived YAML spec (`.context/designer/specs/<id>.yaml`). The operator asked *"why
are these two not combined in one file?"* — and the honest answer is the second
file is a fully-derivable view (T-2603 proved lossless round-trip both ways), so
persisting it creates a derived-artifact drift class with zero information gain.
This framework's own history is the evidence base against that pattern: cron
registry→generated (T-1935, 3 days silent drift), tool-set→manifest (T-2290),
source→vendored (OBS-098/T-2607, found the same day). Decide: single stored
representation (XML) with the spec as an on-demand lens + transient authoring
input, or keep both files and build a staleness gate.

## Assumptions

- A1: `fw corpus derive` on demand is fast enough to replace the stored file for
  every read/diff/lint use (it is — parse+emit of a <11KB XML, measured instant).
- A2: No code consumer reads `.context/designer/specs/*.yaml` at all. Verified live:
  `grep -rn "designer/specs" bin/ lib/ tools/ web/ agents/ tests/` → zero matches;
  the only references are T-2603's task Verification lines (the retrofit surface)
  and the T-2603 report doc. Lint reads XML directly.
- A3: The T-2605 recreate proof stays meaningful without a persisted spec: the
  proof is derive→generate→canonical-identical, with git history of the XML as the
  surviving source across a delete.

## Open Questions

- **IW-1: Are raw XML diffs acceptable for operator review of map changes in git history, or does the workflow need a diff-time lens (e.g. `git diff` textconv driver running `fw corpus derive`, or a `fw corpus diff --git <ref>` verb)?**
  confidence: 1
  disposition: deferred
  rationale: Operator-taste question; cheap to add a lens verb later if XML diffs annoy — deferred to first real review of a map change in git history (revisit when a map edit lands post-decision).

- **IW-2: Retrofit scope for T-2603's shipped artifacts — delete the two tracked spec files, reword T-2603 AC1/AC2 (specs become on-demand output), repoint T-2603's Verification commands at derive-on-the-fly instead of tracked files?**
  confidence: 2
  disposition: deferred
  rationale: Mechanical once GO is recorded; executed as the first act of the GO's build child (or T-2605 pre-step) — exact edit list in the research artifact §Retrofit.

- **IW-3: Under the single-file model, does `fw corpus prove` regenerate from a spec derived in-memory from the CURRENT served XML (pure round-trip proof), from git-history XML (survivability proof), or both as separate legs?**
  confidence: 2
  disposition: deferred
  rationale: Recommendation in artifact: both legs, current-XML round-trip as the default `prove`, git-history leg as `prove --from <ref>`; final shape decided at T-2605 build time.

## Exploration Plan

No spikes needed — the exploration already happened as live dialogue + shipped
evidence: T-2603's round-trip proof IS the feasibility evidence (lossless both
directions, on both served maps, through /api/save). Remaining work is the
decision itself + mechanical retrofit. Time-box: this session's dialogue (done).

## Technical Constraints

- The 832 editor's load/save contract is BPMN XML — the XML representation cannot
  be replaced, only the YAML's persistence is in question.
- `/api/save` is the only write path (T-2603 discipline); retrofit touches tracked
  files + task wording only, never the store.

## Scope Fence

**IN:** persistence decision for the YAML spec; retrofit of T-2603 artifacts/ACs;
T-2605 proof-source semantics (IW-3).
**OUT:** the recreate itself (T-2605), lint rules (T-2604, reads XML — unaffected),
the editor bundle, 832-side anything.

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
- No consumer depends on the persisted spec files (A2 — verified by grep)
- Derive-on-demand covers every use the stored file served (read, lint, authoring input, recreate source) — A1/A3
- Retrofit is bounded (2 tracked files + T-2603 AC/Verification wording)

**NO-GO if:**
- Some workflow genuinely needs the spec at rest (e.g. offline diff tooling that cannot invoke fw), or
- The recreate proof turns out to require a persisted source distinct from git XML history (A3 fails)

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

Operator question 'why are these two not combined in one file?' exposed that the persisted spec YAML is a fully-derivable view (T-2603 proved lossless round-trip both directions) — storing it creates a derived-artifact drift class the framework has been burned by repeatedly (T-1935 cron registry, T-2290 manifest, OBS-098 today); single stored XML + derive-on-demand eliminates the drift class and dissolves the IW-1 authority question entirely

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

**Decision**: GO

**Rationale**: Operator question 'why are these two not combined in one file?' exposed that the persisted spec YAML is a fully-derivable view (T-2603 proved lossless round-trip both directions) — storing it creates a derived-artifact drift class the framework has been burned by repeatedly (T-1935 cron registry, T-2290 manifest, OBS-098 today); single stored XML + derive-on-demand eliminates the drift class and dissolves the IW-1 authority question entirely

**Date**: 2026-07-22T19:03:25Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-22T19:03:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Operator question 'why are these two not combined in one file?' exposed that the persisted spec YAML is a fully-derivable view (T-2603 proved lossless round-trip both directions) — storing it creates a derived-artifact drift class the framework has been burned by repeatedly (T-1935 cron registry, T-2290 manifest, OBS-098 today); single stored XML + derive-on-demand eliminates the drift class and dissolves the IW-1 authority question entirely

### 2026-07-22T19:03:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f27f2568
- **Timestamp:** 2026-07-22T19:03:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-66cd2093
- **Timestamp:** 2026-07-22T19:03:27Z
- **Overall:** CONFIRMED
- **Claims:** 3

| Claim | Type | Status |
|-------|------|--------|
| `T-2603` | task | ✓ pass |
| `T-1935` | task | ✓ pass |
| `T-2290` | task | ✓ pass |

### 2026-07-22T19:03:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
