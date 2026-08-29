---
id: T-3178
name: "fw review-queue does not show decided-unclosed inceptions — wire it to lib/decided_unclosed
  (T-3175 split)"
description: >
  T-3175 shipped the shared predicate and the /approvals section. The CLI mirror is
  unwired because fw review-queue is an inline python heredoc inside bin/fw, which
  T-3127 holds uncommitted.

status: started-work
workflow_type: build
owner: agent
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
created: 2026-08-26T17:01:54Z
last_update: 2026-08-29T10:40:40Z
date_finished:
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
  - ts: '2026-08-26T17:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T17:15:14Z'
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

# T-3178: fw review-queue does not show decided-unclosed inceptions — wire it to lib/decided_unclosed (T-3175 split)

## Context

Split from T-3175, which closed the `/approvals` half of the same gap and left
this half named rather than silently dropped. T-3175's fourth Agent AC reads:

> `fw review-queue` renders the section too — **SPLIT to T-3178**, blocked: the
> command is an inline python heredoc inside `bin/fw`, which T-3127 holds
> uncommitted.

**That blocker is gone.** T-3127 landed on 2026-08-29 (`f0fec8e43`, `1da495d4b`);
`git status --short bin/fw` is now empty. Editing the heredoc no longer sweeps
another task's uncommitted work — which was the T-3165 defect the split existed
to avoid, not a property of the work itself.

**The gap.** A decided-but-unclosed inception is one where the operator recorded
GO or NO-GO, the task stayed in `active/` because `update-task.sh:87` (Human
Sovereignty Gate, R-033) refuses agent closure on `owner: human`, and exactly one
action remains: the operator closing it. `fw review-queue` has three sections and
the task falls through all of them:

| section | predicate | why a decided inception misses it |
|---|---|---|
| DECISIONS | `workflow_type == inception AND NOT DECISION_RE.search(text)` | it *has* a decision — recording one drops it out |
| PAUSED | `list_paused_dispatches()` | unrelated |
| VERDICT | `count_unchecked_human_acs(text) > 0` | an inception whose Human ACs are ticked has none |

`/approvals` had the identical shape and T-3175 fixed it there. Leaving the CLI
unfixed is worse than never having fixed either: the two surfaces are documented
as mirrors of one another (`bin/fw:7146`, "terminal mirror of Watchtower
/approvals"), so an operator who checks the terminal now gets a *confidently*
empty answer that the web page would contradict.

**This is not hypothetical, and the operator hit it.** T-3181 was GO'd on
2026-08-27 and asked about on 2026-08-29 — *"why is it back in the list again and
we are not acting on it?"*. It is in this exact set.

**Why it must import rather than reimplement.** Peer 010-termlink's finding on the
chat arc, generalised: *a guard that reimplements the code it guards cannot detect
that code being fixed.* Locally the same class is L-638 / L-298 / L-315 —
cross-surface count divergence from each surface owning a copy of the predicate.
`lib/decided_unclosed.py` exists precisely so this file imports it; a fourth
inline regex in `bin/fw` would rebuild the divergence T-3175 removed.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw review-queue` renders a DECIDED section listing decided-unclosed
      inceptions, distinct from DECISIONS (undecided) and VERDICT (unchecked
      Human ACs), and T-3181 appears in it on the live corpus
      — measured: `DECIDED — inceptions awaiting operator closure (2)`, listing
      T-2876 (20d) and T-3181 (2d)
- [x] The section is populated by importing `lib/decided_unclosed.py` — no second
      copy of the predicate inside `bin/fw`. Verified by grepping `bin/fw` for a
      `\*\*Decision\*\*` regex outside the pre-existing `DECISION_RE` line
      — measured: `grep -c '(GO|NO-GO|DEFER)' bin/fw` = **1**, and
      `import decided_unclosed as _du` present at `bin/fw:7265`
- [x] `fw review-queue` and `/approvals` report the SAME decided-unclosed count.
      A mirror that disagrees with what it mirrors is the defect, not the fix
      — measured: page renders `2 inceptions — decision recorded` and `2 to close`;
      CLI renders `(2)`; both name T-2876 and T-3181
- [x] `--arc <id>` filters the DECIDED section as it already filters the other
      two, and `--arc continuous-run` is measured (not assumed) to narrow it
      — measured: unfiltered 2 → `--arc continuous-run` 1 (T-3181 only).
      **Control arm:** `--arc arc-006` returns T-3181 absent, which is what
      separates "the filter works" from "the filter is inert"
- [x] `fw review-queue --ids` output is BYTE-IDENTICAL before and after. It feeds
      `fw verify-queue`'s population (T-2765, L-539); widening it here would
      silently change which tasks another rail runs over
      — measured against `git show HEAD:bin/fw`: 1964B / 281 lines both sides,
      `cmp -s` clean
- [x] A bats test pins the section, and is mutation-tested: breaking the predicate
      import must redden it. A test that stays green when the feature is removed
      is the empty-queue false-green this whole task is about (same control leg as
      T-3175 and T-3099)
      — `tests/unit/t3178_review_queue_decided.bats`, 14/14. Mutations below.

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

## RCA

**Symptom.** T-3181 was GO'd on 2026-08-27 and the operator asked on 2026-08-29
why it was "back in the list again". It had never been on a list. Both terminal
surfaces reported nothing outstanding for it.

**Why (5-whys).**
1. *Why was T-3181 invisible?* `fw review-queue` has three sections and it matched
   none of them.
2. *Why none?* DECISIONS excludes anything with a recorded decision; VERDICT
   requires unchecked Human ACs, and T-3181 has zero; PAUSED is unrelated.
3. *Why does no section cover "decided, still open"?* Because that state is
   created by a gate the queue's author did not model: `update-task.sh:87` refuses
   agent closure on `owner: human`. The state exists only because sovereignty is
   enforced, so it is invisible to anyone reasoning about the task lifecycle
   without that gate in mind.
4. *Why did the `/approvals` fix (T-3175) not cover it?* It did — for the web
   surface. The CLI half was correctly identified and correctly split to this
   task, blocked on `bin/fw` being held uncommitted by T-3127.
5. *Why did the split then sit?* Nothing watches for a split-out AC whose blocker
   has cleared. T-3127 landed and T-3178 stayed `captured`; the unblocking event
   produced no signal. **This is the residual and it is not fixed here.**

**Why the framework was blind (G-019).** The section's absence and its emptiness
are the same output. A queue that omits a category renders identically to a queue
whose category is empty, so the failure cannot be seen from the surface it
affects — the operator's only evidence was remembering a task the tool had
forgotten. Same false-green family as the rest of arc-012, and the reason this
task's tests seed the negative case explicitly rather than asserting exit 0.

**A defect found while fixing it.** The first implementation resolved the
predicate against `PROJECT_ROOT/lib`. In this repo `PROJECT_ROOT ==
FRAMEWORK_ROOT`, so it worked live and passed every by-hand check — and would
have been permanently, silently absent in every consumer, where `lib/` belongs to
the framework and not the project. T-1633's class: path knowledge implicitly
hard-coded to the framework developer's layout. Caught only because the bats
suite runs against a synthetic PROJECT_ROOT rather than the repo it lives in.

**Mutation record.** Two applied to the shipped code, each reverted:
- **M1** — neuter the `decided_rows.append` call. Reddened 1, 2, 3, 8, 10, 12, 14.
- **M2** — revert *only* the emptiness guard to its pre-T-3178 form
  (`not rows and not decision_rows and not paused_rows`). Reddened 1, 2, 3, 8, 10,
  12 — and left 14 green, correctly, because that test seeds a second task so the
  early exit never fires. M2 discriminating from M1 is what shows the guard is
  load-bearing on its own and not incidentally covered by the render assertions.
- **M0** (unplanned, the useful one) — the `PROJECT_ROOT/lib` path bug above.
  Reddened the same six on first run. It is recorded as a mutation because that is
  what it functionally was: the suite met a broken implementation and reddened.

## Decisions

### 2026-08-29 — no dedup between DECIDED and VERDICT
- **Chose:** let a task appear in both sections if it somehow qualifies for both.
- **Why:** `/approvals` does not dedup either — it sums the section counts — and
  this command is documented as its terminal mirror. Parity with the surface being
  mirrored beats a local improvement that would make the two disagree.
- **Rejected:** suppressing VERDICT entries that appear in DECIDED. It would change
  `--ids`, which is `fw verify-queue`'s population (L-539), to fix a case that does
  not occur: measured 0 overlap across the live corpus (both decided inceptions
  have zero unchecked Human ACs).

### 2026-08-29 — DEFER stays out
- **Chose:** GO and NO-GO only.
- **Why:** inherited from `lib/decided_unclosed.py` rather than re-decided. A DEFER
  is awaiting a *date* (`revisit_at`, T-1451, G-053 daily scan), not an action;
  listing it as "awaiting closure" would misdescribe it. Re-deciding it here would
  be the second copy of a judgement, which is the thing this task exists to avoid.

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

# The outer shell parses. Necessary, not sufficient — it says nothing about the
# embedded python, which is where every edit in this task landed (T-3210, L-408).
bash -n bin/fw
# The suite, with the guard the exit code no longer supplies. Test 14 is the
# mutation control; naming it explicitly means a future edit that deletes the
# control cannot leave this line still passing.
timeout 300 bats tests/unit/t3178_review_queue_decided.bats > /tmp/.t3178-bats.out 2>&1 && grep -q '^ok 14 ' /tmp/.t3178-bats.out && ! grep -q '^not ok' /tmp/.t3178-bats.out
# The section renders on the live corpus.
bin/fw review-queue > /tmp/.t3178-rq.out 2>&1 && grep -q 'DECIDED — inceptions awaiting operator closure' /tmp/.t3178-rq.out
# ONE predicate. If this becomes 2, someone has reimplemented the decision regex
# inside bin/fw and the two surfaces have started to drift (L-638, L-298, L-315).
test "$(grep -c '(GO|NO-GO|DEFER)' bin/fw)" = "1"
# The import is what makes the section shared rather than parallel.
grep -q 'import decided_unclosed as _du' bin/fw
# --ids must not widen: it is fw verify-queue's population (T-2765, L-539).
bin/fw review-queue --ids > /tmp/.t3178-ids.out 2>&1 && ! grep -q 'DECIDED' /tmp/.t3178-ids.out

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-08-26T17:01:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3178-fw-review-queue-does-not-show-decided-un.md
- **Context:** Initial task creation

### 2026-08-29T10:40:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
