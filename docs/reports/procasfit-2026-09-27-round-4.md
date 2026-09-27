# procAsFit — round 4 of 4 — handback

**Run:** T-3517 (parent orchestration task, TermLink-dispatched round 4 — final round)
**Worker agent id:** pf0927-r4
**Repo:** /opt/999-Agentic-Engineering-Framework, branch `bleeding-edge`
**Window:** 2026-09-27, single session
**Predecessor:** `docs/reports/procasfit-2026-09-27-round-3.md` (round 3's handback, informed selection for round 4)

## Inherited state from round 3

Round 3 closed T-3516 and T-3520 (two completed tasks). It confirmed for the fourth time that the BVP framework is flatly tied (all remaining tasks at BVP 108/norm 0.40/cost 3.6), which is Sovereign Question 1 blocking the sanctioned selection mechanism. Round 3 noted that the next productive move for round 4 is to shift to a lateral tiebreaker and walk the **captured, owner:agent** task list looking for real, well-scoped content with placeholder ACs.

Round 3 flagged T-3376 (OneDev credential) as worth a look due to scale ("unblock 91 stranded commits"), but noted it was parked at 97% budget from a prior session and depends on a Tier-0 OTP gate the operator controls.

Sovereign questions from prior rounds remain open, unchanged:
1. BVP v1 heuristic has no differentiating signal for structural/hygiene bug-class tasks (confirmed 4 independent times)
2. Should the ~39-task standalone hygiene backlog get an accumulator arc, or is arc-less maintenance-by-design intended?
3. Inception-vs-build voi_score/BVP-flatness framing (unfiled, recurring third time)
4. Batch-surface-not-batch-execute efficiency for `fw review-queue`'s ready-to-close list (no capacity spent)

## Selection (stated before execution, per mandate)

**Objective:** AEF governs its own development (D2 Reliability) — fixing a rendering bug in the BVP ranking CLI that causes column misalignment when arc slugs exceed hardcoded width.

**Arc:** none declared; related to diagnostics/CLI infrastructure (`bvp, cli, render` tags).

**Task:** T-3514 ("fw bvp arcs auto-sizes the slug column instead of pinning it at 24"), captured/owner:agent.

**Quadrant:** Same flat BVP tie (108/0.40/cost 3.6); using round 3's lateral tiebreaker: "captured/owner:agent tasks with real, well-scoped-by-author content and placeholder ACs." This task had all three: clear problem statement (27-char slug "ewcr-arc0-contract-evidence" and 25-char slug "onboarding-shape-detection" overflow the hardcoded 24-char limit), fix direction sketched (compute width dynamically), and placeholder ACs.

**Why over other candidates:**
- T-3376 (OneDev credential) is budget-parked at 97% from a prior session + depends on Tier-0 OTP gate (risky continuation in final round)
- T-3472, T-3473 (doctor/enforcement checks) are more complex (~50-100 lines estimated)
- T-3514 is self-contained, small (~15 lines), fully within one round's scope, no external dependencies
- This is round 4 of 4 (final round) — picked work that would fit in remaining time

**Activity:** Write real ACs (4 agent-verifiable criteria), implement the fix (modify `lib/bvp.sh:737-742` to compute slug_width dynamically), write verification (test alignment, not literal width), fill RCA section (bug-class task).

## What closed

**T-3514 → `work-completed`.** Agent-owned, no Human ACs (all criteria agent-verifiable), 4/4 Agent ACs checked, 3/3 Verification commands passed (bash run + grep for long slugs + Python alignment check), reviewer static-scan PASS/no-findings. Closed via `fw task update T-3514 --status work-completed` — no bypass, no `--force`.

**Implementation details:**
- Read the existing hardcoded format string on line 737-742
- Computed slug_width as `max(24, max(len(r['slug']) for r in rows), default=24))` — floor of 24 to prevent shrinking below expected minimum
- Applied the computed width to both header and all data rows using Python format string `{slug_width}`
- Adjusted separator line length dynamically as well (`8+1 + slug_width+1 + 12+1 + 5+1 + 6+2 + 18+1 + 8`)
- Verified the fix works by running `fw bvp arcs` live and confirming both long slugs (27 and 25 chars) now align properly with STATUS column

**Verification design (per mandate: anchor on behaviour, not literal width):**
- Command 1: `fw bvp arcs` runs without error
- Command 2: Output contains at least one long slug (ewcr-arc0-contract-evidence OR onboarding-shape-detection)
- Command 3: Python script checks that all STATUS column positions are identical (alignment invariant), rather than hardcoding a width of 28 or 29

This verification cannot regress when new slugs are added, because it checks the alignment property (all rows start at the same column) rather than a constant width.

## Arc state: tasks by status and quadrant

Unchanged from round 3's observation (BVP flat-tie confirmed fifth time):
- `fw bvp --quadrant hv-lc --include-proposed`: identical 17-task flat tie at BVP 108/norm 0.40/cost 3.6
- T-3514 is now in `completed/`, outside the ranked set
- The standalone hygiene backlog (~39 tasks) remains structurally unselectable (Sovereign Question 1/2)
- 16-task `fw review-queue` "READY TO CLOSE" list remains owner:human (not delegated)
- Untouched captured/agent candidates from round 3 remain in active: T-3339, T-3376, T-3441, T-3471, T-3472, T-3473, T-3513, T-3514 (now completed), T-3519 (completed in parent's round)

## What remains in Q1/Q2, per task, with the reason it was not done

Same as round 3's table (no change):

| Task | Reason not done this round |
|---|---|
| T-3358 (claude-fw exit-detection) | Fleet access broken; third-party CLI wrapper bug on remote_exec.py |
| T-3481 (predecessor 3-round orchestration) | Evidence gap confirmed with different instrument; not re-attempted |
| T-2770 (inception: read-only fw query auto-init) | Correctly parked at DEFER; owner sovereignty boundary |
| T-3496 (SOVEREIGN: voi_score constant on inceptions) | Owner: human, explicit Sovereign question; not touched |
| T-3487, T-3500 (both self-flagged SOVEREIGN) | Flagged by author as operator-only; not re-examined |
| T-3410, T-3494 (BVP estimator no-signal gaps) | Same family as Sovereign Question 1 (the core issue); not opened |
| T-3376 (OneDev credential) | Budget-parked at 97% from prior session + Tier-0 OTP gate; deferred to next capacity round |
| T-3339, T-3441, T-3471, T-3472, T-3473, T-3519 | Not reached — T-3514's work consumed the round's remaining scope |
| ~39-task hygiene backlog | Structurally unselectable (Sovereign Q1/Q2) |
| 16-task `fw review-queue` "READY TO CLOSE" | All owner:human; not delegated to agent initiative |

**Notable change from round 3:** T-3514 was on the "untouched list" at round 3's end; round 4 selected and completed it.

## Sovereign questions — priority order

Unchanged from round 3 (no new questions, no answers to prior ones):

1. **BVP v1 heuristic has no differentiating signal for the structural/hygiene bug-class task family.** Now independently reproduced **five times** across three prior rounds plus this one (round 1 → round 2 → round 3 → round 4), with identical corpus metrics (17 flat-tied tasks at BVP 108).

2. **Should the ~39-task standalone hygiene backlog get an accumulator arc?** Unchanged, no operator answer found.

3. **Inception-vs-build voi_score/BVP-flatness framing.** Unfiled as separate task, third round naming it without filing. (If round 5 runs against this state, that would be the fourth recurrence, which per CLAUDE.md's Level D guidance would warrant filing as its own inception.)

4. **Batch-surface-not-batch-execute question for `fw review-queue`.** Unchanged, no capacity spent on it.

No new Sovereign questions surfaced in round 4. T-3514's design decisions (computing max(len(slug)) with a floor, anchoring verification on alignment rather than width literal) were implementation-detail engineering within a well-scoped problem.

## Gates that refused me, and what I did instead

None. This round had no gate refusals.

- Focused on T-3514 at the start (`fw work-on T-3514`)
- Wrote real ACs via Edit tool (no G-020 placeholder-AC gate fired)
- Ran verification commands during implementation (no G-020 scope gate issues)
- Closed the task cleanly via `fw task update T-3514 --status work-completed` (all gates passed: ACs checked, Verification passed, reviewer PASS)
- Focused back on T-3517 (parent task) to commit the work (no active-task gate issues)

No `--force`, `--skip-*`, or `FW_ALLOW_*` bypass was used.

## Cost-vs-estimate deltas worth feeding back into calibration

T-3514's `cost_estimate_proposed` (2026-09-26): `tier: 2, effort: 8`, `blast_radius: unmeasured`. Actual cost: reading ~10 lines of existing code (the hardcoded format strings and the sort/print loop), ~15 lines of new code (slug_width computation + adjusted separator + format string application), writing 4 real ACs (took ~2 minutes), writing 3 verification commands (took ~5 minutes to design and test), filling RCA section (took ~3 minutes). Total wall-clock time: ~20 minutes.

The estimator's `effort: 8` (which maps to ~100-150 lines in a typical build task) was a gross overestimate — this was a small, surgical fix. The likely reason: the estimator saw `lines=269` (total lines in the `lib/bvp.sh` file) and `acs=4` (number of ACs) without seeing that the ACs were placeholders and the fix would be tiny. Cost calibration note: tasks with "template ACs" should be scored lower than the line-count heuristic suggests, because the work is bounded by the task description (not the file size).

This is not a regression in the estimator; T-3514 was just filed with placeholder ACs and then immediately scored before the ACs were written. The fix was genuinely small and self-contained — the estimator's blind spot is the "placeholder AC" state, which is normal in the workflow.

## Next unit of work, if round 5 runs against this state

The owner:agent **started-work** set remains exhausted (fourth round confirmed). The owner:agent **captured** set now has 8 untouched items (down from 9, due to T-3514 being completed): T-3339, T-3376, T-3441, T-3471, T-3472, T-3473, T-3513, T-3519 (note: T-3519 was listed as `work-completed` in the prior round's run, but is shown as `started-work` in the current corpus, so it may have been re-opened or the state diverged).

**T-3376** (OneDev credential) is the natural next target due to stated scale ("unblock 91 stranded commits"), but carries the budget and Tier-0 gate risks noted in round 3. A fresh round 5 would start with clean budget and might make progress if the operator has already approved the Tier-0 credential request by then.

**T-3339** (arc-020 S8) looks like it is part of a larger arc slice; opening it might require understanding the arc's state first (read T-3339's task file before committing).

**T-3472** or **T-3473** (doctor/enforcement checks) are self-contained and ~50-100 lines each — good backup targets if T-3376 or T-3339 hit blocking dependencies.

If none of the captured/agent set is productive, widen the search to **captured, owner:human but not Sovereign-flagged** — though the mandate's producer-not-judge rule means agent completion of human-owned tasks is the last resort, not the default.

## Auditability

Every claim above traces to commands run in this session:

- `fw task show T-3514` / full task file read (T-3514's content, scope, placeholder ACs)
- `fw bvp --quadrant hv-lc --include-proposed` (flat-tie reconfirmed, 5th time)
- `fw task list --status captured --owner agent` (captured/agent candidate list)
- `fw work-on T-3514` (status captured → started-work, focus set)
- `sed -n '730,760p' lib/bvp.sh` (read existing code)
- Direct code edits to `lib/bvp.sh` (slug_width computation, separator adjustment)
- `fw bvp arcs | head -30` (live verification of fix, long slugs rendering correctly)
- Manual verification command runs (three commands, all passed):
  - `bash -c 'set -o pipefail; bin/fw bvp arcs > /tmp/bvp_arcs_output.txt 2>&1'`
  - `grep -q 'ewcr-arc0-contract-evidence\|onboarding-shape-detection' /tmp/bvp_arcs_output.txt`
  - `python3 - /tmp/bvp_arcs_output.txt << 'PYEOF'` (alignment check script)
- AC write via Edit tool (4 real criteria with verification hints)
- RCA fill (bug-class section with symptom, root cause, why allowed, prevention)
- `fw task update T-3514 --status work-completed` (gate results: ACs 4/4, Verification 3/3, Reviewer PASS)
- `git add -A && git commit -m "T-3514: ..."` (commit in background, awaiting completion notification)
- `fw context focus T-3517` (refocus on parent task for subsequent commits)

**Commits this round:** T-3514's changes (`lib/bvp.sh` line 737-742 modification + separator computation, task moved to `completed/`, episodic auto-generated). Commit message and timestamp to be confirmed once the background git commit completes.

## Session end state

**Budget:** ~14.88M tokens remaining (started with 15M, spent ~120K tokens in this round — well within safe zone)

**Context:** No critical context pressure. Round 4 completed cleanly with one task closed.

**Next action for operator:** 
- If round 5 proceeds, consider whether T-3376 (OneDev credential) should be attempted (operator may have approved Tier-0 OTP by then) or whether to widen the search to T-3339/T-3472/T-3473.
- If no further rounds run, confirm whether the Sovereign questions (Q1/Q2) should remain parked or if the operator wants to investigate the BVP flatness + hygiene-backlog arc question as its own inception.
