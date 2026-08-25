---
id: T-3129
name: "episodic git mining is skipped in worktrees and writes its initialised zeros
  as measurements"
description: >
  episodic git mining is skipped in worktrees and writes its initialised zeros as
  measurements

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-25T05:58:02Z
last_update: '2026-08-25T06:00:17Z'
date_finished:
cost_estimate_proposed:
  - ts: '2026-08-25T06:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=98,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T06:00:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3129: episodic git mining is skipped in worktrees and writes its initialised zeros as measurements

## Context

Reported independently by two peer projects within 7 hours, both measuring rather
than inferring, both declining to send a patch on the grounds that it is our file
and our fixtures. Verified here against our own corpus before acceptance.

**The bug.** `agents/context/lib/episodic.sh:165` gates ALL git mining on:

```sh
if command -v git >/dev/null 2>&1 && [ -d "$PROJECT_ROOT/.git" ]; then
```

In a linked git worktree `.git` is a regular **file** holding a `gitdir:` pointer,
not a directory. The test is false, the whole block is skipped —
`mine_git_summary`, `mine_git_challenges`, `mine_git_artifacts`,
`mine_git_timeline`, `mine_git_timestamps`, and the `commit_count` / `--numstat`
block — and the counters keep the `0` they were initialised with at lines 160-163.

The very next line already does the right thing and is never reached:
`git -C "$PROJECT_ROOT" log --all --grep="$task_id:"` works correctly from
inside a worktree. Nothing was lost. It was never read.

**This is the framework's own default flow.** `fw worktree create` is the
sanctioned path for parallel work (CLAUDE.md §Execution Model item 4,
§Trunk-Based Session Flow), and dispatched workers run in worktrees. So the
tasks most likely to record a zero footprint are the ones the framework itself
routes into isolation.

**Why the shape of the failure matters more than the line.** A skipped
measurement writes its *initialised value* as a *result*. An absent field reads
as "not measured". `commits: 0` reads as "measured, answer none". The failure
therefore cannot degrade gracefully and nothing anywhere flags it. This is the
part that outlives the one-liner, and it is why AC3 exists separately from AC1.

Sibling of **L-575** — *a guard that cannot read its input reports the same thing
as a guard that found nothing* — surfaced by `fw work-on`'s own recall on this
task. Same family as T-1828, T-3125, T-3126, T-3128: the instrument cannot
distinguish "could not look" from "looked and found nothing".

**Scope fence.** The ORDERING root cause — episodic generation running before the
completion commit exists, so single-commit tasks record zero even with the guard
passing — is a second, independent cause of the same symptom and is filed
separately. It converges on this same file, so it lands after this task, not
alongside it. Do NOT fix it here.

## Measured evidence (this repo, main checkout, verified 2026-08-25)

```
episodics total : 2736
commits: 0      : 697
  FALSE zeros   : 577   (git log --all --grep finds commits for the task)
  TRUE zeros    : 120
```

Counted with an ANCHORED `^T-XXX:` grep, which is stricter than the generator's
own unanchored `T-XXX:` query — so 577 is a floor, not a ceiling.

Cross-checked the one outlier (T-077 → 612 matches) rather than assuming a
measurement artefact: those are 612 genuine handover commits stamped to that id,
anchored and unanchored counts agree. No overcount defect.

Note this checkout's `.git` IS a directory, so the guard passes here — meaning
these 577 are NOT all attributable to this bug. That is the point of the scope
fence, and it is the trap the fix has to survive: **fixing the guard will barely
move this number**, and a reader who expects it to will reasonably conclude the
fix failed.

Peer measurements, for corroboration only (not evidence for our numbers):
001-CashWeb 46/56 zeros in a worktree; 832-Workflow-designer 75/92 false with the
guard passing.

## Acceptance Criteria

### Agent

- [ ] AC1 — The guard tests what the code actually depends on. `[ -d "$PROJECT_ROOT/.git" ]` is replaced by a test that is true in a linked worktree AND in a normal checkout (`git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree` preferred over `[ -e ]`, because it tests reachability rather than the existence of a path).
- [ ] AC2 — A control generates an episodic FROM A LINKED WORKTREE and asserts `commits > 0` for a task that has commits. This control MUST fail against pre-change code. Report "N of M fail against pre-change code"; a fixture that passes both before and after guards nothing.
- [ ] AC3 — When mining cannot run, the numeric fields are absent or null in the emitted YAML — never `0`. A reader (human or code) can distinguish "not measured" from "measured, none". This is a separate assertion from AC1 and must have its own test: force the mining block to be unreachable and assert the fields are not `0`.
- [ ] AC4 — Every sibling `[ -d "…/.git" ]` test in the repo is enumerated, and each is either fixed or explicitly recorded as correct-as-written with a reason. The idiom repeats; a point fix on one line leaves the class open.
- [ ] AC5 — The control lives in its own fixture tree, not pinned to the live corpus or to any currently-failing task (L-599). It must still pass after the 577 are backfilled.
- [ ] AC6 — `bin/fw test unit` shows no NEW failures attributable to this change; any pre-existing RED is named explicitly rather than absorbed.

### Human

- [ ] [REVIEW] Backfill decision: the 577 false zeros are regenerable (the commits never went anywhere) but regenerating against a definition that is about to change again for the ordering fix means doing it twice. **Steps:** read the Recommendation block below, then decide backfill-now vs backfill-after-ordering-fix. **Expected:** a one-line decision recorded on this task. **If not:** the corpus keeps understating itself and a zero keeps looking like an answer.

## Verification

bash -n agents/context/lib/episodic.sh
grep -q 'rev-parse --is-inside-work-tree' agents/context/lib/episodic.sh
! grep -qE '\[ -d "\$PROJECT_ROOT/\.git" \]' agents/context/lib/episodic.sh

## Decisions

## Updates
