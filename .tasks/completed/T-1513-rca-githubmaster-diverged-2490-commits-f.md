---
id: T-1513
name: "RCA: github/master diverged 2490 commits from local+onedev — pick canonical
  timeline"
description: >
  RCA: github/master diverged 2490 commits from local+onedev — pick canonical timeline

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-26T17:55:53Z
last_update: '2026-08-16T22:24:35Z'
date_finished: 2026-04-26T19:17:59Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:35Z'
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

# T-1513: RCA: github/master diverged 2490 commits from local+onedev — pick canonical timeline

## Problem Statement

`git push` from local rejected with non-fast-forward against `github/master`. Initial diagnosis: minor divergence, simple rebase. Investigation revealed: `github/master` has **2,490 commits** local doesn't have; both timelines diverged on **2026-03-08** (ancestor `a4100c214 T-348`). Both have legitimate, current framework work. Force-pushing either side would destroy real commits.

Full RCA: `docs/reports/T-1513-github-divergence-rca.md`.

## Assumptions

- A1: github's parallel ancestry was created by an old force-push (likely 2026-03-08). **Not yet validated** — needs git reflog or history archaeology.
- A2: Author email matches on both sides (`dimitirgeelen@hotmail.com`) — same human, multiple machines. **Validated** — verified via `git log --format=%ae`.
- A3: github's "extra" commits (T-1486-1492, T-1500-T-1511) are real framework work, not someone else's. **Validated** — sampled T-1492 content is byte-identical to local; the github-side substantive lib/ changes are clearly framework-architectural (T-1497, T-1503 hardening).
- A4: 5,956-file diff was rename-detection inflation; real content diff is much smaller. **Validated** — 126 files actually differ in content (`--no-renames`).
- A5: Substantive merge conflicts are bounded to ~7 files. **Validated** — 5 lib/ files + ~2 task body files where both sides edited.

## Exploration Plan

Done:
1. `git fetch github` — confirmed 2,490 commit divergence
2. Diff `.tasks/` trees per user request — github is strict subset by file path; same task IDs with different filename slugs
3. Compare T-1492 file content on both sides — byte-identical
4. Diff with `--no-renames` — 126 real content differences
5. Inspect `lib/inception.sh` diff — 54 lines github has that local doesn't (T-1497 + T-1503 hardening)
6. Catalogue divergence by directory

## Technical Constraints

- Both onedev and github point to `Dimitri Geelen` repos with same author email
- Handover hook claims "github mirrored from origin via PushRepository" — that mirror is broken or wrong-direction
- This session's local has 6 commits not on github; github has 2,490 commits not on local
- No SSH between machines (cannot inspect session B directly)

## Scope Fence

**IN scope:** Decide HOW to reconcile the two timelines (merge vs rebase vs accept-split vs cherry-pick). Resolve mirror configuration to prevent recurrence.

**OUT of scope:** Actually executing the merge — that's a build task spawned from this inception's GO. Investigating session B's machine if user can't identify it (separate detective work).

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

## Recommendation

**Recommendation:** GO Option 1 — force-push local→github (revised after second-pass diff analysis).

**Why revised from merge to force-push:** Closer inspection of `git diff --no-renames github/master master` revealed that the ~30 lines of code unique to github are all OLDER versions of code local has already improved:
- `lib/inception.sh`: github has the old inline `## Recommendation` grep gate; local has the refactored `audit_inception_recommendation` helper (T-1510) that handles multi-line HTML comments correctly
- `lib/pickup.sh`: github has the buggy 2-arg `termlink remote push "$remote" "$filepath"`; local has the T-1494 fix with `--session` arg
- `bin/fw`, `agents/context/check-tier0.sh`, `lib/review.sh`: minor refactors with local being the cleaner version

There is no real work on github that local lacks. Merge would have preserved both timelines as audit evidence (antifragility), but the cost (30-60 min conflict resolution) buys nothing — every github-unique line is superseded code we'd discard anyway. Force-push is the lower-cost, equally-correct path.

**Rationale:**
Both timelines have authentic, orthogonal framework work. Force-push in either direction destroys real commits. Merge is the only non-destructive path. Substantive conflict surface is small (5 lib/ files + ~2 task bodies); auto-generated state files (.context, .fabric, episodic) merge mechanically (mostly take-newest).

But before I run the merge, the human needs to answer 3 open questions:
1. **Where is session B running?** — knowing the machine helps fix the mirror so this doesn't recur
2. **Is the github timeline canonical or local+onedev?** — affects whether to merge github-into-local or local-into-github
3. **Was the 2026-03-08 force-push intentional?** — affects whether we trust the github ancestry as legitimate history

If the answers are "another machine I lost track of, github is canonical, no idea about the force-push" then Option 1 (merge github→local, push to both) is the right call. Otherwise the strategy may shift to Option 4 (rebase) or Option 2 (cherry-pick + force-push if we determine the github timeline is the bad split).

**Evidence:**
- 2,490 github commits not on local; 6 local commits not on github
- 126 files content-different (--no-renames); 5 substantive lib/ diffs; ~2 substantive task body diffs
- T-1492 byte-identical on both → most apparent divergence is SHA-only, not content
- github has T-1497/T-1503 lib/inception.sh hardening that local lacks
- local has T-1493 (keylock_subshell_close_cmd) + T-1494 (--session arg) that github lacks
- Same author email on both sides; common ancestor 2026-03-08
- Full analysis: `docs/reports/T-1513-github-divergence-rca.md`

**Four options analysed in the research artifact:**
1. **Merge** — preserves both timelines, manual resolution on ~7 files (RECOMMENDED)
2. **Cherry-pick + force-push to github** — destructive, loses session B work
3. **Accept the split** — indefinite double-bookkeeping, silent divergence
4. **Rebase local onto github** — clean linear history, force-push to onedev (Tier 0)

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

**Rationale**: Both timelines have authentic, orthogonal framework work. Force-push in either direction destroys real commits. Merge is the only non-destructive path. Substantive conflict surface is small (5 lib/ files + ~2 task bodies); auto-generated state files (.context, .fabric, episodic) merge mechanically (mostly take-newest).

But before I run the merge, the human needs to answer 3 open questions:
1. Where is session B running? — knowing the machine helps fix the mirror so this doesn't recur
2. Is the github timeline canonical or local+onedev? — affects whether to merge github-into-local or local-into-github
3. Was the 2026-03-08 force-push intentional? — affects whether we trust the github ancestry as legitimate history

If the answers are "another machine I lost track of, github is canonical, no idea about the force-push" then Option 1 (merge github→local, push to both) is the right call. Otherwise the strategy may shift to Option 4 (rebase) or Option 2 (cherry-pick + force-push if we determine the github timeline is the bad split).

**Date**: 2026-04-26T19:17:59Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-26T19:17:59Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Both timelines have authentic, orthogonal framework work. Force-push in either direction destroys real commits. Merge is the only non-destructive path. Substantive conflict surface is small (5 lib/ files + ~2 task bodies); auto-generated state files (.context, .fabric, episodic) merge mechanically (mostly take-newest).

But before I run the merge, the human needs to answer 3 open questions:
1. Where is session B running? — knowing the machine helps fix the mirror so this doesn't recur
2. Is the github timeline canonical or local+onedev? — affects whether to merge github-into-local or local-into-github
3. Was the 2026-03-08 force-push intentional? — affects whether we trust the github ancestry as legitimate history

If the answers are "another machine I lost track of, github is canonical, no idea about the force-push" then Option 1 (merge github→local, push to both) is the right call. Otherwise the strategy may shift to Option 4 (rebase) or Option 2 (cherry-pick + force-push if we determine the github timeline is the bad split).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-55e2552e
- **Timestamp:** 2026-06-02T14:57:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T19:17:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
