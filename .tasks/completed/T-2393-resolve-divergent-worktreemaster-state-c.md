---
id: T-2393
name: "Resolve divergent worktree/master state cleanly without loss"
description: >
  Tactical inception: the arc-012 worktree branch is 42 commits ahead of master while
  master is 6 commits ahead (T-2376..T-2379 deployed directly via cherry-pick), with
  2 live sessions on the master checkout and a push blocked by spurious worktree-only
  audit failures. Explore consolidation options (merge / rebase-onto-master / cherry-pick
  reconcile / push-branch-then-server-merge) that reconcile the duplicate cherry-picked
  content WITHOUT losing any of the 42 commits, and that do not mutate the master
  working tree under the live sessions. Produce one recommended path.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [git-hygiene, worktree, parallel-agents, inception]
components: []
related_tasks: []
created: 2026-06-14T13:30:43Z
last_update: 2026-06-14T15:00:06Z
date_finished: 2026-06-14T15:00:06Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-14T15:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F-AUTONOMY=2 
      (no-signal); F3=2 (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-14T15:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2393: Resolve divergent worktree/master state cleanly without loss

## Problem Statement

The arc-012 worktree branch `worktree-arc012-continuous-run-s4s5` (HEAD `4b1ceb798`) is
**42 commits ahead** of `master` while `master` (HEAD `4679b9a42`) is **6 commits ahead**
of the branch — the 6 being T-2376/T-2377/T-2378/T-2379, deployed *directly onto master* via
cherry-pick/TermLink in prior sessions (2026-06-13 20:10–22:14). The branch's auto-handover
push is blocked by 3 audit FAILs that are worktree-local artifacts (cron-not-installed for a
throwaway worktree ×2 + self-vendor `bin/fw`). Two live `claude-fw` sessions sit on the master
checkout (one with an active inner `claude`, PID 1753005).

We must consolidate ALL 42 branch commits to the canonical line **without losing any work** and
**without mutating the master working tree underneath the live sessions**. For: the operator,
who needs the arc-012 work durably on master/remote and the throwaway worktree retired. Why now:
the work is unpushed and at risk on a branch nobody else feeds; every additional session widens
the divergence.

## Assumptions

- A1: The 6 master-only commits are *duplicate content* (cherry-picks) of commits already on
  the branch → a merge will be mostly auto-resolving, not a genuine content fork. (TEST: patch-id.)
- A2: The audit FAILs blocking the push are worktree-local artifacts, not real product defects
  that would also fail on master. (TEST: inspect each FAIL's referent.)
- A3: No git operation that consolidates onto master can avoid touching the master *working tree*
  while master is checked out — so any working-tree-mutating path requires the live sessions to be
  quiesced first. (TEST: enumerate operations vs. checked-out-branch constraints.)

## Open Questions

- **IW-1: Are the 6 master-only commits (T-2376..T-2379) duplicate content of commits already on the branch, or a genuine content fork?**
  confidence: 3
  disposition: answered
  rationale: patch-id over 6 master-only vs 42 branch commits → 5 UNIQ / 1 DUP; master has genuine content (self-vendor/episodic/runbook), so union (merge) required not discard. Assumption A1 falsified. (docs/reports/T-2393-consolidation-options.md §IW-1)
- **IW-2: Which consolidation operation reconciles the divergence with zero commit loss AND zero mutation of the master working tree under the 2 live sessions?**
  confidence: 3
  disposition: answered
  rationale: `git merge-tree` simulation → 7 conflicts, all doc/episodic/task-completion (add/add), zero core-code. Selected: `git merge master` IN this worktree → branch becomes superset → operator FF master conflict-free when sessions quiesced. (docs/reports/T-2393-consolidation-options.md §IW-2 matrix)
- **IW-3: Are the 3 push-blocking audit FAILs genuinely spurious (worktree artifacts), such that bypassing them for THIS consolidation is safe?**
  confidence: 3
  disposition: answered
  rationale: 2 spurious (cron target keyed to worktree name; registry/generated drift worktree-local — both clear on master line) + 1 trivial (self-vendor bin/fw = 19-line T-2390 block, cleared by one `fw vendor`). None are product defects. (docs/reports/T-2393-consolidation-options.md §IW-3)

## Exploration Plan

1. **patch-id duplicate detection** (≤10 min) — compute patch-ids of the 6 master-only commits
   and the 42 branch commits; classify each master-only commit DUP/UNIQ. Settles IW-1/A1.
2. **Audit-FAIL referent inspection** (≤10 min) — for each of the 3 FAILs, confirm whether the
   referent is worktree-local (cron path keyed to worktree name; bin/fw self-vendor delta).
   Settles IW-3/A2.
3. **Operation enumeration** (≤15 min) — tabulate merge / rebase-onto-master / push-branch-then-
   server-merge / FF against three constraints: (a) zero commit loss, (b) no master-working-tree
   mutation, (c) divergence reconciliation. Settles IW-2/A3.
4. Write `docs/reports/T-2393-consolidation-options.md` incrementally as each step lands; finish
   with a recommended path + the exact command sequence (operator-runnable, copy-pasteable).

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** identifying a zero-loss, no-master-tree-mutation consolidation path for the *current* instance;
producing the exact operator-runnable command sequence; classifying the push-blocking audit FAILs.
**OUT:** executing the merge (post-GO build work, not under this inception ID); structural prevention of
recurrence (that is inception B / [[T-2394]]); fixing the T-2390 dead-code block (that is [[T-2391]]);
touching or quiescing the 2 live master-checkout sessions (operator-owned).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — divergence quantified (42 ahead / 6 behind), constraints C-a/b/c fixed
- [x] Assumptions tested — A1 falsified (patch-id), A2 confirmed (FAIL triage), A3 confirmed (operation matrix)
- [x] Recommendation written with rationale — GO Option 1, evidence-cited, artifact at docs/reports/T-2393-consolidation-options.md

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
- A consolidation path exists that loses zero of the 42 commits AND does not mutate the master working tree under the live sessions — ✅ met (Option 1: merge-into-branch here → FF master when quiesced)
- The conflict surface is bounded and resolvable — ✅ met (`merge-tree` shows 7 doc/state conflicts, zero code)
- The push-blocking FAILs are spurious or trivially clearable — ✅ met (2 worktree artifacts + 1 `fw vendor`)

**NO-GO if:**
- Consolidation would require discarding commits or force operations — not the case (union merge)
- The only viable path mutates the live master checkout with no quiesce option — not the case (server-side PR fallback exists)

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

**Recommendation:** GO — Option 1 (merge master into THIS branch, here in the worktree; then operator fast-forwards master when the 2 live sessions are quiesced)

**Rationale:** Exploration complete (`docs/reports/T-2393-consolidation-options.md`). All three IWs answered with confidence 3. A bounded, proven, reversible path exists that satisfies all constraints — zero commit loss (union merge, not discard), no mutation of the master working tree under the live sessions (merge happens in the isolated worktree; master advances later by conflict-free FF), and a clean conflict surface (`git merge-tree` simulated exactly 7 conflicts, all doc/episodic/task-completion add/add, zero core-code). The push-blocking audit FAILs are 2 worktree artifacts + 1 trivial `fw vendor` — no product defects. A server-side PR merge is the zero-mutation fallback if the sessions cannot be quiesced.

**Evidence:**
- patch-id: 5/6 master-only commits are unique content → merge (union) is the correct reconciliation, not FF or discard.
- `git merge-tree --write-tree`: 7 conflicts, all in `.tasks/completed/T-2377..2379`, `.context/episodic/T-2377..2378`, `reviewer-overrides.yaml`, runbook, vendored discard-manifest — every one a "same task closed on both lines" artifact.
- audit FAIL triage: cron target keyed to worktree name (spurious), registry/generated worktree-local (spurious), self-vendor `bin/fw` = 19-line T-2390 block (one `fw vendor`).
- Execution is post-GO build work (a follow-on task or operator-run), NOT performed under this inception ID.

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

**Rationale**: Recommendation: GO — Option 1 (merge master into THIS branch, here in the worktree; then operator fast-forwards master when the 2 live sessions are quiesced)

Rationale: Exploration complete (`docs/reports/T-2393-consolidation-options.md`). All three IWs answered with confidence 3. A bounded, proven, reversible path exists that satisfies all constraints — zero commit loss (union merge, not discard), no mutation of the master working tree under the live sessions (merge happens in the isolated worktree; master advances later by conflict-free FF), and a clean conflict surface (`git merge-tree` simulated exactly 7 conflicts, all doc/episodic/task-completion add/add, zero core-code). The push-blocking audit FAILs are 2 worktree artifacts + 1 trivial `fw vendor` — no product defects. A server-side PR merge is the zero-mutation fallback if the sessions cannot be quiesced.

Evidence:
- patch-id: 5/6 master-only commits are unique content → merge (union) is the correct reconciliation, not FF or discard.
- `git merge-tree --write-tree`: 7 conflicts, all in `.tasks/completed/T-2377..2379`, `.context/episodic/T-2377..2378`, `reviewer-overrides.yaml`, runbook, vendored discard-manifest — every one a "same task closed on both lines" artifact.
- audit FAIL triage: cron target keyed to worktree name (spurious), registry/generated worktree-local (spurious), self-vendor `bin/fw` = 19-line T-2390 block (one `fw vendor`).
- Execution is post-GO build work (a follow-on task or operator-run), NOT performed under this inception ID.

**Date**: 2026-06-14T15:00:06Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-14T13:31:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6fd2520d
- **Timestamp:** 2026-06-14T15:00:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-14T15:00:06Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Option 1 (merge master into THIS branch, here in the worktree; then operator fast-forwards master when the 2 live sessions are quiesced)

Rationale: Exploration complete (`docs/reports/T-2393-consolidation-options.md`). All three IWs answered with confidence 3. A bounded, proven, reversible path exists that satisfies all constraints — zero commit loss (union merge, not discard), no mutation of the master working tree under the live sessions (merge happens in the isolated worktree; master advances later by conflict-free FF), and a clean conflict surface (`git merge-tree` simulated exactly 7 conflicts, all doc/episodic/task-completion add/add, zero core-code). The push-blocking audit FAILs are 2 worktree artifacts + 1 trivial `fw vendor` — no product defects. A server-side PR merge is the zero-mutation fallback if the sessions cannot be quiesced.

Evidence:
- patch-id: 5/6 master-only commits are unique content → merge (union) is the correct reconciliation, not FF or discard.
- `git merge-tree --write-tree`: 7 conflicts, all in `.tasks/completed/T-2377..2379`, `.context/episodic/T-2377..2378`, `reviewer-overrides.yaml`, runbook, vendored discard-manifest — every one a "same task closed on both lines" artifact.
- audit FAIL triage: cron target keyed to worktree name (spurious), registry/generated worktree-local (spurious), self-vendor `bin/fw` = 19-line T-2390 block (one `fw vendor`).
- Execution is post-GO build work (a follow-on task or operator-run), NOT performed under this inception ID.

### 2026-06-14T15:00:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
