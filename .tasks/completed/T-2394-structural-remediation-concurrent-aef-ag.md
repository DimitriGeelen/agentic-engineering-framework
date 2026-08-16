---
id: T-2394
name: "Structural remediation: concurrent AEF agents on a shared backlog and master"
description: >
  Structural inception. The divergence/contention surfaced in inception A is a symptom
  of a class: worktree isolation was introduced to let multiple AEF agents work the
  same task-list/backlog (or multiple projects using AEF) in parallel, but nothing
  structurally governs (a) who may write to master, (b) how parallel branches reconcile,
  (c) task/backlog ownership so two agents don't grab the same task, (d) merge-queue/locking.
  Explore the structural model: master-as-merge-only enforcement (pre-commit guard),
  branch-per-agent + merge queue, task-claim/lease protocol on the shared backlog,
  and how this composes with arc-011 parallel-execution (disjoint write-sets, fw write-set
  check). Produce a recommended structural direction + the first concrete slice.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [parallel-agents, governance, concurrency, inception]
arc_id: parallel-execution-aef
components: []
related_tasks: [T-2393]
created: 2026-06-14T13:31:06Z
last_update: '2026-08-16T22:25:04Z'
date_finished: 2026-06-14T14:59:55Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:04Z'
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

# T-2394: Structural remediation: concurrent AEF agents on a shared backlog and master

## Problem Statement

Worktree isolation was introduced to let multiple AEF agents work in parallel — the same shared
backlog/master, or multiple projects using AEF. It solved per-session blast-radius (each worktree =
own git-toplevel, own `.restart-requested`, own `focus.yaml`), but it exposed a class of *concurrency
governance* gaps that isolation alone cannot close. Inception A ([[T-2393]]) is the first symptom: a
branch 42 ahead / master 6 ahead, reconciled only by manual merge, after prior sessions committed
**directly to master**. The operator's stated invariant — *"none other than this should write to
master"* — is currently enforced by **nothing**; two live sessions sit on the master checkout right now
and either can `git commit` straight onto master.

Four gaps, for the operator and every future parallel-agent deployment:
- **G1 — Master write governance:** no guard stops a session on the master checkout from committing
  directly to master, bypassing the branch/merge model.
- **G2 — Divergence/reconciliation:** parallel worktree branches diverge from master; reconciliation is
  manual, ad-hoc, and error-prone (A is the evidence).
- **G3 — Backlog/task ownership:** `focus.yaml` is per-worktree; nothing coordinates *across* worktrees,
  so two agents can grab the same `T-XXX` (double-work, conflicting closes).
- **G4 — Shared-state merge conflicts:** episodic/, reviewer-overrides, completed-task `.md`, audit YAMLs
  are written by every session and collide on merge — A's 7 conflicts were *all* this class.

Why now: the gaps are live (2 sessions on master), the symptom already cost a session of reconciliation
work, and every additional parallel agent widens the exposure (L-405: advisory rules drift to
non-compliance — this must be structural, not a convention).

## Assumptions

- A1: A pre-commit guard refusing commits while on `master`/`main` in the main checkout is sufficient to
  enforce G1 without breaking legitimate FF/merge advances. (TEST: enumerate master-advance paths.)
- A2: The dominant *friction* in parallel operation is G4 (shared-state conflicts), not G1/G3 — i.e. the
  guard fixes the scary case but the merge-conflict toil is the frequent case. (TEST: A's conflict set.)
- A3: TermLink already provides cross-session coordination primitives (kv, channel-claim) that a task-lease
  protocol (G3) can build on rather than inventing storage. (TEST: grep termlink kv/claim surface.)
- A4: This composes with arc-011 (parallel-execution-aef) rather than duplicating it — arc-011 governs
  parallel *dispatch* + disjoint write-sets; B governs the *shared-repo* substrate underneath. (TEST: read arc YAML.)

## Open Questions

- **IW-1: What is the minimal structural guard that enforces "master is merge-only" without breaking legitimate FF/merge/cherry-pick advances?**
  confidence: 3
  disposition: answered
  rationale: extend existing pre-commit hook (agents/git/git.sh installs pre-commit already); block authored commit on master/main when no MERGE_HEAD; FF creates no commit (silent allow), merge has MERGE_HEAD (allow), Tier-2 bypass for deploy. (docs/reports/T-2394-parallel-agent-substrate.md §IW-1 table)
- **IW-2: Is the dominant parallel-operation friction master contention (G1), task double-grab (G3), or shared-state merge conflicts (G4)?**
  confidence: 3
  disposition: answered
  rationale: G4 by frequency (T-2393 = 7/7 shared-state conflicts) but G4 is arc-011's headline mechanic; G1 by severity (zero current protection, operator-alarming) → B owns G1+G2, routes G4 to arc-011. (docs/reports/T-2394-parallel-agent-substrate.md §IW-2)
- **IW-3: Do framework/TermLink primitives already exist for a cross-worktree task-claim/lease (G3), or must one be built from scratch?**
  confidence: 3
  disposition: answered
  rationale: no fw claim/lease verb exists; TermLink kv set/get/watch + channel claim/transfer are the substrate → G3 is build-from-scratch, sequenced as a captured follow-on behind arc-011 write-set discipline. (docs/reports/T-2394-parallel-agent-substrate.md §IW-3)
- **IW-4: How does B compose with arc-011 (parallel-execution-aef) so the two don't overlap or contradict?**
  confidence: 3
  disposition: answered
  rationale: arc-011 = parallel dispatch over disjoint write-sets (owns G4 + partial G3, mechanic "no .tasks/.context merge conflicts", fw write-set check exists); B = shared-repo substrate G1+G2 that arc-011 sits on. Dependency-sibling, no overlap. (docs/reports/T-2394-parallel-agent-substrate.md §IW-4)

## Exploration Plan

1. **Master-advance path enumeration** (≤10 min) — list every legitimate way master should advance
   (FF from a reviewed branch, server-side PR merge, the documented cherry-pick deploy) and design a
   pre-commit guard that blocks *direct authored commits on master* while permitting those. Settles IW-1/A1.
2. **Friction classification from A** (≤5 min) — A's `merge-tree` conflict set is 7/7 shared-state files;
   weigh G1 (rare, catastrophic) vs G4 (frequent, toil). Settles IW-2/A2.
3. **Primitive inventory** (≤15 min) — grep `fw` for any claim/lease verb; inventory TermLink `kv` +
   `channel claim` as a substrate for a `fw task claim` lease. Settles IW-3/A3.
4. **arc-011 boundary read** (≤10 min) — read `.context/arcs/parallel-execution-aef.yaml`; draw the line
   between arc-011 (dispatch + disjoint write-sets) and B (shared-repo substrate). Settles IW-4/A4.
5. Write `docs/reports/T-2394-parallel-agent-substrate.md` incrementally; finish with a layered structural
   direction (G1→G4) + the recommended first slice + follow-on slices filed as captured.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** the shared-repo substrate for parallel AEF agents — G1 (master write governance) and G2 (branch
reconciliation); the layered direction + recommended first slice + sequenced follow-ons.
**OUT:** G4 shared-state merge conflicts (owned by arc-011 disjoint-write-set discipline — do not duplicate);
executing the Layer-1 hook (post-GO build work, separate task); the current-instance reconciliation (that is
[[T-2393]]); touching/quiescing the live master-checkout sessions (operator-owned).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — 4 gaps (G1-G4) classified by severity/frequency/owner
- [x] Assumptions tested — A1 confirmed (pre-commit surface exists), A2 confirmed (G4 frequent/G1 severe), A3 confirmed (no fw verb, TermLink substrate), A4 confirmed (arc-011 boundary)
- [x] Recommendation written with rationale — GO layered direction, first slice = master-merge-only guard, artifact at docs/reports/T-2394-parallel-agent-substrate.md

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
- The highest-severity gap (G1) has a bounded, feasible fix — ✅ met (extend existing pre-commit hook; intent distinguishable via MERGE_HEAD)
- The fix is scoped, testable, reversible — ✅ met (one hook, bats-pinnable, env-bypassable)
- Lower-severity gaps are owned or sequenced without scope-creep — ✅ met (G4→arc-011; G2/G3 captured follow-ons)

**NO-GO if:**
- G1 requires redesigning the git/branch model — falsified (IW-1)
- No guard can distinguish a legitimate merge from a direct authored commit — falsified (MERGE_HEAD test)

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

**Recommendation:** GO — layered structural direction; first slice = master-as-merge-only pre-commit guard (G1)

**Rationale:** Exploration complete (`docs/reports/T-2394-parallel-agent-substrate.md`); all 4 IWs answered at confidence 3. The operator's invariant ("none other than this should write to master") is currently enforced by nothing; the highest-severity gap G1 has a bounded, feasible fix on an *existing* hook surface (the framework already installs a pre-commit hook), is testable and reversible, and aligns with L-405 (make it structural, not advisory). Lower-severity gaps are either already owned (G4 = arc-011's headline mechanic — no duplication) or sequenced as captured follow-ons (G2 reconciliation helper, G3 task-claim lease over TermLink kv). GO authorises a small, safe first slice without over-committing the whole concurrency model.

**Evidence:**
- IW-1: `fw git install-hooks` already installs pre-commit (agents/git/git.sh); intent is distinguishable (FF → no commit; merge → MERGE_HEAD present; direct commit → blocked).
- IW-2: T-2393's conflict set was 7/7 shared-state (G4 = frequent) but G4 ∈ arc-011; G1 = rare/catastrophic with zero current protection → B's unique target.
- IW-3: no `fw` claim/lease verb; TermLink `kv`+`channel claim` are the substrate (G3 = build-from-scratch, deferred).
- IW-4: arc-011 owns parallel dispatch + disjoint write-sets (mechanic "no .tasks/.context merge conflicts", `fw write-set check` exists); B owns the substrate G1+G2 underneath. No overlap.
- Layer-1 build is post-GO work (separate task), NOT performed under this inception ID.

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

**Rationale**: Recommendation: GO — layered structural direction; first slice = master-as-merge-only pre-commit guard (G1)

Rationale: Exploration complete (`docs/reports/T-2394-parallel-agent-substrate.md`); all 4 IWs answered at confidence 3. The operator's invariant ("none other than this should write to master") is currently enforced by nothing; the highest-severity gap G1 has a bounded, feasible fix on an existing hook surface (the framework already installs a pre-commit hook), is testable and reversible, and aligns with L-405 (make it structural, not advisory). Lower-severity gaps are either already owned (G4 = arc-011's headline mechanic — no duplication) or sequenced as captured follow-ons (G2 reconciliation helper, G3 task-claim lease over TermLink kv). GO authorises a small, safe first slice without over-committing the whole concurrency model.

Evidence:
- IW-1: `fw git install-hooks` already installs pre-commit (agents/git/git.sh); intent is distinguishable (FF → no commit; merge → MERGE_HEAD present; direct commit → blocked).
- IW-2: T-2393's conflict set was 7/7 shared-state (G4 = frequent) but G4 ∈ arc-011; G1 = rare/catastrophic with zero current protection → B's unique target.
- IW-3: no `fw` claim/lease verb; TermLink `kv`+`channel claim` are the substrate (G3 = build-from-scratch, deferred).
- IW-4: arc-011 owns parallel dispatch + disjoint write-sets (mechanic "no .tasks/.context merge conflicts", `fw write-set check` exists); B owns the substrate G1+G2 underneath. No overlap.
- Layer-1 build is post-GO work (separate task), NOT performed under this inception ID.

**Date**: 2026-06-14T14:59:55Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-14T13:37:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-15ac1a80
- **Timestamp:** 2026-06-14T14:59:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-14T14:59:55Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — layered structural direction; first slice = master-as-merge-only pre-commit guard (G1)

Rationale: Exploration complete (`docs/reports/T-2394-parallel-agent-substrate.md`); all 4 IWs answered at confidence 3. The operator's invariant ("none other than this should write to master") is currently enforced by nothing; the highest-severity gap G1 has a bounded, feasible fix on an existing hook surface (the framework already installs a pre-commit hook), is testable and reversible, and aligns with L-405 (make it structural, not advisory). Lower-severity gaps are either already owned (G4 = arc-011's headline mechanic — no duplication) or sequenced as captured follow-ons (G2 reconciliation helper, G3 task-claim lease over TermLink kv). GO authorises a small, safe first slice without over-committing the whole concurrency model.

Evidence:
- IW-1: `fw git install-hooks` already installs pre-commit (agents/git/git.sh); intent is distinguishable (FF → no commit; merge → MERGE_HEAD present; direct commit → blocked).
- IW-2: T-2393's conflict set was 7/7 shared-state (G4 = frequent) but G4 ∈ arc-011; G1 = rare/catastrophic with zero current protection → B's unique target.
- IW-3: no `fw` claim/lease verb; TermLink `kv`+`channel claim` are the substrate (G3 = build-from-scratch, deferred).
- IW-4: arc-011 owns parallel dispatch + disjoint write-sets (mechanic "no .tasks/.context merge conflicts", `fw write-set check` exists); B owns the substrate G1+G2 underneath. No overlap.
- Layer-1 build is post-GO work (separate task), NOT performed under this inception ID.

### 2026-06-14T14:59:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
