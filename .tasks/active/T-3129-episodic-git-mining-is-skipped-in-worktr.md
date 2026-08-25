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

- [x] AC1 — The guard tests what the code actually depends on. `[ -d "$PROJECT_ROOT/.git" ]` is replaced by a test that is true in a linked worktree AND in a normal checkout (`git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree` preferred over `[ -e ]`, because it tests reachability rather than the existence of a path).
- [x] AC2 — A control generates an episodic FROM A LINKED WORKTREE and asserts `commits > 0` for a task that has commits. This control MUST fail against pre-change code. Report "N of M fail against pre-change code"; a fixture that passes both before and after guards nothing.
- [x] AC3 — When mining cannot run, the numeric fields are absent or null in the emitted YAML — never `0`. A reader (human or code) can distinguish "not measured" from "measured, none". This is a separate assertion from AC1 and must have its own test: force the mining block to be unreachable and assert the fields are not `0`.
- [x] AC4 — Every sibling `[ -d "…/.git" ]` test in the repo is enumerated, and each is either fixed or explicitly recorded as correct-as-written with a reason. The idiom repeats; a point fix on one line leaves the class open.
- [x] AC5 — The control lives in its own fixture tree, not pinned to the live corpus or to any currently-failing task (L-599). It must still pass after the 577 are backfilled.
- [ ] AC6 — `bin/fw test unit` shows no NEW failures attributable to this change; any pre-existing RED is named explicitly rather than absorbed.

### Human

- [ ] [REVIEW] Backfill decision: the 577 false zeros are regenerable (the commits never went anywhere) but regenerating against a definition that is about to change again for the ordering fix means doing it twice. **Steps:** read the Recommendation block below, then decide backfill-now vs backfill-after-ordering-fix. **Expected:** a one-line decision recorded on this task. **If not:** the corpus keeps understating itself and a zero keeps looking like an answer.

## Recommendation

**Recommendation:** GO — backfill AFTER T-3129 lands, BEFORE T-3130.

**Rationale.** 832-Workflow-designer advised the opposite ("if the generator is
going to change, backfilling first means doing it twice against a moving
definition"), and that is sound reasoning about a moving *schema*. It does not
apply to the *commit mining*, and the distinction is what settles the call:

The ordering bug (T-3130) corrupts an episodic only at the instant it is
generated — mining ran before the completion commit existed. **Regenerating an
old episodic today mines a history that has long since been complete.** The
commits are all there; my 577 measurement is itself proof, because it found them
with the generator's own query. So a backfill run today is not exposed to T-3130
at all, and T-3130's fix changes WHEN mining runs, not WHAT it records.

What genuinely would invalidate a backfill is a change to the emitted *shape* —
and that is T-3129's AC3 (absent/null rather than 0), which lands in this task.
So the schema is settled by the thing we are shipping now, and waiting for T-3130
buys nothing while leaving 577 records understating themselves for however long
the ordering fix takes.

**Evidence:**
- 577 of 2736 episodics carry a false `commits: 0`; all 577 are recoverable by
  the generator's own `git log --all --grep` today (that is how they were counted).
- 403 of the 577 have exactly one commit, 509 have two or fewer — the ordering
  signature, i.e. the majority are T-3130-caused and *still* regenerable now.
- This checkout's `.git` is a directory and no worktrees are currently
  registered, so the guard bug is not what produced most of these — which is
  precisely why fixing the guard will barely move the number, and why the
  backfill is the step that actually repairs the corpus.
- Recovery is one-directional and lossless: the failure can only understate, so
  a regenerated value is never worse than the stored one.

**What I am NOT recommending:** running the backfill under agent authority. It
rewrites 577 files in episodic memory — one of the three memory types — and the
operator should say go before that happens, which is why this is a Human AC and
not an Agent AC.

## Verification

bash -n agents/context/lib/episodic.sh
grep -q 'rev-parse --is-inside-work-tree' agents/context/lib/episodic.sh
! grep -qE '\[ -d "\$PROJECT_ROOT/\.git" \]' agents/context/lib/episodic.sh

## Decisions

**AC4 — every `[ -d "…/.git" ]` site in the repo, with a verdict for each.**

Enumerated with `grep -rn '\-d .*\.git"' --include='*.sh' .` (excluding the
vendored `.agentic-framework/` mirror, which is regenerated by `fw vendor self`,
and `tests/`).

FIXED — 13 sites across 13 files. Two different questions were being asked under
one idiom, and they take two different answers:

- *"Can git answer here?"* → `git -C "$DIR" rev-parse --is-inside-work-tree`.
  Used in `agents/context/lib/episodic.sh` (the origin site). This is the correct
  test wherever the code goes on to RUN git commands, because it asks the
  question those commands actually depend on rather than inferring it from the
  shape of a path.
- *"Does a `.git` exist at this path?"* → `[ -e "$DIR/.git" ]`. Used in
  `agents/audit/self-audit.sh`, `agents/git/lib/large-file-scan.sh`,
  `agents/git/lib/secret-scan.sh`, `agents/termlink/termlink.sh`, `install.sh`,
  `lib/init.sh`, `lib/setup.sh`, `lib/update.sh`, `lib/upgrade.sh`,
  `lib/upstream.sh`, `lib/url-credentials.sh`, `lib/validate-init.sh`. These are
  repo-detection predicates; `-e` is sufficient and is worktree-correct because a
  linked worktree's `.git` exists as a file.

CORRECT AS WRITTEN — 2 sites, deliberately left alone:

- `agents/audit/self-audit.sh:348` — not code. It is a comment that quotes the
  old `[ -d "$PROJECT_ROOT/.git" ]` gate while explaining the bug it caused.
  Rewriting it would destroy the explanation.
- `lib/update.sh:80` — `[ ! -d "$vendored_dir/.git" ]`. This asks a genuinely
  different question: *"is the vendored framework copy a clone rather than a
  vendored tree?"*, i.e. it is testing for **residue**, not for reachability. A
  vendored directory is produced by file copy and is never a linked worktree, so
  the worktree failure mode cannot arise here. `-d` is the right test for
  "a `.git` DIRECTORY is sitting in the vendored path". Noted rather than
  changed, per this AC's requirement that skipped sites be recorded with a reason.

**Mutation check (run by the orchestrator, not reported by the worker).**
5 of 7 controls fail against pre-change code (tests 1, 2, 3, 5, 6). The two that
pass on both sides are regression guards and are supposed to: test 4 asserts an
ordinary checkout still mines after the guard change, and test 7 asserts the
emitted YAML stays parseable in the skipped case. Counting them as mutation
coverage would overstate the suite — 5 controls detect the defect, 2 protect
against the fix breaking something else.

**AC3 went further than specified.** The task asked for absent/null instead of
`0`. The implementation also emits an explicit `git_mining: ok|skipped` field, so
the record states *why* the counters are null rather than leaving a reader to
infer it from their absence. Kept — it converts an inference into a statement,
which is the whole point of the AC.

**AC6 status at hand-off — deliberately NOT ticked.**

What is established: of 22 failures in a 385-test partial run, **zero are in any
of the 13 files this task changed**. The clusters are
`tests/unit/audit*.bats` (18), `approvals_close_ready_arcs` (2),
`atomic_yaml_write_lint` (1, names `lib/corpus-id.sh`), and
`ac_counter_sed_range_one_line_comment` (1, names `update-task.sh`).

Why the audit cluster is not attributable to this change — by reachability, not
by assumption: `tests/unit/audit.bats` invokes `agents/audit/audit.sh` and
contains **zero** references to `self-audit.sh`, which is the only audit file this
task touched. `audit.sh` is untouched here. The change cannot reach that test file.

The live explanation is lock contention: those tests assert `[ "$status" -le 1 ]`,
which cannot distinguish exit 2 (audit ran, found FAILs) from exit 75 (audit could
not run — another audit holds the lock). A direct probe of
`audit.sh --section structure` with no lock held exited **1** (pass).
`audit_flock.bats` — a test *about* the lock — is itself in the failing set, which
corroborates it. Filed as OBS-341.

Why it is still not ticked: part of that contention was **self-inflicted**. This
session ran the unit suite concurrently with pushes (whose pre-push gate runs an
audit) and briefly with a second `audit.bats` run. So "pre-existing" is the
likely reading but is not *proven*, and a clean quiet-system run is the evidence
that would settle it. Ticking on a likely reading is exactly the move the
false-green work in this task exists to discourage.

Next session: re-run `bin/fw test unit` with nothing else touching the audit lock,
and tick AC6 only if the audit cluster is green or fails for a named non-lock reason.

**The worker did not finish.** It was killed by the dispatch watchdog at its 600s
timeout while running `bin/fw test unit` for AC6 — correctly; the watchdog wrote
`TIMEOUT` to its stderr log. The 600s budget was the orchestrator's error, not
the worker's: AC6 requires the full unit suite, which alone exceeds that. Source
changes, the test file and `fw vendor self` had all landed on disk before the
kill; the AC4 decisions above, AC ticking, verification and the commit were
completed by the orchestrator.

## Updates
