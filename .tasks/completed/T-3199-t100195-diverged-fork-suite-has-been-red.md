---
id: T-3199
name: "t100195 diverged-fork suite has been red since T-3094 added days= to the finding
  format"
description: >
  tests/unit/t100195_diverged_fork.bats tests 1 and 2 assert on anchored strings that
  no longer exist: 'diverged-fork fork-feat ahead=3 behind=3 (threshold 2)$' and 'behind-threshold
  lag-feat behind=3 (threshold 2)$'. T-3094 inserted 'days=<d>' before the threshold
  clause, and the trailing $ anchor means neither pattern can ever match again. Red
  since T-3094, unnoticed because the suite is not in any gate's path. Verified pre-existing:
  stashing the T-3194 edits leaves the same 2 failures. Sibling to T-3195 (t3095 hygiene
  test 3) but a DIFFERENT root cause - that one is a T-3188 retarget, this one is
  a T-3094 format change. Fix is to update both patterns to tolerate the days= field,
  not to drop the anchor: the anchor is what makes them assert the WHOLE line rather
  than a prefix.

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [C-004, agents/handover/handover.sh, bin/fw, lib/branch-hygiene.sh]
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
created: 2026-08-27T09:56:12Z
last_update: 2026-08-27T21:22:07Z
date_finished: 2026-08-27T21:22:07Z
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
  - ts: '2026-08-27T10:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 1
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=1 
      (workflow:test); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-27T10:00:20Z'
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

# T-3199: t100195 diverged-fork suite has been red since T-3094 added days= to the finding format

## Context

`tests/unit/t100195_diverged_fork.bats` has 2 of 5 tests red. Reproduced
2026-08-27 before any edit:

```
not ok 1 hygiene: branch ahead>threshold AND behind>threshold → diverged-fork
not ok 2 hygiene: small-ahead branch behind>threshold → behind-threshold
```

**The title's diagnosis is incomplete — measured, not assumed.** T-3094's
`days=` field is the *second* cause. The dominant one is T-3094's other half:
the recency gate at `lib/branch-hygiene.sh:175`.

```
_days=$(_bh_days_since_commit "$repo" "refs/heads/$br")
if [ -n "$_days" ] && [ "$_days" -lt "$stale_days" ]; then continue; fi
```

Every commit in a bats fixture is made *now*, so `_days=0`, which is `< 30`
(`FW_BRANCH_STALE_DAYS` default). The branch is skipped before either finding
is reached. The suite is not asserting on a changed string — it is asserting
against **empty output**. Probe:

```
FW_BRANCH_BEHIND_WARN=2                        fw_branch_hygiene $FIX  →  (nothing)
FW_BRANCH_BEHIND_WARN=2 FW_BRANCH_STALE_DAYS=0 fw_branch_hygiene $FIX  →  diverged-fork fork-feat ahead=3 behind=3 days=0 (threshold 2)
```

So the fix is two-part, and a one-part fix stays red: neutralise the recency
gate in the fixture (`FW_BRANCH_STALE_DAYS=0`) *and* pin the current
`days=<n>` format. Repairing only the format leaves the tests comparing
against no output at all.

This matters beyond the two tests. The recency gate makes **every fresh
fixture invisible** to `fw_branch_hygiene`'s all-branches scan, so any future
test of that function silently exercises the `continue` path unless it opts
out. That is the false-green shape: a suite that looks like it covers the scan
and covers nothing.

Scope: release-train branch model — this is the guard that polices which
branches are stranded.

## Acceptance Criteria

### Agent
- [x] Red state reproduced and root cause measured BEFORE any edit: probe shows
      `fw_branch_hygiene` emits nothing on a fresh fixture at the default
      `FW_BRANCH_STALE_DAYS`, and emits the `days=` finding at 0
- [x] `tests/unit/t100195_diverged_fork.bats` runs with zero failures (6 tests —
      the 5 originals plus the recency-gate pin this task adds)
- [x] Both repaired assertions still pin the finding format exactly — anchored
      `^...$`, `days=` present. No assertion is loosened to a bare substring
- [x] Mutation-tested: with the fix in place, breaking the emission in
      `lib/branch-hygiene.sh` reddens the repaired tests. Which mutation reddened
      which test is recorded in `## RCA`
- [x] The recency-gate trap is documented in the suite header, so the next author
      of a `fw_branch_hygiene` test does not silently re-enter the `continue` path
- [x] `lib/branch-hygiene.sh` is unmodified by this task — test-side defect
      (`git diff --stat` names no lib file)
- [x] The five inert `! cmd` assertions found while mutation-testing are converted
      to the `if <cmd>; then false; fi` form, and a mutation proves each converted
      assertion now fires

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

bash -n lib/branch-hygiene.sh
out=$(timeout 300 bats tests/unit/t100195_diverged_fork.bats 2>&1); echo "$out" | grep -q "^ok 6" && ! echo "$out" | grep -q "^not ok"
grep -q "days=" tests/unit/t100195_diverged_fork.bats
grep -q "FW_BRANCH_STALE_DAYS" tests/unit/t100195_diverged_fork.bats
test -z "$(git diff --stat -- lib/branch-hygiene.sh)"

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

**Symptom:** `tests/unit/t100195_diverged_fork.bats` 2 of 5 red since T-3094.

**Root cause — two, where the task title named one.** T-3094 made two changes
in one commit and the filed diagnosis caught only the second:

1. **A recency gate** (`lib/branch-hygiene.sh:175`) that skips any branch whose
   last commit is newer than `FW_BRANCH_STALE_DAYS` (default 30). Every commit a
   bats fixture makes is seconds old, so the fixture branch is skipped and the
   scan emits **nothing at all**. This is the dominant cause: the tests were not
   comparing against a changed string, they were comparing against empty output.
2. **A `days=<n>` field** inserted into both finding formats, which the anchored
   `^...$` patterns could no longer match.

Fixing only (2) — what the title prescribed — leaves both tests red.

**Why structurally allowed:** the suite is in no gate's path, so red is
indistinguishable from unrun. Sibling to T-3195 (same week, same shape,
different cause: a harness that had silently unpinned itself).

**The second defect, found by mutation and not by reading.** Mutation M2
(delete the recency gate) left the entire repaired suite green. The assertion
that should have caught it was `! echo "$output" | grep -q "fresh-fork"`, and
**`! cmd` does not fail a bats test**. POSIX: *"the -e setting shall be ignored
when executing … any command preceded by `!`"*. bats reads only the last
command's status, so a negated assertion mid-body aborts nothing. Measured in
an isolated two-test file rather than inferred:

```
{ output="PRESENT"; ! echo "$output" | grep -q PRESENT; true; }                    → ok       (inert)
{ output="PRESENT"; if echo "$output" | grep -q PRESENT; then false; fi; true; }   → not ok   (fires)
```

Five assertions in this file were in the inert form — four pre-existing, one I
had just written. All five converted to `if <cmd>; then false; fi`. Note test 5
already used the correct form, so the file contained both spellings and looked
internally consistent to a reader who was not counting.

**Mutation battery** (each applied to `lib/branch-hygiene.sh`, then reverted;
`git diff --stat` verified clean after every one):

| Mutation | Reddened |
|---|---|
| M1 — drop `days=` from the `diverged-fork` line | tests 1, 6 |
| M2 — delete the recency gate (`if false; then continue`) | test 6 **only after the negation fix; nothing before** |
| M3 — emit `behind-threshold` where `diverged-fork` belongs | tests 1, 6 |
| M4 — `fw_branch_divergence` emits `nudge` instead of `fork` | test 3 |
| M5b — `behind-threshold` branch also emits `diverged-fork $br` | test 2 (converted negation) |
| M6 — emit `fork` alongside `nudge` | test 4 (converted negation) |

M5's first attempt reddened nothing because the perl one-liner interpolated
`$br` as an empty Perl variable and emitted `diverged-fork  BOGUS` with no
branch name — a malformed mutation, not a passing test. Re-run via awk with the
literal preserved, it reddened test 2. Worth recording: a mutation that fails to
mutate is a false green about the test, in exactly the way the test is a false
green about the code.

**Prevention:** (a) the suite header now documents both traps — the recency gate
and the inert `!` — at the point of use; (b) test 6 pins the recency gate as
covered behaviour with an explicit control leg, so "suppressed by recency" and
"emits nothing ever" are no longer the same observation; (c) the structural
catch for the negation class is a lint wired into a gate, which is **T-3191**
and already filed — this task does not duplicate it. No new task filed.

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

### 2026-08-27T09:56:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3199-t100195-diverged-fork-suite-has-been-red.md
- **Context:** Initial task creation

### 2026-08-27T21:15:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-67c1940c
- **Timestamp:** 2026-08-27T21:22:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-27T21:22:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
