---
id: T-3142
name: "24 commits on 3 branches exist only on this disk — no remote, dormant 8 weeks"
description: >
  24 commits on 3 branches exist only on this disk — no remote, dormant 8 weeks

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-25T16:07:21Z
last_update: 2026-08-25T16:18:20Z
date_finished: 2026-08-25T16:18:20Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-08-25T16:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=280,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T16:15:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3142: 24 commits on 3 branches exist only on this disk — no remote, dormant 8 weeks

## Context

Three local branches carry commits that exist on no remote. If this disk fails,
the work is gone — there is no second copy anywhere.

| branch | commits ahead of master | on origin? | last commit |
|---|---:|---|---|
| `t2353-audit-emit-tasks` | 22 | **no** | 2026-06-27 |
| `audit-remediation-t2416` | 1 | **no** | 2026-06-26 |
| `t2511-warn-remediation` | 1 | **no** | 2026-07-07 |

Four further branches carry unlanded work but *do* exist on origin, so they are
backed up even though they are not landed: `t2417-fw-sessions` (58, a diverged
fork), `worktree-rca-worktree-push-strand` (37),
`worktree-inception-gov-payload-mediation` (6), `learning/precompact-cleanup` (1).

**This task pushes; it does not land and it does not delete.** Landing is a
merge decision per branch and several of these are stale enough that the right
answer may be "drop it" — but that is a decision to make with the work backed up,
not with it hostage to one disk. Branch deletion is Tier 0 regardless.

### Why this is filed now, and the correction that produced it

T-3097 (worktree failure-class RCA, GO recorded 2026-08-20) told the operator
that the two `worktree-*` branches were safe to prune: *"T-2824 recovered
everything of value and correctly stopped short; branch deletion is Tier 0."*

Running `fw worktree gc`, which compares **content** rather than commit identity,
disagrees: `worktree-rca-worktree-push-strand` is `unlanded 28/53` and
`worktree-inception-gov-payload-mediation` is `unlanded 3/3`. Both are KEEP, not
RECLAIM. Had that handoff been executed as written, 31 commits' worth of content
would have gone with them.

The near-miss is the reason for this task's shape: the RCA reasoned about
recovery from a *previous task's report* that recovery had happened, and never
re-derived it. The recovery claim was two weeks old and had never been re-checked
against the tree. **A recovery claim is evidence about the past; only a content
comparison is evidence about now.**

Origin: surfaced while acting on the operator's restatement of the worktree
directive (the same directive T-3132 codified as §Worktree Policy).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — the three no-remote branches are pushed to `origin` under their own
      names. Nothing is merged, rebased, force-pushed or deleted: the working
      state of `master` and of every branch is byte-identical before and after,
      and that is checked rather than assumed.
- [x] AC2 — after the push, **zero** local branches carry commits that exist on no
      remote. Verified by re-deriving the set from `git ls-remote` rather than by
      re-reading the table above, so the check answers "is it true now" and not
      "did I write it down correctly".
- [x] AC3 — the T-3097 handoff is corrected in the task file itself, not only in
      this one. It currently tells the operator the two `worktree-*` branches are
      safe to prune; leaving that standing means the next person to act on it
      deletes 31 commits of unlanded content.
- [x] AC4 — `fw worktree gc` still reports the same RECLAIM/KEEP split after the
      push as before it. A push must not change reclaimability; if it does, the
      gc predicate is keyed on remote presence rather than on content and that is
      a separate defect worth knowing about.
- [x] AC5 — the stale duplicate `**Recommendation:** DEFER` block in T-3097 is
      removed. Two conflicting verdicts in one file means any parser reading "the"
      recommendation can get either. Measured across the whole corpus: T-3097 is
      the only file with conflicting verdicts, so this is a repair, not a class,
      and no separate task is warranted.

### Human
- [ ] [REVIEW] Decide what happens to the seven branches of unlanded work

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw worktree gc`
  2. The five `RECLAIM` entries are content-verified as already in master — those
     are safe to delete (Tier 0, your call, `git branch -D <name>`).
  3. The seven `KEEP` entries are not. For each, decide: land it
     (`fw integrate`), or drop it deliberately. Two are 8 weeks dormant
     (`worktree-*`, 2026-07-01) and one is a diverged fork
     (`t2417-fw-sessions`, ahead 58 / behind 2232) that cannot be integrated and
     must be reconciled or abandoned.

  **Expected:** each KEEP branch has a decision. Deleting nothing is a valid
  outcome; leaving them undecided for another 8 weeks is the state this task
  exists to end.

  **If not:** if any branch is unreadable or you want the analysis before
  deciding, say which and I will produce a per-branch content summary — that is a
  static read over finished work and dispatches cleanly.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# AC2 — the invariant, re-derived from the remote every run. Not a count and not
# a branch list: it asks "does any branch carry work that exists only here", so
# it stays meaningful as branches are created, landed and deleted.
for b in $(git branch --format="%(refname:short)"); do n=$(git rev-list --count master..$b 2>/dev/null || echo 0); [ "${n:-0}" -eq 0 ] && continue; git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1 || exit 1; done

# AC1 — the three specific branches this task was filed for. Named deliberately:
# they are the evidence, and if one silently vanishes the invariant above would
# still pass while the work was gone.
git ls-remote --exit-code --heads origin t2353-audit-emit-tasks > /dev/null && git ls-remote --exit-code --heads origin audit-remediation-t2416 > /dev/null && git ls-remote --exit-code --heads origin t2511-warn-remediation > /dev/null

# AC3 — the corrected T-3097 handoff is in T-3097's own file.
grep -q "CORRECTED 2026-08-25 (T-3142) — do not execute this as written" .tasks/active/T-3097-worktree-failure-class--ultra-deep-rca-a.md

# AC5 — exactly one verdict line in T-3097.
[ "$(grep -c "^\*\*Recommendation:\*\*" .tasks/active/T-3097-worktree-failure-class--ultra-deep-rca-a.md)" -eq 1 ]

# AC4 — the substantive safety claim, in a form that survives the operator acting
# on the Human AC. Asserting the literal "5 reclaimable, 7 to keep" split would go
# red the moment a branch is landed or deleted — which is the stale-count trap
# T-3140 was filed about, and it would be filed here for the same reason. What
# must stay true is narrower and permanent: neither worktree-* branch may ever be
# reported RECLAIM while it still holds unlanded content. Once landed or deleted
# the branch drops out of the report entirely and the assertion still holds.
bin/fw worktree gc > /tmp/.t3142g 2>&1 && ! grep -qE "RECLAIM branch +worktree-(rca-worktree-push-strand|inception-gov-payload-mediation)" /tmp/.t3142g

## RCA

**Symptom:** 24 commits across three branches existed on no remote — a single disk
failure away from being lost. Two of them carried completed task work (OpenRouter
fallback routing, BVP estimator handlers, six closed tasks). They had been dormant
for eight weeks and nothing had ever said so out loud.

**Root cause:** two independent things, and only the second is interesting.

1. Branches created for worktree-based work outlived their worktrees. `git worktree
   list` shows only the main checkout; the directories are gone and the branches
   remain. Nothing pushes a branch when its worktree is torn down.
2. **The safety claim was inherited rather than re-derived.** T-3097's operator
   handoff said the stranded branches were safe to prune, sourced from T-2824's
   report that recovery had happened. That report was two weeks old and had never
   been re-checked. `fw worktree gc` — which compares content, not commit identity
   — says `unlanded 28/53` and `unlanded 3/3`. Executing the handoff as written
   would have destroyed 31 commits of content that is in master nowhere.

**Why structurally allowed:** the branch-hygiene audit does report these — the WARN
lists `behind-threshold` and `remote-unlanded` findings every run, and has for
weeks. It is not blind. But it reports *staleness*, and staleness reads as
untidiness; nothing in the output distinguishes "this branch is old" from "this
branch is the only copy of 22 commits". The consequential fact and the cosmetic one
are rendered in the same voice, so the consequential one was triaged at the priority
of the cosmetic one. That is the same shape as T-3140, one level up: not a check
that cannot see, but a check that sees and cannot say which part matters.

**Prevention** (distinct from the fix — the push is the fix):

- The AC2 verification line is the standing invariant: *no branch may carry commits
  that exist on no remote*, re-derived from `git ls-remote` on every run rather than
  from any stored list. It is one loop and it answers the consequential question
  directly instead of by proxy.
- T-3097's handoff is corrected in place, so the next reader of that task cannot act
  on the superseded instruction. Correcting only this task's file would have left the
  live hazard exactly where it was.
- The generalisable rule, recorded as a learning: **a recovery claim is evidence
  about the past; only a content comparison is evidence about now.** T-2824's report
  was true when written. The error was treating it as still true two weeks later
  without asking.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

**Recommendation:** GO

**Rationale:** The agent half is finished and is the reversible half: four branches
pushed, nothing merged, nothing rebased, nothing deleted, `HEAD` byte-identical
before and after. 24 commits that existed on one disk now exist on two. The
standing invariant — no branch carries work that exists on no remote — is a single
`git ls-remote` loop in Verification and currently passes.

The Human AC is the part I deliberately did not do. Seven branches hold unlanded
work and each needs a land-or-drop decision; two are eight weeks dormant and one is
a fork that cannot be integrated at all. Those are your calls, and they are now
safe calls to take slowly, which was the point.

**Evidence:**
- Pushed: `t2353-audit-emit-tasks` (22 commits), `audit-remediation-t2416` (1),
  `t2511-warn-remediation` (1), `t100196-vendor-fix` (content-verified merged, pushed
  on `gc`'s own "push first" advice). Unprotected branches: 4 → **0**.
- `fw worktree gc` split unchanged across the push (5 reclaimable / 7 keep), which
  also confirms the predicate is content-keyed rather than remote-keyed.
- **T-3097's operator handoff was wrong and is corrected in place.** It said the two
  `worktree-*` branches were safe to prune; content comparison says `unlanded 28/53`
  and `3/3`. Executing it as written would have destroyed 31 commits.
- T-3097's stale duplicate `**Recommendation:** DEFER` removed; that file now carries
  exactly one verdict. Corpus-wide measurement: it was the only file with conflicting
  verdicts, so no follow-up task is warranted.

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-25T16:07:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3142-24-commits-on-3-branches-exist-only-on-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4d49ecb1
- **Timestamp:** 2026-08-25T16:18:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 68
     - evidence: `git ls-remote --exit-code --heads origin t2353-audit-emit-tasks > /dev/null && git ls-remote --exit-code --heads origin audit-remediation-t2416 > /dev/null && git ls-remote --exit-code --heads origin `

### 2026-08-25T16:18:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
