---
id: T-100186
name: "Reviewer-assisted inception decides — validator profile on fw independent-review
  rail (pickup 073)"
description: >
  Inception: Reviewer-assisted inception decides — validator profile on fw independent-review
  rail (pickup 073)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-07-04T21:47:09Z
last_update: 2026-07-04T22:20:27Z
date_finished: 2026-07-04T22:20:27Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-04T21:49:23Z'
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
  - ts: '2026-07-04T22:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100186: Reviewer-assisted inception decides — validator profile on fw independent-review rail (pickup 073)

## Problem Statement

Inception decides are sovereignty-gated (human-only) by design, but a growing share are rubber-stamp class — every claim in the agent's recommendation is mechanically checkable (file exists, code at file:line, task in completed/). The operator pays full-read review cost for these, and recommendations with dead/false references (TermLink T-2338/T-2339 exhibit; this pickup's own mis-reference, see research artifact) reach the decide queue unflagged. Proposal (pickup 073): an independent reviewer mechanically verifies the recommendation's evidence claims and renders a per-claim verdict beside the recommendation, shrinking the human decide to a verdict-glance. The decide gate itself stays human-only.

Research artifact: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`

## Assumptions

- A1: The claim classes in recommendations (file path, file:line, T-XXX, module.function) are extractable with the existing ships_in referent grammar (T-1984) plus a file:line extension.
- A2: The existing reviewer rail (`fw reviewer --dispatch`, T-1951) satisfies the "provably not the authoring session" isolation requirement without new infrastructure.
- A3: Rendering the verdict beside the recommendation on `/inception/<id>` measurably reduces operator decide cost (proxy: operator feedback after first live use).

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

- **IW-1: Does the pickup's target rail (`fw independent-review` v0.1, "T-1885") exist in AEF?**
  confidence: 3
  disposition: answered
  rationale: No — grep of lib/agents/bin + fw help finds no such verb; AEF's T-1885 is an unrelated fabric-card task. Remapped to the T-1443 reviewer lineage (fw reviewer + --dispatch), which already provides isolation, verdict blocks, and Watchtower render. See research artifact §Premise check.

- **IW-2: Can evidence claims be verified mechanically with existing framework machinery?**
  confidence: 2
  disposition: answered
  rationale: Yes for 4 of 5 claim classes — the ships_in referent resolver (T-1984) already validates path/module.function/test-fn/T-XXX shapes; file:line is a small extension. Command-execution claims need sandbox design → explicitly out of scope for slice A.

- **IW-3: Does the verdict risk weakening the sovereignty gate (G-068 class)?**
  confidence: 3
  disposition: answered
  rationale: No — proposal touches neither fw inception decide (T-1259/T-1260 gate unchanged) nor any AC ticking on inception tasks; verdict block is append-only advisory evidence, same trust model as the existing Reviewer Verdict block.

## Exploration Plan

1. Premise check: verify pickup's claimed rail exists in AEF (grep lib/agents/bin, fw help, T-1885 task file) — DONE 2026-07-04.
2. Inventory reusable machinery (reviewer dispatch isolation, static_scan section parsing, ships_in resolver, Watchtower verdict render) — DONE, see research artifact.
3. Scope the build slices + invariants — DONE (§Missing pieces).
No prototype spike needed: all components verified by reading shipped code paths; the premise-check itself live-demonstrated the validator concept by catching the pickup's false T-1885 reference.

## Technical Constraints

- Verdict write must use the reviewer's existing atomic single-pass write path (os.replace) — task files are concurrently read by Watchtower and hooks.
- Claims verifier must be read-only against the repo (no command execution in slice A).
- Watchtower render is a server-side template change; no new JS dependencies.

## Scope Fence

- **IN:** claims extractor + mechanical verifier for `## Recommendation`/Evidence referents; `## Recommendation Verdict` block schema + write; `/inception/<id>` and `/approvals` render of the verdict; exposure via `fw reviewer T-XXX` inception path (flag or auto-run).
- **OUT:** any change to `fw inception decide` or its sovereignty gate; command-execution claim class (sandbox design → follow-up inception); auto-decide or auto-tick of anything; TermLink-side T-2348 work (theirs).

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

**Rationale:**

(Filing-time DEFER upgraded after same-day research spike.) The proposal is sound but its claimed rail is mis-referenced: AEF has no `fw independent-review` verb — "T-1885 v0.1" is TermLink's task numbering. The correct AEF home is the T-1443 reviewer lineage, where the isolation property (`fw reviewer --dispatch`, T-1951), section parsing (`static_scan.py`, T-2145/T-100159), claims-shape validation (ships_in resolver, T-1984), and Watchtower verdict rendering all already exist. Build scope reduces to: claims extractor + verifier + `## Recommendation Verdict` block (slice A), and the `/inception/<id>` + `/approvals` render join (slice B). The sovereignty gate is untouched — verdict is advisory evidence only, so the G-068 self-approval class stays structurally impossible. The premise check itself is a live demo of the value: run by hand, it caught a false reference in its own origin proposal.

**Evidence:**

- No `fw independent-review` in AEF: grep of lib/, agents/, bin/ + `fw help` — zero hits; `.tasks/completed/T-1885-register-fabric-card-for-libarcmembershi.md` is unrelated.
- Isolation rail shipped: `fw reviewer T-XXX --dispatch` (T-1951) — isolated TermLink worker, fresh context, bus-posted verdict.
- Claims-shape validator shipped: ships_in referent resolver (T-1984) covers path / module.function / test-fn / T-XXX / deferred:T-YYYY.
- Recommendation-section parsing shipped: `lib/reviewer/static_scan.py` defer-as-hedge detector (T-2145) + wrapped-rationale reader (T-100159).
- Full analysis: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`.

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

Rationale:

(Filing-time DEFER upgraded after same-day research spike.) The proposal is sound but its claimed rail is mis-referenced: AEF has no `fw independent-review` verb — "T-1885 v0.1" is TermLink's task numbering. The correct AEF home is the T-1443 reviewer lineage, where the isolation property (`fw reviewer --dispatch`, T-1951), section parsing (`static_scan.py`, T-2145/T-100159), claims-shape validation (ships_in resolver, T-1984), and Watchtower verdict rendering all already exist. Build scope reduces to: claims extractor + verifier + `## Recommendation Verdict` block (slice A), and the `/inception/<id>` + `/approvals` render join (slice B). The sovereignty gate is untouched — verdict is advisory evidence only, so the G-068 self-approval class stays structurally impossible. The premise check itself is a live demo of the value: run by hand, it caught a false reference in its own origin proposal.

Evidence:

- No `fw independent-review` in AEF: grep of lib/, agents/, bin/ + `fw help` — zero hits; `.tasks/completed/T-1885-register-fabric-card-for-libarcmembershi.md` is unrelated.
- Isolation rail shipped: `fw reviewer T-XXX --dispatch` (T-1951) — isolated TermLink worker, fresh context, bus-posted verdict.
- Claims-shape validator shipped: ships_in referent resolver (T-1984) covers path / module.function / test-fn / T-XXX / deferred:T-YYYY.
- Recommendation-section parsing shipped: `lib/reviewer/static_scan.py` defer-as-hedge detector (T-2145) + wrapped-rationale reader (T-100159).
- Full analysis: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`.

**Date**: 2026-07-04T22:20:27Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-04T21:49:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-04T22:20:27Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

(Filing-time DEFER upgraded after same-day research spike.) The proposal is sound but its claimed rail is mis-referenced: AEF has no `fw independent-review` verb — "T-1885 v0.1" is TermLink's task numbering. The correct AEF home is the T-1443 reviewer lineage, where the isolation property (`fw reviewer --dispatch`, T-1951), section parsing (`static_scan.py`, T-2145/T-100159), claims-shape validation (ships_in resolver, T-1984), and Watchtower verdict rendering all already exist. Build scope reduces to: claims extractor + verifier + `## Recommendation Verdict` block (slice A), and the `/inception/<id>` + `/approvals` render join (slice B). The sovereignty gate is untouched — verdict is advisory evidence only, so the G-068 self-approval class stays structurally impossible. The premise check itself is a live demo of the value: run by hand, it caught a false reference in its own origin proposal.

Evidence:

- No `fw independent-review` in AEF: grep of lib/, agents/, bin/ + `fw help` — zero hits; `.tasks/completed/T-1885-register-fabric-card-for-libarcmembershi.md` is unrelated.
- Isolation rail shipped: `fw reviewer T-XXX --dispatch` (T-1951) — isolated TermLink worker, fresh context, bus-posted verdict.
- Claims-shape validator shipped: ships_in referent resolver (T-1984) covers path / module.function / test-fn / T-XXX / deferred:T-YYYY.
- Recommendation-section parsing shipped: `lib/reviewer/static_scan.py` defer-as-hedge detector (T-2145) + wrapped-rationale reader (T-100159).
- Full analysis: `docs/reports/T-100186-reviewer-assisted-inception-decides.md`.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2668be23
- **Timestamp:** 2026-07-04T22:20:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

### 2026-07-04T22:20:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
